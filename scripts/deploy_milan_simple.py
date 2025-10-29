#!/usr/bin/env python3
"""
Deploy SecureVox su Milano - Versione Semplice
"""

import oci
import time
import json
import sys
import os
from datetime import datetime

# Configurazione
COMPARTMENT_ID = "ocid1.tenancy.oc1..aaaaaaaa4mih7gc5nndai7ysnb34rhfxzf3mekc6qe3f4phoi2jnxxsxtw2q"
DOMAIN_NAME = "www.securevox.it"
REGION = "eu-milan-1"

def get_available_image(compute_client):
    """Ottiene un'immagine Ubuntu disponibile"""
    try:
        # Prova Ubuntu 22.04 prima
        images = compute_client.list_images(
            compartment_id=COMPARTMENT_ID,
            operating_system="Canonical Ubuntu",
            operating_system_version="22.04",
            limit=1
        )
        
        if images.data:
            return images.data[0]
        
        # Fallback a Ubuntu 20.04
        images = compute_client.list_images(
            compartment_id=COMPARTMENT_ID,
            operating_system="Canonical Ubuntu",
            operating_system_version="20.04",
            limit=1
        )
        
        if images.data:
            return images.data[0]
            
        return None
    except Exception as e:
        print(f"❌ Errore nel recupero immagini: {e}")
        return None

def create_instance(compute_client):
    """Crea un'istanza in Milano"""
    try:
        # Ottieni immagine
        image = get_available_image(compute_client)
        if not image:
            print(f"❌ Nessuna immagine Ubuntu disponibile")
            return None
            
        print(f"📦 Usando immagine: {image.display_name}")
        
        # Leggi chiave SSH
        ssh_key_path = f"{os.path.expanduser('~')}/.ssh/id_rsa.pub"
        if not os.path.exists(ssh_key_path):
            print(f"❌ Chiave SSH non trovata: {ssh_key_path}")
            return None
            
        with open(ssh_key_path, 'r') as f:
            ssh_key = f.read().strip()
        
        # Configurazione istanza Always Free
        instance_details = oci.core.models.LaunchInstanceDetails(
            compartment_id=COMPARTMENT_ID,
            display_name="securevox-milan",
            shape="VM.Standard.E2.1.Micro",
            source_details=oci.core.models.InstanceSourceViaImageDetails(
                image_id=image.id,
                boot_volume_size_in_gbs=50
            ),
            metadata={
                "ssh_authorized_keys": ssh_key
            }
        )
        
        print(f"🚀 Creando istanza in {REGION}...")
        response = compute_client.launch_instance(instance_details)
        instance_id = response.data.id
        
        print(f"✅ Istanza creata: {instance_id}")
        return instance_id
        
    except Exception as e:
        print(f"❌ Errore creazione istanza: {e}")
        return None

def wait_for_instance_running(compute_client, instance_id):
    """Attende che l'istanza sia in running"""
    print(f"⏳ Attendo che l'istanza {instance_id} sia in running...")
    
    for i in range(30):  # 5 minuti max
        try:
            instance = compute_client.get_instance(instance_id)
            if instance.data.lifecycle_state == "RUNNING":
                print(f"✅ Istanza {instance_id} è RUNNING!")
                return instance.data
            elif instance.data.lifecycle_state == "TERMINATED":
                print(f"❌ Istanza {instance_id} è TERMINATED!")
                return None
            else:
                print(f"⏳ Stato: {instance.data.lifecycle_state}...")
                time.sleep(10)
        except Exception as e:
            print(f"⚠️ Errore controllo stato: {e}")
            time.sleep(10)
    
    print(f"❌ Timeout: istanza non è RUNNING dopo 5 minuti")
    return None

def get_instance_ip(compute_client, instance_id):
    """Ottiene l'IP pubblico dell'istanza"""
    try:
        vnic_attachments = compute_client.list_vnic_attachments(
            compartment_id=COMPARTMENT_ID,
            instance_id=instance_id
        )
        
        if vnic_attachments.data:
            vnic_id = vnic_attachments.data[0].vnic_id
            vnic = compute_client.get_vnic(vnic_id)
            return vnic.data.public_ip
    except Exception as e:
        print(f"❌ Errore recupero IP: {e}")
    
    return None

def main():
    print("🚀 SecureVox Deploy su Milano")
    print("=" * 40)
    
    try:
        config = oci.config.from_file()
        config['region'] = REGION
        compute_client = oci.core.ComputeClient(config)
        
        # Crea istanza
        instance_id = create_instance(compute_client)
        if not instance_id:
            print(f"❌ Fallito creazione istanza")
            return False
        
        # Attendi che sia running
        instance = wait_for_instance_running(compute_client, instance_id)
        if not instance:
            print(f"❌ Istanza non è running")
            return False
        
        # Ottieni IP
        public_ip = get_instance_ip(compute_client, instance_id)
        if not public_ip:
            print(f"❌ Impossibile ottenere IP pubblico")
            return False
        
        print(f"🎉 SUCCESSO! Istanza creata in {REGION}")
        print(f"📍 IP Pubblico: {public_ip}")
        print(f"🆔 Instance ID: {instance_id}")
        
        # Salva informazioni
        deploy_info = {
            "region": REGION,
            "instance_id": instance_id,
            "public_ip": public_ip,
            "domain": DOMAIN_NAME,
            "timestamp": datetime.now().isoformat()
        }
        
        with open("deploy_info.json", "w") as f:
            json.dump(deploy_info, f, indent=2)
        
        print(f"\n📋 Informazioni salvate in deploy_info.json")
        print(f"🌐 Prossimo passo: Configurare DNS per {DOMAIN_NAME} → {public_ip}")
        
        return True
        
    except Exception as e:
        print(f"❌ Errore: {e}")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
