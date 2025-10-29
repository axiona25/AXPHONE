#!/bin/bash

# Setup SecureVox su Oracle Cloud
IP="204.216.219.104"
DOMAIN="www.securevox.it"

echo "🚀 Setup SecureVox su Oracle Cloud"
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
    echo "💡 Verifica che la chiave SSH sia configurata correttamente"
    exit 1
fi

echo ""
echo "📦 Installando dipendenze..."

# Installa dipendenze base
ssh ubuntu@$IP << 'REMOTE_SCRIPT'
set -e

echo "🔄 Aggiornando sistema..."
sudo apt update && sudo apt upgrade -y

echo "📦 Installando dipendenze..."
sudo apt install -y docker.io docker-compose git nginx certbot python3-certbot-nginx

echo "🐳 Avviando Docker..."
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

echo "📁 Creando directory..."
mkdir -p ~/securevox
cd ~/securevox

echo "📥 Clonando repository..."
git clone https://github.com/your-repo/securevox.git . || echo "Repository non disponibile, creando struttura base"

echo "✅ Setup base completato!"
REMOTE_SCRIPT

echo ""
echo "🎉 Setup completato!"
echo "📍 IP Pubblico: $IP"
echo "🌐 Prossimo passo: Configurare DNS per $DOMAIN → $IP"
echo ""
echo "📋 Per accedere al server:"
echo "   ssh ubuntu@$IP"
echo ""
echo "🔧 Per configurare il dominio:"
echo "   1. Vai al tuo provider DNS"
echo "   2. Crea un record A: $DOMAIN → $IP"
echo "   3. Crea un record CNAME: securevox.it → $DOMAIN"
