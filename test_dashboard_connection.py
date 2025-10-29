#!/usr/bin/env python3
"""
Script per testare la connessione tra la dashboard React e il backend Django
"""

import requests
import json
import sys
from urllib.parse import urljoin

# Configurazione
BACKEND_URL = "http://localhost:8000"
DASHBOARD_URL = "http://localhost:3000"

def test_backend_endpoints():
    """Testa gli endpoint del backend"""
    print("🔍 Testando endpoint del backend...")
    
    endpoints = [
        "/admin/api/dashboard-stats-test/",
        "/admin/api/users-management/",
        "/admin/api/system-health/",
        "/admin/login/",
    ]
    
    results = {}
    
    for endpoint in endpoints:
        url = urljoin(BACKEND_URL, endpoint)
        try:
            if endpoint == "/admin/login/":
                # Test POST per login
                response = requests.post(url, json={"username": "test", "password": "test"})
            else:
                # Test GET per altri endpoint
                response = requests.get(url, headers={'X-Requested-With': 'XMLHttpRequest'})
            
            results[endpoint] = {
                "status_code": response.status_code,
                "success": response.status_code < 400,
                "content_type": response.headers.get('content-type', ''),
            }
            
            status_icon = "✅" if response.status_code < 400 else "❌"
            print(f"  {status_icon} {endpoint} - {response.status_code}")
            
        except requests.exceptions.ConnectionError:
            results[endpoint] = {
                "status_code": "CONNECTION_ERROR",
                "success": False,
                "error": "Impossibile connettersi al backend"
            }
            print(f"  ❌ {endpoint} - ERRORE CONNESSIONE")
        except Exception as e:
            results[endpoint] = {
                "status_code": "ERROR",
                "success": False,
                "error": str(e)
            }
            print(f"  ❌ {endpoint} - ERRORE: {e}")
    
    return results

def test_dashboard_access():
    """Testa l'accesso alla dashboard"""
    print("\n🌐 Testando accesso alla dashboard...")
    
    try:
        response = requests.get(DASHBOARD_URL, timeout=5)
        if response.status_code == 200:
            print(f"  ✅ Dashboard accessibile su {DASHBOARD_URL}")
            return True
        else:
            print(f"  ❌ Dashboard risponde con status {response.status_code}")
            return False
    except requests.exceptions.ConnectionError:
        print(f"  ❌ Dashboard non accessibile su {DASHBOARD_URL}")
        print("     Assicurati che la dashboard sia in esecuzione con: npm run dev")
        return False
    except Exception as e:
        print(f"  ❌ Errore accesso dashboard: {e}")
        return False

def test_cors_headers():
    """Testa le intestazioni CORS"""
    print("\n🔒 Testando intestazioni CORS...")
    
    try:
        # Test preflight request
        response = requests.options(
            urljoin(BACKEND_URL, "/admin/api/dashboard-stats-test/"),
            headers={
                'Origin': DASHBOARD_URL,
                'Access-Control-Request-Method': 'GET',
                'Access-Control-Request-Headers': 'X-Requested-With'
            }
        )
        
        cors_headers = {
            'Access-Control-Allow-Origin': response.headers.get('Access-Control-Allow-Origin'),
            'Access-Control-Allow-Methods': response.headers.get('Access-Control-Allow-Methods'),
            'Access-Control-Allow-Headers': response.headers.get('Access-Control-Allow-Headers'),
        }
        
        print(f"  CORS Headers: {cors_headers}")
        
        if cors_headers['Access-Control-Allow-Origin']:
            print("  ✅ CORS configurato correttamente")
            return True
        else:
            print("  ⚠️  CORS potrebbe non essere configurato")
            return False
            
    except Exception as e:
        print(f"  ❌ Errore test CORS: {e}")
        return False

def main():
    """Funzione principale"""
    print("🛡️  Test Connessione SecureVOX Dashboard")
    print("=" * 50)
    
    # Test backend
    backend_results = test_backend_endpoints()
    
    # Test dashboard
    dashboard_accessible = test_dashboard_access()
    
    # Test CORS
    cors_ok = test_cors_headers()
    
    # Riepilogo
    print("\n📊 RIEPILOGO TEST")
    print("=" * 30)
    
    backend_ok = all(result.get('success', False) for result in backend_results.values())
    
    print(f"Backend Django: {'✅ OK' if backend_ok else '❌ PROBLEMI'}")
    print(f"Dashboard React: {'✅ OK' if dashboard_accessible else '❌ NON ACCESSIBILE'}")
    print(f"CORS Headers: {'✅ OK' if cors_ok else '⚠️  DA VERIFICARE'}")
    
    if backend_ok and dashboard_accessible:
        print("\n🎉 Tutto funziona correttamente!")
        print("   Puoi accedere alla dashboard su: http://localhost:3000")
        return 0
    else:
        print("\n⚠️  Alcuni test sono falliti. Controlla la configurazione.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
