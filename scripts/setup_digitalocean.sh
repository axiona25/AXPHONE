#!/bin/bash

# SecureVOX - DigitalOcean Setup Script
# Automated deployment script for SecureVOX on DigitalOcean

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Header
echo -e "${BLUE}"
echo "======================================================="
echo "🚀 SecureVOX - DigitalOcean Deployment Setup"
echo "======================================================="
echo -e "${NC}"

# Check requirements
log_info "Checking requirements..."

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    log_error "Python 3 is required but not installed."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    log_error "pip3 is required but not installed."
    exit 1
fi

log_success "Requirements check passed"

# Install Python dependencies
log_info "Installing Python dependencies..."
pip3 install requests python-dotenv

# Get configuration
echo ""
log_info "Please provide the following information:"

# DigitalOcean API Token
if [ -z "$DO_API_TOKEN" ]; then
    echo -n "DigitalOcean API Token: "
    read -s DO_API_TOKEN
    echo ""
    export DO_API_TOKEN
fi

# Domain name
if [ -z "$DOMAIN" ]; then
    echo -n "Domain name (e.g., securevox.com): "
    read DOMAIN
    export DOMAIN
fi

# SSH Key ID (optional - we'll try to get it automatically)
if [ -z "$SSH_KEY_ID" ]; then
    log_info "Getting SSH keys from DigitalOcean..."
    
    # Try to get SSH keys automatically
    SSH_KEYS=$(curl -s -X GET \
        -H "Authorization: Bearer $DO_API_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.digitalocean.com/v2/account/keys")
    
    if echo "$SSH_KEYS" | grep -q '"ssh_keys"'; then
        # Extract first SSH key ID
        SSH_KEY_ID=$(echo "$SSH_KEYS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
if data['ssh_keys']:
    print(data['ssh_keys'][0]['id'])
else:
    print('')
")
        
        if [ -n "$SSH_KEY_ID" ]; then
            log_success "Found SSH key ID: $SSH_KEY_ID"
            export SSH_KEY_ID
        else
            log_warning "No SSH keys found in your DigitalOcean account"
            echo -n "Please enter SSH Key ID manually: "
            read SSH_KEY_ID
            export SSH_KEY_ID
        fi
    else
        log_error "Failed to retrieve SSH keys. Please check your API token."
        echo -n "Please enter SSH Key ID manually: "
        read SSH_KEY_ID
        export SSH_KEY_ID
    fi
fi

# Create .env file
log_info "Creating environment configuration..."
cat > .env << EOF
DO_API_TOKEN=$DO_API_TOKEN
DOMAIN=$DOMAIN
SSH_KEY_ID=$SSH_KEY_ID

# Django settings
DJANGO_SECRET_KEY=$(python3 -c 'import secrets; print(secrets.token_urlsafe(50))')
JWT_SECRET=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
GRAFANA_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(16))')

# Database settings (will be populated after deployment)
POSTGRES_DB=securevox
POSTGRES_USER=securevox
POSTGRES_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')

# Email settings (configure these for notifications)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
EOF

log_success "Environment file created: .env"

# Validate API token
log_info "Validating DigitalOcean API token..."
ACCOUNT_INFO=$(curl -s -X GET \
    -H "Authorization: Bearer $DO_API_TOKEN" \
    -H "Content-Type: application/json" \
    "https://api.digitalocean.com/v2/account")

