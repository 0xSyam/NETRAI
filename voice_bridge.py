#!/usr/bin/env python
"""
Voice Bridge - Script untuk menghubungkan pilihan suara Flutter dengan aplikasi Python

Cara penggunaan:
1. Jalankan sebagai server: python voice_bridge.py server
2. Set suara: python voice_bridge.py set <nama_suara>
3. Dapatkan suara sekarang: python voice_bridge.py get
"""

import os
import sys
import json
import logging
import argparse
from flask import Flask, request, jsonify
import threading

# Konfigurasi logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("voice-bridge")

# Pilihan suara yang tersedia
VALID_VOICES = ["Puck", "Charon", "Kore", "Fenrir", "Aoede", "Leda", "Orus", "Zephyr"]

# File konfigurasi untuk menyimpan preferensi suara
CONFIG_FILE = "voice_config.json"

app = Flask(__name__)

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
    except Exception as e:
        logger.warning(f"Error membaca preferensi suara: {e}")
    
    return "Kore"  # Default ke Kore jika tidak ditemukan

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

@app.route('/api/voice', methods=['GET'])
def get_voice():
    """API endpoint untuk mendapatkan suara yang digunakan saat ini"""
    voice = get_voice_preference()
    return jsonify({
        "success": True,
        "voice": voice,
        "available_voices": VALID_VOICES
    })

@app.route('/api/voice', methods=['POST'])
def set_voice():
    """API endpoint untuk mengatur suara"""
    data = request.json
    voice = data.get('voice')
    
    if not voice:
        return jsonify({"success": False, "error": "Parameter 'voice' diperlukan"}), 400
    
    if voice not in VALID_VOICES:
        return jsonify({
            "success": False, 
            "error": f"Suara tidak valid. Pilihan yang tersedia: {', '.join(VALID_VOICES)}"
        }), 400
    
    try:
        set_voice_preference(voice)
        return jsonify({"success": True, "voice": voice})
    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500

def run_server(host='0.0.0.0', port=5000):
    """Jalankan server Flask"""
    logger.info(f"Menjalankan server pada http://{host}:{port}")
    app.run(host=host, port=port)

def main():
    parser = argparse.ArgumentParser(description='Voice Bridge - Flutter ke Python')
    subparsers = parser.add_subparsers(dest='command', help='Perintah')
    
    # Perintah server
    server_parser = subparsers.add_parser('server', help='Jalankan server HTTP')
    server_parser.add_argument('--host', default='0.0.0.0', help='Host untuk server (default: 0.0.0.0)')
    server_parser.add_argument('--port', type=int, default=5000, help='Port untuk server (default: 5000)')
    
    # Perintah set
    set_parser = subparsers.add_parser('set', help='Atur suara')
    set_parser.add_argument('voice', choices=VALID_VOICES, help='Nama suara')
    
    # Perintah get
    subparsers.add_parser('get', help='Dapatkan suara yang digunakan saat ini')
    
    # Perintah list
    subparsers.add_parser('list', help='Tampilkan semua suara yang tersedia')
    
    args = parser.parse_args()
    
    if args.command == 'server':
        run_server(host=args.host, port=args.port)
    elif args.command == 'set':
        try:
            set_voice_preference(args.voice)
            print(f"Suara diatur ke: {args.voice}")
        except Exception as e:
            print(f"Error: {e}")
            sys.exit(1)
    elif args.command == 'get':
        voice = get_voice_preference()
        print(f"Suara yang digunakan saat ini: {voice}")
    elif args.command == 'list':
        print("Pilihan suara yang tersedia:")
        for voice in VALID_VOICES:
            print(f"  - {voice}")
    else:
        parser.print_help()

if __name__ == '__main__':
    main() 