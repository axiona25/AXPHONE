#!/usr/bin/env python3
"""
Configurazione Dominio www.securevox.it per SecureVox
Configura automaticamente il dominio e SSL per SecureVox
"""

import oci
import json
import time
from datetime import datetime

class SecureVoxDomainConfig:
    """Configurazione dominio per SecureVox"""
    
    def __init__(self):
        self.config = oci.config.from_file()
        self.dns_client = oci.dns.DnsClient(self.config)
        self.identity_client = oci.identity.IdentityClient(self.config)
        self.tenancy_id = self.config["tenancy"]
        
    def get_public_ips(self):
        """Ottieni IP pubblici delle istanze SecureVox"""
        try:
            compute_client = oci.core.ComputeClient(self.config)
            instances = compute_client.list_instances(
                compartment_id=self.tenancy_id
            ).data
            
            securevox_instances = []
            for instance in instances:
                if 'securevox' in instance.display_name.lower():
                    # Get public IP
                    vnics = compute_client.list_vnic_attachments(
                        compartment_id=self.tenancy_id,
                        instance_id=instance.id
                    ).data
                    
                    if vnics:
                        network_client = oci.core.VirtualNetworkClient(self.config)
                        vnic = network_client.get_vnic(vnics[0].vnic_id).data
                        public_ip = vnic.public_ip
                        
                        securevox_instances.append({
                            'name': instance.display_name,
                            'public_ip': public_ip,
                            'id': instance.id
                        })
            
            return securevox_instances
            
        except Exception as e:
            print(f"❌ Errore nel recupero IP: {e}")
            return []
    
    def create_dns_zone(self, domain="securevox.it"):
        """Crea zona DNS per il dominio"""
        try:
            print(f"🌐 Creando zona DNS per {domain}...")
            
            # Crea zona DNS
            zone_details = oci.dns.models.CreateZoneDetails(
                name=domain,
                zone_type="PRIMARY",
                compartment_id=self.tenancy_id
            )
            
            zone = self.dns_client.create_zone(zone_details).data
            print(f"✅ Zona DNS creata: {zone.id}")
            
            return zone
            
        except Exception as e:
            print(f"❌ Errore creazione zona DNS: {e}")
            return None
    
    def configure_dns_records(self, main_server_ip, call_server_ip, domain="securevox.it"):
        """Configura record DNS per SecureVox"""
        try:
            print(f"📝 Configurando record DNS per {domain}...")
            
            # Trova zona DNS
            zones = self.dns_client.list_zones(
                compartment_id=self.tenancy_id,
                name=domain
            ).data
            
            if not zones:
                print(f"❌ Zona DNS per {domain} non trovata")
                return False
            
            zone = zones[0]
            
            # Record A per www.securevox.it -> Main Server
            www_record = oci.dns.models.RecordDetails(
                domain="www.securevox.it",
                rtype="A",
                ttl=300,
                rdata=main_server_ip
            )
            
            # Record A per securevox.it -> Main Server
            apex_record = oci.dns.models.RecordDetails(
                domain="securevox.it",
                rtype="A", 
                ttl=300,
                rdata=main_server_ip
            )
            
            # Record A per api.securevox.it -> Main Server
            api_record = oci.dns.models.RecordDetails(
                domain="api.securevox.it",
                rtype="A",
                ttl=300,
                rdata=main_server_ip
            )
            
            # Record A per calls.securevox.it -> Call Server
            calls_record = oci.dns.models.RecordDetails(
                domain="calls.securevox.it",
                rtype="A",
                ttl=300,
                rdata=call_server_ip
            )
            
            # Crea tutti i record
            records = [www_record, apex_record, api_record, calls_record]
            
            for record in records:
                try:
                    self.dns_client.patch_domain_records(
                        zone_name_or_id=zone.name,
                        domain=record.domain,
                        patch_domain_records_details=oci.dns.models.PatchDomainRecordsDetails(
                            items=[record]
                        )
                    )
                    print(f"✅ Record {record.domain} -> {record.rdata}")
                except Exception as e:
                    print(f"⚠️  Record {record.domain}: {e}")
            
            return True
            
        except Exception as e:
            print(f"❌ Errore configurazione DNS: {e}")
            return False
    
    def generate_nginx_ssl_config(self, domain="securevox.it"):
        """Genera configurazione Nginx con SSL per il dominio"""
        
        nginx_config = f"""
# Nginx Configuration for SecureVox - {domain}
# Configurazione ottimizzata per 50 utenti con SSL

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

worker_rlimit_nofile 2048;

events {{
    worker_connections 1024;
    use epoll;
    multi_accept on;
}}

http {{
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Log format
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time ut=$upstream_response_time';

    access_log /var/log/nginx/access.log main;

    # Performance ottimizzazioni
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 50M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Rate limiting per 50 utenti
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=register:10m rate=2r/m;

    # Upstream per Django backend
    upstream django_backend {{
        server django-backend:8000;
        keepalive 32;
    }}

    # Upstream per Call Server
    upstream call_server {{
        server call-server:3001;
        keepalive 16;
    }}

    # Upstream per Janus WebRTC
    upstream janus_http {{
        server janus:8088;
    }}

    upstream janus_websocket {{
        server janus:8188;
    }}

    # Redirect HTTP to HTTPS
    server {{
        listen 80;
        server_name {domain} www.{domain} api.{domain} calls.{domain};
        return 301 https://$server_name$request_uri;
    }}

    # HTTPS server - Main Domain
    server {{
        listen 443 ssl http2;
        server_name {domain} www.{domain};

        # SSL Configuration
        ssl_certificate /etc/nginx/ssl/securevox.crt;
        ssl_certificate_key /etc/nginx/ssl/securevox.key;
        
        # SSL ottimizzazioni
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        # Static files
        location /static/ {{
            alias /var/www/static/;
            expires 30d;
            add_header Cache-Control "public, immutable";
        }}

        # Media files
        location /media/ {{
            alias /var/www/media/;
            expires 7d;
            add_header Cache-Control "public";
            client_max_body_size 10M;
        }}

        # API endpoints con rate limiting
        location /api/auth/login/ {{
            limit_req zone=login burst=3 nodelay;
            proxy_pass http://django_backend;
            include /etc/nginx/proxy_params;
        }}

        location /api/auth/register/ {{
            limit_req zone=register burst=2 nodelay;
            proxy_pass http://django_backend;
            include /etc/nginx/proxy_params;
        }}

        location /api/ {{
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://django_backend;
            include /etc/nginx/proxy_params;
        }}

        # Admin panel
        location /admin/ {{
            limit_req zone=login burst=2 nodelay;
            proxy_pass http://django_backend;
            include /etc/nginx/proxy_params;
        }}

        # Health check
        location /health/ {{
            proxy_pass http://django_backend;
            access_log off;
        }}

        # Main Django app
        location / {{
            proxy_pass http://django_backend;
            include /etc/nginx/proxy_params;
        }}
    }}

    # HTTPS server - API Subdomain
    server {{
        listen 443 ssl http2;
        server_name api.{domain};

        ssl_certificate /etc/nginx/ssl/securevox.crt;
        ssl_certificate_key /etc/nginx/ssl/securevox.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        location / {{
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://django_backend;
            include /etc/nginx/proxy_params;
        }}
    }}

    # HTTPS server - Calls Subdomain
    server {{
        listen 443 ssl http2;
        server_name calls.{domain};

        ssl_certificate /etc/nginx/ssl/securevox.crt;
        ssl_certificate_key /etc/nginx/ssl/securevox.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Call server WebSocket e HTTP
        location / {{
            proxy_pass http://call_server;
            include /etc/nginx/proxy_params;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_cache_bypass $http_upgrade;
        }}

        # Janus WebRTC Gateway
        location /janus/ {{
            proxy_pass http://janus_http/;
            include /etc/nginx/proxy_params;
        }}

        # Janus WebSocket
        location /janus-ws/ {{
            proxy_pass http://janus_websocket/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_read_timeout 86400;
        }}
    }}
}}
"""
        
        # Salva configurazione
        with open('nginx.securevox.it.conf', 'w') as f:
            f.write(nginx_config)
        
        print("✅ Configurazione Nginx per www.securevox.it creata")
        return True
    
    def generate_ssl_setup_script(self, domain="securevox.it"):
        """Genera script per setup SSL con Let's Encrypt"""
        
        ssl_script = f"""#!/bin/bash
# SSL Setup Script for {domain}
# Configurazione automatica SSL con Let's Encrypt

set -e

echo "🔒 Setting up SSL for {domain}..."

# Install Certbot
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Stop nginx temporarily
systemctl stop nginx

# Generate SSL certificate
certbot certonly --standalone -d {domain} -d www.{domain} -d api.{domain} -d calls.{domain} --non-interactive --agree-tos --email admin@{domain}

# Copy certificates to nginx directory
mkdir -p /etc/nginx/ssl
cp /etc/letsencrypt/live/{domain}/fullchain.pem /etc/nginx/ssl/securevox.crt
cp /etc/letsencrypt/live/{domain}/privkey.pem /etc/nginx/ssl/securevox.key

# Set permissions
chmod 600 /etc/nginx/ssl/securevox.key
chmod 644 /etc/nginx/ssl/securevox.crt

# Update nginx configuration
cp nginx.securevox.it.conf /etc/nginx/nginx.conf

# Test nginx configuration
nginx -t

# Start nginx
systemctl start nginx
systemctl enable nginx

# Setup auto-renewal
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -

echo "✅ SSL setup completed for {domain}"
echo "🌐 Your site is now available at:"
echo "   https://{domain}"
echo "   https://www.{domain}"
echo "   https://api.{domain}"
echo "   https://calls.{domain}"
"""
        
        with open('setup_ssl_securevox.sh', 'w') as f:
            f.write(ssl_script)
        
        chmod +x('setup_ssl_securevox.sh')
        print("✅ Script SSL per www.securevox.it creato")
        return True

