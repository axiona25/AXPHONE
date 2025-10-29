#!/bin/bash

# SecureVox Oracle Cloud Preparation Script
# Esegui questo script quando l'account Oracle Cloud è pronto

set -e

echo "🌟 SecureVox Oracle Cloud Preparation"
echo "===================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if virtual environment exists
if [ ! -d "../venv_oracle" ]; then
    print_warning "Virtual environment not found. Creating..."
    cd ..
    python3 -m venv venv_oracle
    source venv_oracle/bin/activate
    pip install oci psycopg2-binary redis requests schedule python-dotenv
    cd scripts
fi

# Activate virtual environment
source ../venv_oracle/bin/activate

print_info "Virtual environment activated"

# Check OCI CLI
if ! command -v oci &> /dev/null; then
    print_warning "OCI CLI not found. Installing via pipx..."
    pipx install oci-cli
    pipx ensurepath
    source ~/.zshrc
fi

print_status "OCI CLI ready"

# Check SSH key
if [ ! -f "$HOME/.ssh/id_rsa_oracle.pub" ]; then
    print_warning "SSH key not found. Generating..."
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa_oracle -N ""
fi

print_status "SSH key ready: $HOME/.ssh/id_rsa_oracle.pub"

# Show SSH public key
echo ""
print_info "Your SSH Public Key (copy this for Oracle Cloud):"
echo "=================================================="
cat ~/.ssh/id_rsa_oracle.pub
echo "=================================================="
echo ""

# Create Oracle Cloud configuration helper
cat > oracle_config_helper.py << 'EOF'
#!/usr/bin/env python3
"""
Oracle Cloud Configuration Helper
Guida passo-passo per configurare OCI CLI
"""

import os
import subprocess

