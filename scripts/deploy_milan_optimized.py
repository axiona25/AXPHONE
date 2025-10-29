#!/usr/bin/env python3
"""
SecureVox Deployment su Milano - Ottimizzato per evitare "Out of host capacity"
Usa istanze più piccole e prova diverse availability domain
"""

import oci
import json
import time
import sys
import os
from datetime import datetime
from typing import Dict, List, Optional

class SecureVoxMilanOptimized:
    """Deployment manager per SecureVox su Milano ottimizzato"""
    
    def __init__(self):
        self.config = oci.config.from_file()
        self.compute_client = oci.core.ComputeClient(self.config)
        self.network_client = oci.core.VirtualNetworkClient(self.config)
        self.identity_client = oci.identity.IdentityClient(self.config)
        self.block_storage_client = oci.core.BlockstorageClient(self.config)
        
        self.tenancy_id = self.config["tenancy"]
        self.compartment_id = self.config.get("compartment", self.tenancy_id)
        
        print("✅ Oracle Cloud client initialized successfully")
    
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
    
    def create_vcn_and_subnet(self, vcn_name: str = "securevox-milan-vcn") -> Dict:
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
    
    def create_optimized_instances(self, network_config: Dict) -> List[Dict]:
        """Create optimized instances for Milan"""
        print("\n🚀 Creating optimized SecureVox instances...")
        
        instances = []
        ads = self.get_availability_domains()
        
        if not ads:
            print("❌ No availability domains available")
            return []
        
        # Try different instance shapes and availability domains
        instance_configs = [
            {
                'name': 'securevox-main-server',
                'shape': 'VM.Standard.E2.1.Micro',  # AMD - smaller
                'ocpus': 1,
                'memory_gb': 1,
                'description': 'Main server (Django + Database) - AMD',
                'startup_script': self._get_main_server_startup_script()
            },
            {
                'name': 'securevox-call-server',
                'shape': 'VM.Standard.E2.1.Micro',  # AMD - smaller
                'ocpus': 1,
                'memory_gb': 1,
                'description': 'Call server (Node.js + WebRTC) - AMD',
                'startup_script': self._get_call_server_startup_script()
            }
        ]
        
        # Try ARM instances as fallback
        arm_configs = [
            {
                'name': 'securevox-main-server-arm',
                'shape': 'VM.Standard.A1.Flex',
                'ocpus': 1,
                'memory_gb': 6,
                'description': 'Main server (Django + Database) - ARM',
                'startup_script': self._get_main_server_startup_script()
            },
            {
                'name': 'securevox-call-server-arm',
                'shape': 'VM.Standard.A1.Flex',
                'ocpus': 1,
                'memory_gb': 6,
                'description': 'Call server (Node.js + WebRTC) - ARM',
                'startup_script': self._get_call_server_startup_script()
            }
        ]
        
        # Try AMD first, then ARM
        configs_to_try = instance_configs + arm_configs
        
        for i, config in enumerate(configs_to_try):
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
                
                # Try different availability domains
                success = False
                for ad in ads:
                    try:
                        print(f"   Trying availability domain: {ad}")
                        
                        # Create instance
                        instance_details = oci.core.models.LaunchInstanceDetails(
                            compartment_id=self.compartment_id,
                            availability_domain=ad,
                            display_name=config['name'],
                            image_id=image.id,
                            shape=config['shape'],
                            shape_config=oci.core.models.LaunchInstanceShapeConfigDetails(
                                ocpus=config['ocpus'],
                                memory_in_gbs=config['memory_gb']
                            ) if config['shape'].startswith('VM.Standard.A1.Flex') else None,
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
                        
                        print(f"✅ Created {config['name']} (ID: {instance.id}) in {ad}")
                        
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
                            'description': config['description'],
                            'availability_domain': ad
                        })
                        
                        print(f"✅ {config['name']} ready at {public_ip}")
                        success = True
                        break
                        
                    except Exception as e:
                        if "Out of host capacity" in str(e):
                            print(f"   ⚠️  Out of host capacity in {ad}, trying next...")
                            continue
                        else:
                            print(f"   ❌ Error in {ad}: {e}")
                            continue
                
                if not success:
                    print(f"❌ Failed to create {config['name']} in any availability domain")
                    continue
                
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
            return ""
    
    def _encode_startup_script(self, script: str) -> str:
        """Encode startup script for cloud-init"""
        import base64
        return base64.b64encode(script.encode()).decode()
    
    def _get_main_server_startup_script(self) -> str:
        """Get startup script for main server"""
        return """#!/bin/bash
# SecureVox Main Server Setup Script
# ORACLE CLOUD MILAN - OTTIMIZZATO PER 50 UTENTI

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
apt-get install -y git htop nano curl wget unzip

# Create application directory
mkdir -p /opt/securevox/{logs,ssl,monitoring}
cd /opt/securevox

# Create environment file optimized for 50 users
cat > .env << EOF
# SecureVox Production Environment - Oracle Cloud Milan (50 users)
DJANGO_SECRET_KEY=$(openssl rand -base64 32)
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=*
POSTGRES_PASSWORD=$(openssl rand -base64 16)
DATABASE_URL=postgresql://securevox:\${POSTGRES_PASSWORD}@postgres:5432/securevox
REDIS_URL=redis://redis:6379/0
ENVIRONMENT=production_milan
MAX_USERS=50
GUNICORN_WORKERS=2
GUNICORN_MAX_REQUESTS=1000
MAX_CONCURRENT_CALLS=10
MAX_PARTICIPANTS_PER_CALL=4
EOF

# Setup log rotation
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
EOF

# Create systemd service
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

echo "✅ SecureVox Main Server setup completed (50 users capacity)"
echo "📊 System optimized for:"
echo "   - Max 50 registered users"
echo "   - Max 10 concurrent calls"
echo "   - Max 4 participants per call"
echo ""
echo "📝 Next steps:"
echo "   1. SSH to this server: ssh ubuntu@<PUBLIC_IP>"
echo "   2. Clone your SecureVox repository"
echo "   3. Start services: systemctl start securevox"
"""
    
    def _get_call_server_startup_script(self) -> str:
        """Get startup script for call server"""
        return """#!/bin/bash
# SecureVox Call Server Setup Script
# ORACLE CLOUD MILAN - OTTIMIZZATO PER 50 UTENTI

set -e

echo "🚀 Starting SecureVox Call Server setup (50 users max)..."

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
# SecureVox Call Server - Oracle Cloud Milan (50 users)
NODE_ENV=production
PORT=3001
REDIS_URL=redis://localhost:6379
MAIN_SERVER_URL=http://MAIN_SERVER_IP:8000
MAX_CONCURRENT_CALLS=10
MAX_PARTICIPANTS_PER_CALL=4
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

echo "✅ SecureVox Call Server setup completed (50 users capacity)"
echo "📝 Next steps:"
echo "   1. SSH to this server: ssh ubuntu@<PUBLIC_IP>"
echo "   2. Clone your call server code"
echo "   3. Run: npm install && systemctl start securevox-call"
"""

def main():
    """Main deployment function"""
    print("🌟 SecureVox Milan Optimized Deployment - 50 Users Edition")
    print("=" * 60)
    
    # Initialize manager
    manager = SecureVoxMilanOptimized()
    
    try:
        # Create network infrastructure
        network_config = manager.create_vcn_and_subnet()
        
        # Create instances
        instances = manager.create_optimized_instances(network_config)
        
        if instances:
            print("\n✅ Deployment completed successfully!")
            print("\n📋 Instance Summary:")
            for instance in instances:
                print(f"   {instance['name']}: {instance['public_ip']}")
                print(f"     Shape: {instance['shape']} ({instance['ocpus']} OCPU, {instance['memory_gb']}GB RAM)")
                print(f"     Description: {instance['description']}")
                print(f"     Availability Domain: {instance['availability_domain']}")
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
            
            with open('securevox_milan_deployment.json', 'w') as f:
                json.dump(deployment_info, f, indent=2)
            
        else:
            print("\n❌ No instances were created")
        
    except KeyboardInterrupt:
        print("\n⚠️  Deployment interrupted by user")
    except Exception as e:
        print(f"\n❌ Deployment failed: {e}")

if __name__ == "__main__":
    main()