def main():
    """Main function"""
    print("🌐 Configurazione Dominio www.securevox.it per SecureVox")
    print("=" * 60)
    
    try:
        config = SecureVoxDomainConfig()
        
        # Ottieni IP delle istanze
        instances = config.get_public_ips()
        
        if not instances:
            print("❌ Nessuna istanza SecureVox trovata")
            print("   Prima esegui il deployment: ./deploy_oracle_50users.sh")
            return
        
        # Trova main server e call server
        main_server = None
        call_server = None
        
        for instance in instances:
            if 'main' in instance['name'].lower():
                main_server = instance
            elif 'call' in instance['name'].lower():
                call_server = instance
        
        if not main_server or not call_server:
            print("❌ Server SecureVox non trovati")
            return
        
        print(f"✅ Main Server: {main_server['public_ip']}")
        print(f"✅ Call Server: {call_server['public_ip']}")
        
        # Configura DNS
        print("\n🌐 Configurando DNS...")
        config.configure_dns_records(
            main_server['public_ip'],
            call_server['public_ip'],
            "securevox.it"
        )
        
        # Genera configurazioni
        print("\n📝 Generando configurazioni...")
        config.generate_nginx_ssl_config("securevox.it")
        config.generate_ssl_setup_script("securevox.it")
        
        print("\n🎉 Configurazione dominio completata!")
        print("\n📋 Prossimi passi:")
        print("1. Configura i nameserver del dominio securevox.it")
        print("2. SSH al main server e esegui: ./setup_ssl_securevox.sh")
        print("3. Il sito sarà disponibile su https://www.securevox.it")
        
    except Exception as e:
        print(f"❌ Errore: {e}")

if __name__ == "__main__":
    main()
"""
