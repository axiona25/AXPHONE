#!/usr/bin/env python3
"""
Wait for OCI connection and deploy SecureVox
Aspetta che la connessione OCI sia pronta e procede con il deployment
"""

import subprocess
import time
import sys
import os
from datetime import datetime

def test_oci_connection():
    """Test OCI connection"""
    try:
        result = subprocess.run([
            'oci', 'iam', 'user', 'list', '--limit', '1'
        ], capture_output=True, text=True, timeout=30)
        
        return result.returncode == 0
    except:
        return False

def wait_for_oci_connection(max_wait_minutes=10):
    """Wait for OCI connection to be ready"""
    print("⏳ Aspettando che la connessione OCI sia pronta...")
    print("   (La chiave API potrebbe aver bisogno di qualche minuto per essere attivata)")
    
    start_time = time.time()
    max_wait_seconds = max_wait_minutes * 60
    
    while time.time() - start_time < max_wait_seconds:
        if test_oci_connection():
            print("✅ Connessione OCI pronta!")
            return True
        
        print(f"   ⏳ Tentativo in corso... (attesa: {int((time.time() - start_time)/60)} minuti)")
        time.sleep(30)  # Wait 30 seconds between attempts
    
    print("❌ Timeout: Connessione OCI non pronta dopo 10 minuti")
    return False

def deploy_securevox():
    """Deploy SecureVox"""
    print("🚀 Avviando deployment di SecureVox...")
    
    try:
        # Activate virtual environment
        venv_python = os.path.join(os.path.dirname(__file__), '..', 'venv_oracle', 'bin', 'python')
        
        # Run deployment
        result = subprocess.run([
            venv_python, 'deploy_oracle_50users.py'
        ], cwd=os.path.dirname(__file__))
        
        if result.returncode == 0:
            print("✅ Deployment completato!")
            return True
        else:
            print("❌ Deployment fallito!")
            return False
            
    except Exception as e:
        print(f"❌ Errore durante deployment: {e}")
        return False

def main():
    """Main function"""
    print("🌟 SecureVox Deployment con Dominio www.securevox.it")
    print("=" * 60)
    print(f"⏰ Inizio: {datetime.now().strftime('%H:%M:%S')}")
    print()
    
    # Wait for OCI connection
    if not wait_for_oci_connection():
        print("\n❌ Impossibile procedere senza connessione OCI")
        print("   Verifica che la chiave API sia stata caricata correttamente")
        print("   e riprova tra qualche minuto")
        sys.exit(1)
    
    # Deploy SecureVox
    if not deploy_securevox():
        print("\n❌ Deployment fallito")
        sys.exit(1)
    
    print("\n🎉 Deployment completato con successo!")
    print("🌐 SecureVox sarà disponibile su https://www.securevox.it")
    print("\n📋 Prossimi passi:")
    print("   1. Configura i nameserver del dominio securevox.it")
    print("   2. SSH al server e configura SSL")
    print("   3. Il sito sarà live!")

if __name__ == "__main__":
    main()
