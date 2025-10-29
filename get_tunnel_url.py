#!/usr/bin/env python3
import subprocess
import time
import re

def get_tunnel_url():
    """Ottiene l'URL del tunnel Cloudflare"""
    try:
        # Cerca nei log di cloudflared
        result = subprocess.run(['ps', 'aux'], capture_output=True, text=True)
        lines = result.stdout.split('\n')
        
        for line in lines:
            if 'cloudflared tunnel' in line and '--url' in line:
                print("✅ Tunnel Cloudflare attivo")
                print("🔍 Cerca l'URL nei log di cloudflared...")
                print("💡 L'URL dovrebbe essere simile a: https://xxxxx.trycloudflare.com")
                print("🌐 Controlla il terminale dove hai avviato cloudflared")
                return True
        
        print("❌ Tunnel Cloudflare non trovato")
        return False
        
    except Exception as e:
        print(f"❌ Errore: {e}")
        return False

if __name__ == "__main__":
    get_tunnel_url()
