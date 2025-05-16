# Panduan Integrasi Pemilihan Suara Flutter & Python

## Gambaran Umum

Dokumen ini menjelaskan cara mengintegrasikan dropdown pilihan suara di aplikasi Flutter dengan backend Python yang menggunakan Google Gemini API dengan LiveKit.

## Bagian 1: Modifikasi pada File main.py

Berikut adalah modifikasi yang perlu dilakukan pada file `main.py` di `c:\Users\SYAM\Desktop\agent\main.py`:

```python
import logging
import os
import json

from dotenv import load_dotenv
from google.genai import types

from livekit.agents import (
    Agent,
    AgentSession,
    JobContext,
    RoomInputOptions,
    WorkerOptions,
    cli,
)
from livekit.plugins import google, noise_cancellation

logger = logging.getLogger("vision-assistant")

load_dotenv()

# Fungsi untuk mendapatkan preferensi suara
def get_voice_preference():
    """Membaca preferensi suara dari shared preferences atau file konfigurasi"""
    default_voice = "Kore"
    app_id = "com.netrai.v3"  # Ganti dengan ID aplikasi Flutter yang sesuai
    
    # Daftar suara yang valid
    valid_voices = ["Puck", "Charon", "Kore", "Fenrir", "Aoede", "Leda", "Orus", "Zephyr"]
    
    try:
        # Cek file konfigurasi lokal terlebih dahulu
        if os.path.exists("voice_config.json"):
            with open("voice_config.json", 'r') as f:
                config = json.load(f)
                if "selected_voice" in config and config["selected_voice"] in valid_voices:
                    return config["selected_voice"]
        
        # Coba baca dari shared_preferences Flutter
        possible_paths = [
            os.path.expanduser(f"~/.local/share/{app_id}/shared_preferences.json"),
            os.path.expanduser(f"~/AppData/Local/{app_id}/shared_preferences.json"),
            os.path.expanduser(f"~/Library/Application Support/{app_id}/shared_preferences.json"),
            # Path khusus untuk Android (dapat berubah tergantung perangkat)
            f"/data/data/{app_id}/shared_prefs/FlutterSharedPreferences.xml"
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                with open(path, 'r') as f:
                    content = f.read()
                    # Jika xml format (Android)
                    if path.endswith('.xml'):
                        import xml.etree.ElementTree as ET
                        root = ET.fromstring(content)
                        for item in root.findall('.//string'):
                            if "selected_voice_preference" in item.get('name', ''):
                                voice = item.text
                                if voice in valid_voices:
                                    return voice
                    # Jika json format
                    else:
                        prefs = json.loads(content)
                        key = "flutter.selected_voice_preference"
                        if key in prefs and prefs[key] in valid_voices:
                            return prefs[key]
    except Exception as e:
        logger.warning(f"Error membaca preferensi suara: {e}")
    
    return default_voice  # Default ke Kore jika tidak ditemukan

class VisionAssistant(Agent):
    def __init__(self) -> None:
        # Ambil preferensi suara
        selected_voice = get_voice_preference()
        logger.info(f"Menggunakan suara: {selected_voice}")
        
        super().__init__(
            instructions="""
            # Instruksi asisten...
            """,
            llm=google.beta.realtime.RealtimeModel(
                voice=selected_voice,  # Gunakan suara yang dipilih
                temperature=0.8,
            ),
        )

    # ...kode lainnya...
```

## Bagian 2: File Konfigurasi JSON

Buat file konfigurasi `voice_config.json` di folder yang sama dengan `main.py`:

```json
{
  "selected_voice": "Kore"
}
```

## Bagian 3: Mekanisme Komunikasi Flutter → Python

### Opsi 1: Berbagi Preferensi melalui File

Karena aplikasi Flutter dan Python berjalan di lingkungan yang sama, Anda dapat menggunakan file konfigurasi bersama. Modifikasi `settings_screen.dart` untuk menulis ke file konfigurasi selain Shared Preferences:

```dart
Future<void> _updateVoiceConfig(String voiceName) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final configPath = '${directory.path}/voice_config.json';
    final configFile = File(configPath);
    
    // Tulis ke file konfigurasi yang bisa dibaca Python
    await configFile.writeAsString(
      jsonEncode({'selected_voice': voiceName})
    );
    
    // Juga simpan di SharedPreferences seperti biasa
    _saveStringPreference(_selectedVoiceKey, voiceName);
  } catch (e) {
    print("Gagal menyimpan konfigurasi suara: $e");
  }
}
```

Dalam fungsi `onChanged` di dropdown suara:

```dart
onChanged: (String? newValue) {
  if (newValue != null) {
    setState(() {
      _selectedVoice = newValue;
    });
    _saveStringPreference(_selectedVoiceKey, newValue);
    _updateVoiceConfig(newValue); // Tambahkan ini
  }
},
```

### Opsi 2: REST API Sederhana

Anda juga bisa membuat REST API sederhana yang dijalankan bersama dengan aplikasi Python untuk menerima perubahan suara dari aplikasi Flutter.

Tambahkan Flask ke aplikasi Python:

```python
from flask import Flask, request, jsonify
import threading

app = Flask(__name__)

@app.route('/set-voice', methods=['POST'])
def set_voice():
    data = request.json
    voice = data.get('voice')
    
    if voice in ["Puck", "Charon", "Kore", "Fenrir", "Aoede", "Leda", "Orus", "Zephyr"]:
        # Simpan ke file konfigurasi
        with open("voice_config.json", "w") as f:
            json.dump({"selected_voice": voice}, f)
        return jsonify({"success": True})
    else:
        return jsonify({"success": False, "error": "Invalid voice"})

# Jalankan Flask di thread terpisah
def run_flask():
    app.run(host='0.0.0.0', port=5000)

# Di main
flask_thread = threading.Thread(target=run_flask)
flask_thread.daemon = True
flask_thread.start()
```

### Opsi 3: Fitur Command Line

Tambahkan metode command line pada aplikasi Python dan panggil dari Flutter menggunakan `Process.run()`:

```dart
Future<void> _setVoiceWithPython(String voice) async {
  try {
    final result = await Process.run(
      'python', 
      ['c:/Users/SYAM/Desktop/agent/main.py', '--set-voice', voice]
    );
    if (result.exitCode == 0) {
      print("Berhasil mengatur suara melalui Python");
    } else {
      print("Gagal mengatur suara: ${result.stderr}");
    }
  } catch (e) {
    print("Error: $e");
  }
}
```

## Kesimpulan

Solusi terbaik tergantung pada arsitektur aplikasi Anda:

1. Jika kedua aplikasi berjalan di mesin yang sama: gunakan file konfigurasi bersama
2. Jika aplikasi Python berjalan sebagai server: gunakan REST API
3. Jika aplikasi Python dijalankan oleh aplikasi Flutter: gunakan command line arguments

Impor paket yang diperlukan untuk opsi yang dipilih. 