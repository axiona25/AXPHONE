#!/bin/bash

# 🚀 SecureVOX - Configurazione Xcode per Deployment iPhone Fisici
# Versione: 1.3.0
# Data: 1 Ottobre 2025

echo "🍎 SecureVOX - Configurazione Xcode per iPhone Fisici"
echo "=================================================="

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Verifica che Xcode sia installato
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode non trovato. Installa Xcode dal Mac App Store.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Xcode trovato: $(xcodebuild -version | head -n1)${NC}"

# Verifica che Flutter sia configurato
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter non trovato. Installa Flutter.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Flutter trovato: $(flutter --version | head -n1)${NC}"

# Directory del progetto
PROJECT_DIR="/Users/r.amoroso/Desktop/Securevox/mobile/securevox_app"
IOS_DIR="$PROJECT_DIR/ios"

echo -e "${BLUE}📁 Directory progetto: $PROJECT_DIR${NC}"

# Verifica che il progetto iOS esista
if [ ! -d "$IOS_DIR" ]; then
    echo -e "${RED}❌ Directory iOS non trovata: $IOS_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Directory iOS trovata${NC}"

# 1. Pulisci e ricostruisci il progetto
echo -e "${YELLOW}🧹 Pulizia progetto Flutter...${NC}"
cd "$PROJECT_DIR"
flutter clean
flutter pub get

# 2. Build per dispositivo fisico
echo -e "${YELLOW}🔨 Build per dispositivo fisico...${NC}"
flutter build ios --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build iOS completata con successo${NC}"
else
    echo -e "${RED}❌ Errore durante la build iOS${NC}"
    exit 1
fi

# 3. Apri Xcode
echo -e "${YELLOW}🚀 Apertura Xcode...${NC}"
open "$IOS_DIR/Runner.xcworkspace"

echo ""
echo -e "${GREEN}🎉 Configurazione completata!${NC}"
echo ""
echo -e "${BLUE}📋 ISTRUZIONI PER DEPLOYMENT:${NC}"
echo "1. In Xcode, seleziona il tuo iPhone fisico come destinazione"
echo "2. Vai su 'Signing & Capabilities'"
echo "3. Seleziona il tuo Team di sviluppo Apple"
echo "4. Verifica che il Bundle Identifier sia: com.example.securevoxApp"
echo "5. Clicca su 'Build and Run' (⌘+R)"
echo ""
echo -e "${YELLOW}⚠️  NOTA: Assicurati che il tuo iPhone sia connesso e fidato${NC}"
echo -e "${YELLOW}⚠️  NOTA: Il dispositivo deve essere registrato nel tuo Apple Developer Account${NC}"
echo ""
echo -e "${GREEN}🚀 Pronto per il deployment su iPhone fisico!${NC}"
