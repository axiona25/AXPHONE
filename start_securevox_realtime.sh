#!/bin/bash

# Script completo per avviare SecureVOX con dashboard real-time
echo "🛡️ Avvio SecureVOX con Dashboard Real-time"
echo "============================================="

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica prerequisiti
print_status "Verifica prerequisiti..."

# Verifica Redis
if ! redis-cli ping > /dev/null 2>&1; then
    print_warning "Redis non è in esecuzione. Avvio Redis..."
    redis-server --daemonize yes --port 6379
    sleep 3
    
    if redis-cli ping > /dev/null 2>&1; then
        print_success "Redis avviato con successo"
    else
        print_error "Impossibile avviare Redis. Installalo con: brew install redis"
        exit 1
    fi
else
    print_success "Redis già in esecuzione"
fi

# Verifica Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js non trovato. Installalo da https://nodejs.org/"
    exit 1
else
    print_success "Node.js $(node --version) trovato"
fi

# Verifica Python
if ! command -v python3 &> /dev/null; then
    print_error "Python3 non trovato"
    exit 1
else
    print_success "Python3 $(python3 --version) trovato"
fi

# Build della dashboard React
print_status "Build della dashboard React..."
cd admin

if [ ! -d "node_modules" ]; then
    print_status "Installazione dipendenze npm..."
    npm install
fi

print_status "Build della dashboard..."
npm run build:securevox

if [ $? -eq 0 ]; then
    print_success "Dashboard React buildata con successo"
else
    print_error "Errore nel build della dashboard"
    exit 1
fi

cd ..

# Setup del server Django
print_status "Setup del server Django..."
cd server

# Attiva ambiente virtuale
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
    print_success "Ambiente virtuale attivato"
else
    print_error "Ambiente virtuale non trovato. Crealo con: python3 -m venv venv"
    exit 1
fi

# Installa dipendenze se necessario
print_status "Verifica dipendenze Python..."
pip install django-channels channels-redis daphne > /dev/null 2>&1
print_success "Dipendenze Python verificate"

# Applica migrazioni
print_status "Applicazione migrazioni database..."
python manage.py makemigrations > /dev/null 2>&1
python manage.py migrate > /dev/null 2>&1
print_success "Migrazioni applicate"

# Raccoglie file statici
print_status "Raccolta file statici..."
python manage.py collectstatic --noinput > /dev/null 2>&1
print_success "File statici raccolti"

# Torna alla directory principale
cd ..

# Avvia il server
print_status "Avvio del server Django con WebSocket..."
print ""
print "🌐 Dashboard Admin: http://localhost:8001/admin/"
print "📡 WebSocket: ws://localhost:8001/ws/admin/"
print "🔌 API: http://localhost:8001/admin/api/"
print ""
print "Premi Ctrl+C per fermare il server"
print ""

# Avvia il server ASGI con daphne
cd server
daphne -b 0.0.0.0 -p 8001 src.asgi:application
