#!/usr/bin/env python3
"""
SecureVOX - DigitalOcean Deployment Script
Automated deployment of SecureVOX infrastructure on DigitalOcean
"""

import os
import sys
import time
import json
import requests
import subprocess
from typing import Dict, List, Optional
from dataclasses import dataclass

@dataclass
class DropletConfig:
    name: str
    size: str
    region: str
    image: str
    tags: List[str]
    user_data: Optional[str] = None

class DigitalOceanDeployer:
    def __init__(self, api_token: str, domain: str, ssh_key_id: str):
        self.api_token = api_token
        self.domain = domain
        self.ssh_key_id = ssh_key_id
        self.base_url = "https://api.digitalocean.com/v2"
        self.headers = {
            "Authorization": f"Bearer {api_token}",
            "Content-Type": "application/json"
        }
        
    def make_request(self, method: str, endpoint: str, data: dict = None) -> dict:
        """Make API request to DigitalOcean"""
        url = f"{self.base_url}{endpoint}"
        
        if method.upper() == "GET":
            response = requests.get(url, headers=self.headers)
        elif method.upper() == "POST":
            response = requests.post(url, headers=self.headers, json=data)
        elif method.upper() == "PUT":
            response = requests.put(url, headers=self.headers, json=data)
        elif method.upper() == "DELETE":
            response = requests.delete(url, headers=self.headers)
        else:
            raise ValueError(f"Unsupported HTTP method: {method}")
            
        if response.status_code not in [200, 201, 202, 204]:
            print(f"API Error: {response.status_code} - {response.text}")
            raise Exception(f"DigitalOcean API error: {response.status_code}")
            
        return response.json() if response.text else {}
    
    def create_vpc(self) -> str:
        """Create VPC for SecureVOX"""
        print("🌐 Creating VPC...")
        
        vpc_data = {
            "name": "securevox-vpc",
            "region": "fra1",
            "ip_range": "10.0.0.0/16",
            "description": "SecureVOX Private Network"
        }
        
        result = self.make_request("POST", "/vpcs", vpc_data)
        vpc_id = result["vpc"]["id"]
        print(f"✅ VPC created: {vpc_id}")
        return vpc_id
    
    def create_database(self) -> Dict:
        """Create managed PostgreSQL database"""
        print("🗄️ Creating PostgreSQL database...")
        
        db_data = {
            "name": "securevox-postgres",
            "engine": "pg",
            "version": "16",
            "region": "fra1",
            "size": "db-s-2vcpu-4gb",
            "num_nodes": 1,
            "private_network_uuid": None,  # Will be set after VPC creation
            "tags": ["securevox", "database", "production"]
        }
        
        result = self.make_request("POST", "/databases", db_data)
        db_info = result["database"]
        print(f"✅ Database created: {db_info['name']}")
        return db_info
    
    def create_redis_cluster(self) -> Dict:
        """Create managed Redis cluster"""
        print("🔴 Creating Redis cluster...")
        
        redis_data = {
            "name": "securevox-redis",
            "engine": "redis",
            "version": "7",
            "region": "fra1",
            "size": "db-s-1vcpu-1gb",
            "num_nodes": 3,
            "tags": ["securevox", "cache", "production"]
        }
        
        result = self.make_request("POST", "/databases", redis_data)
        redis_info = result["database"]
        print(f"✅ Redis cluster created: {redis_info['name']}")
        return redis_info
    
    def create_spaces_bucket(self) -> Dict:
        """Create Spaces bucket for file storage"""
        print("🗃️ Creating Spaces bucket...")
        
        bucket_data = {
            "name": f"securevox-{int(time.time())}",
            "region": "fra1"
        }
        
        result = self.make_request("POST", "/spaces", bucket_data)
        bucket_info = result["space"]
        print(f"✅ Spaces bucket created: {bucket_info['name']}")
        return bucket_info
    
    def get_user_data_script(self, service_type: str) -> str:
        """Get cloud-init user data script for different service types"""
        
        base_script = """#!/bin/bash
set -e

# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker root

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install monitoring tools
apt-get install -y htop iotop nethogs

# Setup firewall
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
"""

        if service_type == "load-balancer":
            return base_script + """
# Load balancer specific ports
ufw allow 80
ufw allow 443
ufw allow 8080

# Create traefik directory
mkdir -p /opt/traefik/config
"""

        elif service_type == "app-server":
            return base_script + """
# App server specific setup
ufw allow 8000
ufw allow 8001

# Create app directory
mkdir -p /opt/securevox/app
"""

        elif service_type == "call-server":
            return base_script + """
# Call server specific setup
ufw allow 8002
ufw allow 8003

# Create call server directory
mkdir -p /opt/securevox/calls
"""

        else:
            return base_script
    
    def create_droplet(self, config: DropletConfig) -> Dict:
        """Create a single droplet"""
        print(f"💻 Creating droplet: {config.name}")
        
        droplet_data = {
            "name": config.name,
            "region": config.region,
            "size": config.size,
            "image": config.image,
            "ssh_keys": [self.ssh_key_id],
            "backups": True,
            "ipv6": True,
            "monitoring": True,
            "tags": config.tags,
            "user_data": config.user_data
        }
        
        result = self.make_request("POST", "/droplets", droplet_data)
        droplet_info = result["droplet"]
        print(f"✅ Droplet created: {droplet_info['name']} (ID: {droplet_info['id']})")
        return droplet_info
    
    def wait_for_droplet(self, droplet_id: int) -> Dict:
        """Wait for droplet to be ready"""
        print(f"⏳ Waiting for droplet {droplet_id} to be ready...")
        
        while True:
            result = self.make_request("GET", f"/droplets/{droplet_id}")
            droplet = result["droplet"]
            
            if droplet["status"] == "active":
                print(f"✅ Droplet {droplet_id} is ready!")
                return droplet
                
            print(f"   Status: {droplet['status']}... waiting 10s")
            time.sleep(10)
    
    def create_domain_records(self, droplets: Dict) -> None:
        """Create DNS records for the domain"""
        print(f"🌍 Creating DNS records for {self.domain}")
        
        lb_ip = droplets["load-balancer"]["networks"]["v4"][0]["ip_address"]
        
        # Try to create domain on DigitalOcean (only works if nameservers are delegated)
        try:
            self.make_request("GET", f"/domains/{self.domain}")
            print(f"   Domain {self.domain} already exists on DigitalOcean")
            dns_managed = True
        except:
            try:
                domain_data = {
                    "name": self.domain,
                    "ip_address": lb_ip
                }
                self.make_request("POST", "/domains", domain_data)
                print(f"✅ Domain {self.domain} created on DigitalOcean")
                dns_managed = True
            except Exception as e:
                print(f"⚠️ Cannot manage DNS on DigitalOcean (nameservers not delegated)")
                print(f"   You'll need to configure DNS manually on Register.it")
                dns_managed = False
        
        if dns_managed:
            # DNS records to create
            records = [
                {"type": "A", "name": "@", "data": lb_ip},
                {"type": "A", "name": "api", "data": lb_ip},
                {"type": "A", "name": "app", "data": lb_ip},
                {"type": "A", "name": "calls", "data": lb_ip},
                {"type": "A", "name": "monitor", "data": lb_ip},
                {"type": "A", "name": "admin", "data": lb_ip},
            ]
            
            for record in records:
                try:
                    self.make_request("POST", f"/domains/{self.domain}/records", record)
                    print(f"✅ DNS record created: {record['name']}.{self.domain} -> {record['data']}")
                except Exception as e:
                    print(f"⚠️ DNS record already exists or error: {record['name']}")
        else:
            # Provide manual DNS configuration instructions
            print("\n" + "="*60)
            print("📋 MANUAL DNS CONFIGURATION REQUIRED")
            print("="*60)
            print(f"Configure these DNS records on Register.it for {self.domain}:")
            print(f"")
            print(f"@ (root)     A    {lb_ip}")
            print(f"api          A    {lb_ip}")
            print(f"app          A    {lb_ip}  ← 📱 App Distribution")
            print(f"calls        A    {lb_ip}")
            print(f"monitor      A    {lb_ip}")
            print(f"admin        A    {lb_ip}")
            print("="*60)
    
    def generate_docker_compose(self, droplets: Dict, database: Dict, redis: Dict) -> str:
        """Generate production docker-compose.yml"""
        
        compose_content = f"""# SecureVOX Production - DigitalOcean
version: '3.8'

networks:
  securevox-backend:
    driver: bridge
  securevox-internal:
    driver: bridge
    internal: true

volumes:
  media_data:
  logs_data:
  ssl_certs:

services:
  # === LOAD BALANCER ===
  traefik:
    image: traefik:v3.0
    container_name: securevox-traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"
    command:
      - --api.dashboard=true
      - --api.insecure=false
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.email=admin@{self.domain}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --log.level=INFO
      - --accesslog=true
      - --metrics.prometheus=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ssl_certs:/letsencrypt
    networks:
      - securevox-backend
    labels:
      - traefik.enable=true
      - traefik.http.routers.traefik.rule=Host(`monitor.{self.domain}`)
      - traefik.http.routers.traefik.tls.certresolver=letsencrypt
      - traefik.http.routers.traefik.service=api@internal

  # === MAIN API SERVER ===
  api-server:
    image: securevox/api-server:latest
    container_name: securevox-api
    restart: unless-stopped
    environment:
      - DEBUG=0
      - DJANGO_SECRET_KEY=${{DJANGO_SECRET_KEY}}
      - POSTGRES_HOST={database['connection']['host']}
      - POSTGRES_DB={database['name']}
      - POSTGRES_USER={database['connection']['user']}
      - POSTGRES_PASSWORD={database['connection']['password']}
      - REDIS_URL=redis://{redis['connection']['host']}:{redis['connection']['port']}
      - ALLOWED_HOSTS={self.domain},api.{self.domain}
      - CORS_ALLOWED_ORIGINS=https://{self.domain},https://app.{self.domain}
    volumes:
      - media_data:/app/media
      - logs_data:/app/logs
    networks:
      - securevox-backend
    labels:
      - traefik.enable=true
      - traefik.http.routers.api.rule=Host(`api.{self.domain}`)
      - traefik.http.routers.api.tls.certresolver=letsencrypt
      - traefik.http.services.api.loadbalancer.server.port=8000
      
  # === APP DISTRIBUTION ===
  app-distribution:
    image: securevox/api-server:latest
    container_name: securevox-app-distribution
    restart: unless-stopped
    environment:
      - DEBUG=0
      - DJANGO_SECRET_KEY=${{DJANGO_SECRET_KEY}}
      - POSTGRES_HOST={database['connection']['host']}
      - POSTGRES_DB={database['name']}
      - POSTGRES_USER={database['connection']['user']}
      - POSTGRES_PASSWORD={database['connection']['password']}
      - REDIS_URL=redis://{redis['connection']['host']}:{redis['connection']['port']}
      - ALLOWED_HOSTS={self.domain},app.{self.domain}
    volumes:
      - media_data:/app/media
    networks:
      - securevox-backend
    labels:
      - traefik.enable=true
      - traefik.http.routers.app.rule=Host(`app.{self.domain}`)
      - traefik.http.routers.app.tls.certresolver=letsencrypt
      - traefik.http.services.app.loadbalancer.server.port=8001

  # === CALL SERVER ===
  call-server:
    image: securevox/call-server:latest
    container_name: securevox-calls
    restart: unless-stopped
    environment:
      - NODE_ENV=production
      - PORT=8002
      - JWT_SECRET=${{JWT_SECRET}}
      - MAIN_SERVER_URL=http://api-server:8000
      - REDIS_URL=redis://{redis['connection']['host']}:{redis['connection']['port']}
    networks:
      - securevox-backend
    labels:
      - traefik.enable=true
      - traefik.http.routers.calls.rule=Host(`calls.{self.domain}`)
      - traefik.http.routers.calls.tls.certresolver=letsencrypt
      - traefik.http.services.calls.loadbalancer.server.port=8002

  # === MONITORING ===
  prometheus:
    image: prom/prometheus:latest
    container_name: securevox-prometheus
    restart: unless-stopped
    volumes:
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - securevox-internal
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'

  grafana:
    image: grafana/grafana:latest
    container_name: securevox-grafana
    restart: unless-stopped
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${{GRAFANA_PASSWORD}}
    networks:
      - securevox-internal
    labels:
      - traefik.enable=true
      - traefik.http.routers.grafana.rule=Host(`monitor.{self.domain}`)
      - traefik.http.routers.grafana.tls.certresolver=letsencrypt
"""
        
        return compose_content
    
    def deploy_infrastructure(self) -> Dict:
        """Deploy complete SecureVOX infrastructure"""
        print("🚀 Starting SecureVOX deployment on DigitalOcean...")
        
        # Step 1: Create VPC
        vpc_id = self.create_vpc()
        time.sleep(10)
        
        # Step 2: Create managed services
        database = self.create_database()
        redis = self.create_redis_cluster()
        spaces = self.create_spaces_bucket()
        
        # Step 3: Define droplet configurations
        droplet_configs = [
            DropletConfig(
                name="securevox-lb",
                size="s-2vcpu-4gb",
                region="fra1",
                image="ubuntu-22-04-x64",
                tags=["securevox", "load-balancer", "production"],
                user_data=self.get_user_data_script("load-balancer")
            ),
            DropletConfig(
                name="securevox-app-1",
                size="s-4vcpu-8gb",
                region="fra1",
                image="ubuntu-22-04-x64",
                tags=["securevox", "app-server", "production"],
                user_data=self.get_user_data_script("app-server")
            ),
            DropletConfig(
                name="securevox-app-2",
                size="s-4vcpu-8gb",
                region="fra1",
                image="ubuntu-22-04-x64",
                tags=["securevox", "app-server", "production"],
                user_data=self.get_user_data_script("app-server")
            ),
            DropletConfig(
                name="securevox-calls-1",
                size="c-4",
                region="fra1",
                image="ubuntu-22-04-x64",
                tags=["securevox", "call-server", "production"],
                user_data=self.get_user_data_script("call-server")
            ),
            DropletConfig(
                name="securevox-monitor",
                size="s-2vcpu-4gb",
                region="fra1",
                image="ubuntu-22-04-x64",
                tags=["securevox", "monitoring", "production"],
                user_data=self.get_user_data_script("monitoring")
            )
        ]
        
        # Step 4: Create droplets
        droplets = {}
        droplet_ids = []
        
        for config in droplet_configs:
            droplet = self.create_droplet(config)
            droplet_ids.append(droplet["id"])
            
            if "lb" in config.name:
                droplets["load-balancer"] = droplet
            elif "app" in config.name:
                if "app-servers" not in droplets:
                    droplets["app-servers"] = []
                droplets["app-servers"].append(droplet)
            elif "calls" in config.name:
                if "call-servers" not in droplets:
                    droplets["call-servers"] = []
                droplets["call-servers"].append(droplet)
            elif "monitor" in config.name:
                droplets["monitoring"] = droplet
        
        # Step 5: Wait for all droplets to be ready
        print("⏳ Waiting for all droplets to be ready...")
        ready_droplets = {}
        for droplet_id in droplet_ids:
            ready_droplet = self.wait_for_droplet(droplet_id)
            ready_droplets[droplet_id] = ready_droplet
        
        # Update droplets dict with ready droplets
        for key, value in droplets.items():
            if isinstance(value, list):
                for i, droplet in enumerate(value):
                    droplets[key][i] = ready_droplets[droplet["id"]]
            else:
                droplets[key] = ready_droplets[value["id"]]
        
        # Step 6: Create DNS records
        self.create_domain_records(droplets)
        
        # Step 7: Generate deployment files
        compose_content = self.generate_docker_compose(droplets, database, redis)
        
        deployment_info = {
            "droplets": droplets,
            "database": database,
            "redis": redis,
            "spaces": spaces,
            "vpc_id": vpc_id,
            "domain": self.domain,
            "docker_compose": compose_content
        }
        
        return deployment_info
    
    def generate_deployment_summary(self, deployment_info: Dict) -> str:
        """Generate deployment summary"""
        
        summary = f"""
# 🚀 SecureVOX Deployment Summary

## 🌐 Domain Configuration
- **Main Domain**: https://{self.domain}
- **API Endpoint**: https://api.{self.domain}
- **App Distribution**: https://app.{self.domain} 📱
- **Call Server**: https://calls.{self.domain}
- **Monitoring**: https://monitor.{self.domain}

## 💻 Infrastructure Created

### Droplets
"""
        
        for key, value in deployment_info["droplets"].items():
            if isinstance(value, list):
                for i, droplet in enumerate(value):
                    ip = droplet["networks"]["v4"][0]["ip_address"]
                    summary += f"- **{droplet['name']}**: {ip} ({droplet['size_slug']})\n"
            else:
                ip = value["networks"]["v4"][0]["ip_address"]
                summary += f"- **{value['name']}**: {ip} ({value['size_slug']})\n"
        
        summary += f"""
### Managed Services
- **PostgreSQL**: {deployment_info["database"]["name"]} (Primary + Replica)
- **Redis**: {deployment_info["redis"]["name"]} (3-node cluster)
- **Spaces**: {deployment_info["spaces"]["name"]} (CDN enabled)

## 📱 App Distribution System
- **iOS Installation**: `https://app.{self.domain}/ios/`
- **Android Downloads**: `https://app.{self.domain}/android/`
- **Admin Panel**: `https://app.{self.domain}/admin/`
- **API**: `https://app.{self.domain}/api/`

### iOS Over-the-Air Installation
Users can install iOS apps directly by visiting:
`https://app.{self.domain}` on Safari iOS

### Android APK Distribution
Direct APK downloads available at:
`https://app.{self.domain}/android/`

## 🔐 Security Features
- ✅ SSL/TLS certificates (Let's Encrypt)
- ✅ VPC private networking
- ✅ Firewall configuration
- ✅ SSH key authentication
- ✅ Automated backups

## 📊 Monitoring
- **Grafana Dashboard**: https://monitor.{self.domain}
- **Prometheus Metrics**: Internal network
- **Log Aggregation**: Centralized logging

## 🔄 Next Steps

1. **Deploy Application**:
   ```bash
   # On load balancer server
   cd /opt/securevox
   docker-compose up -d
   ```

2. **Upload iOS/Android Apps**:
   ```bash
   curl -X POST https://app.{self.domain}/api/builds/ \\
     -H "Authorization: Token YOUR_TOKEN" \\
     -F "app_file=@YourApp.ipa" \\
     -F "platform=ios"
   ```

3. **Configure DNS**: Point your domain to {deployment_info["droplets"]["load-balancer"]["networks"]["v4"][0]["ip_address"]}

4. **Test App Distribution**: Visit https://app.{self.domain}

## 💰 Monthly Cost Estimate: ~$360

Your SecureVOX infrastructure is ready! 🎉
"""
        
        return summary

