#!/bin/bash

echo "🚀 Avvio SecureVOX Server sulla porta 8001"
echo "=========================================="

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Entra nella directory server
cd server

# Verifica che Python sia installato
if ! command -v python &> /dev/null; then
    print_error "Python non trovato. Installa Python prima di continuare."
    exit 1
fi

print_status "Avvio server Django sulla porta 8001..."
print_success "Dashboard disponibile su: http://localhost:8001/admin"
print_success "API disponibili su: http://localhost:8001/api/"
print_success "Health check su: http://localhost:8001/health/"

echo ""
print_status "Premi Ctrl+C per fermare il server"
echo ""

# Avvia il server Django sulla porta 8001
python manage.py runserver 8001
