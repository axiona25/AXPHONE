#!/bin/bash

# Start SecureVox 50 Users Monitoring

echo "🛡️ Starting SecureVox 50 Users Protection Monitoring..."

# Activate virtual environment
source ../venv_oracle/bin/activate

# Load environment
source .env.deployment

# Start monitoring
python3 ../scripts/oracle_protection_50users.py --monitor --interval ${MONITORING_INTERVAL_MINUTES:-5}