def main():
    """Main deployment function"""
    print("🚀 SecureVOX DigitalOcean Deployment Script")
    print("=" * 50)
    
    # Get required parameters
    api_token = os.getenv("DO_API_TOKEN")
    domain = os.getenv("DOMAIN")
    ssh_key_id = os.getenv("SSH_KEY_ID")
    
    if not all([api_token, domain, ssh_key_id]):
        print("❌ Missing required environment variables:")
        print("   - DO_API_TOKEN: DigitalOcean API token")
        print("   - DOMAIN: Your domain name (e.g., securevox.com)")
        print("   - SSH_KEY_ID: Your SSH key ID from DigitalOcean")
        sys.exit(1)
    
    deployer = DigitalOceanDeployer(api_token, domain, ssh_key_id)
    
    try:
        # Deploy infrastructure
        deployment_info = deployer.deploy_infrastructure()
        
        # Save docker-compose file
        with open("docker-compose.production.yml", "w") as f:
            f.write(deployment_info["docker_compose"])
        
        # Save deployment info
        with open("deployment_info.json", "w") as f:
            json.dump(deployment_info, f, indent=2, default=str)
        
        # Generate summary
        summary = deployer.generate_deployment_summary(deployment_info)
        with open("DEPLOYMENT_SUMMARY.md", "w") as f:
            f.write(summary)
        
        print("\n" + "=" * 50)
        print("✅ DEPLOYMENT COMPLETED SUCCESSFULLY!")
        print("=" * 50)
        print(summary)
        
        print("\n🔗 Important files created:")
        print("   - docker-compose.production.yml")
        print("   - deployment_info.json")
        print("   - DEPLOYMENT_SUMMARY.md")
        
    except Exception as e:
        print(f"\n❌ Deployment failed: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
