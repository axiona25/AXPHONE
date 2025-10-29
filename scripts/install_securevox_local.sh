#!/bin/bash

echo "🚀 Installazione SecureVox Locale con Docker"
echo "==========================================="
echo ""

# Verifica Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker non installato. Installa Docker Desktop prima di procedere."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose non installato. Installa Docker Compose prima di procedere."
    exit 1
fi

echo "✅ Docker e Docker Compose trovati"

# Vai nella directory del progetto
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack

echo ""
echo "🐳 Avviando servizi SecureVox..."

# Avvia i servizi con Docker Compose
docker-compose -f docker-compose.securevox-call.yml up -d

echo "⏳ Aspetto che i servizi si avviino..."
sleep 30

echo ""
echo "🔍 Verificando servizi..."
docker-compose -f docker-compose.securevox-call.yml ps

echo ""
echo "📱 Configurando App Distribution..."
# Setup App Distribution
docker exec securevox-backend python manage.py makemigrations app_distribution
docker exec securevox-backend python manage.py migrate
docker exec securevox-backend python manage.py setup_app_distribution --create-demo-data

echo ""
echo "🔐 Attivando moduli di crittografia..."
# Attiva moduli di crittografia
docker exec securevox-backend python manage.py makemigrations crypto
docker exec securevox-backend python manage.py migrate

echo ""
echo "🔔 Configurando notifiche..."
# Attiva notifiche
docker exec securevox-backend python manage.py makemigrations notifications
docker exec securevox-backend python manage.py migrate

echo ""
echo "📱 Configurando gestione dispositivi..."
# Attiva gestione dispositivi
docker exec securevox-backend python manage.py makemigrations devices
docker exec securevox-backend python manage.py migrate

echo ""
echo "✅ Installazione completata!"
echo ""
echo "📋 Servizi attivi:"
echo "  - Django Backend: http://localhost:8001"
echo "  - Call Server: http://localhost:8002"  
echo "  - Notify Server: http://localhost:8003"
echo "  - App Distribution: http://localhost:8001/app-distribution/"
echo "  - Admin Panel: http://localhost:8001/admin/"
echo ""
echo "🎉 SecureVox è ora attivo localmente!"
echo "🌐 Apri http://localhost:8001 per iniziare"
