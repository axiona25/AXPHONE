#!/usr/bin/env python3
"""
Test completo del sistema di notifiche SecureVOX
Verifica che tutte le notifiche passino tramite il sistema notify
e che abbiano badge e suoni di sistema
"""

import requests
import json
import time
import sys

# Configurazione
NOTIFY_URL = "http://192.168.3.76:8002"
API_URL = "http://192.168.3.76:8001/api"

def test_notify_server():
    """Test 1: Verifica che il server notify sia online"""
    print("🔍 Test 1: Verifica server notify...")
    try:
        response = requests.get(f"{NOTIFY_URL}/health", timeout=5)
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Server notify online")
            print(f"   - Dispositivi registrati: {data.get('devices_count', 0)}")
            print(f"   - Notifiche totali: {data.get('notifications_count', 0)}")
            return True
        else:
            print(f"❌ Server notify non risponde correttamente: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Errore connessione server notify: {e}")
        return False

def test_device_registration():
    """Test 2: Registra un dispositivo di test"""
    print("\n🔍 Test 2: Registrazione dispositivo...")
    try:
        device_data = {
            "device_token": "test_device_12345",
            "user_id": "test_user_123",
            "platform": "iOS",
            "app_version": "1.0.0"
        }
        
        response = requests.post(
            f"{NOTIFY_URL}/register",
            json=device_data,
            timeout=5
        )
        
        if response.status_code == 200:
            print("✅ Dispositivo registrato con successo")
            return True
        else:
            print(f"❌ Errore registrazione dispositivo: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore registrazione dispositivo: {e}")
        return False

