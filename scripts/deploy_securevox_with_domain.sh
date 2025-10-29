#!/bin/bash

# SecureVox Deployment con Dominio www.securevox.it
# Deploy completo con configurazione dominio e SSL

set -e

echo "🌟 SecureVox Deployment con Dominio www.securevox.it"
echo "=================================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if OCI is configured
print_info "Verificando configurazione OCI..."
if ! oci iam user list --limit 1 &> /dev/null; then
    print_error "OCI CLI non configurato. Esegui prima:"
    echo "   python3 configure_oci_auto.py"
    echo "   Segui le istruzioni per caricare la chiave API"
    exit 1
fi

print_status "OCI CLI configurato correttamente"

# Activate virtual environment
source ../venv_oracle/bin/activate

# Create domain-specific environment
print_info "Creando configurazione per www.securevox.it..."

cat > .env.securevox << 'EOF'
# SecureVox Production Environment - www.securevox.it
# Oracle Cloud Always Free Tier (50 users)

# Domain Configuration
DOMAIN=securevox.it
WWW_DOMAIN=www.securevox.it
API_DOMAIN=api.securevox.it
CALLS_DOMAIN=calls.securevox.it

# Deployment Configuration
DEPLOYMENT_TYPE=oracle_cloud_50_users
MAX_USERS=50
MAX_CONCURRENT_CALLS=10
MAX_PARTICIPANTS_PER_CALL=4

# Django Configuration
DJANGO_SECRET_KEY=CHANGE_ME_IN_PRODUCTION
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=securevox.it,www.securevox.it,api.securevox.it,calls.securevox.it
DJANGO_CSRF_TRUSTED_ORIGINS=https://securevox.it,https://www.securevox.it,https://api.securevox.it,https://calls.securevox.it

# Database Configuration
DATABASE_URL=postgresql://securevox:CHANGE_ME_IN_PRODUCTION@postgres:5432/securevox
POSTGRES_PASSWORD=CHANGE_ME_IN_PRODUCTION

# Redis Configuration
REDIS_URL=redis://redis:6379/0

# SSL Configuration
SSL_ENABLED=true
SSL_CERT_PATH=/etc/nginx/ssl/securevox.crt
SSL_KEY_PATH=/etc/nginx/ssl/securevox.key

# Monitoring Configuration
MONITORING_INTERVAL_MINUTES=5
ALERT_EMAIL_RECIPIENTS=
ALERT_WEBHOOK_URL=
AUTO_EMERGENCY_SHUTDOWN=false

# Oracle Cloud Configuration
OCI_CONFIG_FILE=~/.oci/config
OCI_PROFILE=DEFAULT

# Backup Configuration
BACKUP_RETENTION_DAYS=7
AUTO_CLEANUP_ENABLED=true

# Security Configuration
RATE_LIMITING_ENABLED=true
FIREWALL_STRICT_MODE=true

# Performance Configuration
GUNICORN_WORKERS=3
POSTGRES_MAX_CONNECTIONS=20
REDIS_MAX_MEMORY=400mb
EOF

print_status "Configurazione dominio creata"

# Update deployment script for domain
print_info "Aggiornando script di deployment per il dominio..."

# Create domain-specific deployment script
cat > deploy_securevox_domain.py << 'EOF'
#!/usr/bin/env python3
"""
SecureVox Deployment con Dominio www.securevox.it
Deploy automatico su Oracle Cloud con configurazione dominio
"""

import sys
import os
import json
import time
from datetime import datetime
from oracle_cloud_deployment import OracleCloudFreeTierManager

