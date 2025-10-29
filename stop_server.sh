#!/bin/bash

echo "🛑 Fermando server SecureVOX..."
echo "==============================="

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Ferma processi Django
print_status "Fermando processi Django..."
if pkill -f "manage.py runserver"; then
    print_success "Processi Django fermati"
else
    print_warning "Nessun processo Django trovato"
fi

# Ferma processi sulla porta 8001
print_status "Fermando processi sulla porta 8001..."
if lsof -ti:8001 > /dev/null 2>&1; then
    kill $(lsof -ti:8001) 2>/dev/null
    print_success "Processi sulla porta 8001 fermati"
else
    print_warning "Nessun processo sulla porta 8001"
fi

# Ferma processi sulla porta 8000 (backup)
print_status "Fermando processi sulla porta 8000..."
if lsof -ti:8000 > /dev/null 2>&1; then
    kill $(lsof -ti:8000) 2>/dev/null
    print_success "Processi sulla porta 8000 fermati"
else
    print_warning "Nessun processo sulla porta 8000"
fi

# Ferma processi Node.js (se la dashboard è in esecuzione)
print_status "Fermando processi Node.js..."
if pkill -f "vite"; then
    print_success "Processi Vite fermati"
else
    print_warning "Nessun processo Vite trovato"
fi

print_success "✅ Tutti i server sono stati fermati!"
print_status "Per riavviare: ./start_server_8001.sh"
