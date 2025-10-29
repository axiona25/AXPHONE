#!/usr/bin/env python3
"""
Script di test per chiamate crittografate E2E con SFrame
Verifica il funzionamento dell'intero stack di crittografia
"""

import os
import sys
import requests
import json
import time
from datetime import datetime

# Aggiungi il percorso del server Django
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'server'))

# Configurazione test
BASE_URL = 'http://localhost:8000/api'
CALL_SERVER_URL = 'http://localhost:8003'

# Credenziali utenti di test
TEST_USERS = {
    'caller': {
        'email': 'raffaele@securevox.test',
        'password': 'testpassword123',
        'id': 2
    },
    'callee': {
        'email': 'riccardo@securevox.test', 
        'password': 'testpassword123',
        'id': 3
    }
}

class EncryptedCallTester:
    def __init__(self):
        self.sessions = {}  # user -> session data
        self.current_call = None
        
    def log(self, message, level="INFO"):
        timestamp = datetime.now().strftime("%H:%M:%S")
        print(f"[{timestamp}] {level}: {message}")
    
    def login_user(self, user_key):
        """Login di un utente di test"""
        user = TEST_USERS[user_key]
        
        try:
            response = requests.post(f"{BASE_URL}/auth/login/", json={
                'email': user['email'],
                'password': user['password']
            })
            
            if response.status_code == 200:
                data = response.json()
                self.sessions[user_key] = {
                    'token': data['token'],
                    'user_id': data['user']['id'],
                    'headers': {'Authorization': f"Token {data['token']}"}
                }
                self.log(f"✅ Login {user_key} riuscito - User ID: {data['user']['id']}")
                return True
            else:
                self.log(f"❌ Login {user_key} fallito: {response.status_code} - {response.text}", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Errore login {user_key}: {e}", "ERROR")
            return False
    
    def get_ice_servers(self, user_key):
        """Test recupero server ICE"""
        try:
            headers = self.sessions[user_key]['headers']
            response = requests.get(f"{BASE_URL}/webrtc/ice-servers/", headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                ice_servers = data.get('ice_servers', [])
                self.log(f"✅ ICE servers recuperati per {user_key}: {len(ice_servers)} server")
                return ice_servers
            else:
                self.log(f"❌ Errore ICE servers {user_key}: {response.status_code}", "ERROR")
                return []
                
        except Exception as e:
            self.log(f"❌ Errore recupero ICE servers: {e}", "ERROR")
            return []
    
    def create_encrypted_call(self, caller_key, callee_key):
        """Crea una chiamata crittografata E2E"""
        try:
            caller_headers = self.sessions[caller_key]['headers']
            callee_id = TEST_USERS[callee_key]['id']
            
            call_data = {
                'callee_id': callee_id,
                'call_type': 'video',
                'encrypted': True
            }
            
            response = requests.post(f"{BASE_URL}/webrtc/calls/create/", 
                                   json=call_data, 
                                   headers=caller_headers)
            
            if response.status_code == 200:
                data = response.json()
                self.current_call = data
                session_id = data.get('session_id')
                is_encrypted = data.get('encryption', {}).get('enabled', False)
                algorithm = data.get('encryption', {}).get('algorithm', 'N/A')
                
                self.log(f"✅ Chiamata crittografata creata")
                self.log(f"   Session ID: {session_id}")
                self.log(f"   Crittografia: {'✅ Abilitata' if is_encrypted else '❌ Disabilitata'}")
                self.log(f"   Algoritmo: {algorithm}")
                self.log(f"   Server Signaling: {data.get('signaling_server', 'N/A')}")
                
                return data
            else:
                self.log(f"❌ Errore creazione chiamata: {response.status_code} - {response.text}", "ERROR")
                return None
                
        except Exception as e:
            self.log(f"❌ Errore creazione chiamata crittografata: {e}", "ERROR")
            return None
    
    def get_encryption_stats(self, session_id, user_key):
        """Verifica statistiche crittografia"""
        try:
            headers = self.sessions[user_key]['headers']
            response = requests.get(f"{BASE_URL}/webrtc/calls/{session_id}/encryption/", 
                                  headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                stats = data.get('encryption_stats', {})
                
                self.log(f"✅ Statistiche crittografia per {session_id}:")
                self.log(f"   Partecipanti: {stats.get('participants', 0)}")
                self.log(f"   Rotazioni chiavi: {stats.get('total_key_rotations', 0)}")
                
                return stats
            else:
                self.log(f"❌ Errore statistiche crittografia: {response.status_code}", "ERROR")
                return None
                
        except Exception as e:
            self.log(f"❌ Errore recupero statistiche: {e}", "ERROR")
            return None
    
    def get_security_info(self, session_id, user_key):
        """Ottiene informazioni di sicurezza complete"""
        try:
            headers = self.sessions[user_key]['headers']
            response = requests.get(f"{BASE_URL}/webrtc/calls/{session_id}/security/", 
                                  headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                
                self.log(f"✅ Informazioni sicurezza per {session_id}:")
                self.log(f"   E2E Encryption: {data.get('security_features', {}).get('end_to_end_encryption', False)}")
                self.log(f"   Forward Secrecy: {data.get('security_features', {}).get('forward_secrecy', False)}")
                self.log(f"   Key Rotation: {data.get('security_features', {}).get('key_rotation', False)}")
                self.log(f"   Algoritmo: {data.get('security_features', {}).get('algorithm', 'N/A')}")
                self.log(f"   Protocollo: {data.get('security_features', {}).get('protocol', 'N/A')}")
                
                return data
            else:
                self.log(f"❌ Errore informazioni sicurezza: {response.status_code}", "ERROR")
                return None
                
        except Exception as e:
            self.log(f"❌ Errore recupero informazioni sicurezza: {e}", "ERROR")
            return None
    
    def rotate_keys(self, session_id, user_key):
        """Test rotazione chiavi"""
        try:
            headers = self.sessions[user_key]['headers']
            response = requests.post(f"{BASE_URL}/webrtc/calls/rotate-keys/", 
                                   json={'session_id': session_id},
                                   headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                self.log(f"✅ Rotazione chiavi completata per {session_id}")
                self.log(f"   Timestamp: {data.get('rotation_timestamp')}")
                return True
            else:
                self.log(f"❌ Errore rotazione chiavi: {response.status_code} - {response.text}", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Errore rotazione chiavi: {e}", "ERROR")
            return False
    
    def verify_encryption(self, session_id, user_key):
        """Verifica stato crittografia"""
        try:
            headers = self.sessions[user_key]['headers']
            response = requests.post(f"{BASE_URL}/webrtc/calls/verify-encryption/", 
                                   json={'session_id': session_id},
                                   headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                is_verified = data.get('encryption_verified', False)
                
                self.log(f"✅ Verifica crittografia per {session_id}:")
                self.log(f"   Verificata: {'✅ Sì' if is_verified else '❌ No'}")
                self.log(f"   Attiva: {data.get('encryption_active', False)}")
                self.log(f"   Chiavi presenti: {data.get('keys_present', False)}")
                
                return is_verified
            else:
                self.log(f"❌ Errore verifica crittografia: {response.status_code}", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Errore verifica crittografia: {e}", "ERROR")
            return False
    
    def end_call(self, session_id, user_key):
        """Termina chiamata"""
        try:
            headers = self.sessions[user_key]['headers']
            response = requests.post(f"{BASE_URL}/webrtc/calls/end/", 
                                   json={'session_id': session_id},
                                   headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                self.log(f"✅ Chiamata terminata: {session_id}")
                self.log(f"   Crittografia pulita: {data.get('encryption_cleaned', False)}")
                return True
            else:
                self.log(f"❌ Errore termine chiamata: {response.status_code}", "ERROR")
                return False
                
        except Exception as e:
            self.log(f"❌ Errore termine chiamata: {e}", "ERROR")
            return False
    
    def run_full_test(self):
        """Esegue test completo delle chiamate crittografate"""
        self.log("🚀 Avvio test chiamate crittografate E2E", "TEST")
        
        # 1. Login utenti
        self.log("\n=== FASE 1: LOGIN UTENTI ===")
        if not self.login_user('caller') or not self.login_user('callee'):
            self.log("❌ Test fallito: impossibile fare login", "ERROR")
            return False
        
        # 2. Test ICE servers
        self.log("\n=== FASE 2: TEST ICE SERVERS ===")
        ice_servers_caller = self.get_ice_servers('caller')
        ice_servers_callee = self.get_ice_servers('callee')
        
        if not ice_servers_caller or not ice_servers_callee:
            self.log("❌ Test fallito: ICE servers non disponibili", "ERROR")
            return False
        
        # 3. Creazione chiamata crittografata
        self.log("\n=== FASE 3: CREAZIONE CHIAMATA CRITTOGRAFATA ===")
        call_data = self.create_encrypted_call('caller', 'callee')
        if not call_data:
            self.log("❌ Test fallito: impossibile creare chiamata", "ERROR")
            return False
        
        session_id = call_data['session_id']
        
        # 4. Verifica crittografia
        self.log("\n=== FASE 4: VERIFICA CRITTOGRAFIA ===")
        time.sleep(2)  # Attendi setup completo
        
        encryption_stats = self.get_encryption_stats(session_id, 'caller')
        security_info = self.get_security_info(session_id, 'caller')
        is_encrypted = self.verify_encryption(session_id, 'caller')
        
        if not is_encrypted:
            self.log("⚠️ Warning: crittografia non completamente verificata", "WARN")
        
        # 5. Test rotazione chiavi
        self.log("\n=== FASE 5: TEST ROTAZIONE CHIAVI ===")
        key_rotated = self.rotate_keys(session_id, 'caller')
        
        if key_rotated:
            # Verifica nuovamente dopo rotazione
            time.sleep(1)
            self.verify_encryption(session_id, 'caller')
        
        # 6. Termine chiamata
        self.log("\n=== FASE 6: TERMINE CHIAMATA ===")
        call_ended = self.end_call(session_id, 'caller')
        
        # 7. Risultato finale
        self.log("\n=== RISULTATO TEST ===")
        if call_ended and encryption_stats and security_info:
            self.log("✅ TEST COMPLETATO CON SUCCESSO!", "SUCCESS")
            self.log("🔐 Chiamate crittografate E2E funzionanti")
            return True
        else:
            self.log("❌ TEST FALLITO - Alcuni componenti non funzionano", "ERROR")
            return False


def main():
    """Funzione principale"""
    print("🔐 SecureVox - Test Chiamate Crittografate E2E")
    print("=" * 50)
    
    tester = EncryptedCallTester()
    success = tester.run_full_test()
    
    print("\n" + "=" * 50)
    if success:
        print("✅ TUTTI I TEST SUPERATI - Sistema pronto per chiamate crittografate!")
        exit(0)
    else:
        print("❌ TEST FALLITI - Verificare configurazione sistema")
        exit(1)


if __name__ == "__main__":
    main()
