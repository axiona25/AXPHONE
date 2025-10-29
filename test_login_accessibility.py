#!/usr/bin/env python3
"""
Test per verificare che il warning DOM per autocomplete sia risolto
"""

import requests
import re

def test_login_accessibility():
    """Test accessibilità del form di login"""
    print("🔍 Test Accessibilità Form Login")
    print("=" * 40)
    
    base_url = "http://localhost:8001"
    
    try:
        # Ottieni la pagina di login
        response = requests.get(f"{base_url}/admin/login/", timeout=5)
        if response.status_code != 200:
            print(f"❌ Errore accesso pagina login: {response.status_code}")
            return False
        
        html_content = response.text
        
        # Cerca i campi input con regex
        input_pattern = r'<input[^>]*>'
        inputs = re.findall(input_pattern, html_content, re.IGNORECASE)
        
        print(f"📋 Trovati {len(inputs)} campi input:")
        
        has_autocomplete = True
        
        # Verifica campo password
        password_inputs = [inp for inp in inputs if 'type="password"' in inp or "type='password'" in inp]
        username_inputs = [inp for inp in inputs if 'name="username"' in inp or "name='username'" in inp]
        
        if password_inputs:
            password_input = password_inputs[0]
            print(f"  - Campo password: {password_input[:100]}...")
            
            if 'autocomplete="current-password"' in password_input or "autocomplete='current-password'" in password_input:
                print("    ✅ Campo password ha autocomplete='current-password'")
            else:
                print("    ❌ Campo password manca autocomplete='current-password'")
                has_autocomplete = False
        
        if username_inputs:
            username_input = username_inputs[0]
            print(f"  - Campo username: {username_input[:100]}...")
            
            if 'autocomplete="username"' in username_input or "autocomplete='username'" in username_input:
                print("    ✅ Campo username ha autocomplete='username'")
            else:
                print("    ❌ Campo username manca autocomplete='username'")
                has_autocomplete = False
        
        print("\n" + "=" * 40)
        if has_autocomplete:
            print("✅ ACCESSIBILITÀ FORM LOGIN: CORRETTA")
            print("✅ Tutti i campi hanno gli attributi autocomplete appropriati")
            print("✅ Il warning DOM dovrebbe essere risolto")
        else:
            print("❌ ACCESSIBILITÀ FORM LOGIN: PROBLEMI RILEVATI")
            print("❌ Alcuni campi mancano degli attributi autocomplete")
        
        return has_autocomplete
        
    except Exception as e:
        print(f"❌ Errore durante il test: {e}")
        return False

if __name__ == "__main__":
    success = test_login_accessibility()
    exit(0 if success else 1)