class SecureVoxDomainDeployment:
    """Deployment manager per SecureVox con dominio"""
    
    def __init__(self):
        self.manager = OracleCloudFreeTierManager()
        self.domain = "securevox.it"
        self.deployment_config = {
            'domain': self.domain,
            'max_users': 50,
            'max_concurrent_calls': 10,
            'max_participants_per_call': 4,
            'ssl_enabled': True,
            'subdomains': ['www', 'api', 'calls']
        }
    
    def deploy_with_domain(self):
        """Deploy SecureVox con configurazione dominio"""
        print(f"🚀 Deploying SecureVox with domain {self.domain}...")
        
        try:
            # Check free tier compliance
            if not self.manager.check_free_tier_compliance():
                print("❌ Current resources exceed free tier limits!")
                return False
            
            # Create network infrastructure
            print("🌐 Creating network infrastructure...")
            network_config = self.manager.create_vcn_and_subnet("securevox-domain-vcn")
            
            # Create instances
            print("🖥️ Creating SecureVox instances...")
            instances = self.manager.create_securevox_instances(network_config)
            
            if not instances:
                print("❌ Failed to create instances")
                return False
            
            # Configure domain
            print("🌐 Configuring domain...")
            self.configure_domain(instances)
            
            # Save deployment info
            deployment_info = {
                'timestamp': datetime.now().isoformat(),
                'domain': self.domain,
                'instances': instances,
                'network_config': network_config,
                'access_info': self.generate_access_info(instances)
            }
            
            with open('securevox_domain_deployment.json', 'w') as f:
                json.dump(deployment_info, f, indent=2)
            
            # Show results
            self.display_deployment_summary(deployment_info)
            
            return True
            
        except Exception as e:
            print(f"❌ Deployment failed: {e}")
            return False
    
    def configure_domain(self, instances):
        """Configura dominio per le istanze"""
        print(f"🌐 Configuring domain {self.domain}...")
        
        # Find main and call servers
        main_server = None
        call_server = None
        
        for instance in instances:
            if 'main' in instance['name'].lower():
                main_server = instance
            elif 'call' in instance['name'].lower():
                call_server = instance
        
        if not main_server or not call_server:
            print("❌ Main or call server not found")
            return False
        
        print(f"✅ Main Server: {main_server['public_ip']}")
        print(f"✅ Call Server: {call_server['public_ip']}")
        
        # Create domain configuration
        domain_config = {
            'domain': self.domain,
            'main_server_ip': main_server['public_ip'],
            'call_server_ip': call_server['public_ip'],
            'subdomains': {
                'www': main_server['public_ip'],
                'api': main_server['public_ip'],
                'calls': call_server['public_ip']
            }
        }
        
        with open('domain_config.json', 'w') as f:
            json.dump(domain_config, f, indent=2)
        
        print("✅ Domain configuration saved")
        
        # Generate nginx config
        self.generate_nginx_config(domain_config)
        
        return True
    
    def generate_nginx_config(self, domain_config):
        """Genera configurazione Nginx per il dominio"""
        print("📝 Generating Nginx configuration...")
        
        nginx_config = f"""
# Nginx Configuration for {self.domain}
# SecureVox 50 Users - Oracle Cloud Always Free

user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

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
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    client_max_body_size 50M;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

    # Upstreams
    upstream django_backend {{
        server django-backend:8000;
        keepalive 32;
    }}

    upstream call_server {{
        server call-server:3001;
        keepalive 16;
    }}

    # Redirect HTTP to HTTPS
    server {{
        listen 80;
        server_name {self.domain} www.{self.domain} api.{self.domain} calls.{self.domain};
        return 301 https://$server_name$request_uri;
    }}

    # HTTPS - Main Domain
    server {{
        listen 443 ssl http2;
        server_name {self.domain} www.{self.domain};

        # SSL (will be configured with Let's Encrypt)
        ssl_certificate /etc/nginx/ssl/securevox.crt;
        ssl_certificate_key /etc/nginx/ssl/securevox.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
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
        }}

        # API with rate limiting
        location /api/ {{
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://django_backend;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }}

        # Admin panel
        location /admin/ {{
            limit_req zone=login burst=2 nodelay;
            proxy_pass http://django_backend;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }}

        # Health check
        location /health/ {{
            proxy_pass http://django_backend;
            access_log off;
        }}

        # Main app
        location / {{
            proxy_pass http://django_backend;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }}
    }}

    # HTTPS - API Subdomain
    server {{
        listen 443 ssl http2;
        server_name api.{self.domain};

        ssl_certificate /etc/nginx/ssl/securevox.crt;
        ssl_certificate_key /etc/nginx/ssl/securevox.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;

        location / {{
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://django_backend;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }}
    }}

    # HTTPS - Calls Subdomain
    server {{
        listen 443 ssl http2;
        server_name calls.{self.domain};

        ssl_certificate /etc/nginx/ssl/securevox.crt;
        ssl_certificate_key /etc/nginx/ssl/securevox.key;
        
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;

        # Call server
        location / {{
            proxy_pass http://call_server;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # WebSocket support
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_cache_bypass $http_upgrade;
        }}

        # Janus WebRTC
        location /janus/ {{
            proxy_pass http://janus:8088/;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }}

        # Janus WebSocket
        location /janus-ws/ {{
            proxy_pass http://janus:8188/;
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
        
        with open('nginx.securevox.it.conf', 'w') as f:
            f.write(nginx_config)
        
        print("✅ Nginx configuration generated")
        return True
    
    def generate_access_info(self, instances):
        """Genera informazioni di accesso"""
        access_info = {
            'domain': self.domain,
            'urls': {
                'main_site': f'https://{self.domain}',
                'www_site': f'https://www.{self.domain}',
                'api': f'https://api.{self.domain}',
                'calls': f'https://calls.{self.domain}'
            },
            'ssh_access': [],
            'admin_access': f'https://{self.domain}/admin/'
        }
        
        for instance in instances:
            if instance['public_ip']:
                access_info['ssh_access'].append({
                    'server': instance['name'],
                    'command': f"ssh ubuntu@{instance['public_ip']}",
                    'description': instance['description']
                })
        
        return access_info
    
    def display_deployment_summary(self, deployment_info):
        """Mostra riepilogo deployment"""
        print("\n" + "="*60)
        print("🎉 SECUREVOX DEPLOYMENT COMPLETED - www.securevox.it")
        print("="*60)
        
        print(f"\n🌐 DOMAIN CONFIGURATION:")
        print(f"   Main Site: https://{self.domain}")
        print(f"   WWW Site: https://www.{self.domain}")
        print(f"   API: https://api.{self.domain}")
        print(f"   Calls: https://calls.{self.domain}")
        
        print(f"\n🖥️  SERVERS:")
        for instance in deployment_info['instances']:
            print(f"   • {instance['name']}: {instance['public_ip']}")
        
        print(f"\n📋 NEXT STEPS:")
        print(f"   1. Configure DNS for {self.domain}")
        print(f"   2. SSH to main server: ssh ubuntu@<MAIN_IP>")
        print(f"   3. Clone SecureVox repository")
        print(f"   4. Run: ./setup_ssl_securevox.sh")
        print(f"   5. Your site will be live at https://www.securevox.it")
        
        print(f"\n⚠️  IMPORTANT:")
        print(f"   • Configure DNS A records to point to server IPs")
        print(f"   • SSL will be configured automatically with Let's Encrypt")
        print(f"   • All traffic will be redirected to HTTPS")

def main():
    """Main function"""
    deployer = SecureVoxDomainDeployment()
    
    try:
        success = deployer.deploy_with_domain()
        
        if success:
            print("\n✅ Deployment completed successfully!")
            print("Your SecureVox instance is ready for www.securevox.it")
        else:
            print("\n❌ Deployment failed!")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n⚠️  Deployment interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF

chmod +x deploy_securevox_domain.py

print_status "Script di deployment con dominio creato"

# Create SSL setup script
print_info "Creando script SSL per www.securevox.it..."

cat > setup_ssl_securevox.sh << 'EOF'
#!/bin/bash
# SSL Setup Script for www.securevox.it
# Configurazione automatica SSL con Let's Encrypt

set -e

echo "🔒 Setting up SSL for www.securevox.it..."

# Install Certbot
apt-get update
apt-get install -y certbot python3-certbot-nginx

# Stop nginx temporarily
systemctl stop nginx

# Generate SSL certificate
certbot certonly --standalone \
    -d securevox.it \
    -d www.securevox.it \
    -d api.securevox.it \
    -d calls.securevox.it \
    --non-interactive \
    --agree-tos \
    --email admin@securevox.it

# Copy certificates to nginx directory
mkdir -p /etc/nginx/ssl
cp /etc/letsencrypt/live/securevox.it/fullchain.pem /etc/nginx/ssl/securevox.crt
cp /etc/letsencrypt/live/securevox.it/privkey.pem /etc/nginx/ssl/securevox.key

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

echo "✅ SSL setup completed for www.securevox.it"
echo "🌐 Your site is now available at:"
echo "   https://securevox.it"
echo "   https://www.securevox.it"
echo "   https://api.securevox.it"
echo "   https://calls.securevox.it"
EOF

chmod +x setup_ssl_securevox.sh

print_status "Script SSL creato"

# Create DNS configuration instructions
print_info "Creando istruzioni per configurazione DNS..."

cat > DNS_SETUP_INSTRUCTIONS.md << 'EOF'
# Configurazione DNS per www.securevox.it

## 🌐 Configurazione Nameserver

Configura i nameserver del dominio `securevox.it` per puntare a Oracle Cloud DNS:

### Nameserver da configurare:
```
ns1.pdns1.oci.oraclecloud.com
ns2.pdns1.oci.oraclecloud.com
ns3.pdns1.oci.oraclecloud.com
ns4.pdns1.oci.oraclecloud.com
```

## 📝 Record DNS da creare

Dopo il deployment, crea questi record DNS:

### Record A:
- `securevox.it` → `<MAIN_SERVER_IP>`
- `www.securevox.it` → `<MAIN_SERVER_IP>`
- `api.securevox.it` → `<MAIN_SERVER_IP>`
- `calls.securevox.it` → `<CALL_SERVER_IP>`

### Record CNAME (alternativo):
- `www.securevox.it` → `securevox.it`

## 🔧 Configurazione nel Registrar

1. Vai al pannello del tuo registrar (es. Register.it, Aruba, etc.)
2. Modifica i nameserver del dominio `securevox.it`
3. Imposta i nameserver Oracle Cloud sopra
4. Attendi la propagazione DNS (24-48 ore)

## ✅ Verifica Configurazione

Dopo la propagazione DNS:
```bash
nslookup securevox.it
nslookup www.securevox.it
nslookup api.securevox.it
nslookup calls.securevox.it
```

Tutti dovrebbero puntare agli IP corretti.

## 🚀 Deploy e SSL

1. Esegui il deployment: `./deploy_securevox_domain.py`
2. SSH al main server: `ssh ubuntu@<MAIN_IP>`
3. Esegui setup SSL: `./setup_ssl_securevox.sh`
4. Il sito sarà live su https://www.securevox.it
EOF

print_status "Istruzioni DNS create"

print_info "🎉 Preparazione completata per www.securevox.it!"
echo ""
print_info "📋 Prossimi passi:"
echo "   1. Carica la chiave API su Oracle Cloud (se non l'hai già fatto)"
echo "   2. Configura i nameserver del dominio securevox.it"
echo "   3. Esegui: python3 deploy_securevox_domain.py"
echo "   4. SSH al server e configura SSL"
echo ""
print_info "📄 File creati:"
echo "   • .env.securevox - Configurazione ambiente"
echo "   • deploy_securevox_domain.py - Script di deployment"
echo "   • setup_ssl_securevox.sh - Script SSL"
echo "   • nginx.securevox.it.conf - Configurazione Nginx"
echo "   • DNS_SETUP_INSTRUCTIONS.md - Istruzioni DNS"
echo ""
print_warning "⚠️  IMPORTANTE:"
echo "   • Configura i nameserver del dominio prima del deployment"
echo "   • La chiave API deve essere caricata su Oracle Cloud"
echo "   • SSL sarà configurato automaticamente con Let's Encrypt"
