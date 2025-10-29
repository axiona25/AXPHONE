#!/usr/bin/env python
"""
Script per monitorare in tempo reale l'arrivo delle chiavi E2EE
Esegui: python monitor_e2e_keys.py
"""

import os
import sys
import time
import django
from datetime import datetime

# Setup Django
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'settings')
django.setup()

from api.models import User, UserStatus

def clear_screen():
    """Pulisce lo schermo del terminale"""
    os.system('clear' if os.name != 'nt' else 'cls')

def format_timestamp(dt):
    """Formatta timestamp in modo leggibile"""
    if not dt:
        return "Mai"
    return dt.strftime("%H:%M:%S")

def get_users_e2e_status():
    """Ottiene lo stato E2EE di tutti gli utenti"""
    users = User.objects.all().order_by('id')
    status_list = []
    
    for user in users:
        try:
            status = UserStatus.objects.get(user=user)
            status_list.append({
                'id': user.id,
                'username': user.username,
                'e2e_enabled': status.e2e_enabled,
                'has_key': bool(status.e2e_public_key),
                'force_disabled': status.e2e_force_disabled,
                'is_online': status.status == 'online' and status.is_logged_in,
                'last_activity': status.last_activity,
                'key_length': len(status.e2e_public_key) if status.e2e_public_key else 0,
            })
        except UserStatus.DoesNotExist:
            status_list.append({
                'id': user.id,
                'username': user.username,
                'e2e_enabled': False,
                'has_key': False,
                'force_disabled': False,
                'is_online': False,
                'last_activity': None,
                'key_length': 0,
            })
    
    return status_list

def display_status(previous_status=None):
    """Mostra lo stato corrente e evidenzia i cambiamenti"""
    clear_screen()
    
    print("=" * 80)
    print("🔐 MONITOR E2EE - CHIAVI PUBBLICHE IN TEMPO REALE")
    print("=" * 80)
    print(f"⏰ Aggiornato: {datetime.now().strftime('%H:%M:%S')}")
    print("💡 Premi Ctrl+C per uscire")
    print("=" * 80)
    print()
    
    current_status = get_users_e2e_status()
    
    # Header tabella
    print(f"{'ID':<4} {'Username':<20} {'Online':<8} {'E2EE':<6} {'Chiave':<8} {'Bytes':<10} {'Ultimo aggiornamento'}")
    print("-" * 80)
    
    # Dati utenti
    for user_status in current_status:
        user_id = user_status['id']
        username = user_status['username'][:20]
        is_online = "🟢 SI" if user_status['is_online'] else "⚫ NO"
        e2e_enabled = "✅" if user_status['e2e_enabled'] else "❌"
        
        # Evidenzia i cambiamenti
        has_key_changed = False
        if previous_status:
            prev = next((u for u in previous_status if u['id'] == user_id), None)
            if prev and not prev['has_key'] and user_status['has_key']:
                has_key_changed = True
        
        if user_status['force_disabled']:
            has_key_status = "⛔ ADMIN"
        elif user_status['has_key']:
            if has_key_changed:
                has_key_status = "🎉 NUOVO!"
            else:
                has_key_status = "✅ SI"
        else:
            has_key_status = "❌ NO"
        
        key_length = str(user_status['key_length']) if user_status['has_key'] else "-"
        last_activity = format_timestamp(user_status['last_activity'])
        
        # Colora la riga se la chiave è appena arrivata
        if has_key_changed:
            print(f"\033[92m{user_id:<4} {username:<20} {is_online:<8} {e2e_enabled:<6} {has_key_status:<8} {key_length:<10} {last_activity}\033[0m")
        else:
            print(f"{user_id:<4} {username:<20} {is_online:<8} {e2e_enabled:<6} {has_key_status:<8} {key_length:<10} {last_activity}")
    
    print()
    print("=" * 80)
    
    # Statistiche
    total_users = len(current_status)
    users_with_keys = sum(1 for u in current_status if u['has_key'])
    users_online = sum(1 for u in current_status if u['is_online'])
    
    print(f"📊 Statistiche:")
    print(f"   Totale utenti: {total_users}")
    print(f"   Utenti online: {users_online}")
    print(f"   Con chiave E2EE: {users_with_keys}/{total_users}")
    print(f"   Percentuale copertura: {(users_with_keys/total_users*100):.1f}%")
    print("=" * 80)
    
    return current_status

def main():
    """Loop principale di monitoraggio"""
    print("\n🔐 Avvio monitor E2EE...\n")
    time.sleep(1)
    
    previous_status = None
    
    try:
        while True:
            previous_status = display_status(previous_status)
            time.sleep(2)  # Aggiorna ogni 2 secondi
            
    except KeyboardInterrupt:
        print("\n\n✅ Monitor interrotto dall'utente.")
        print("👋 Arrivederci!\n")
        sys.exit(0)
    except Exception as e:
        print(f"\n\n❌ Errore: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()

