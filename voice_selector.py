import os
import json
import sys
import logging

# Konfigurasi logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("voice-selector")

# Pilihan suara yang tersedia
VALID_VOICES = ["Puck", "Charon", "Kore", "Fenrir", "Aoede", "Leda", "Orus", "Zephyr"]

# File konfigurasi untuk menyimpan preferensi suara
CONFIG_FILE = "voice_config.json"

def get_voice_preference():
    """Membaca preferensi suara dari file konfigurasi"""
    try:
        if os.path.exists(CONFIG_FILE):
            with open(CONFIG_FILE, 'r') as f:
                config = json.load(f)
                if "selected_voice" in config:
                    voice = config["selected_voice"]
                    if voice in VALID_VOICES:
                        return voice
        
        # Coba baca dari shared_preferences Flutter jika ada
        app_id = "com.netrai.v3"  # Ganti dengan ID aplikasi Flutter yang sesuai
        
        # Lokasi umum untuk shared_preferences di sistem berbeda
        possible_paths = [
            os.path.expanduser(f"~/.local/share/{app_id}/shared_preferences.json"),
            os.path.expanduser(f"~/AppData/Local/{app_id}/shared_preferences.json"),
            os.path.expanduser(f"~/Library/Application Support/{app_id}/shared_preferences.json")
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                with open(path, 'r') as f:
                    prefs = json.load(f)
                    if "selected_voice_preference" in prefs:
                        voice = prefs["selected_voice_preference"]
                        if voice in VALID_VOICES:
                            return voice
                        break
    except Exception as e:
        logger.warning(f"Error membaca preferensi suara: {e}")
    
    # Default ke Kore jika tidak ditemukan
    return "Kore"

def set_voice_preference(voice):
    """Menyimpan preferensi suara ke file konfigurasi"""
    if voice not in VALID_VOICES:
        raise ValueError(f"Suara '{voice}' tidak valid. Pilihan yang tersedia: {', '.join(VALID_VOICES)}")
    
    try:
        config = {"selected_voice": voice}
        with open(CONFIG_FILE, "w") as f:
            json.dump(config, f)
        logger.info(f"Preferensi suara diatur ke: {voice}")
        return True
    except Exception as e:
        logger.error(f"Gagal menyimpan preferensi suara: {e}")
        return False

def print_current_voice():
    """Menampilkan suara yang dipilih saat ini"""
    voice = get_voice_preference()
    print(f"Suara yang digunakan saat ini: {voice}")

def show_help():
    """Menampilkan bantuan penggunaan"""
    print("Penggunaan voice_selector.py:")
    print("  python voice_selector.py [OPSI]")
    print("")
    print("Opsi:")
    print("  --get         : Menampilkan suara yang digunakan saat ini")
    print("  --set SUARA   : Mengatur suara (SUARA dapat berupa salah satu dari:")
    print(f"                  {', '.join(VALID_VOICES)})")
    print("  --list        : Menampilkan semua pilihan suara yang tersedia")
    print("  --help        : Menampilkan bantuan ini")

if __name__ == "__main__":
    # Tanpa argumen, tampilkan suara saat ini
    if len(sys.argv) == 1:
        print_current_voice()
        sys.exit(0)
        
    # Parse argumen command line
    if sys.argv[1] == "--get":
        print_current_voice()
    elif sys.argv[1] == "--set" and len(sys.argv) > 2:
        voice = sys.argv[2]
        if voice in VALID_VOICES:
            if set_voice_preference(voice):
                print(f"Suara berhasil diatur ke: {voice}")
                sys.exit(0)
            else:
                print("Gagal mengatur suara")
                sys.exit(1)
        else:
            print(f"Error: '{voice}' bukan suara yang valid")
            print(f"Pilihan suara yang tersedia: {', '.join(VALID_VOICES)}")
            sys.exit(1)
    elif sys.argv[1] == "--list":
        print("Pilihan suara yang tersedia:")
        for voice in VALID_VOICES:
            print(f"  - {voice}")
    elif sys.argv[1] == "--help":
        show_help()
    else:
        print("Opsi tidak valid")
        show_help()
        sys.exit(1) 