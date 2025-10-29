#!/usr/bin/env python3
"""
Test della sostituzione inline dei file statici
"""

import requests
import re

def test_inline_replacement():
    """Testa se la sostituzione inline funziona correttamente"""
    print("🔍 Test Sostituzione Inline File Statici")
    print("=" * 45)
    
    base_url = "http://localhost:8001"
    
    try:
        response = requests.get(f"{base_url}/admin/", timeout=10)
        if response.status_code == 200:
            content = response.text
            
            print("1. Analizzando HTML generato...")
            
            # Controlla se ci sono ancora riferimenti esterni
            css_links = re.findall(r'<link[^>]*href="/admin/assets/[^"]*"[^>]*>', content)
            js_scripts = re.findall(r'<script[^>]*src="/admin/assets/[^"]*"[^>]*>', content)
            
            print(f"   Riferimenti CSS esterni trovati: {len(css_links)}")
            print(f"   Riferimenti JS esterni trovati: {len(js_scripts)}")
            
            if css_links:
                print("   ❌ CSS ancora esterni:")
                for link in css_links:
                    print(f"      {link}")
            else:
                print("   ✅ Nessun CSS esterno trovato")
            
            if js_scripts:
                print("   ❌ JS ancora esterni:")
                for script in js_scripts:
                    print(f"      {script}")
            else:
                print("   ✅ Nessun JS esterno trovato")
            
            # Controlla se ci sono file inline
            inline_styles = content.count('<style>')
            inline_scripts = content.count('<script type="module">')
            
            print(f"   Tag <style> trovati: {inline_styles}")
            print(f"   Tag script type='module' trovati: {inline_scripts}")
            
            if inline_styles > 0 and inline_scripts > 0:
                print("   ✅ File inline trovati correttamente")
            else:
                print("   ❌ File inline non trovati")
            
            # Controlla la lunghezza del contenuto
            print(f"   Lunghezza HTML: {len(content)} caratteri")
            
            if len(content) > 100000:  # Se è molto lungo, probabilmente contiene i file inline
                print("   ✅ HTML sembra contenere file inline (lungo)")
            else:
                print("   ⚠️  HTML potrebbe non contenere file inline (corto)")
            
        else:
            print(f"❌ Errore nel caricamento: {response.status_code}")
            
    except Exception as e:
        print(f"❌ Errore: {e}")
    
    print("\n" + "=" * 45)
    print("📊 RIEPILOGO")
    print("=" * 45)
    print("Se non ci sono riferimenti esterni e ci sono file inline, la sostituzione funziona!")
    print("Ricarica la pagina nel browser per verificare che non ci siano più errori 404.")

if __name__ == "__main__":
    test_inline_replacement()
