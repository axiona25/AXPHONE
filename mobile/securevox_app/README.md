# SecureVOX Mobile App

App mobile Flutter per comunicazioni sicure end-to-end.

## 🎨 Design System

Basato sul design Figma con font **Poppins** come standard per tutto il progetto.

### Colori
- **Primary**: Ciano (#00D4FF)
- **Background**: Nero profondo (#0F0F0F)
- **Surface**: Grigio scuro (#1E1E1E)
- **Text Primary**: Bianco (#FFFFFF)
- **Text Secondary**: Grigio chiaro (#B0B0B0)

### Font
- **Poppins Regular** (400)
- **Poppins Medium** (500)
- **Poppins Bold** (700)

## 🚀 Funzionalità Implementate

### ✅ Schermata HOME
- Design moderno con gradiente ciano
- Azioni rapide per chat e chiamate
- Widget stato sicurezza
- Chat recenti con indicatori E2EE
- Statistiche sicurezza

### ✅ Navigazione
- Bottom navigation bar
- GoRouter per navigazione
- 4 sezioni principali: Home, Chat, Calls, Settings

### ✅ Servizi Backend
- ApiService per tutte le API
- AuthService per autenticazione
- Integrazione completa con backend Django

## 📱 Struttura App

```
lib/
├── main.dart                 # Entry point
├── theme/
│   └── app_theme.dart       # Tema e colori
├── screens/
│   ├── home_screen.dart     # Schermata principale
│   ├── chat_screen.dart     # Lista chat
│   ├── calls_screen.dart    # Lista chiamate
│   └── settings_screen.dart # Impostazioni
├── widgets/
│   ├── quick_action_card.dart
│   ├── status_widget.dart
│   └── recent_chats_widget.dart
├── services/
│   ├── api_service.dart     # API backend
│   └── auth_service.dart    # Autenticazione
└── crypto/
    ├── libsignal_api.dart   # API crypto
    ├── key_store.dart       # Storage chiavi
    └── libsignal_stub.dart  # Stub per sviluppo
```

## 🔧 Setup Sviluppo

### Prerequisiti
- Flutter 3.22+
- Dart 3.5.0+
- Android Studio / VS Code
- Backend SecureVOX in esecuzione

### Installazione
```bash
# Installa dipendenze
flutter pub get

# Esegui app
flutter run
```

### Configurazione Backend
L'app si connette al backend su `http://localhost:8080` per sviluppo.

## 🎯 Prossimi Sviluppi

### Chat Singola e Gruppo
- Interfaccia chat 1:1
- Chat di gruppo
- Messaggi cifrati E2EE
- Notifiche push

### Chiamate Audio/Video
- Chiamate 1:1
- Chiamate di gruppo
- WebRTC con E2EE
- TURN server integration

### Sicurezza
- Integrazione libsignal
- Storage chiavi hardware-backed
- Root/jailbreak detection
- Remote wipe

## 🔒 Sicurezza

- **E2EE**: Tutti i messaggi e media sono cifrati
- **Zero-Knowledge**: Server non vede contenuti
- **Metadati Minimizzati**: Solo routing necessario
- **Hardware Security**: Chiavi in KeyStore/Keychain

## 📱 Screenshots

La schermata HOME include:
- Header con saluto personalizzato
- Widget stato sicurezza attiva
- 4 azioni rapide con gradiente
- Lista chat recenti con indicatori E2EE
- Statistiche sicurezza in tempo reale

## 🎨 Design Figma

Basato sul design di riferimento con:
- Layout moderno e pulito
- Colori scuri con accenti ciano
- Typography Poppins consistente
- Icone Material Design
- Animazioni fluide

## 📞 Supporto

Per domande o supporto, contatta il team di sviluppo SecureVOX.
