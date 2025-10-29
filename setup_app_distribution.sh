#!/bin/bash

# 📱 SecureVOX App Distribution - Setup Script
# Questo script configura il sistema di distribuzione app

set -e

echo "🚀 SecureVOX App Distribution Setup"
echo "=================================="

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Verifica che siamo nella directory corretta
if [ ! -f "server/manage.py" ]; then
    print_error "Errore: Esegui questo script dalla root del progetto SecureVOX"
    exit 1
fi

print_status "Configurazione App Distribution..."

# Vai nella directory server
cd server

# Verifica che Python e Django siano disponibili
if ! command -v python3 &> /dev/null; then
    print_error "Python3 non trovato. Installa Python3 per continuare."
    exit 1
fi

print_success "Python3 trovato"

# Verifica dipendenze Django
print_status "Verifico dipendenze Django..."
if ! python3 -c "import django" &> /dev/null; then
    print_error "Django non trovato. Installa le dipendenze con: pip install -r requirements.txt"
    exit 1
fi

print_success "Django trovato"

# Crea le migrazioni
print_status "Creazione migrazioni per App Distribution..."
python3 manage.py makemigrations app_distribution
print_success "Migrazioni create"

# Applica le migrazioni
print_status "Applicazione migrazioni..."
python3 manage.py migrate
print_success "Migrazioni applicate"

# Crea directory media
print_status "Creazione directory media..."
mkdir -p media/app_builds
mkdir -p media/app_icons
print_success "Directory media create"

# Setup iniziale
print_status "Setup iniziale sistema..."
python3 manage.py setup_app_distribution --create-demo-data
print_success "Setup iniziale completato"

# Verifica se esiste un superuser
print_status "Verifica superuser..."
if ! python3 manage.py shell -c "from django.contrib.auth.models import User; print('exists' if User.objects.filter(is_superuser=True).exists() else 'none')" | grep -q "exists"; then
    print_warning "Nessun superuser trovato. Ne creo uno ora..."
    echo ""
    echo "📝 Crea un account amministratore:"
    python3 manage.py createsuperuser
    print_success "Superuser creato"
else
    print_success "Superuser già esistente"
fi

echo ""
echo "🎉 Setup completato con successo!"
echo ""
echo "📋 Prossimi passi:"
echo "=================="
echo ""
echo "1. 🖥️  Avvia il server:"
echo "   cd server && python3 manage.py runserver 0.0.0.0:8001"
echo ""
echo "2. 🌐 Accedi all'interfaccia web:"
echo "   http://localhost:8001/app-distribution/"
echo ""
echo "3. 🔧 Gestisci le build tramite admin:"
echo "   http://localhost:8001/admin/"
echo ""
echo "4. 📱 Per caricare le tue app:"
echo "   - Vai nell'admin panel"
echo "   - Sezione 'App Distribution' > 'App builds'"
echo "   - Clicca 'Aggiungi app build'"
echo "   - Carica il file .ipa (iOS) o .apk/.aab (Android)"
echo ""
echo "5. 📖 Leggi la documentazione completa:"
echo "   docs/APP_DISTRIBUTION_SETUP.md"
echo ""

# Verifica se il server è già in esecuzione
if lsof -i:8001 &> /dev/null; then
    print_warning "Il server sembra già in esecuzione sulla porta 8001"
    echo "   Vai su: http://localhost:8001/app-distribution/"
else
    print_status "Per avviare il server ora:"
    echo "   python3 manage.py runserver 0.0.0.0:8001"
fi

echo ""
print_success "Setup App Distribution completato! 🚀"

# Torna alla directory originale
cd ..

exit 0
