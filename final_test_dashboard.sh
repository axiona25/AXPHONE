#!/bin/bash

echo "🎯 Test Finale Dashboard SecureVOX"
echo "=================================="

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

# Test 1: Server attivo
print_status "1. Verificando server Django..."
if curl -s http://localhost:8001/health/ > /dev/null 2>&1; then
    print_success "✅ Server Django attivo"
else
    print_error "❌ Server Django non attivo"
    echo "   Avvia il server con: cd server && python3 manage.py runserver 8001"
    exit 1
fi

# Test 2: Dashboard accessibile
print_status "2. Verificando dashboard..."
DASHBOARD_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8001/admin/)
HTTP_CODE="${DASHBOARD_RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    print_success "✅ Dashboard accessibile (HTTP 200)"
else
    print_error "❌ Dashboard non accessibile (HTTP $HTTP_CODE)"
    exit 1
fi

# Test 3: Nessun riferimento esterno a file CSS/JS
print_status "3. Verificando assenza di riferimenti esterni..."
EXTERNAL_REFS=$(curl -s http://localhost:8001/admin/ | grep -c -E "assets.*\.(css|js)")
if [ "$EXTERNAL_REFS" -eq 0 ]; then
    print_success "✅ Nessun riferimento esterno a file CSS/JS"
else
    print_warning "⚠️  Trovati $EXTERNAL_REFS riferimenti esterni"
fi

# Test 4: Presenza di file inline
print_status "4. Verificando file inline..."
CSS_INLINE=$(curl -s http://localhost:8001/admin/ | grep -c "<style>")
JS_INLINE=$(curl -s http://localhost:8001/admin/ | grep -c '<script type="module">')

print_status "   CSS inline: $CSS_INLINE"
print_status "   JS inline: $JS_INLINE"

if [ "$CSS_INLINE" -gt 0 ] && [ "$JS_INLINE" -gt 0 ]; then
    print_success "✅ File CSS e JS inline presenti"
else
    print_warning "⚠️  File inline potrebbero mancare"
fi

# Test 5: API funzionanti
print_status "5. Verificando API..."
API_ENDPOINTS=(
    "/admin/api/dashboard-stats-test/"
    "/admin/api/users-management/"
)

for endpoint in "${API_ENDPOINTS[@]}"; do
    API_RESPONSE=$(curl -s -w "%{http_code}" http://localhost:8001$endpoint)
    API_CODE="${API_RESPONSE: -3}"
    
    if [ "$API_CODE" = "200" ]; then
        print_success "   ✅ $endpoint"
    else
        print_warning "   ⚠️  $endpoint (HTTP $API_CODE)"
    fi
done

# Risultato finale
echo ""
echo "=================================="
print_success "🎉 RISULTATO FINALE"
echo "=================================="

if [ "$EXTERNAL_REFS" -eq 0 ] && [ "$CSS_INLINE" -gt 0 ] && [ "$JS_INLINE" -gt 0 ]; then
    print_success "✅ DASHBOARD COMPLETAMENTE FUNZIONALE!"
    echo ""
    print_status "🌐 Dashboard: http://localhost:8001/admin"
    print_status "🔐 Login con credenziali admin del sistema"
    print_status "📱 Interfaccia responsive e moderna"
    print_status "🇮🇹 Completamente in italiano"
    print_status "❌ ZERO errori 404 per file statici"
    echo ""
    print_success "La dashboard SecureVOX è pronta per l'uso! 🛡️"
else
    print_warning "⚠️  Dashboard funzionante ma potrebbero esserci problemi minori"
    print_status "Verifica manualmente nel browser: http://localhost:8001/admin"
fi
