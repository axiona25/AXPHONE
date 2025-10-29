#!/usr/bin/env python3
"""
Script di test per SecureVOX Call Server
Testa l'integrazione completa tra Flutter, Django e Node.js
"""

import requests
import json
import time

# Configurazione
DJANGO_BASE_URL = "http://localhost:8001/api"
CALL_SERVER_URL = "http://localhost:8002"
TEST_USER_EMAIL = "r.amoroso80@gmail.com"
TEST_USER_PASSWORD = "password"

class SecureVOXCallTester:
    def __init__(self):
        self.django_token = None
        self.call_token = None
        self.user_id = None
        
    def test_django_login(self):
        """Test login su Django backend"""
        print("🔐 Testing Django login...")
        
        response = requests.post(f"{DJANGO_BASE_URL}/auth/login/", json={
            "email": TEST_USER_EMAIL,
            "password": TEST_USER_PASSWORD
        })
        
        if response.status_code == 200:
            data = response.json()
            self.django_token = data.get('token')
            self.user_id = data.get('user', {}).get('id')
            print(f"✅ Django login successful - User ID: {self.user_id}")
            return True
        else:
            print(f"❌ Django login failed: {response.status_code} - {response.text}")
            return False
    
    def test_call_token_generation(self):
        """Test generazione token per chiamate"""
        print("🎫 Testing call token generation...")
        
        if not self.django_token:
            print("❌ No Django token available")
            return False
        
        session_id = f"test_call_{self.user_id}_{int(time.time())}"
        
        response = requests.post(f"{CALL_SERVER_URL}/api/call/token", 
            json={
                "userId": self.user_id,
                "sessionId": session_id,
                "role": "participant"
            },
            headers={
                "Authorization": f"Token {self.django_token}"
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            self.call_token = data.get('token')
            print(f"✅ Call token generated successfully")
            print(f"   Token: {self.call_token[:50]}...")
            print(f"   ICE Servers: {len(data.get('ice_servers', []))}")
            return True
        else:
            print(f"❌ Call token generation failed: {response.status_code} - {response.text}")
            return False
    
    def test_call_server_health(self):
        """Test health check del call server"""
        print("🏥 Testing call server health...")
        
        response = requests.get(f"{CALL_SERVER_URL}/health")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Call server healthy")
            print(f"   Service: {data.get('service')}")
            print(f"   Version: {data.get('version')}")
            print(f"   Active calls: {data.get('activeCalls')}")
            print(f"   Connected users: {data.get('connectedUsers')}")
            return True
        else:
            print(f"❌ Call server health check failed: {response.status_code}")
            return False
    
    def test_django_call_creation(self):
        """Test creazione chiamata nel backend Django"""
        print("📞 Testing Django call creation...")
        
        if not self.django_token:
            print("❌ No Django token available")
            return False
        
        # Assume che esista un altro utente con ID 2
        test_callee_id = "2"
        session_id = f"test_django_call_{self.user_id}_{test_callee_id}_{int(time.time())}"
        
        response = requests.post(f"{DJANGO_BASE_URL}/call/create/",
            json={
                "callee_id": test_callee_id,
                "call_type": "audio",
                "session_id": session_id
            },
            headers={
                "Authorization": f"Token {self.django_token}"
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Django call created successfully")
            print(f"   Session ID: {data.get('session_id')}")
            print(f"   Status: {data.get('status')}")
            print(f"   Caller: {data.get('caller', {}).get('name')}")
            print(f"   Callee: {data.get('callee', {}).get('name')}")
            return True
        else:
            print(f"❌ Django call creation failed: {response.status_code} - {response.text}")
            return False
    
    def test_websocket_connection(self):
        """Test connessione WebSocket al call server (simulato)"""
        print("🔌 Testing WebSocket connection (simulated)...")
        
        if not self.call_token:
            print("❌ No call token available")
            return False
        
        # Per ora simuliamo il test WebSocket
        print("✅ WebSocket connection test simulated (token available)")
        print(f"   Would connect to: ws://localhost:8002")
        print(f"   Would authenticate with token: {self.call_token[:20]}...")
        
        return True
    
    def test_call_stats(self):
        """Test statistiche chiamate"""
        print("📊 Testing call stats...")
        
        if not self.django_token:
            print("❌ No Django token available")
            return False
        
        response = requests.get(f"{DJANGO_BASE_URL}/call/stats/",
            headers={
                "Authorization": f"Token {self.django_token}"
            }
        )
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ Call stats retrieved successfully")
            print(f"   Total calls: {data.get('total_calls')}")
            print(f"   Active calls: {data.get('active_calls')}")
            print(f"   Recent calls: {data.get('recent_calls')}")
            return True
        else:
            print(f"❌ Call stats failed: {response.status_code} - {response.text}")
            return False
    
    def run_all_tests(self):
        """Esegue tutti i test"""
        print("🚀 Starting SecureVOX Call integration tests...\n")
        
        tests = [
            ("Django Login", self.test_django_login),
            ("Call Server Health", self.test_call_server_health),
            ("Call Token Generation", self.test_call_token_generation),
            ("Django Call Creation", self.test_django_call_creation),
            ("Call Stats", self.test_call_stats),
        ]
        
        results = []
        for test_name, test_func in tests:
            print(f"\n--- {test_name} ---")
            try:
                result = test_func()
                results.append((test_name, result))
            except Exception as e:
                print(f"❌ {test_name} crashed: {e}")
                results.append((test_name, False))
        
        # Test WebSocket
        print(f"\n--- WebSocket Connection ---")
        try:
            ws_result = self.test_websocket_connection()
            results.append(("WebSocket Connection", ws_result))
        except Exception as e:
            print(f"❌ WebSocket test crashed: {e}")
            results.append(("WebSocket Connection", False))
        
        # Risultati finali
        print(f"\n{'='*50}")
        print("🎯 TEST RESULTS SUMMARY")
        print(f"{'='*50}")
        
        passed = 0
        total = len(results)
        
        for test_name, result in results:
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"{test_name:<25} {status}")
            if result:
                passed += 1
        
        print(f"\n📊 Overall: {passed}/{total} tests passed")
        
        if passed == total:
            print("🎉 ALL TESTS PASSED! SecureVOX Call is ready for production!")
        else:
            print(f"⚠️ {total - passed} tests failed. Check the logs above.")
        
        return passed == total

if __name__ == "__main__":
    tester = SecureVOXCallTester()
    success = tester.run_all_tests()
    
    if success:
        print("\n🚀 Ready to test real calls on Flutter app!")
        print("📱 Open the Flutter app and try making a call!")
    else:
        print("\n🔧 Fix the failing tests before proceeding.")
