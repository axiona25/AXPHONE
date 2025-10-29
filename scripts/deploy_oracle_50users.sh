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
