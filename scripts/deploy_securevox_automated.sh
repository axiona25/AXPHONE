#!/bin/bash

echo "🚀 Deploy Automatico SecureVox su Oracle Cloud"
echo "=============================================="

# Variabili
INSTANCE_ID="ocid1.instance.oc1.eu-milan-1.anwgsljrqoeuthacollibbry4wd2muukk4ejtiul6tg6dw27o6rdavcj5v6q"
REGION="eu-milan-1"
PUBLIC_IP="130.110.3.186"

echo "📍 Istanza: $INSTANCE_ID"
echo "🌐 IP Pubblico: $PUBLIC_IP"
echo ""

# 1. Crea uno script di installazione
echo "📝 Creando script di installazione..."
cat > securevox_install.sh << 'EOF'
#!/bin/bash
echo "🚀 Installazione SecureVox su Oracle Cloud"
echo "=========================================="

# Aggiorna il sistema
sudo apt update && sudo apt upgrade -y

# Installa Docker
sudo apt install -y docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Installa Git
sudo apt install -y git

# Clona il repository (placeholder - dovresti avere il codice)
# git clone https://github.com/your-repo/securevox.git
# cd securevox

# Per ora creiamo una struttura di base
mkdir -p /home/ubuntu/securevox
cd /home/ubuntu/securevox

# Crea docker-compose.yml
cat > docker-compose.yml << 'DOCKER_EOF'
version: '3.8'
services:
  securevox-backend:
    image: python:3.9-slim
    ports:
      - "8001:8001"
    volumes:
      - ./server:/app
    working_dir: /app
    command: python manage.py runserver 0.0.0.0:8001
    environment:
      - DEBUG=True
      - ALLOWED_HOSTS=*

  securevox-call:
    image: node:16-slim
    ports:
      - "8002:8002"
    volumes:
      - ./call-server:/app
    working_dir: /app
    command: npm start
    environment:
      - SECUREVOX_CALL_PORT=8002
      - JWT_SECRET=test-secret
      - NODE_ENV=development
      - HOST=0.0.0.0
      - MAIN_SERVER_URL=http://localhost:8001
      - NOTIFY_SERVER_URL=http://localhost:8003

  securevox-notify:
    image: python:3.9-slim
    ports:
      - "8003:8003"
    volumes:
      - ./server:/app
    working_dir: /app
    command: python securevox_notify.py
    environment:
      - DEBUG=True
DOCKER_EOF

echo "✅ Script di installazione creato"
echo "🌐 SecureVox sarà disponibile su:"
echo "   - Backend: http://$PUBLIC_IP:8001"
echo "   - Call Server: http://$PUBLIC_IP:8002"
echo "   - Notify Server: http://$PUBLIC_IP:8003"
EOF

# 2. Crea un volume di boot con lo script
echo "💾 Creando volume di boot personalizzato..."
# Questo richiede più passi complessi con OCI

echo "⚠️  Per ora, usa la console del browser per:"
echo "1. Vai su https://cloud.oracle.com"
echo "2. Accedi con le tue credenziali"
echo "3. Vai su Compute → Instances"
echo "4. Clicca su 'securevox-production-new'"
echo "5. Clicca su 'Console' per accedere via browser"
echo "6. Esegui i comandi di installazione manualmente"

echo ""
echo "🎯 PROSSIMI PASSI:"
echo "=================="
echo "1. Accedi alla console del browser"
echo "2. Esegui: sudo apt update && sudo apt install -y docker.io"
echo "3. Installa SecureVox manualmente"
echo "4. Configura le porte 8001, 8002, 8003"
