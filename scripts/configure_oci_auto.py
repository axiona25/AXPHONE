#!/usr/bin/env python3
"""
Automatic OCI CLI Configuration
Configura automaticamente OCI CLI con i parametri forniti
"""

import os
import subprocess
import sys

def configure_oci():
    """Configura OCI CLI automaticamente"""
    
    # Parametri di configurazione
    user_ocid = "ocid1.user.oc1..aaaaaaaay7j5usmrhryaed5p4t33nrcvocjytdueyc3euepahephwnp53sma"
    tenancy_ocid = "ocid1.tenancy.oc1..aaaaaaaa4mih7gc5nndai7ysnb34rhfxzf3mekc6qe3f4phoi2jnxxsxtw2q"
    region = "eu-frankfurt-1"
    
    print("🔧 Configurando OCI CLI automaticamente...")
    print(f"   User OCID: {user_ocid}")
    print(f"   Tenancy OCID: {tenancy_ocid}")
    print(f"   Region: {region}")
    
    # Crea directory .oci se non esiste
    oci_dir = os.path.expanduser("~/.oci")
    os.makedirs(oci_dir, exist_ok=True)
    
    # Crea file di configurazione
    config_content = f"""[DEFAULT]
user={user_ocid}
fingerprint=
key_file=~/.oci/oci_api_key.pem
tenancy={tenancy_ocid}
region={region}
"""
    
    config_file = os.path.join(oci_dir, "config")
    with open(config_file, 'w') as f:
        f.write(config_content)
    
    print(f"✅ File di configurazione creato: {config_file}")
    
    # Genera chiave API
    print("🔑 Generando chiave API...")
    
    try:
        # Genera chiave privata
        key_file = os.path.expanduser("~/.oci/oci_api_key.pem")
        subprocess.run([
            "openssl", "genrsa", "-out", key_file, "2048"
        ], check=True, capture_output=True)
        
        # Genera chiave pubblica
        pub_key_file = os.path.expanduser("~/.oci/oci_api_key_public.pem")
        subprocess.run([
            "openssl", "rsa", "-pubout", "-in", key_file, "-out", pub_key_file
        ], check=True, capture_output=True)
        
        print("✅ Chiavi API generate")
        
        # Leggi fingerprint
        fingerprint_result = subprocess.run([
            "openssl", "rsa", "-pubout", "-outform", "DER", "-in", key_file
        ], capture_output=True)
        
        if fingerprint_result.returncode == 0:
            import hashlib
            fingerprint = hashlib.md5(fingerprint_result.stdout).hexdigest()
            fingerprint = ':'.join([fingerprint[i:i+2] for i in range(0, len(fingerprint), 2)])
            
            # Aggiorna configurazione con fingerprint
            config_content = f"""[DEFAULT]
user={user_ocid}
fingerprint={fingerprint}
key_file=~/.oci/oci_api_key.pem
tenancy={tenancy_ocid}
region={region}
"""
            
            with open(config_file, 'w') as f:
                f.write(config_content)
            
            print(f"✅ Fingerprint generato: {fingerprint}")
            
            # Mostra chiave pubblica per upload su Oracle Cloud
            with open(pub_key_file, 'r') as f:
                public_key = f.read()
            
            print("\n" + "="*60)
            print("🔑 CHIAVE PUBBLICA API - UPLOAD SU ORACLE CLOUD")
            print("="*60)
            print(public_key)
            print("="*60)
            print("\n📋 ISTRUZIONI:")
            print("1. Vai su Oracle Cloud Console")
            print("2. Clicca su 'Profile' → 'User Settings'")
            print("3. Clicca su 'API Keys'")
            print("4. Clicca 'Add API Key'")
            print("5. Incolla la chiave pubblica sopra")
            print("6. Clicca 'Add'")
            print("7. Torna qui e premi INVIO per continuare")
            
            input("\nPremi INVIO quando hai caricato la chiave su Oracle Cloud...")
            
            # Test configurazione
            print("\n🧪 Testando configurazione...")
            test_result = subprocess.run([
                "oci", "iam", "user", "get", "--user-id", user_ocid
            ], capture_output=True, text=True)
            
            if test_result.returncode == 0:
                print("✅ Configurazione OCI completata con successo!")
                print("✅ Connessione a Oracle Cloud verificata!")
                return True
            else:
                print(f"❌ Errore nel test: {test_result.stderr}")
                return False
                
        else:
            print("❌ Errore nella generazione del fingerprint")
            return False
            
    except subprocess.CalledProcessError as e:
        print(f"❌ Errore nella generazione delle chiavi: {e}")
        return False
    except Exception as e:
        print(f"❌ Errore: {e}")
        return False

if __name__ == "__main__":
    success = configure_oci()
    if success:
        print("\n🎉 OCI CLI configurato correttamente!")
        print("🚀 Pronto per il deployment di SecureVox!")
    else:
        print("\n❌ Configurazione fallita. Controlla gli errori sopra.")
        sys.exit(1)
