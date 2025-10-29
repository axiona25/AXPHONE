# 📱 SecureVOX - Guida Deployment iPhone Fisici

**Versione**: 1.3.0  
**Data**: 1 Ottobre 2025  
**Compatibilità**: iOS 14.0+

---

## 🚀 **Deployment Rapido**

### 1. **Esegui lo Script di Configurazione**
```bash
cd /Users/r.amoroso/Desktop/Securevox/mobile/securevox_app
./configure_xcode_deployment.sh
```

### 2. **In Xcode (si aprirà automaticamente)**
1. Seleziona il tuo iPhone fisico come destinazione
2. Vai su **Signing & Capabilities**
3. Seleziona il tuo **Team di sviluppo Apple**
4. Clicca su **Build and Run** (⌘+R)

---

## 📋 **Configurazione Dettagliata**

### 🔧 **Prerequisiti**

#### ✅ **Apple Developer Account**
- Account Apple Developer attivo
- Dispositivo registrato nel profilo di sviluppo
- Certificati di sviluppo validi

#### ✅ **Xcode**
- Xcode 15.0+ installato
- Command Line Tools configurati
- Simulator iOS installato

#### ✅ **Dispositivo iPhone**
- iOS 14.0 o superiore
- Connesso via USB o Wi-Fi
- Modalità sviluppatore abilitata
- Dispositivo fidato nel Mac

---

## 🛠️ **Configurazione Step-by-Step**

### **Step 1: Preparazione Progetto**
```bash
# Naviga nella directory del progetto
cd /Users/r.amoroso/Desktop/Securevox/mobile/securevox_app

# Pulisci e ricostruisci
flutter clean
flutter pub get

# Build per dispositivo fisico
flutter build ios --release
```

### **Step 2: Apertura Xcode**
```bash
# Apri il workspace Xcode
open ios/Runner.xcworkspace
```

### **Step 3: Configurazione Xcode**

#### 🎯 **Selezione Dispositivo**
1. In Xcode, clicca sul menu a tendina accanto al pulsante "Build and Run"
2. Seleziona il tuo iPhone fisico dalla lista
3. Verifica che sia mostrato come "Connected" o "Available"

#### 🔐 **Configurazione Signing**
1. Seleziona il target **Runner** nel navigator
2. Vai alla tab **Signing & Capabilities**
3. Configura:
   - **Team**: Seleziona il tuo Apple Developer Team
   - **Bundle Identifier**: `com.example.securevoxApp`
   - **Signing Certificate**: Automatico o manuale
   - **Provisioning Profile**: Automatico o manuale

#### ⚙️ **Configurazione Build**
1. Vai su **Build Settings**
2. Verifica:
   - **iOS Deployment Target**: 14.0
   - **Architectures**: arm64
   - **Code Signing Identity**: Apple Development

### **Step 4: Deployment**

#### 🚀 **Build and Run**
1. Clicca su **Build and Run** (⌘+R)
2. Attendi la compilazione
3. L'app verrà installata automaticamente sull'iPhone

#### 📱 **Primo Avvio**
1. Sull'iPhone, vai su **Impostazioni > Generali > Gestione profili**
2. Fidati del profilo di sviluppo
3. Apri l'app SecureVOX

---

## 🔧 **Risoluzione Problemi**

### ❌ **"No matching provisioning profiles found"**
**Soluzione:**
1. In Xcode, vai su **Preferences > Accounts**
2. Aggiungi il tuo Apple ID
3. Clicca su **Download Manual Profiles**
4. Riprova il build

### ❌ **"Device not registered"**
**Soluzione:**
1. Vai su [Apple Developer Portal](https://developer.apple.com)
2. **Certificates, Identifiers & Profiles > Devices**
3. Aggiungi il tuo iPhone con UDID
4. Rigenera il provisioning profile

### ❌ **"Code signing error"**
**Soluzione:**
1. In Xcode, vai su **Signing & Capabilities**
2. Cambia da "Automatic" a "Manual"
3. Seleziona il certificato corretto
4. Seleziona il provisioning profile corretto

### ❌ **"App installation failed"**
**Soluzione:**
1. Verifica che l'iPhone sia sbloccato
2. Controlla che ci sia spazio sufficiente
3. Riavvia l'iPhone e riprova
4. Verifica che l'app non sia già installata

---

## 📊 **Configurazioni Specifiche SecureVOX**

### 🔐 **Permessi Richiesti**
L'app richiede i seguenti permessi (già configurati in Info.plist):
- **Camera**: Per foto e video
- **Microfono**: Per chiamate audio
- **Posizione**: Per condivisione posizione
- **Foto**: Per accesso galleria

### 🎵 **Suoni e Notifiche**
- Suoni personalizzati per chiamate
- Notifiche push per messaggi
- Background audio per chiamate

### 📞 **Funzionalità WebRTC**
- Chiamate audio/video real-time
- Signaling WebSocket
- Gestione ICE candidates

---

## 🎯 **Checklist Deployment**

### ✅ **Prima del Deployment**
- [ ] Apple Developer Account attivo
- [ ] iPhone connesso e fidato
- [ ] Xcode aggiornato
- [ ] Flutter build completato
- [ ] Certificati validi

### ✅ **Durante il Deployment**
- [ ] Dispositivo selezionato in Xcode
- [ ] Team di sviluppo configurato
- [ ] Bundle ID corretto
- [ ] Build and Run eseguito
- [ ] App installata sull'iPhone

### ✅ **Dopo il Deployment**
- [ ] App si avvia correttamente
- [ ] Permessi richiesti e concessi
- [ ] Funzionalità testate
- [ ] Chiamate audio/video funzionanti
- [ ] Notifiche operative

---

## 🚀 **Deployment Automatico**

### **Script di Deploy Rapido**
```bash
#!/bin/bash
# Deploy automatico su iPhone fisico

echo "🚀 SecureVOX - Deploy Automatico iPhone"
cd /Users/r.amoroso/Desktop/Securevox/mobile/securevox_app

# Build
flutter build ios --release

# Deploy
flutter install --release
```

### **Deploy via Xcode Command Line**
```bash
# Build e deploy in un comando
xcodebuild -workspace ios/Runner.xcworkspace \
           -scheme Runner \
           -destination 'generic/platform=iOS' \
           -configuration Release \
           build

# Installa sull'iPhone connesso
ios-deploy --bundle build/ios/iphoneos/Runner.app
```

---

## 📞 **Supporto**

Per problemi o domande:
- **GitHub Issues**: [solutions25/securevox](https://github.com/solutions25/securevox)
- **Documentazione**: Vedi README.md
- **Release Notes**: Vedi RELEASE_NOTES_v1.3.0.md

---

**🎉 Buon deployment! L'app SecureVOX è pronta per iPhone fisici!** 📱✨