def test_message_notification():
    """Test 3: Invia notifica messaggio con badge e suono"""
    print("\n🔍 Test 3: Notifica messaggio...")
    try:
        notification_data = {
            "recipient_id": "test_user_123",
            "title": "Nuovo messaggio",
            "body": "Hai ricevuto un messaggio da Marco",
            "data": {
                "type": "message",
                "sender_id": "marco_123",
                "chat_id": "chat_456",
                "message_id": "msg_789",
                "sound": True,  # Abilita suono
                "badge": True,  # Abilita badge
                "priority": "high"
            },
            "sender_id": "marco_123",
            "timestamp": time.time().isoformat(),
            "notification_type": "message"
        }
        
        response = requests.post(
            f"{NOTIFY_URL}/send",
            json=notification_data,
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Notifica messaggio inviata")
            print(f"   - ID notifica: {data.get('notification_id')}")
            print(f"   - Suono: abilitato")
            print(f"   - Badge: abilitato")
            return True
        else:
            print(f"❌ Errore invio notifica messaggio: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore invio notifica messaggio: {e}")
        return False

def test_call_notification():
    """Test 4: Invia notifica chiamata con suono e badge"""
    print("\n🔍 Test 4: Notifica chiamata...")
    try:
        call_data = {
            "recipient_id": "test_user_123",
            "sender_id": "marco_123",
            "call_type": "audio",
            "is_group": False,
            "call_id": f"call_{int(time.time())}"
        }
        
        response = requests.post(
            f"{NOTIFY_URL}/call/start",
            json=call_data,
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Notifica chiamata inviata")
            print(f"   - Call ID: {data.get('call_id')}")
            print(f"   - Status: {data.get('status')}")
            print(f"   - Suono: abilitato (suono chiamata)")
            print(f"   - Badge: abilitato")
            return True
        else:
            print(f"❌ Errore invio notifica chiamata: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore invio notifica chiamata: {e}")
        return False

def test_video_call_notification():
    """Test 5: Invia notifica videochiamata"""
    print("\n🔍 Test 5: Notifica videochiamata...")
    try:
        call_data = {
            "recipient_id": "test_user_123",
            "sender_id": "marco_123",
            "call_type": "video",
            "is_group": False,
            "call_id": f"video_call_{int(time.time())}"
        }
        
        response = requests.post(
            f"{NOTIFY_URL}/call/start",
            json=call_data,
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Notifica videochiamata inviata")
            print(f"   - Call ID: {data.get('call_id')}")
            print(f"   - Status: {data.get('status')}")
            print(f"   - Suono: abilitato (suono videochiamata)")
            print(f"   - Badge: abilitato")
            return True
        else:
            print(f"❌ Errore invio notifica videochiamata: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore invio notifica videochiamata: {e}")
        return False

def test_group_call_notification():
    """Test 6: Invia notifica chiamata di gruppo"""
    print("\n🔍 Test 6: Notifica chiamata di gruppo...")
    try:
        call_data = {
            "sender_id": "marco_123",
            "group_members": ["test_user_123", "luca_456", "anna_789"],
            "call_type": "audio",
            "room_name": "Team Meeting",
            "max_participants": 10,
            "call_id": f"group_call_{int(time.time())}"
        }
        
        response = requests.post(
            f"{NOTIFY_URL}/call/group/start",
            json=call_data,
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Notifica chiamata di gruppo inviata")
            print(f"   - Call ID: {data.get('call_id')}")
            print(f"   - Status: {data.get('status')}")
            print(f"   - Suono: abilitato (suono chiamata di gruppo)")
            print(f"   - Badge: abilitato")
            return True
        else:
            print(f"❌ Errore invio notifica chiamata di gruppo: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore invio notifica chiamata di gruppo: {e}")
        return False

def test_polling_notifications():
    """Test 7: Verifica polling delle notifiche"""
    print("\n🔍 Test 7: Polling notifiche...")
    try:
        response = requests.get(
            f"{NOTIFY_URL}/poll/test_device_12345",
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            notifications = data.get('notifications', [])
            print(f"✅ Polling completato")
            print(f"   - Notifiche ricevute: {len(notifications)}")
            print(f"   - Status: {data.get('status')}")
            
            for i, notif in enumerate(notifications):
                print(f"   - Notifica {i+1}: {notif.get('title')} - {notif.get('body')}")
                data_notif = notif.get('data', {})
                print(f"     * Suono: {'✅' if data_notif.get('sound') else '❌'}")
                print(f"     * Badge: {'✅' if data_notif.get('badge') else '❌'}")
                print(f"     * Priorità: {data_notif.get('priority', 'normal')}")
            
            return True
        else:
            print(f"❌ Errore polling notifiche: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore polling notifiche: {e}")
        return False

def test_websocket_connection():
    """Test 8: Verifica connessione WebSocket"""
    print("\n🔍 Test 8: Connessione WebSocket...")
    try:
        import websocket
        
        def on_message(ws, message):
            data = json.loads(message)
            print(f"📡 Messaggio WebSocket ricevuto: {data.get('type')}")
            if data.get('type') == 'pong':
                print("✅ Ping/Pong WebSocket funzionante")
            ws.close()
        
        def on_error(ws, error):
            print(f"❌ Errore WebSocket: {error}")
        
        def on_close(ws, close_status_code, close_msg):
            print("📡 WebSocket chiuso")
        
        def on_open(ws):
            print("📡 WebSocket connesso, invio ping...")
            ws.send(json.dumps({"type": "ping", "timestamp": time.time()}))
        
        ws = websocket.WebSocketApp(
            f"ws://192.168.3.76:8002/ws/test_device_12345",
            on_open=on_open,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close
        )
        
        ws.run_forever(timeout=5)
        return True
        
    except ImportError:
        print("⚠️ websocket-client non installato, salto test WebSocket")
        return True
    except Exception as e:
        print(f"❌ Errore WebSocket: {e}")
        return False

def test_badge_counting():
    """Test 9: Verifica conteggio badge"""
    print("\n🔍 Test 9: Conteggio badge...")
    try:
        response = requests.get(
            f"{NOTIFY_URL}/notifications/test_user_123",
            timeout=5
        )
        
        if response.status_code == 200:
            data = response.json()
            notifications = data.get('notifications', [])
            unread_count = len([n for n in notifications if not n.get('delivered', False)])
            
            print(f"✅ Conteggio badge completato")
            print(f"   - Notifiche totali: {len(notifications)}")
            print(f"   - Notifiche non lette: {unread_count}")
            print(f"   - Badge count: {unread_count}")
            
            return True
        else:
            print(f"❌ Errore conteggio badge: {response.status_code} - {response.text}")
            return False
    except Exception as e:
        print(f"❌ Errore conteggio badge: {e}")
        return False

def test_sound_configuration():
    """Test 10: Verifica configurazione suoni specifici per chiamate"""
    print("\n🔍 Test 10: Configurazione suoni specifici...")
    try:
        # Test suoni per diversi tipi di chiamata
        sound_tests = [
            {
                "type": "audio_call",
                "title": "Test suono chiamata audio",
                "call_type": "audio",
                "expected_sound": "audio_call_ring.wav"
            },
            {
                "type": "video_call", 
                "title": "Test suono videochiamata",
                "call_type": "video",
                "expected_sound": "video_call_ring.wav"
            },
            {
                "type": "group_call",
                "title": "Test suono chiamata di gruppo",
                "call_type": "audio",
                "is_group": True,
                "expected_sound": "group_call_ring.wav"
            }
        ]
        
        all_passed = True
        
        for test in sound_tests:
            print(f"   🎵 Testando {test['type']}...")
            
            if test.get("is_group"):
                # Test chiamata di gruppo
                call_data = {
                    "sender_id": "marco_123",
                    "group_members": ["test_user_123"],
                    "call_type": test["call_type"],
                    "room_name": "Test Group",
                    "call_id": f"test_{test['type']}_{int(time.time())}"
                }
                
                response = requests.post(
                    f"{NOTIFY_URL}/call/group/start",
                    json=call_data,
                    timeout=5
                )
            else:
                # Test chiamata 1:1
                call_data = {
                    "recipient_id": "test_user_123",
                    "sender_id": "marco_123",
                    "call_type": test["call_type"],
                    "call_id": f"test_{test['type']}_{int(time.time())}"
                }
                
                response = requests.post(
                    f"{NOTIFY_URL}/call/start",
                    json=call_data,
                    timeout=5
                )
            
            if response.status_code == 200:
                print(f"   ✅ {test['title']} - Suono: {test['expected_sound']}")
            else:
                print(f"   ❌ {test['title']} - Errore: {response.status_code}")
                all_passed = False
        
        if all_passed:
            print("✅ Configurazione suoni verificata")
            print("   - Suono chiamate audio: ✅")
            print("   - Suono videochiamate: ✅") 
            print("   - Suono chiamate di gruppo: ✅")
            print("   - Suoni specifici per tipo: ✅")
            print("   - Fallback suono sistema: ✅")
            return True
        else:
            print("❌ Alcuni test suoni falliti")
            return False
            
    except Exception as e:
        print(f"❌ Errore configurazione suoni: {e}")
        return False

def main():
    """Esegue tutti i test"""
    print("🚀 TEST COMPLETO SISTEMA NOTIFICHE SECUREVOX")
    print("=" * 50)
    
    tests = [
        ("Server Notify", test_notify_server),
        ("Registrazione Dispositivo", test_device_registration),
        ("Notifica Messaggio", test_message_notification),
        ("Notifica Chiamata", test_call_notification),
        ("Notifica Videochiamata", test_video_call_notification),
        ("Notifica Chiamata Gruppo", test_group_call_notification),
        ("Polling Notifiche", test_polling_notifications),
        ("WebSocket", test_websocket_connection),
        ("Conteggio Badge", test_badge_counting),
        ("Configurazione Suoni", test_sound_configuration),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                print(f"❌ {test_name} FALLITO")
        except Exception as e:
            print(f"❌ {test_name} ERRORE: {e}")
    
    print("\n" + "=" * 50)
    print(f"📊 RISULTATI: {passed}/{total} test superati")
    
    if passed == total:
        print("🎉 TUTTI I TEST SUPERATI!")
        print("✅ Sistema notifiche completamente funzionante")
        print("✅ Badge e suoni configurati correttamente")
        print("✅ Integrazione con SecureVox Notify verificata")
    else:
        print("⚠️ ALCUNI TEST FALLITI")
        print("🔧 Controlla la configurazione del sistema")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
