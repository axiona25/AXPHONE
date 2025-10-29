#!/bin/bash

# Deploy SecureVox su Oracle Cloud
IP="130.110.3.186"
DOMAIN="securevox.it"

echo "🚀 Deploy SecureVox su Oracle Cloud"
echo "=================================="
echo "📍 IP: $IP"
echo "🌐 Domain: $DOMAIN"
echo ""

# Testa connessione SSH
echo "🔍 Testando connessione SSH..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$IP "echo 'Connessione SSH OK'" 2>/dev/null; then
    echo "✅ Connessione SSH funzionante"
else
    echo "❌ Connessione SSH fallita"
    echo "💡 Configura prima le regole di sicurezza per la porta 22"
    echo "💡 Oppure usa un approccio diverso (es. Docker Hub + pull)"
    exit 1
fi

echo ""
echo "📦 Installando SecureVox..."

# Installa tutto via SSH
ssh ubuntu@$IP << 'REMOTE_SCRIPT'
set -e

echo "🔄 Aggiornando sistema..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installando dipendenze..."
sudo apt install -y docker.io docker-compose git nginx certbot python3-certbot-nginx curl wget unzip python3 python3-pip python3-venv

echo "🐳 Configurando Docker..."
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

echo "📁 Creando directory..."
mkdir -p ~/securevox
cd ~/securevox

echo "📥 Clonando repository SecureVox..."
# Per ora creiamo la struttura, poi copieremo i file
mkdir -p server call-server mobile

echo "✅ Setup base completato!"
REMOTE_SCRIPT

echo ""
echo "📤 Copiando file SecureVox..."

# Copia i file del progetto
rsync -avz --progress /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/ ubuntu@$IP:~/securevox/ --exclude='.git' --exclude='node_modules' --exclude='__pycache__' --exclude='*.pyc' --exclude='venv_local'

echo ""
echo "🔧 Configurando servizi..."

# Configura e avvia i servizi
ssh ubuntu@$IP << 'REMOTE_SCRIPT'
set -e

cd ~/securevox

echo "🐳 Avviando servizi con Docker Compose..."
sudo docker-compose -f docker-compose.securevox-call.yml up -d

echo "⏳ Aspetto che i servizi si avviino..."
sleep 30

echo "🔍 Verificando servizi..."
sudo docker-compose -f docker-compose.securevox-call.yml ps

echo "📱 Configurando App Distribution..."
# Setup App Distribution se non è già configurato
if [ ! -f "server/src/app_distribution/migrations/0001_initial.py" ]; then
    echo "🔧 Creando migrazioni App Distribution..."
    sudo docker exec securevox-backend python manage.py makemigrations app_distribution
    sudo docker exec securevox-backend python manage.py migrate
    sudo docker exec securevox-backend python manage.py setup_app_distribution --create-demo-data
fi

echo "✅ Installazione completata!"
echo ""
echo "📋 Servizi attivi:"
echo "  - Django Backend: http://$IP:8001"
echo "  - Call Server: http://$IP:8002"  
echo "  - Notify Server: http://$IP:8003"
echo "  - App Distribution: http://$IP:8001/app-distribution/"
echo ""
echo "🌐 Configura il dominio $DOMAIN per puntare a $IP"
REMOTE_SCRIPT

echo ""
echo "🎉 Deploy completato!"
echo "📍 IP Pubblico: $IP"
echo "🌐 Prossimo passo: Configurare il dominio $DOMAIN"
echo ""
echo "📋 Per accedere al server:"
echo "   ssh ubuntu@$IP"
echo ""
echo "🔧 Per gestire i servizi:"
echo "   cd ~/securevox"
echo "   sudo docker-compose -f docker-compose.securevox-call.yml up -d"