def main():
    print("🔧 Oracle Cloud Configuration Helper")
    print("=" * 40)
    print()
    
    print("📋 Step 1: Get your OCIDs from Oracle Cloud Console")
    print("   1. Go to: https://cloud.oracle.com/")
    print("   2. Login to your account")
    print("   3. Click on your profile (top right)")
    print("   4. Click 'User Settings'")
    print("   5. Copy the 'OCID' (starts with ocid1.user.oc1...)")
    print()
    
    user_ocid = input("Enter your User OCID: ").strip()
    
    print()
    print("📋 Step 2: Get your Tenancy OCID")
    print("   1. Go to 'Administration' → 'Tenancy Details'")
    print("   2. Copy the 'OCID' (starts with ocid1.tenancy.oc1...)")
    print()
    
    tenancy_ocid = input("Enter your Tenancy OCID: ").strip()
    
    print()
    print("📋 Step 3: Choose Region")
    print("   Available regions:")
    print("   1. eu-frankfurt-1 (Europe - Frankfurt)")
    print("   2. us-ashburn-1 (US East - Ashburn)")
    print("   3. us-phoenix-1 (US West - Phoenix)")
    print("   4. ap-sydney-1 (Asia Pacific - Sydney)")
    print()
    
    region_choice = input("Choose region (1-4): ").strip()
    
    regions = {
        "1": "eu-frankfurt-1",
        "2": "us-ashburn-1", 
        "3": "us-phoenix-1",
        "4": "ap-sydney-1"
    }
    
    region = regions.get(region_choice, "eu-frankfurt-1")
    
    print()
    print("🔧 Step 4: Configure OCI CLI")
    print("Run this command:")
    print()
    print("oci setup config")
    print()
    print("When prompted, enter:")
    print(f"   User OCID: {user_ocid}")
    print(f"   Tenancy OCID: {tenancy_ocid}")
    print(f"   Region: {region}")
    print("   Generate API key: Y")
    print("   Directory for keys: [press Enter for default]")
    print("   Passphrase: [press Enter for no passphrase]")
    print()
    
    # Test configuration
    print("🧪 Testing configuration...")
    try:
        result = subprocess.run(['oci', 'iam', 'user', 'get', '--user-id', user_ocid], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print("✅ Configuration test successful!")
        else:
            print("❌ Configuration test failed. Please check your OCIDs and try again.")
    except Exception as e:
        print(f"❌ Error testing configuration: {e}")
    
    print()
    print("📝 Next steps:")
    print("   1. Run: oci setup config")
    print("   2. Test: oci iam user list --limit 1")
    print("   3. Deploy: ./deploy_oracle_50users.sh")

if __name__ == "__main__":
    main()
EOF

chmod +x oracle_config_helper.py

print_status "Configuration helper created"

# Create deployment script
cat > deploy_oracle_50users.sh << 'EOF'
#!/bin/bash

# SecureVox Oracle Cloud Deployment - 50 Users
# Esegui questo script dopo aver configurato OCI CLI

set -e

echo "🚀 SecureVox Oracle Cloud Deployment - 50 Users"
echo "=============================================="

# Activate virtual environment
source ../venv_oracle/bin/activate

# Load environment variables
if [ -f ".env.deployment" ]; then
    source .env.deployment
else
    echo "⚠️  .env.deployment not found. Creating default..."
    cat > .env.deployment << 'ENVEOF'
# SecureVox Oracle Cloud 50 Users Deployment Environment

# Deployment Configuration
DEPLOYMENT_TYPE=oracle_cloud_50_users
MAX_USERS=50
MAX_CONCURRENT_CALLS=10
MAX_PARTICIPANTS_PER_CALL=4

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
ENVEOF
fi

# Test OCI configuration
echo "🧪 Testing OCI configuration..."
if oci iam user list --limit 1 &> /dev/null; then
    echo "✅ OCI configuration is valid"
else
    echo "❌ OCI configuration failed. Please run:"
    echo "   python3 oracle_config_helper.py"
    echo "   oci setup config"
    exit 1
fi

# Run deployment
echo "🚀 Starting deployment..."
python3 deploy_oracle_50users.py

echo "✅ Deployment completed!"
echo ""
echo "📋 Next steps:"
echo "   1. SSH to your servers using the IPs shown above"
echo "   2. Clone your SecureVox repository"
echo "   3. Start services: systemctl start securevox"
echo "   4. Monitor: ./start_monitoring.sh"
EOF

chmod +x deploy_oracle_50users.sh

print_status "Deployment script created"

# Create monitoring script
cat > start_monitoring.sh << 'EOF'
#!/bin/bash

# Start SecureVox 50 Users Monitoring

echo "🛡️ Starting SecureVox 50 Users Protection Monitoring..."

# Activate virtual environment
source ../venv_oracle/bin/activate

# Load environment
source .env.deployment

# Start monitoring
python3 ../scripts/oracle_protection_50users.py --monitor --interval ${MONITORING_INTERVAL_MINUTES:-5}
EOF

chmod +x start_monitoring.sh

print_status "Monitoring script created"

# Create status check script
cat > check_status.sh << 'EOF'
#!/bin/bash

# Check SecureVox Status

echo "📊 SecureVox 50 Users Status Check"
echo "================================="

# Activate virtual environment
source ../venv_oracle/bin/activate

# Load environment
source .env.deployment

# Run status check
python3 ../scripts/oracle_protection_50users.py --check

echo ""
echo "📈 Oracle Cloud usage:"
python3 ../scripts/oracle_cost_monitor.py --check
EOF

chmod +x check_status.sh

print_status "Status check script created"

echo ""
print_info "🎉 Preparation completed!"
echo ""
print_info "📋 What's ready:"
echo "   ✅ OCI CLI installed and configured"
echo "   ✅ SSH keys generated"
echo "   ✅ Python dependencies installed"
echo "   ✅ Deployment scripts created"
echo "   ✅ Monitoring scripts created"
echo ""
print_info "📝 Next steps when Oracle Cloud is ready:"
echo "   1. Run: python3 oracle_config_helper.py"
echo "   2. Follow the instructions to configure OCI CLI"
echo "   3. Run: ./deploy_oracle_50users.sh"
echo "   4. Start monitoring: ./start_monitoring.sh"
echo ""
print_info "🔑 Your SSH Public Key (save this):"
echo "=========================================="
cat ~/.ssh/id_rsa_oracle.pub
echo "=========================================="
echo ""
print_warning "⚠️  Keep this SSH key safe - you'll need it to access your servers!"
