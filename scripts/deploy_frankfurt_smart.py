#!/usr/bin/env python3
"""
Deploy SecureVox su Oracle Cloud - Francoforte con fallback intelligente
"""

import oci
import time
import json
import subprocess
import sys
import os
from datetime import datetime

# Configurazione
COMPARTMENT_ID = "ocid1.tenancy.oc1..aaaaaaaa4mih7gc5nndai7ysnb34rhfxzf3mekc6qe3f4phoi2jnxxsxtw2q"
DOMAIN_NAME = "www.securevox.it"
REGIONS_TO_TRY = ["eu-frankfurt-1", "eu-milan-1", "us-ashburn-1"]

# Configurazioni istanze per regione
INSTANCE_CONFIGS = {
    "eu-frankfurt-1": {
        "shape": "VM.Standard.E2.1.Micro",  # Always Free
        "ocpus": 1,
        "memory_in_gbs": 1,
        "boot_volume_size_in_gbs": 50
    },
    "eu-milan-1": {
        "shape": "VM.Standard.E2.1.Micro",  # Always Free
        "ocpus": 1,
        "memory_in_gbs": 1,
        "boot_volume_size_in_gbs": 50
    },
    "us-ashburn-1": {
        "shape": "VM.Standard.E2.1.Micro",  # Always Free
        "ocpus": 1,
        "memory_in_gbs": 1,
        "boot_volume_size_in_gbs": 50
    }
}

def test_region_access(region):
    """Testa l'accesso a una regione"""
    try:
        config = oci.config.from_file()
        config['region'] = region
        
        identity = oci.identity.IdentityClient(config)
        users = identity.list_users(compartment_id=COMPARTMENT_ID, limit=1)
        print(f"✅ Regione {region}: Accesso OK")
        return True
    except Exception as e:
        print(f"❌ Regione {region}: {str(e)[:100]}...")
        return False

def get_available_image(compute_client, region):
    """Ottiene un'immagine Ubuntu disponibile"""
    try:
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

def create_instance(compute_client, region, config):
    """Crea un'istanza in una regione specifica"""
    try:
        # Ottieni immagine
        image = get_available_image(compute_client, region)
        if not image:
            print(f"❌ Nessuna immagine Ubuntu disponibile in {region}")
            return None
            
        print(f"📦 Usando immagine: {image.display_name}")
        
        # Configurazione istanza
        instance_config = INSTANCE_CONFIGS[region]
        
        instance_details = oci.core.models.LaunchInstanceDetails(
            compartment_id=COMPARTMENT_ID,
            display_name=f"securevox-{region}",
            shape=instance_config["shape"],
            source_details=oci.core.models.InstanceSourceViaImageDetails(
                image_id=image.id,
                boot_volume_size_in_gbs=instance_config["boot_volume_size_in_gbs"]
            ),
            metadata={
                "ssh_authorized_keys": open(f"{os.path.expanduser('~')}/.ssh/id_rsa.pub").read().strip()
            },
            shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
                ocpus=instance_config["ocpus"],
                memory_in_gbs=instance_config["memory_in_gbs"]
            )
        )
        
        print(f"🚀 Creando istanza in {region}...")
        response = compute_client.launch_instance(instance_details)
        instance_id = response.data.id
        
        print(f"✅ Istanza creata: {instance_id}")
        return instance_id
        
    except Exception as e:
        print(f"❌ Errore creazione istanza in {region}: {e}")
        return None

def wait_for_instance_running(compute_client, instance_id, region):
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
    print("🚀 SecureVox Deploy - Francoforte con Fallback Intelligente")
    print("=" * 60)
    
    # Testa accesso alle regioni
    working_regions = []
    for region in REGIONS_TO_TRY:
        if test_region_access(region):
            working_regions.append(region)
    
    if not working_regions:
        print("❌ Nessuna regione accessibile!")
        return False
    
    print(f"✅ Regioni funzionanti: {', '.join(working_regions)}")
    
    # Prova a creare istanza in ogni regione funzionante
    for region in working_regions:
        try:
            print(f"\n🌍 Tentativo deploy in {region}...")
            
            config = oci.config.from_file()
            config['region'] = region
            compute_client = oci.core.ComputeClient(config)
            
            # Crea istanza
            instance_id = create_instance(compute_client, region, config)
            if not instance_id:
                print(f"❌ Fallito creazione istanza in {region}")
                continue
            
            # Attendi che sia running
            instance = wait_for_instance_running(compute_client, instance_id, region)
            if not instance:
                print(f"❌ Istanza non è running in {region}")
                continue
            
            # Ottieni IP
            public_ip = get_instance_ip(compute_client, instance_id)
            if not public_ip:
                print(f"❌ Impossibile ottenere IP pubblico in {region}")
                continue
            
            print(f"🎉 SUCCESSO! Istanza creata in {region}")
            print(f"📍 IP Pubblico: {public_ip}")
            print(f"🆔 Instance ID: {instance_id}")
            
            # Salva informazioni
            deploy_info = {
                "region": region,
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
            print(f"❌ Errore in {region}: {e}")
            continue
    
    print("❌ Deploy fallito in tutte le regioni!")
    return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
