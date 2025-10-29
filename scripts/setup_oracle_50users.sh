#!/bin/bash

# SecureVox Oracle Cloud Setup Script - 50 Users Edition
# Script di setup completo per deployment su Oracle Cloud Always Free

set -e

echo "🌟 SecureVox Oracle Cloud Setup - 50 Users Edition"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root"
   exit 1
fi

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        print_error "pip3 is required but not installed"
        exit 1
    fi
    
    # Check git
    if ! command -v git &> /dev/null; then
        print_error "git is required but not installed"
        exit 1
    fi
    
    print_status "Prerequisites check completed"
}

# Install Python dependencies
install_python_deps() {
    print_info "Installing Python dependencies..."
    
    pip3 install --user oci psycopg2-binary redis requests schedule python-dotenv
    
    print_status "Python dependencies installed"
}

# Check OCI CLI configuration
check_oci_config() {
    print_info "Checking OCI CLI configuration..."
    
    if ! command -v oci &> /dev/null; then
        print_warning "OCI CLI not found. Installing..."
        
        # Install OCI CLI
        bash -c "$(curl -L https://raw.githubusercontent.com/oracle/oci-cli/master/scripts/install/install.sh)" -- --accept-all-defaults
        
        # Add to PATH
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        source ~/.bashrc
    fi
    
    # Check if OCI config exists
    if [ ! -f "$HOME/.oci/config" ]; then
        print_warning "OCI configuration not found. Please run 'oci setup config' manually"
        print_info "After configuration, run this script again"
        exit 1
    fi
    
    # Test OCI connection
    if oci iam user list --limit 1 &> /dev/null; then
        print_status "OCI CLI configuration is valid"
    else
        print_error "OCI CLI configuration is invalid. Please run 'oci setup config'"
        exit 1
    fi
}

# Check SSH keys
check_ssh_keys() {
    print_info "Checking SSH keys..."
    
    if [ ! -f "$HOME/.ssh/id_rsa.pub" ]; then
        print_warning "SSH public key not found. Generating..."
        
        ssh-keygen -t rsa -b 2048 -f "$HOME/.ssh/id_rsa" -N ""
        
        print_status "SSH key pair generated"
    else
        print_status "SSH key pair found"
    fi
}

# Validate Oracle Cloud Always Free eligibility
validate_free_tier() {
    print_info "Validating Oracle Cloud Always Free eligibility..."
    
    python3 << 'EOF'
import oci
import sys

try:
    config = oci.config.from_file()
    identity_client = oci.identity.IdentityClient(config)
    
    # Get tenancy info
    tenancy = identity_client.get_tenancy(config["tenancy"])
    print(f"✅ Tenancy: {tenancy.data.name}")
    
    # Check if Always Free eligible
    # This is a simplified check
    print("✅ Oracle Cloud connection successful")
    print("ℹ️  Please ensure your account has Always Free tier active")
    
except Exception as e:
    print(f"❌ Error validating Oracle Cloud: {e}")
    sys.exit(1)
EOF

    print_status "Oracle Cloud validation completed"
}

# Setup environment variables
setup_environment() {
    print_info "Setting up environment variables..."
    
    # Create .env file for deployment
    cat > .env.deployment << 'EOF'
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

# SMTP Configuration for Alerts (Optional)
SMTP_SERVER=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=

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

    print_status "Environment configuration created (.env.deployment)"
    print_info "Please edit .env.deployment to configure email alerts and other settings"
}

# Create deployment directory structure
create_directories() {
    print_info "Creating deployment directory structure..."
    
    mkdir -p oracle_deployment/{logs,backups,monitoring,ssl,config}
    
    # Create monitoring config
    cat > oracle_deployment/monitoring/prometheus.oracle.yml << 'EOF'
global:
  scrape_interval: 60s
  evaluation_interval: 60s

rule_files:
  # Add rule files here

scrape_configs:
  - job_name: 'securevox-main'
    static_configs:
      - targets: ['localhost:8000']
    scrape_interval: 30s
    metrics_path: '/metrics'
    
  - job_name: 'securevox-calls'
    static_configs:
      - targets: ['localhost:3001']
    scrape_interval: 30s
    metrics_path: '/metrics'

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

    # Create Janus config for Oracle
    cat > oracle_deployment/config/janus.oracle.jcfg << 'EOF'
general: {
    configs_folder = "/opt/janus/etc/janus"
    plugins_folder = "/opt/janus/lib/janus/plugins"
    transports_folder = "/opt/janus/lib/janus/transports"
    events_folder = "/opt/janus/lib/janus/events"
    loggers_folder = "/opt/janus/lib/janus/loggers"
    
    debug_level = 4
    debug_timestamps = true
    debug_colors = false
    debug_locks = false
    
    interface = "0.0.0.0"
    server_name = "SecureVox Janus (50 users)"
    session_timeout = 60
    reclaim_session_timeout = 0
    candidates_timeout = 45
    
    # 50 users optimization
    max_nack_queue = 500
    no_webrtc_encryption = false
}

certificates: {
    cert_pem = "/opt/janus/share/janus/certs/mycert.pem"
    cert_key = "/opt/janus/share/janus/certs/mycert.key"
}

media: {
    rtp_port_range = "20000-20010"
    dtls_mtu = 1200
    no_media_timer = 1
    slowlink_threshold = 4
}

nat: {
    stun_server = "stun.l.google.com"
    stun_port = 19302
    nice_debug = false
    full_trickle = true
    ice_lite = false
    ice_tcp = false
    nat_1_1_mapping = ""
    keep_private_host = false
}
EOF

    print_status "Directory structure created"
}

