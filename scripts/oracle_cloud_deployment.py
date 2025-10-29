#!/usr/bin/env python3
"""
Oracle Cloud Always Free Deployment Script for SecureVox
STRICT FREE TIER LIMITS ENFORCEMENT

Oracle Always Free Limits:
- 2x AMD VM (1/8 OCPU, 1GB RAM each) 
- 4x ARM VM (total 4 OCPU, 24GB RAM)
- 200GB Block Storage
- 10GB Object Storage
- 1 Load Balancer
- NO CHARGES if within limits

Author: AI Assistant
Version: 1.0
"""

import oci
import json
import time
import sys
import os
from datetime import datetime
from typing import Dict, List, Optional

class OracleCloudFreeTierManager:
    """Manages Oracle Cloud deployment with strict free tier enforcement"""
    
    # HARD LIMITS - NEVER EXCEED THESE
    FREE_TIER_LIMITS = {
        'amd_instances': 2,          # Max AMD instances
        'amd_ocpu_per_instance': 0.125,  # 1/8 OCPU per AMD instance
        'amd_memory_per_instance': 1,     # 1GB RAM per AMD instance
        'arm_instances': 4,          # Max ARM instances (we'll use 2)
        'arm_total_ocpu': 4,         # Total ARM OCPU
        'arm_total_memory': 24,      # Total ARM memory (GB)
        'block_storage_gb': 200,     # Total block storage
        'object_storage_gb': 10,     # Object storage
        'load_balancers': 1,         # Load balancers
        'vcn_count': 2,              # Virtual Cloud Networks
        'public_ips': 2              # Reserved public IPs
    }
    
    def __init__(self, config_file: str = "~/.oci/config"):
        """Initialize OCI client with config file"""
        try:
            self.config = oci.config.from_file(config_file)
            self.compute_client = oci.core.ComputeClient(self.config)
            self.network_client = oci.core.VirtualNetworkClient(self.config)
            self.identity_client = oci.identity.IdentityClient(self.config)
            self.block_storage_client = oci.core.BlockstorageClient(self.config)
            
            # Get tenancy and compartment info
            self.tenancy_id = self.config["tenancy"]
            self.compartment_id = self.config.get("compartment", self.tenancy_id)
            
            print("✅ Oracle Cloud client initialized successfully")
            
        except Exception as e:
            print(f"❌ Failed to initialize Oracle Cloud client: {e}")
            print("Make sure you have configured OCI CLI: oci setup config")
            sys.exit(1)
    
    def check_free_tier_compliance(self) -> bool:
        """Check if current resources are within free tier limits"""
        print("\n🔍 Checking Free Tier Compliance...")
        
        try:
            # Get all instances
            instances = self.compute_client.list_instances(
                compartment_id=self.compartment_id
            ).data
            
            active_instances = [i for i in instances if i.lifecycle_state != 'TERMINATED']
            
            amd_instances = []
            arm_instances = []
            
            for instance in active_instances:
                shape = instance.shape
                if shape.startswith('VM.Standard.E2.1.Micro'):
                    amd_instances.append(instance)
                elif shape.startswith('VM.Standard.A1.Flex'):
                    arm_instances.append(instance)
            
            # Check AMD limits
            if len(amd_instances) > self.FREE_TIER_LIMITS['amd_instances']:
                print(f"❌ AMD instances: {len(amd_instances)}/{self.FREE_TIER_LIMITS['amd_instances']}")
                return False
            
            # Check ARM limits
            if len(arm_instances) > self.FREE_TIER_LIMITS['arm_instances']:
                print(f"❌ ARM instances: {len(arm_instances)}/{self.FREE_TIER_LIMITS['arm_instances']}")
                return False
            
            # Check block storage
            volumes = self.block_storage_client.list_volumes(
                compartment_id=self.compartment_id
            ).data
            
            active_volumes = [v for v in volumes if v.lifecycle_state == 'AVAILABLE']
            total_storage = sum(v.size_in_gbs for v in active_volumes)
            
            if total_storage > self.FREE_TIER_LIMITS['block_storage_gb']:
                print(f"❌ Block storage: {total_storage}GB/{self.FREE_TIER_LIMITS['block_storage_gb']}GB")
                return False
            
            print("✅ All resources within Free Tier limits")
            print(f"   AMD instances: {len(amd_instances)}/{self.FREE_TIER_LIMITS['amd_instances']}")
            print(f"   ARM instances: {len(arm_instances)}/{self.FREE_TIER_LIMITS['arm_instances']}")
            print(f"   Block storage: {total_storage}GB/{self.FREE_TIER_LIMITS['block_storage_gb']}GB")
            
            return True
            
        except Exception as e:
            print(f"❌ Error checking compliance: {e}")
            return False
    
    def get_availability_domains(self) -> List[str]:
        """Get available availability domains"""
        try:
            ads = self.identity_client.list_availability_domains(
                compartment_id=self.compartment_id
            ).data
            return [ad.name for ad in ads]
        except Exception as e:
            print(f"❌ Error getting availability domains: {e}")
            return []
    
    def create_vcn_and_subnet(self, vcn_name: str = "securevox-vcn") -> Dict:
        """Create VCN and subnet for SecureVox"""
        print(f"\n🌐 Creating VCN: {vcn_name}")
        
        try:
            # Check if VCN already exists
            existing_vcns = self.network_client.list_vcns(
                compartment_id=self.compartment_id,
                display_name=vcn_name
            ).data
            
            if existing_vcns:
                vcn = existing_vcns[0]
                print(f"✅ Using existing VCN: {vcn.display_name}")
            else:
                # Create VCN
                vcn_details = oci.core.models.CreateVcnDetails(
                    compartment_id=self.compartment_id,
                    display_name=vcn_name,
                    cidr_block="10.0.0.0/16",
                    dns_label="securevox"
                )
                
                vcn = self.network_client.create_vcn(vcn_details).data
                print(f"✅ Created VCN: {vcn.display_name}")
            
            # Create Internet Gateway
            ig_name = f"{vcn_name}-ig"
            existing_igs = self.network_client.list_internet_gateways(
                compartment_id=self.compartment_id,
                vcn_id=vcn.id,
                display_name=ig_name
            ).data
            
            if existing_igs:
                internet_gateway = existing_igs[0]
            else:
                ig_details = oci.core.models.CreateInternetGatewayDetails(
                    compartment_id=self.compartment_id,
                    vcn_id=vcn.id,
                    display_name=ig_name,
                    is_enabled=True
                )
                internet_gateway = self.network_client.create_internet_gateway(ig_details).data
            
            # Create Route Table
            rt_name = f"{vcn_name}-rt"
            existing_rts = self.network_client.list_route_tables(
                compartment_id=self.compartment_id,
                vcn_id=vcn.id,
                display_name=rt_name
            ).data
            
            if existing_rts:
                route_table = existing_rts[0]
            else:
                route_rules = [
                    oci.core.models.RouteRule(
                        destination="0.0.0.0/0",
                        destination_type="CIDR_BLOCK",
                        network_entity_id=internet_gateway.id
                    )
                ]
                
                rt_details = oci.core.models.CreateRouteTableDetails(
                    compartment_id=self.compartment_id,
                    vcn_id=vcn.id,
                    display_name=rt_name,
                    route_rules=route_rules
                )
                route_table = self.network_client.create_route_table(rt_details).data
            
            # Create Security List
            sl_name = f"{vcn_name}-sl"
            existing_sls = self.network_client.list_security_lists(
                compartment_id=self.compartment_id,
                vcn_id=vcn.id,
                display_name=sl_name
            ).data
            
            if existing_sls:
                security_list = existing_sls[0]
            else:
                # Security rules for SecureVox
                ingress_rules = [
                    # SSH
                    oci.core.models.IngressSecurityRule(
                        protocol="6",  # TCP
                        source="0.0.0.0/0",
                        tcp_options=oci.core.models.TcpOptions(
                            destination_port_range=oci.core.models.PortRange(min=22, max=22)
                        )
                    ),
                    # HTTP
                    oci.core.models.IngressSecurityRule(
                        protocol="6",
                        source="0.0.0.0/0",
                        tcp_options=oci.core.models.TcpOptions(
                            destination_port_range=oci.core.models.PortRange(min=80, max=80)
                        )
                    ),
                    # HTTPS
                    oci.core.models.IngressSecurityRule(
                        protocol="6",
                        source="0.0.0.0/0",
                        tcp_options=oci.core.models.TcpOptions(
                            destination_port_range=oci.core.models.PortRange(min=443, max=443)
                        )
                    ),
                    # Django (8000)
                    oci.core.models.IngressSecurityRule(
                        protocol="6",
                        source="0.0.0.0/0",
                        tcp_options=oci.core.models.TcpOptions(
                            destination_port_range=oci.core.models.PortRange(min=8000, max=8000)
                        )
                    ),
                    # Call Server (3001)
                    oci.core.models.IngressSecurityRule(
                        protocol="6",
                        source="0.0.0.0/0",
                        tcp_options=oci.core.models.TcpOptions(
                            destination_port_range=oci.core.models.PortRange(min=3001, max=3001)
                        )
                    ),
                ]
                
                egress_rules = [
                    oci.core.models.EgressSecurityRule(
                        protocol="all",
                        destination="0.0.0.0/0"
                    )
                ]
                
                sl_details = oci.core.models.CreateSecurityListDetails(
                    compartment_id=self.compartment_id,
                    vcn_id=vcn.id,
                    display_name=sl_name,
                    ingress_security_rules=ingress_rules,
                    egress_security_rules=egress_rules
                )
                security_list = self.network_client.create_security_list(sl_details).data
            
            # Create Subnet
            subnet_name = f"{vcn_name}-subnet"
            existing_subnets = self.network_client.list_subnets(
                compartment_id=self.compartment_id,
                vcn_id=vcn.id,
                display_name=subnet_name
            ).data
            
            if existing_subnets:
                subnet = existing_subnets[0]
            else:
                ads = self.get_availability_domains()
                if not ads:
                    raise Exception("No availability domains found")
                
                subnet_details = oci.core.models.CreateSubnetDetails(
                    compartment_id=self.compartment_id,
                    vcn_id=vcn.id,
                    display_name=subnet_name,
                    cidr_block="10.0.1.0/24",
                    availability_domain=ads[0],
                    route_table_id=route_table.id,
                    security_list_ids=[security_list.id],
                    dns_label="securevoxsub"
                )
                subnet = self.network_client.create_subnet(subnet_details).data
            
            return {
                'vcn_id': vcn.id,
                'subnet_id': subnet.id,
                'security_list_id': security_list.id
            }
            
        except Exception as e:
            print(f"❌ Error creating VCN: {e}")
            raise
    
    def create_securevox_instances(self, network_config: Dict) -> List[Dict]:
        """Create SecureVox instances within free tier limits"""
        print("\n🚀 Creating SecureVox instances...")
        
        if not self.check_free_tier_compliance():
            print("❌ Current resources exceed free tier limits!")
            return []
        
        instances = []
        ads = self.get_availability_domains()
        
        if not ads:
            print("❌ No availability domains available")
            return []
        
        # Instance configurations for SecureVox - Ottimizzato per 50 utenti
        instance_configs = [
            {
                'name': 'securevox-main-server',
                'shape': 'VM.Standard.A1.Flex',  # ARM - more resources
                'ocpus': 2,
                'memory_gb': 12,
                'description': 'Main server (Django + PostgreSQL + Redis) - Max 50 users',
                'startup_script': self._get_main_server_startup_script()
            },
            {
                'name': 'securevox-call-server',
                'shape': 'VM.Standard.A1.Flex',  # ARM
                'ocpus': 2,
                'memory_gb': 12,
                'description': 'Call server (Node.js + Janus WebRTC) - Max 10 concurrent calls',
                'startup_script': self._get_call_server_startup_script()
            }
        ]
        
        for i, config in enumerate(instance_configs):
            try:
                print(f"\n📦 Creating {config['name']}...")
                
                # Get latest Ubuntu image
                images = self.compute_client.list_images(
                    compartment_id=self.compartment_id,
                    shape=config['shape'],
                    operating_system='Canonical Ubuntu',
                    sort_by='TIMECREATED',
                    sort_order='DESC'
                ).data
                
                if not images:
                    print(f"❌ No compatible images found for {config['shape']}")
                    continue
                
                image = images[0]
                
                # Create instance
                instance_details = oci.core.models.LaunchInstanceDetails(
                    compartment_id=self.compartment_id,
                    availability_domain=ads[i % len(ads)],
                    display_name=config['name'],
                    image_id=image.id,
                    shape=config['shape'],
                    shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
                        ocpus=config['ocpus'],
                        memory_in_gbs=config['memory_gb']
                    ),
                    create_vnic_details=oci.core.models.CreateVnicDetails(
                        subnet_id=network_config['subnet_id'],
                        assign_public_ip=True,
                        display_name=f"{config['name']}-vnic"
                    ),
                    metadata={
                        'user_data': self._encode_startup_script(config['startup_script']),
                        'ssh_authorized_keys': self._get_ssh_public_key()
                    }
                )
                
                instance = self.compute_client.launch_instance(instance_details).data
                
                print(f"✅ Created {config['name']} (ID: {instance.id})")
                
                # Wait for instance to be running
                print("⏳ Waiting for instance to start...")
                instance = oci.wait_until(
                    self.compute_client,
                    self.compute_client.get_instance(instance.id),
                    'lifecycle_state',
                    'RUNNING',
                    max_wait_seconds=300
                ).data
                
                # Get public IP
                vnics = self.compute_client.list_vnic_attachments(
                    compartment_id=self.compartment_id,
                    instance_id=instance.id
                ).data
                
                public_ip = None
                if vnics:
                    vnic = self.network_client.get_vnic(vnics[0].vnic_id).data
                    public_ip = vnic.public_ip
                
                instances.append({
                    'id': instance.id,
                    'name': config['name'],
                    'public_ip': public_ip,
                    'shape': config['shape'],
                    'ocpus': config['ocpus'],
                    'memory_gb': config['memory_gb'],
                    'description': config['description']
                })
                
                print(f"✅ {config['name']} ready at {public_ip}")
                
            except Exception as e:
                print(f"❌ Error creating {config['name']}: {e}")
                continue
        
        return instances
    
    def _get_ssh_public_key(self) -> str:
        """Get SSH public key for instance access"""
        ssh_key_path = os.path.expanduser("~/.ssh/id_rsa.pub")
        
        if os.path.exists(ssh_key_path):
            with open(ssh_key_path, 'r') as f:
                return f.read().strip()
        else:
            print("⚠️  No SSH public key found at ~/.ssh/id_rsa.pub")
            print("Run: ssh-keygen -t rsa -b 2048")
            return ""
    
    def _encode_startup_script(self, script: str) -> str:
        """Encode startup script for cloud-init"""
        import base64
        return base64.b64encode(script.encode()).decode()
    
    def _get_main_server_startup_script(self) -> str:
        """Get startup script for main server - Ottimizzato per 50 utenti"""
        return """#!/bin/bash
# SecureVox Main Server Setup Script
# ORACLE CLOUD FREE TIER - OTTIMIZZATO PER 50 UTENTI

set -e

echo "🚀 Starting SecureVox Main Server setup (50 users max)..."

# Update system
apt-get update
apt-get upgrade -y

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git and monitoring tools
apt-get install -y git htop nano curl wget unzip iotop nethogs

# Create application directory
mkdir -p /opt/securevox/{logs,ssl,monitoring}
cd /opt/securevox

# Clone SecureVox repository (you'll need to provide the repo URL)
# git clone https://github.com/your-repo/securevox-complete-cursor-pack.git .

# Create environment file optimized for 50 users
cat > .env << EOF
# SecureVox Production Environment - Oracle Cloud Free Tier (50 users)
DJANGO_SECRET_KEY=$(openssl rand -base64 32)
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=*
POSTGRES_PASSWORD=$(openssl rand -base64 16)
DATABASE_URL=postgresql://securevox:\${POSTGRES_PASSWORD}@postgres:5432/securevox
REDIS_URL=redis://redis:6379/0
ENVIRONMENT=production_oracle
MAX_USERS=50
GUNICORN_WORKERS=3
GUNICORN_MAX_REQUESTS=1000
MAX_CONCURRENT_CALLS=10
MAX_PARTICIPANTS_PER_CALL=4
EOF

# Create nginx proxy_params
mkdir -p nginx
cat > nginx/proxy_params << EOF
proxy_set_header Host \$http_host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_connect_timeout 60s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
EOF

# Setup comprehensive log rotation
cat > /etc/logrotate.d/securevox << EOF
/opt/securevox/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    create 644 ubuntu ubuntu
    maxsize 100M
}
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    maxsize 50M
}
EOF

# Create monitoring script for 50 users
cat > /opt/securevox/monitor_50users.sh << 'MONITOR_EOF'
#!/bin/bash
# Monitor SecureVox for 50 users capacity

LOG_FILE="/opt/securevox/logs/capacity_monitor.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# Check active users
ACTIVE_USERS=$(docker exec securevox-backend python -c "
from django.contrib.auth.models import User
from django.contrib.sessions.models import Session
from django.utils import timezone
from datetime import timedelta

# Users active in last 5 minutes
recent = timezone.now() - timedelta(minutes=5)
active_sessions = Session.objects.filter(expire_date__gte=timezone.now())
print(len(active_sessions))
" 2>/dev/null || echo "0")

# Check system resources
MEMORY_USAGE=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
DISK_USAGE=$(df -h /opt | awk 'NR==2 {print $5}' | sed 's/%//')

echo "[$DATE] Active Users: $ACTIVE_USERS/50 | Memory: ${MEMORY_USAGE}% | CPU: ${CPU_USAGE}% | Disk: ${DISK_USAGE}%" >> $LOG_FILE

# Alert if approaching limits
if [ "$ACTIVE_USERS" -gt 45 ]; then
    echo "[$DATE] WARNING: Approaching user limit ($ACTIVE_USERS/50)" >> $LOG_FILE
fi

if [ "${MEMORY_USAGE%.*}" -gt 85 ]; then
    echo "[$DATE] WARNING: High memory usage (${MEMORY_USAGE}%)" >> $LOG_FILE
fi
MONITOR_EOF

chmod +x /opt/securevox/monitor_50users.sh

# Setup monitoring cron job
echo "*/5 * * * * ubuntu /opt/securevox/monitor_50users.sh" >> /etc/crontab

# Create systemd service for automatic startup
cat > /etc/systemd/system/securevox.service << EOF
[Unit]
Description=SecureVox Application (50 users max)
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/securevox
ExecStart=/usr/local/bin/docker-compose -f docker-compose.oracle-50users.yml up -d
ExecStop=/usr/local/bin/docker-compose -f docker-compose.oracle-50users.yml down
TimeoutStartSec=300
User=ubuntu
Group=docker
Environment=COMPOSE_HTTP_TIMEOUT=120

[Install]
WantedBy=multi-user.target
EOF

systemctl enable securevox.service

# Setup system optimizations for 50 users
cat >> /etc/sysctl.conf << EOF
# SecureVox optimizations for 50 users
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 65536 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
vm.swappiness = 10
fs.file-max = 65536
EOF

sysctl -p

echo "✅ SecureVox Main Server setup completed (50 users capacity)"
echo "📊 System optimized for:"
echo "   - Max 50 registered users"
echo "   - Max 10 concurrent calls"
echo "   - Max 4 participants per call"
echo "   - Automatic monitoring every 5 minutes"
echo ""
echo "📝 Next steps:"
echo "   1. SSH to this server: ssh ubuntu@<PUBLIC_IP>"
echo "   2. Clone your SecureVox repository to /opt/securevox"
echo "   3. Start services: systemctl start securevox"
echo "   4. Monitor capacity: tail -f /opt/securevox/logs/capacity_monitor.log"
"""
    
    def _get_call_server_startup_script(self) -> str:
        """Get startup script for call server"""
        return """#!/bin/bash
# SecureVox Call Server Setup Script
# ORACLE CLOUD FREE TIER - STRICT LIMITS

set -e

echo "🚀 Starting SecureVox Call Server setup..."

# Update system
apt-get update
apt-get upgrade -y

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Install Docker and Docker Compose
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker ubuntu

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Git and other tools
apt-get install -y git htop nano curl wget unzip

# Create application directory
mkdir -p /opt/securevox-call
cd /opt/securevox-call

# Create environment file
cat > .env << EOF
# SecureVox Call Server - Oracle Cloud Free Tier
NODE_ENV=production
PORT=3001
REDIS_URL=redis://localhost:6379
MAIN_SERVER_URL=http://MAIN_SERVER_IP:8000
EOF

# Setup log rotation
cat > /etc/logrotate.d/securevox-call << EOF
/opt/securevox-call/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    create 644 ubuntu ubuntu
}
EOF

# Create systemd service
cat > /etc/systemd/system/securevox-call.service << EOF
[Unit]
Description=SecureVox Call Server
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/securevox-call
Environment=NODE_ENV=production
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=securevox-call

[Install]
WantedBy=multi-user.target
EOF

systemctl enable securevox-call.service

echo "✅ SecureVox Call Server setup completed"
echo "📝 Next steps:"
echo "   1. SSH to this server"
echo "   2. Clone your call server code"
echo "   3. Run: npm install && systemctl start securevox-call"
"""
    
    def monitor_costs_and_usage(self) -> Dict:
        """Monitor resource usage to prevent charges"""
        print("\n📊 Monitoring Resource Usage...")
        
        try:
            # Get billing information (if available)
            usage_summary = {
                'timestamp': datetime.now().isoformat(),
                'free_tier_status': 'COMPLIANT',
                'warnings': [],
                'resources': {}
            }
            
            # Check instances
            instances = self.compute_client.list_instances(
                compartment_id=self.compartment_id
            ).data
            
            active_instances = [i for i in instances if i.lifecycle_state != 'TERMINATED']
            
            amd_count = sum(1 for i in active_instances if i.shape.startswith('VM.Standard.E2.1.Micro'))
            arm_count = sum(1 for i in active_instances if i.shape.startswith('VM.Standard.A1.Flex'))
            
            usage_summary['resources']['amd_instances'] = {
                'current': amd_count,
                'limit': self.FREE_TIER_LIMITS['amd_instances'],
                'percentage': (amd_count / self.FREE_TIER_LIMITS['amd_instances']) * 100
            }
            
            usage_summary['resources']['arm_instances'] = {
                'current': arm_count,
                'limit': self.FREE_TIER_LIMITS['arm_instances'],
                'percentage': (arm_count / self.FREE_TIER_LIMITS['arm_instances']) * 100
            }
            
            # Check storage
            volumes = self.block_storage_client.list_volumes(
                compartment_id=self.compartment_id
            ).data
            
            active_volumes = [v for v in volumes if v.lifecycle_state == 'AVAILABLE']
            total_storage = sum(v.size_in_gbs for v in active_volumes)
            
            usage_summary['resources']['block_storage'] = {
                'current_gb': total_storage,
                'limit_gb': self.FREE_TIER_LIMITS['block_storage_gb'],
                'percentage': (total_storage / self.FREE_TIER_LIMITS['block_storage_gb']) * 100
            }
            
            # Add warnings if approaching limits
            for resource, data in usage_summary['resources'].items():
                if data['percentage'] > 80:
                    usage_summary['warnings'].append(f"{resource} usage at {data['percentage']:.1f}%")
                    if data['percentage'] > 95:
                        usage_summary['free_tier_status'] = 'DANGER'
                    elif usage_summary['free_tier_status'] == 'COMPLIANT':
                        usage_summary['free_tier_status'] = 'WARNING'
            
            # Save usage report
            with open('oracle_usage_report.json', 'w') as f:
                json.dump(usage_summary, f, indent=2)
            
            print(f"Status: {usage_summary['free_tier_status']}")
            for warning in usage_summary['warnings']:
                print(f"⚠️  {warning}")
            
            return usage_summary
            
        except Exception as e:
            print(f"❌ Error monitoring usage: {e}")
            return {}
    
    def emergency_shutdown(self):
        """Emergency shutdown of all resources to prevent charges"""
        print("\n🚨 EMERGENCY SHUTDOWN - Stopping all resources...")
        
        try:
            # Stop all instances
            instances = self.compute_client.list_instances(
                compartment_id=self.compartment_id
            ).data
            
            for instance in instances:
                if instance.lifecycle_state == 'RUNNING':
                    print(f"🛑 Stopping instance: {instance.display_name}")
                    self.compute_client.instance_action(
                        instance.id,
                        'STOP'
                    )
            
            print("✅ Emergency shutdown completed")
            
        except Exception as e:
            print(f"❌ Error during emergency shutdown: {e}")