if echo "$ACCOUNT_INFO" | grep -q '"account"'; then
    ACCOUNT_EMAIL=$(echo "$ACCOUNT_INFO" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(data['account']['email'])
")
    log_success "API token valid for account: $ACCOUNT_EMAIL"
else
    log_error "Invalid API token. Please check and try again."
    exit 1
fi

# Check domain configuration
log_info "Checking domain configuration..."
if dig +short $DOMAIN > /dev/null 2>&1; then
    CURRENT_IP=$(dig +short $DOMAIN | head -n1)
    if [ -n "$CURRENT_IP" ]; then
        log_warning "Domain $DOMAIN currently points to: $CURRENT_IP"
        log_info "After deployment, you'll need to update DNS to point to the new load balancer IP"
    fi
else
    log_info "Domain $DOMAIN is not currently configured (this is OK)"
fi

# Create deployment directory
log_info "Creating deployment directory..."
DEPLOY_DIR="securevox-deployment-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Copy deployment script
cp ../deploy_digitalocean.py .
cp ../.env .

# Create Docker configuration
log_info "Creating Docker configuration files..."

# Create Traefik configuration
mkdir -p config/traefik
cat > config/traefik/traefik.yml << 'EOF'
global:
  checkNewVersion: false
  sendAnonymousUsage: false

api:
  dashboard: true
  debug: false

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entrypoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: securevox-backend

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@${DOMAIN}
      storage: /letsencrypt/acme.json
      tlsChallenge: {}

metrics:
  prometheus:
    addEntryPointsLabels: true
    addServicesLabels: true
EOF

# Create Prometheus configuration
mkdir -p config/prometheus
cat > config/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8080']

  - job_name: 'securevox-api'
    static_configs:
      - targets: ['api-server:8000']

  - job_name: 'securevox-calls'
    static_configs:
      - targets: ['call-server:8002']
EOF

# Create Grafana configuration
mkdir -p config/grafana/provisioning/{datasources,dashboards}
cat > config/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
EOF

# Create deployment summary
log_info "Creating deployment summary..."
cat > DEPLOYMENT_PLAN.md << EOF
# 🚀 SecureVOX Deployment Plan

## Configuration
- **Domain**: $DOMAIN
- **SSH Key ID**: $SSH_KEY_ID
- **Deployment Date**: $(date)

## Infrastructure to be Created

### Droplets (5 total)
- **Load Balancer**: 2GB RAM, 2 vCPU (Traefik + SSL)
- **App Servers**: 2x 8GB RAM, 4 vCPU (Django API)
- **Call Server**: 1x 8GB RAM, 4 vCPU (Node.js WebRTC)
- **Monitoring**: 1x 4GB RAM, 2 vCPU (Prometheus + Grafana)

### Managed Services
- **PostgreSQL**: Primary + Replica (4GB RAM)
- **Redis**: 3-node cluster (1GB each)
- **Spaces**: Object storage + CDN

### Domains Created
- https://$DOMAIN (Main site)
- https://api.$DOMAIN (API endpoints)
- https://app.$DOMAIN (📱 **App Distribution**)
- https://calls.$DOMAIN (WebRTC signaling)
- https://monitor.$DOMAIN (Grafana dashboard)

## App Distribution System
The **app.$DOMAIN** subdomain will serve as your personal TestFlight:

### iOS Installation
- Users visit https://app.$DOMAIN on Safari iOS
- Click "Install App" → Automatic OTA installation
- Support for .ipa files with enterprise certificates

### Android Installation
- Direct APK downloads from https://app.$DOMAIN
- Support for .apk and .aab files
- Automatic update notifications

### Admin Features
- Upload new builds via web interface
- User access control (public or private)
- Download analytics and feedback system
- API for CI/CD integration

## Estimated Monthly Cost: ~$360

## Next Steps
1. Run: python3 deploy_digitalocean.py
2. Wait for infrastructure creation (~10-15 minutes)
3. Deploy applications with Docker Compose
4. Configure DNS to point to load balancer IP
5. Upload your first iOS/Android app to https://app.$DOMAIN/admin/

Your SecureVOX infrastructure will be ready for production use! 🎉
EOF

# Final instructions
echo ""
log_success "Setup completed successfully!"
echo ""
log_info "Files created in directory: $DEPLOY_DIR"
echo "  - deploy_digitalocean.py (main deployment script)"
echo "  - .env (environment configuration)"
echo "  - config/ (Docker configurations)"
echo "  - DEPLOYMENT_PLAN.md (deployment summary)"
echo ""
log_info "To deploy your infrastructure:"
echo "  cd $DEPLOY_DIR"
echo "  python3 deploy_digitalocean.py"
echo ""
log_warning "Important notes:"
echo "  1. The deployment will take 10-15 minutes"
echo "  2. Your app distribution system will be available at: https://app.$DOMAIN"
echo "  3. After deployment, update your domain DNS to point to the load balancer IP"
echo "  4. Configure email settings in .env for notifications"
echo ""
log_info "Ready to deploy? (y/N)"
read -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Starting deployment..."
    cd "$DEPLOY_DIR"
    python3 deploy_digitalocean.py
else
    log_info "Deployment files ready. Run when you're ready:"
    echo "  cd $DEPLOY_DIR && python3 deploy_digitalocean.py"
fi

echo ""
log_success "🚀 SecureVOX deployment setup complete!"