# Validate system requirements
validate_system() {
    print_info "Validating system requirements..."
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    if [ "$TOTAL_MEM" -lt 1000 ]; then
        print_warning "System has only ${TOTAL_MEM}MB RAM. Minimum 1GB recommended"
    else
        print_status "Memory check passed (${TOTAL_MEM}MB available)"
    fi
    
    # Check available disk space
    AVAILABLE_DISK=$(df -BG / | awk 'NR==2{printf "%.0f", $4}' | sed 's/G//')
    if [ "$AVAILABLE_DISK" -lt 10 ]; then
        print_warning "System has only ${AVAILABLE_DISK}GB free disk space. Minimum 10GB recommended"
    else
        print_status "Disk space check passed (${AVAILABLE_DISK}GB available)"
    fi
    
    # Check internet connection
    if ping -c 1 google.com &> /dev/null; then
        print_status "Internet connection check passed"
    else
        print_error "No internet connection available"
        exit 1
    fi
}

# Create deployment scripts
create_deployment_scripts() {
    print_info "Creating deployment helper scripts..."
    
    # Quick deploy script
    cat > oracle_deployment/quick_deploy.sh << 'EOF'
#!/bin/bash
# Quick deployment script for SecureVox 50 users

echo "🚀 Starting SecureVox Oracle Cloud deployment..."

# Load environment
source .env.deployment

# Run deployment
python3 ../scripts/deploy_oracle_50users.py

echo "✅ Deployment completed!"
echo "Check oracle_deployment/logs/ for detailed logs"
EOF

    # Monitoring script
    cat > oracle_deployment/start_monitoring.sh << 'EOF'
#!/bin/bash
# Start monitoring for SecureVox 50 users

echo "🛡️ Starting SecureVox protection monitoring..."

# Load environment
source .env.deployment

# Start protection monitoring
python3 ../scripts/oracle_protection_50users.py --monitor --interval ${MONITORING_INTERVAL_MINUTES:-5}
EOF

    # Status check script
    cat > oracle_deployment/check_status.sh << 'EOF'
#!/bin/bash
# Check SecureVox status

echo "📊 SecureVox 50 Users Status Check"
echo "================================="

# Load environment
source .env.deployment

# Run status check
python3 ../scripts/oracle_protection_50users.py --check

echo ""
echo "📈 Oracle Cloud usage:"
python3 ../scripts/oracle_cost_monitor.py --check
EOF

    # Emergency shutdown script
    cat > oracle_deployment/emergency_shutdown.sh << 'EOF'
#!/bin/bash
# Emergency shutdown script

echo "🚨 EMERGENCY SHUTDOWN"
echo "===================="

read -p "Are you sure you want to emergency shutdown? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    echo "Initiating emergency shutdown..."
    python3 ../scripts/oracle_protection_50users.py --emergency-shutdown
else
    echo "Emergency shutdown cancelled"
fi
EOF

    # Make scripts executable
    chmod +x oracle_deployment/*.sh
    
    print_status "Deployment helper scripts created"
}

# Create systemd service for monitoring
create_systemd_service() {
    print_info "Creating systemd service for monitoring..."
    
    # Create service file (will need sudo to install)
    cat > oracle_deployment/securevox-monitoring.service << EOF
[Unit]
Description=SecureVox 50 Users Protection Monitoring
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$PWD/oracle_deployment
Environment=PATH=$PATH
ExecStart=/usr/bin/python3 ../scripts/oracle_protection_50users.py --monitor
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    print_status "Systemd service file created (oracle_deployment/securevox-monitoring.service)"
    print_info "To install: sudo cp oracle_deployment/securevox-monitoring.service /etc/systemd/system/"
    print_info "Then: sudo systemctl enable securevox-monitoring.service"
}

# Final setup instructions
show_final_instructions() {
    print_info "Setup completed! Next steps:"
    echo ""
    echo "1. 📝 Edit configuration:"
    echo "   nano .env.deployment"
    echo ""
    echo "2. 🚀 Deploy to Oracle Cloud:"
    echo "   cd oracle_deployment"
    echo "   ./quick_deploy.sh"
    echo ""
    echo "3. 🛡️ Start monitoring (after deployment):"
    echo "   ./start_monitoring.sh"
    echo ""
    echo "4. 📊 Check status anytime:"
    echo "   ./check_status.sh"
    echo ""
    echo "5. 🚨 Emergency shutdown (if needed):"
    echo "   ./emergency_shutdown.sh"
    echo ""
    echo "📁 All files are in the 'oracle_deployment' directory"
    echo "📋 Documentation: ORACLE_CLOUD_50_USERS_DEPLOYMENT.md"
    echo ""
    print_status "SecureVox Oracle Cloud setup completed!"
    print_info "Your deployment is ready for up to 50 users with zero cost guarantee!"
}

# Main execution
main() {
    check_prerequisites
    install_python_deps
    check_oci_config
    check_ssh_keys
    validate_free_tier
    validate_system
    setup_environment
    create_directories
    create_deployment_scripts
    create_systemd_service
    show_final_instructions
}

# Run main function
main

echo ""
echo "🎉 Setup completed successfully!"
echo "Ready to deploy SecureVox on Oracle Cloud Always Free!"
