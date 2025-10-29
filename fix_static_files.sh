#!/bin/bash

echo "🔧 Risoluzione Errori File Statici Dashboard"
echo "============================================"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Pulisci la build precedente
print_status "Pulendo build precedente..."
cd admin
rm -rf dist/
print_success "Build precedente rimossa"

# 2. Rebuilda la dashboard
print_status "Rebuilding dashboard con configurazione corretta..."
npm run build

if [ $? -eq 0 ]; then
    print_success "✅ Dashboard rebuildata con successo!"
else
    print_error "❌ Errore nel rebuild della dashboard"
    exit 1
fi

# 3. Verifica che i file esistano
print_status "Verificando file generati..."
if [ -f "dist/index.html" ]; then
    print_success "✅ index.html generato"
else
    print_error "❌ index.html non trovato"
    exit 1
fi

# Conta i file CSS e JS
css_files=$(find dist/assets -name "*.css" 2>/dev/null | wc -l)
js_files=$(find dist/assets -name "*.js" 2>/dev/null | wc -l)

print_status "File CSS generati: $css_files"
print_status "File JS generati: $js_files"

if [ $css_files -gt 0 ] && [ $js_files -gt 0 ]; then
    print_success "✅ File statici generati correttamente"
else
    print_warning "⚠️  Alcuni file statici potrebbero mancare"
fi

# 4. Mostra i file generati
print_status "File generati nella build:"
ls -la dist/assets/ 2>/dev/null || print_warning "Directory assets non trovata"

cd ..

# 5. Test della dashboard
print_status "Testando la dashboard..."
python3 test_dashboard_8001.py

echo ""
print_success "🎉 Risoluzione completata!"
print_status "🌐 Ricarica la pagina: http://localhost:8001/admin"
print_status "🔍 Controlla la console del browser per verificare che non ci siano più errori 404"
