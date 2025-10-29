#!/usr/bin/env python3
"""
Script per configurare il dominio e le app mobile per SecureVox
"""

import os
import re
import json

def update_mobile_config():
    """Aggiorna la configurazione delle app mobile per puntare al server pubblico"""
    
    # IP pubblico del server (da aggiornare quando disponibile)
    SERVER_IP = "130.110.3.186"  # IP Oracle Cloud
    DOMAIN = "securevox.it"
    
    print("🔧 Configurazione App Mobile per Server Pubblico")
    print("=" * 50)
    
    # File di configurazione da aggiornare
    config_files = [
        "mobile/securevox_app/lib/services/api_service.dart",
        "mobile/securevox_app/lib/services/webrtc_call_service.dart",
        "mobile/securevox_app/lib/services/app_distribution_service.dart",
        "mobile/securevox_app/lib/services/notification_service.dart",
    ]
    
    # Pattern di sostituzione
    replacements = [
        (r'http://localhost:8001', f'http://{SERVER_IP}:8001'),
        (r'http://localhost:8002', f'http://{SERVER_IP}:8002'),
        (r'http://localhost:8003', f'http://{SERVER_IP}:8003'),
        (r'ws://localhost:8002', f'ws://{SERVER_IP}:8002'),
        (r'ws://localhost:8003', f'ws://{SERVER_IP}:8003'),
    ]
    
    # Se hai un dominio, usa quello invece dell'IP
    if DOMAIN:
        replacements.extend([
            (f'http://{SERVER_IP}:8001', f'https://{DOMAIN}'),
            (f'http://{SERVER_IP}:8002', f'https://{DOMAIN}:8002'),
            (f'http://{SERVER_IP}:8003', f'https://{DOMAIN}:8003'),
            (f'ws://{SERVER_IP}:8002', f'wss://{DOMAIN}:8002'),
            (f'ws://{SERVER_IP}:8003', f'wss://{DOMAIN}:8003'),
        ])
    
    updated_files = 0
    
    for file_path in config_files:
        if os.path.exists(file_path):
            print(f"📱 Aggiornando {file_path}...")
            
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                original_content = content
                
                # Applica le sostituzioni
                for pattern, replacement in replacements:
                    content = re.sub(pattern, replacement, content)
                
                if content != original_content:
                    with open(file_path, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"✅ {file_path} aggiornato")
                    updated_files += 1
                else:
                    print(f"ℹ️  {file_path} già configurato")
                    
            except Exception as e:
                print(f"❌ Errore aggiornando {file_path}: {e}")
        else:
            print(f"⚠️  File non trovato: {file_path}")
    
    print(f"\n📊 File aggiornati: {updated_files}")
    return updated_files > 0

def create_domain_config():
    """Crea file di configurazione per il dominio"""
    
    config = {
        "domain": "securevox.it",
        "server_ip": "130.110.3.186",
        "services": {
            "django_backend": "http://securevox.it:8001",
            "call_server": "http://securevox.it:8002", 
            "notify_server": "http://securevox.it:8003",
            "app_distribution": "http://securevox.it:8001/app-distribution/"
        },
        "mobile_config": {
            "api_base_url": "http://securevox.it:8001",
            "websocket_url": "ws://securevox.it:8002",
            "notify_url": "ws://securevox.it:8003"
        }
    }
    
    config_file = "domain_config.json"
    
    try:
        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2)
        print(f"✅ Configurazione dominio salvata in {config_file}")
        return True
    except Exception as e:
        print(f"❌ Errore salvando configurazione: {e}")
        return False

def main():
    print("🚀 Configurazione Dominio e App Mobile SecureVox")
    print("=" * 60)
    
    # Aggiorna configurazione app mobile
    mobile_updated = update_mobile_config()
    
    # Crea configurazione dominio
    domain_created = create_domain_config()
    
    print("\n📋 PROSSIMI PASSI:")
    print("=" * 30)
    print("1. 🌐 Configura il DNS di securevox.it per puntare a 130.110.3.186")
    print("2. 🔧 Installa SecureVox sul server Oracle Cloud")
    print("3. 📱 Compila le app mobile con la nuova configurazione")
    print("4. 🔒 Configura HTTPS per il dominio")
    
    if mobile_updated:
        print("\n✅ App mobile configurate per il server pubblico")
    else:
        print("\n⚠️  Configurazione app mobile non completata")
    
    if domain_created:
        print("✅ Configurazione dominio creata")
    else:
        print("❌ Errore creando configurazione dominio")

if __name__ == "__main__":
    main()
