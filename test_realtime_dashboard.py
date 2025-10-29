#!/usr/bin/env python3
"""
Test script per verificare il funzionamento della dashboard real-time
"""

import requests
import websocket
import json
import time
import sys
from datetime import datetime

def test_http_api():
    """Test delle API HTTP"""
    print("🔍 Test API HTTP...")
    
    try:
        # Test health endpoint
        response = requests.get('http://localhost:8001/admin/api/dashboard-stats-test/', timeout=5)
        if response.status_code == 200:
            print("✅ API Dashboard Stats: OK")
            data = response.json()
            print(f"   📊 Utenti totali: {data.get('stats', {}).get('total_users', 'N/A')}")
        else:
            print(f"❌ API Dashboard Stats: {response.status_code}")
            
        # Test system health
        response = requests.get('http://localhost:8001/admin/api/system-health/', timeout=5)
        if response.status_code == 200:
            print("✅ API System Health: OK")
        else:
            print(f"❌ API System Health: {response.status_code}")
            
    except requests.exceptions.ConnectionError:
        print("❌ Server non raggiungibile su localhost:8001")
        return False
    except Exception as e:
        print(f"❌ Errore API: {e}")
        return False
        
    return True

def test_websocket():
    """Test della connessione WebSocket"""
    print("\n🔌 Test WebSocket...")
    
    messages_received = []
    
    def on_message(ws, message):
        try:
            data = json.loads(message)
            messages_received.append(data)
            print(f"📨 Ricevuto: {data.get('type', 'unknown')}")
            
            # Test specifici per tipo messaggio
            if data.get('type') == 'initial_data':
                print("   ✅ Dati iniziali ricevuti")
            elif data.get('type') == 'dashboard_stats_update':
                print("   ✅ Aggiornamento dashboard ricevuto")
            elif data.get('type') == 'system_health_update':
                print("   ✅ Aggiornamento system health ricevuto")
                
        except json.JSONDecodeError:
            print(f"❌ Messaggio non valido: {message}")
    
    def on_error(ws, error):
        print(f"❌ Errore WebSocket: {error}")
    
    def on_close(ws, close_status_code, close_msg):
        print("🔌 WebSocket chiuso")
    
    def on_open(ws):
        print("✅ WebSocket connesso")
        
        # Richiedi dati iniziali
        ws.send(json.dumps({"type": "request_dashboard_stats"}))
        time.sleep(1)
        ws.send(json.dumps({"type": "request_system_health"}))
    
    try:
        # Connessione WebSocket
        ws_url = "ws://localhost:8001/ws/admin/"
        ws = websocket.WebSocketApp(
            ws_url,
            on_open=on_open,
            on_message=on_message,
            on_error=on_error,
            on_close=on_close
        )
        
        # Timeout di 10 secondi per i test
        ws.run_forever(timeout=10)
        
        if len(messages_received) > 0:
            print(f"✅ WebSocket: {len(messages_received)} messaggi ricevuti")
            return True
        else:
            print("❌ WebSocket: Nessun messaggio ricevuto")
            return False
            
    except Exception as e:
        print(f"❌ Errore WebSocket: {e}")
        return False

def test_redis():
    """Test della connessione Redis"""
    print("\n🔴 Test Redis...")
    
    try:
        import redis
        r = redis.Redis(host='localhost', port=6379, db=0)
        
        # Test ping
        response = r.ping()
        if response:
            print("✅ Redis: Connesso e funzionante")
            
            # Test channel layers
            r.set('test_key', 'test_value')
            value = r.get('test_key')
            if value == b'test_value':
                print("✅ Redis: Lettura/scrittura OK")
                r.delete('test_key')
                return True
            else:
                print("❌ Redis: Errore lettura/scrittura")
                return False
        else:
            print("❌ Redis: Ping fallito")
            return False
            
    except ImportError:
        print("⚠️  Redis Python client non installato")
        return False
    except redis.ConnectionError:
        print("❌ Redis: Connessione fallita")
        return False
    except Exception as e:
        print(f"❌ Redis: Errore {e}")
        return False

def main():
    """Funzione principale di test"""
    print("🛡️ Test SecureVOX Admin Dashboard Real-time")
    print("=" * 50)
    print(f"⏰ Inizio test: {datetime.now().strftime('%H:%M:%S')}")
    print()
    
    results = []
    
    # Test Redis
    results.append(("Redis", test_redis()))
    
    # Test API HTTP
    results.append(("API HTTP", test_http_api()))
    
    # Test WebSocket
    results.append(("WebSocket", test_websocket()))
    
    # Risultati finali
    print("\n" + "=" * 50)
    print("📊 RISULTATI TEST:")
    print("=" * 50)
    
    passed = 0
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name:15} {status}")
        if result:
            passed += 1
    
    print("-" * 50)
    print(f"Totale: {passed}/{total} test passati")
    
    if passed == total:
        print("🎉 Tutti i test sono passati! Dashboard real-time funzionante!")
        sys.exit(0)
    else:
        print("⚠️  Alcuni test sono falliti. Controlla la configurazione.")
        sys.exit(1)

if __name__ == "__main__":
    main()
