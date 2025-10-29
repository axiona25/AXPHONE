#!/bin/bash

# 🚀 SecureVOX - Deploy Automatico su iPhone Fisico
# Versione: 1.3.0
# Data: 1 Ottobre 2025

echo "📱 SecureVOX - Deploy Automatico iPhone Fisico"
echo "=============================================="

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Directory del progetto
PROJECT_DIR="/Users/r.amoroso/Desktop/Securevox/mobile/securevox_app"
cd "$PROJECT_DIR"

# Verifica che Flutter sia disponibile
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter non trovato. Installa Flutter.${NC}"
    exit 1
fi

# Verifica che ios-deploy sia installato
if ! command -v ios-deploy &> /dev/null; then
    echo -e "${YELLOW}⚠️  ios-deploy non trovato. Installazione...${NC}"
    npm install -g ios-deploy
fi

echo -e "${GREEN}✅ Flutter: $(flutter --version | head -n1)${NC}"
echo -e "${GREEN}✅ ios-deploy: $(ios-deploy --version)${NC}"

# 1. Pulisci il progetto
echo -e "${YELLOW}🧹 Pulizia progetto...${NC}"
flutter clean
flutter pub get

# 2. Build per dispositivo fisico
echo -e "${YELLOW}🔨 Build per dispositivo fisico...${NC}"
flutter build ios --release

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Errore durante la build iOS${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build completata con successo${NC}"

# 3. Verifica dispositivi connessi
echo -e "${YELLOW}📱 Verifica dispositivi connessi...${NC}"
DEVICES=$(ios-deploy --detect)
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Nessun dispositivo iOS trovato${NC}"
    echo -e "${YELLOW}💡 Assicurati che:${NC}"
    echo "   - L'iPhone sia connesso via USB"
    echo "   - Il dispositivo sia sbloccato"
    echo "   - L'iPhone sia fidato nel Mac"
    echo "   - Il dispositivo sia registrato nel tuo Apple Developer Account"
    exit 1
fi

echo -e "${GREEN}✅ Dispositivo iOS trovato${NC}"

# 4. Deploy sull'iPhone
echo -e "${YELLOW}🚀 Deploy sull'iPhone...${NC}"
ios-deploy --bundle build/ios/iphoneos/Runner.app --debug

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 Deploy completato con successo!${NC}"
    echo -e "${BLUE}📱 L'app SecureVOX è ora installata sul tuo iPhone${NC}"
else
    echo -e "${RED}❌ Errore durante il deploy${NC}"
    echo -e "${YELLOW}💡 Possibili soluzioni:${NC}"
    echo "   - Verifica che l'iPhone sia sbloccato"
    echo "   - Controlla che ci sia spazio sufficiente"
    echo "   - Riavvia l'iPhone e riprova"
    echo "   - Verifica i certificati di sviluppo"
    exit 1
fi

echo ""
echo -e "${GREEN}🎊 SecureVOX v1.3.0 installata con successo!${NC}"
echo -e "${BLUE}📋 Funzionalità disponibili:${NC}"
echo "   📞 Chiamate audio/video WebRTC"
echo "   💬 Messaggi in tempo reale"
echo "   📷 Condivisione foto e video"
echo "   📍 Condivisione posizione"
echo "   🔔 Notifiche push"
echo "   🎵 Suoni personalizzati"
echo ""
echo -e "${YELLOW}⚠️  NOTA: Al primo avvio, concedi tutti i permessi richiesti${NC}"
echo -e "${GREEN}🚀 Buon utilizzo di SecureVOX!${NC}"
