#!/usr/bin/env python3
"""
SecureVOX - Register.it DNS Configuration Helper
Helper script per configurare DNS su Register.it quando non si delegano i nameserver
"""

import sys
import json
from typing import Dict

def generate_dns_instructions(domain: str, load_balancer_ip: str) -> str:
    """Generate DNS configuration instructions for Register.it"""
    
    instructions = f"""
# 📋 Configurazione DNS per {domain} su Register.it

## 🎯 Record DNS da Configurare

Accedi al pannello di controllo Register.it e configura questi record DNS:

### Record A (IPv4)
```
Nome/Host          Tipo    Valore/Destinazione    TTL
@                  A       {load_balancer_ip}     3600
api                A       {load_balancer_ip}     3600
app                A       {load_balancer_ip}     3600    ← 📱 Distribuzione App iOS/Android
calls              A       {load_balancer_ip}     3600
monitor            A       {load_balancer_ip}     3600
admin              A       {load_balancer_ip}     3600
www                CNAME   {domain}               3600
```

## 🌐 Risultato Finale

Dopo la configurazione, questi saranno i tuoi endpoint:

- **Sito principale**: https://{domain}
- **API REST**: https://api.{domain}
- **📱 App Distribution**: https://app.{domain}
- **WebRTC Calls**: https://calls.{domain}
- **Monitoring**: https://monitor.{domain}
- **Admin Panel**: https://admin.{domain}

## 🔍 Come Configurare su Register.it

### Passo 1: Accesso
1. Vai su https://www.register.it
2. Accedi al tuo account
3. Vai nella sezione "Domini" → "Gestione DNS"

### Passo 2: Configurazione Record
1. Seleziona il dominio {domain}
2. Vai nella sezione "Gestione DNS" o "DNS Management"
3. Aggiungi/modifica i record come sopra indicato

### Passo 3: Propagazione
- La propagazione DNS richiede 1-24 ore
- Puoi verificare con: `dig {domain}` o `nslookup {domain}`

## 🚨 Note Importanti

1. **TTL (Time To Live)**: Imposta 3600 secondi (1 ora)
2. **Record @**: Rappresenta il dominio root ({domain})
3. **Record CNAME www**: Reindirizza www.{domain} a {domain}
4. **SSL**: Let's Encrypt si configurerà automaticamente dopo la propagazione DNS

## 🔧 Verifica Configurazione

Dopo aver configurato i DNS, verifica con questi comandi:

```bash
# Verifica record principale
dig {domain} A

# Verifica sottodomini
dig api.{domain} A
dig app.{domain} A
dig calls.{domain} A

# Verifica propagazione globale
# Usa: https://www.whatsmydns.net/#{domain}/A
```

## 📱 Test App Distribution

Una volta configurato, testa il sistema di distribuzione app:

1. Vai su https://app.{domain}
2. Dovrebbe mostrare l'interfaccia di distribuzione app
3. Upload la tua prima app iOS/Android

## 🆘 Troubleshooting

### DNS non si propaga
- Controlla che i record siano salvati correttamente
- Verifica che il TTL sia impostato
- Aspetta fino a 24 ore per la propagazione completa

### SSL non funziona
- Assicurati che i record DNS puntino all'IP corretto
- Let's Encrypt richiede che il dominio sia raggiungibile
- Controlla i log di Traefik per errori

### App distribution non funziona
- Verifica che https://app.{domain} sia raggiungibile
- Controlla che SSL sia attivo (richiesto per iOS OTA)
- Verifica i log del container Django

## 📞 Supporto

Se hai problemi:
1. Verifica la configurazione DNS
2. Controlla i log dei container Docker
3. Testa la raggiungibilità degli endpoint

Il tuo sistema SecureVOX sarà completamente operativo! 🚀
"""
    
    return instructions

def generate_register_it_guide():
    """Generate a comprehensive guide for Register.it DNS configuration"""
    
    guide = """
# 🎯 Guida Completa Register.it DNS per SecureVOX

## Scenario 1: Nameserver Delegati a DigitalOcean (Raccomandato)

### Vantaggi
- ✅ Gestione DNS completamente automatica
- ✅ SSL automatico Let's Encrypt
- ✅ Nessuna configurazione manuale
- ✅ Backup e gestione via API

### Come Fare
1. **Su Register.it**:
   - Pannello Domini → Gestione DNS
   - Cambia nameserver in:
     - `ns1.digitalocean.com`
     - `ns2.digitalocean.com`  
     - `ns3.digitalocean.com`

2. **Su DigitalOcean**: 
   - Il nostro script fa tutto automaticamente
   - Crea domini e record DNS
   - Configura SSL

## Scenario 2: DNS su Register.it (Manuale)

### Vantaggi
- ✅ Mantieni controllo completo DNS
- ✅ Nessun cambio di nameserver
- ✅ Configurazione flessibile

### Svantaggi
- ❌ Configurazione manuale richiesta
- ❌ Aggiornamenti manuali per nuovi servizi

### Come Fare
1. **Deployment**: Esegui il nostro script
2. **DNS**: Configura manualmente i record su Register.it
3. **SSL**: Let's Encrypt si configura automaticamente

## 🚀 Raccomandazione

**Usa lo Scenario 1** (nameserver delegati) per:
- Gestione completamente automatica
- Meno errori di configurazione  
- Deploy più rapido
- Facilità di manutenzione

Il cambio nameserver è sicuro e reversibile!

## 📋 Checklist Pre-Deploy

- [ ] Dominio registrato su Register.it
- [ ] API Key DigitalOcean pronta
- [ ] Decisione su gestione DNS (delegata o manuale)
- [ ] SSH key caricata su DigitalOcean

Sei pronto per il deploy! 🎉
"""
    
    return guide

def main():
    """Main function"""
    if len(sys.argv) < 3:
        print("Usage: python3 setup_register_it_dns.py <domain> <load_balancer_ip>")
        print("\nOr run without arguments for general guide:")
        print("python3 setup_register_it_dns.py")
        return
        
    if len(sys.argv) == 1:
        # Show general guide
        print(generate_register_it_guide())
        return
    
    domain = sys.argv[1]
    load_balancer_ip = sys.argv[2]
    
    # Generate specific instructions
    instructions = generate_dns_instructions(domain, load_balancer_ip)
    
    # Save to file
    filename = f"DNS_SETUP_{domain.replace('.', '_')}.md"
    with open(filename, 'w') as f:
        f.write(instructions)
    
    print(instructions)
    print(f"\n📄 Instructions saved to: {filename}")

if __name__ == "__main__":
    main()
