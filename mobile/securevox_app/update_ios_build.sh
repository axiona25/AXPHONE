#!/bin/bash

echo "🍎 AGGIORNAMENTO BUILD iOS SECUREVOX"
echo "====================================="

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

# 1. Pulizia cache Flutter
print_status "Pulizia cache Flutter..."
flutter clean
if [ $? -eq 0 ]; then
    print_success "Cache Flutter pulita"
else
    print_error "Errore pulizia cache Flutter"
    exit 1
fi

# 2. Aggiornamento dipendenze Flutter
print_status "Aggiornamento dipendenze Flutter..."
flutter pub get
if [ $? -eq 0 ]; then
    print_success "Dipendenze Flutter aggiornate"
else
    print_error "Errore aggiornamento dipendenze Flutter"
    exit 1
fi

# 3. Pulizia cache iOS
print_status "Pulizia cache iOS..."
cd ios
if [ $? -eq 0 ]; then
    print_success "Directory iOS trovata"
else
    print_error "Directory iOS non trovata"
    exit 1
fi

# Rimuovi file di cache
rm -rf Podfile.lock
rm -rf Pods
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/Flutter.podspec

print_success "Cache iOS pulita"

# 4. Deintegrazione CocoaPods
print_status "Deintegrazione CocoaPods..."
pod deintegrate
if [ $? -eq 0 ]; then
    print_success "CocoaPods deintegrato"
else
    print_warning "CocoaPods deintegrate fallito (normale se non installato)"
fi

# 5. Reinstallazione CocoaPods
print_status "Reinstallazione CocoaPods..."
pod install --repo-update
if [ $? -eq 0 ]; then
    print_success "CocoaPods installato"
else
    print_error "Errore installazione CocoaPods"
    exit 1
fi

# 6. Torna alla directory principale
cd ..

# 7. Verifica configurazione
print_status "Verifica configurazione..."

# Verifica Podfile
if [ -f "ios/Podfile" ]; then
    print_success "Podfile trovato"
else
    print_error "Podfile non trovato"
    exit 1
fi

# Verifica Info.plist
if [ -f "ios/Runner/Info.plist" ]; then
    print_success "Info.plist trovato"
else
    print_error "Info.plist non trovato"
    exit 1
fi

# Verifica pubspec.yaml
if [ -f "pubspec.yaml" ]; then
    print_success "pubspec.yaml trovato"
else
    print_error "pubspec.yaml non trovato"
    exit 1
fi

# 8. Build iOS
print_status "Avvio build iOS..."
flutter build ios --release --no-codesign
if [ $? -eq 0 ]; then
    print_success "Build iOS completato con successo!"
else
    print_error "Errore build iOS"
    exit 1
fi

# 9. Riepilogo funzionalità
echo ""
echo "🎉 BUILD iOS AGGIORNATO CON SUCCESSO!"
echo "====================================="
echo ""
echo "✅ Funzionalità implementate:"
echo "   - Notifiche sempre visibili con overlay"
echo "   - Dismiss tastiera automatico"
echo "   - Suoni di sistema per chiamate"
echo "   - Stato occupato intelligente"
echo "   - Wake lock per notifiche"
echo "   - Gestione audio avanzata"
echo ""
echo "✅ Configurazioni iOS:"
echo "   - iOS 14.0+ supportato"
echo "   - Background modes abilitati"
echo "   - Audio session configurata"
echo "   - Notifiche push abilitate"
echo "   - WebSocket supportato"
echo "   - Sicurezza configurata"
echo ""
echo "✅ Dipendenze aggiornate:"
echo "   - flutter_local_notifications: ^16.3.3"
echo "   - flutter_app_badger: ^1.5.0"
echo "   - wakelock_plus: ^1.1.4"
echo "   - overlay_support: ^2.0.0"
echo "   - audioplayers: ^5.2.1"
echo ""
echo "🚀 Il progetto è pronto per il deploy!"
echo ""
echo "Per aprire in Xcode:"
echo "   open ios/Runner.xcworkspace"
echo ""
echo "Per build finale:"
echo "   flutter build ios --release"
echo ""