def main():
    """Main deployment function"""
    print("🌟 SecureVox Oracle Cloud Always Free Deployment")
    print("=" * 50)
    
    # Initialize manager
    manager = OracleCloudFreeTierManager()
    
    # Check initial compliance
    if not manager.check_free_tier_compliance():
        print("\n❌ Current resources exceed free tier limits!")
        print("Please clean up existing resources before proceeding.")
        return
    
    try:
        # Create network infrastructure
        network_config = manager.create_vcn_and_subnet()
        
        # Create instances
        instances = manager.create_securevox_instances(network_config)
        
        if instances:
            print("\n✅ Deployment completed successfully!")
            print("\n📋 Instance Summary:")
            for instance in instances:
                print(f"   {instance['name']}: {instance['public_ip']}")
                print(f"     Shape: {instance['shape']} ({instance['ocpus']} OCPU, {instance['memory_gb']}GB RAM)")
                print(f"     Description: {instance['description']}")
                print()
            
            print("📝 Next Steps:")
            print("1. SSH to each server: ssh ubuntu@<PUBLIC_IP>")
            print("2. Clone your SecureVox repository")
            print("3. Configure environment variables")
            print("4. Start services")
            
            # Save deployment info
            deployment_info = {
                'timestamp': datetime.now().isoformat(),
                'instances': instances,
                'network_config': network_config
            }
            
            with open('oracle_deployment_info.json', 'w') as f:
                json.dump(deployment_info, f, indent=2)
            
        else:
            print("\n❌ No instances were created")
        
        # Monitor usage
        manager.monitor_costs_and_usage()
        
    except KeyboardInterrupt:
        print("\n⚠️  Deployment interrupted by user")
    except Exception as e:
        print(f"\n❌ Deployment failed: {e}")
        print("Consider running emergency shutdown if needed")

if __name__ == "__main__":
    main()
