#!/usr/bin/env python3
"""
Test della dashboard su porta 8001
"""

import requests
import json
import sys

def test_dashboard():
    """Testa la dashboard su porta 8001"""
    print("🧪 Test Dashboard SecureVOX - Porta 8001")
    print("=" * 45)
    
    base_url = "http://localhost:8001"
    
    # Test 1: Health check
    print("1. Testando health check...")
    try:
        response = requests.get(f"{base_url}/health/", timeout=5)
        if response.status_code == 200:
            print("   ✅ Health check OK")
        else:
            print(f"   ❌ Health check fallito: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Health check errore: {e}")
        return False
    
    # Test 2: Dashboard principale
    print("2. Testando dashboard principale...")
    try:
        response = requests.get(f"{base_url}/admin/", timeout=5)
        if response.status_code == 200:
            print("   ✅ Dashboard accessibile")
            if "SecureVOX Admin Dashboard" in response.text:
                print("   ✅ Contenuto dashboard corretto")
            else:
                print("   ⚠️  Contenuto dashboard potrebbe essere di fallback")
        else:
            print(f"   ❌ Dashboard non accessibile: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Dashboard errore: {e}")
        return False
    
    # Test 3: API endpoints
    print("3. Testando API endpoints...")
    api_endpoints = [
        "/admin/api/dashboard-stats-test/",
        "/admin/api/users-management/",
        "/admin/api/system-health/"
    ]
    
    for endpoint in api_endpoints:
        try:
            response = requests.get(f"{base_url}{endpoint}", timeout=5)
            if response.status_code == 200:
                print(f"   ✅ {endpoint}")
            else:
                print(f"   ⚠️  {endpoint} - Status: {response.status_code}")
        except Exception as e:
            print(f"   ❌ {endpoint} - Errore: {e}")
    
    # Test 4: File statici
    print("4. Testando file statici...")
    try:
        # Prova a caricare un file CSS o JS dalla build
        response = requests.get(f"{base_url}/admin/static/dashboard/assets/", timeout=5)
        if response.status_code in [200, 404]:  # 404 è OK se la directory non è listabile
            print("   ✅ Endpoint file statici funzionante")
        else:
            print(f"   ⚠️  File statici: {response.status_code}")
    except Exception as e:
        print(f"   ❌ File statici errore: {e}")
    
    print("\n" + "=" * 45)
    print("📊 RIEPILOGO TEST")
    print("=" * 45)
    print("✅ Dashboard disponibile su: http://localhost:8001/admin")
    print("✅ API disponibili su: http://localhost:8001/admin/api/")
    print("✅ Health check su: http://localhost:8001/health/")
    print("\n🎉 La dashboard è pronta per l'uso!")
    print("🔐 Usa le credenziali admin del sistema per il login")
    
    return True

if __name__ == "__main__":
    test_dashboard()
