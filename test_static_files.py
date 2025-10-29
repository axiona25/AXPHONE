#!/usr/bin/env python3
"""
Test specifico per i file statici della dashboard
"""

import requests
import json

def test_static_files():
    """Testa i file statici della dashboard"""
    print("🧪 Test File Statici Dashboard")
    print("=" * 35)
    
    base_url = "http://localhost:8001"
    
    # Test 1: Dashboard principale
    print("1. Testando dashboard principale...")
    try:
        response = requests.get(f"{base_url}/admin/", timeout=5)
        if response.status_code == 200:
            print("   ✅ Dashboard accessibile")
            
            # Controlla se contiene i riferimenti ai file statici
            content = response.text
            if 'index.D4WfYVCF.js' in content or 'index.BfHow5gp.css' in content:
                print("   ✅ Riferimenti file statici trovati nel HTML")
            else:
                print("   ⚠️  Riferimenti file statici non trovati")
        else:
            print(f"   ❌ Dashboard non accessibile: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Errore dashboard: {e}")
    
    # Test 2: File CSS
    print("2. Testando file CSS...")
    css_files = [
        "index.BfHow5gp.css",
        "index.css"  # Fallback
    ]
    
    for css_file in css_files:
        try:
            response = requests.get(f"{base_url}/admin/static/dashboard/assets/{css_file}", timeout=5)
            if response.status_code == 200:
                print(f"   ✅ CSS {css_file} caricato correttamente")
                break
            else:
                print(f"   ⚠️  CSS {css_file}: {response.status_code}")
        except Exception as e:
            print(f"   ❌ CSS {css_file}: {e}")
    
    # Test 3: File JS
    print("3. Testando file JavaScript...")
    js_files = [
        "index.D4WfYVCF.js",
        "index.js"  # Fallback
    ]
    
    for js_file in js_files:
        try:
            response = requests.get(f"{base_url}/admin/static/dashboard/assets/{js_file}", timeout=5)
            if response.status_code == 200:
                print(f"   ✅ JS {js_file} caricato correttamente")
                break
            else:
                print(f"   ⚠️  JS {js_file}: {response.status_code}")
        except Exception as e:
            print(f"   ❌ JS {js_file}: {e}")
    
    # Test 4: Lista file disponibili
    print("4. Verificando file disponibili...")
    try:
        # Prova a listare la directory assets
        response = requests.get(f"{base_url}/admin/static/dashboard/assets/", timeout=5)
        if response.status_code == 200:
            print("   ✅ Directory assets accessibile")
        else:
            print(f"   ⚠️  Directory assets: {response.status_code}")
    except Exception as e:
        print(f"   ❌ Directory assets: {e}")
    
    print("\n" + "=" * 35)
    print("📊 RIEPILOGO TEST FILE STATICI")
    print("=" * 35)
    print("✅ Se tutti i test sono passati, la dashboard dovrebbe funzionare senza errori 404")
    print("🌐 Ricarica la pagina: http://localhost:8001/admin")
    print("🔍 Controlla la console del browser (F12) per verificare che non ci siano errori")

if __name__ == "__main__":
    test_static_files()
