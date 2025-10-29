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
