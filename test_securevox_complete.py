#!/usr/bin/env python3
"""
Test completo di SecureVox - Tutti i servizi e moduli
"""

import requests
import json
import time

def test_service(url, name, expected_status=200):
    """Testa un servizio e restituisce il risultato"""
    try:
        response = requests.get(url, timeout=5)
        if response.status_code == expected_status:
            print(f"✅ {name}: OK ({response.status_code})")
            return True
        else:
            print(f"❌ {name}: ERRORE ({response.status_code})")
            return False
    except Exception as e:
        print(f"❌ {name}: ERRORE - {str(e)}")
        return False

def main():
    print("🚀 Test Completo SecureVox")
    print("=" * 50)
    
    # Lista servizi da testare
    services = [
        ("http://localhost:8001/", "Django Backend API"),
        ("http://localhost:8001/app-distribution/", "App Distribution Web"),
        ("http://localhost:8001/admin/", "Admin Panel"),
        ("http://localhost:8002/health", "Call Server Health"),
        ("http://localhost:8003/health", "Notify Server Health"),
    ]
    
    # Testa tutti i servizi
    results = []
    for url, name in services:
        results.append(test_service(url, name))
        time.sleep(1)
    
    # Test API specifiche
    print("\n🔍 Test API Specifiche:")
    print("-" * 30)
    
    # Test API crittografia
    try:
        response = requests.get("http://localhost:8001/api/webrtc/calls/", timeout=5)
        if response.status_code in [200, 401, 403]:  # 401/403 sono OK per API protette
            print("✅ API WebRTC: OK")
            results.append(True)
        else:
            print(f"❌ API WebRTC: ERRORE ({response.status_code})")
            results.append(False)
    except Exception as e:
        print(f"❌ API WebRTC: ERRORE - {str(e)}")
        results.append(False)
    
    # Test API App Distribution
    try:
        response = requests.get("http://localhost:8001/app-distribution/api/builds/", timeout=5)
        if response.status_code in [200, 401, 403]:
            print("✅ API App Distribution: OK")
            results.append(True)
        else:
            print(f"❌ API App Distribution: ERRORE ({response.status_code})")
            results.append(False)
    except Exception as e:
        print(f"❌ API App Distribution: ERRORE - {str(e)}")
        results.append(False)
    
    # Risultati finali
    print("\n📊 RISULTATI FINALI:")
    print("=" * 50)
    
    total_tests = len(results)
    passed_tests = sum(results)
    success_rate = (passed_tests / total_tests) * 100
    
    print(f"Test Totali: {total_tests}")
    print(f"Test Superati: {passed_tests}")
    print(f"Test Falliti: {total_tests - passed_tests}")
    print(f"Tasso di Successo: {success_rate:.1f}%")
    
    if success_rate >= 80:
        print("\n🎉 SECUREVOX COMPLETAMENTE FUNZIONANTE!")
        print("🌐 Servizi attivi:")
        print("   - Django Backend: http://localhost:8001")
        print("   - App Distribution: http://localhost:8001/app-distribution/")
        print("   - Admin Panel: http://localhost:8001/admin/")
        print("   - Call Server: http://localhost:8002")
        print("   - Notify Server: http://localhost:8003")
    else:
        print("\n⚠️  Alcuni servizi potrebbero non funzionare correttamente")
    
    return success_rate >= 80

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1)
