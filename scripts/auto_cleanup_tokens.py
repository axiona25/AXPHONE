#!/usr/bin/env python3
"""
Script automatico per pulire token durante sviluppo
Viene chiamato automaticamente quando l'app Flutter viene fermata/ricompilata
"""

import os
import sys
import sqlite3
import json
import requests
from datetime import datetime, timedelta

# Percorsi
DB_PATH = '/Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server/securevox.db'
FLUTTER_APP_PATH = '/Users/r.amoroso/Desktop/securevox-complete-cursor-pack/mobile/securevox_app'
API_BASE_URL = 'http://127.0.0.1:8000/api'

def cleanup_expired_tokens():
    """Pulisce TUTTI i token per forzare re-login durante sviluppo"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # SVILUPPO: Elimina TUTTI i token per forzare re-login universale
        cursor.execute("DELETE FROM authtoken_token")
        deleted_auth_tokens = cursor.rowcount
        
        # Elimina anche tutte le sessioni Django
        try:
            cursor.execute("DELETE FROM django_session")
            deleted_sessions = cursor.rowcount
        except:
            deleted_sessions = 0
        
        # Elimina anche eventuali AuthToken personalizzati
        try:
            cursor.execute("DELETE FROM api_authtoken")
            deleted_custom_tokens = cursor.rowcount
        except:
            deleted_custom_tokens = 0
        
        conn.commit()
        conn.close()
        
        print(f"🧹 Token cleanup COMPLETO: {deleted_auth_tokens} auth token, {deleted_sessions} sessioni Django, {deleted_custom_tokens} token personalizzati eliminati")
        print("🔄 TUTTI gli utenti dovranno fare login di nuovo")
        return True
        
    except Exception as e:
        print(f"❌ Errore cleanup token: {e}")
        return False

def reset_user_online_status():
    """Reset stato online di tutti gli utenti"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Reset stato online (se la tabella esiste)
        try:
            cursor.execute("""
                UPDATE api_userstatus 
                SET is_online = 0, last_seen = ?
                WHERE is_online = 1
            """, (datetime.now().isoformat(),))
            
            updated_users = cursor.rowcount
        except:
            # Tabella potrebbe non esistere
            updated_users = 0
        
        conn.commit()
        conn.close()
        
        print(f"👥 Status reset: {updated_users} utenti impostati offline")
        return True
        
    except Exception as e:
        print(f"❌ Errore reset status: {e}")
        return False

def cleanup_old_calls():
    """Pulisce chiamate vecchie in stato ringing"""
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        # Elimina chiamate in ringing più vecchie di 10 minuti
        cutoff_time = datetime.now() - timedelta(minutes=10)
        
        cursor.execute("""
            DELETE FROM api_call 
            WHERE status = 'ringing' AND created_at < ?
        """, (cutoff_time.isoformat(),))
        
        deleted_calls = cursor.rowcount
        
        conn.commit()
        conn.close()
        
        print(f"📞 Calls cleanup: {deleted_calls} chiamate vecchie eliminate")
        return True
        
    except Exception as e:
        print(f"❌ Errore cleanup calls: {e}")
        return False

def cleanup_all_active_calls():
    """Cleanup tutte le chiamate attive tramite API"""
    try:
        print("🧹 Pulizia tutte le chiamate attive tramite API...")
        
        response = requests.post(f"{API_BASE_URL}/webrtc/calls/cleanup-all-calls/", json={
            "reason": "auto_cleanup_script",
            "cleanup_type": "development_cleanup"
        }, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            calls_cleaned = data.get('calls_cleaned', 0)
            print(f"✅ Cleanup chiamate riuscito: {calls_cleaned} chiamate terminate")
            return True
        else:
            print(f"❌ Cleanup chiamate fallito: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Errore cleanup chiamate: {e}")
        return False

def force_logout_all_via_api():
    """Forza logout di tutti gli utenti tramite API Django"""
    try:
        print("🔄 Forzando logout di tutti gli utenti tramite API...")
        
        response = requests.post(f"{API_BASE_URL}/dev/force-logout-all/", timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            if data.get('success'):
                stats = data.get('stats', {})
                print(f"✅ Force logout API: {stats.get('auth_tokens_deleted', 0)} token, {stats.get('users_logged_out', 0)} utenti disconnessi")
                return True
            else:
                print(f"❌ Force logout API fallito: {data.get('error', 'Errore sconosciuto')}")
                return False
        else:
            print(f"❌ Force logout API - Status code: {response.status_code}")
            return False
            
    except requests.exceptions.ConnectionError:
        print("⚠️ Server Django non raggiungibile - uso cleanup diretto DB")
        return False
    except Exception as e:
        print(f"❌ Errore force logout API: {e}")
        return False

def main():
    """Esegue pulizia completa per sviluppo"""
    print("🧹 === AUTO CLEANUP SVILUPPO ===")
    print(f"⏰ Timestamp: {datetime.now().isoformat()}")
    print()
    
    # 1. Cleanup TUTTE le chiamate attive (NUOVO!)
    print("1️⃣ Pulizia TUTTE le chiamate attive...")
    cleanup_all_active_calls()
    
    # 2. Prova prima con API (più pulito)
    print("\n2️⃣ Tentativo force logout tramite API Django...")
    api_success = force_logout_all_via_api()
    
    if not api_success:
        print("\n3️⃣ Fallback: Cleanup diretto database...")
        # Fallback su cleanup diretto
        cleanup_expired_tokens()
        reset_user_online_status()
    
    # 4. Cleanup chiamate vecchie (ridondante ma sicuro)
    print("\n4️⃣ Pulizia chiamate vecchie...")
    cleanup_old_calls()
    
    print("\n✅ === CLEANUP COMPLETATO ===")
    print("🔄 TUTTI gli utenti dovranno fare login di nuovo")
    print("📱 L'app può ora riavviarsi con stato completamente pulito")

if __name__ == "__main__":
    main()
