# Changelog

## [1.3.1] - 2025-11-01

### 🔧 **MAJOR FIX: PDF Viewer e File Encryption**

#### ✅ **Bug Critici Risolti**
- **📄 PDF Viewer Loop**: Risolto loop infinito nella decifratura e visualizzazione PDF
- **🔐 PDF Encryption**: Corretto fallback per destinatari quando file locale non disponibile
- **⚠️ Null Safety**: Risolti errori null-safety in `pdf_preview_widget.dart`
- **🔄 File Loading**: Gestione corretta file cifrati per mittente e destinatario

#### 🔄 **Correzioni PDF**
- **Loop Infinito**: Aggiunto check `_convertedPdfUrl` per evitare re-decifratura continua
- **PDF Cifrati**: PDF nativi cifrati ora decifrati correttamente senza conversione backend
- **Office Files**: File Office cifrati convertiti in PDF solo se necessario
- **Fallback Destinatario**: Se file locale manca, scarica e decifra dal server automaticamente

#### 🐛 **Bug Fixes**
- **`pdf_preview_widget.dart`**: Risolti accessi null su `File?` con safe navigation operator
- **`file_viewer_screen.dart`**: Corretto ciclo di decifratura per PDF cifrati
- **Decifratura File**: Ottimizzata gestione file locali vs server per destinatari
- **Metadata Handling**: Corretta estrazione `sender_id` per decifratura destinatario

#### 🎯 **Risultato Finale**
- **✅ PDF Cifrati**: Decifrati e visualizzati correttamente
- **✅ Office Files**: Convertiti e mostrati in PDF
- **✅ No Loop**: Nessun loop infinito nella visualizzazione
- **✅ Destinatari**: Ricevono e aprono file correttamente

---

## [1.3.0] - 2025-10-01

### 🔧 **MAJOR FIX: Compatibilità iOS/macOS 26.0.1**

#### ✅ **Problemi Risolti**
- **🍎 iOS Compilazione**: Risolto completamente problema `path_provider_foundation` e moduli mancanti
- **🤖 Android Compilazione**: Verificata e funzionante al 100%
- **📱 Flutter 3.35.5**: Aggiornato alla versione più recente stabile
- **🔧 Widget Incompatibili**: Sostituiti tutti i widget problematici con alternative moderne

#### 🔄 **Sostituzioni Widget**
- **`flutter_inappwebview` → `webview_flutter`**: Più stabile e compatibile
- **`wakelock_plus` → `screen_brightness`**: API moderna per controllo luminosità
- **`chewie` → `video_player` diretto**: Controllo video semplificato e più affidabile

#### 🚀 **Funzionalità Ripristinate**
- **📞 WebRTC Chiamate**: Audio e video completamente funzionanti
- **📍 Geolocalizzazione**: GPS e mappe ripristinate
- **📷 Gestione Media**: Foto, video e audio recording
- **📄 Preview Documenti**: PDF e Office files (DOCX, XLSX, PPTX)
- **🔔 Notifiche**: Sistema notifiche e background processing
- **🎵 Suoni App**: Tutti i suoni per chiamate e notifiche

#### 🛠️ **Miglioramenti Tecnici**
- **📦 Dipendenze**: Aggiornate tutte alla versione più recente compatibile
- **🔧 Configurazioni**: Permessi iOS correttamente configurati
- **🧹 Pulizia**: Rimossi file di test obsoleti e codice non utilizzato
- **⚡ Performance**: Ottimizzazioni per compatibilità macOS 26.0.1

#### 🎯 **Risultato Finale**
- **✅ iOS**: Compilazione e funzionamento al 100%
- **✅ Android**: Compilazione e funzionamento al 100%
- **✅ Tutte le funzionalità**: Ripristinate e aggiornate
- **✅ Compatibilità**: macOS 26.0.1 + Flutter 3.35.5

---

## [1.2.0] - 2025-09-21

### 🚀 **SecureVOX Call - Sistema Chiamate Proprietario**

#### ✨ **Nuove Funzionalità Major**
- **🖥️ SecureVOX Call Server**: Server di signaling WebRTC proprietario (Node.js + Socket.IO)
- **📱 WebRTC Reale**: Chiamate audio/video reali tra dispositivi fisici con `flutter_webrtc`
- **🔒 Zero Dipendenze**: Alternativa proprietaria ad Agora, Twilio e servizi commerciali
- **🎧 Audio Bidirezionale**: Comunicazione audio reale tramite microfono e speaker
- **📹 Video Streaming**: Stream video reali dalla camera del dispositivo
- **🔊 Sistema Suoni Completo**: Suoni per chiamate, messaggi, notifiche e toast
- **⚡ Real-time Signaling**: WebSocket per offer/answer/ICE candidates
- **🛡️ JWT Authentication**: Token sicuri per autenticazione chiamate

#### 🔧 **Miglioramenti Infrastruttura**
- **🐳 Docker Stack**: Container per Django + SecureVOX Call + TURN server
- **📊 Monitoring**: Health checks e statistiche chiamate real-time
- **🔗 Backend Integration**: Webhook e API per sincronizzazione Django
- **🎛️ Call Management**: Gestione completa stati chiamate e partecipanti
- **📈 Scalabilità**: Architettura pronta per load balancing

#### 🎨 **UI/UX Enhancements**
- **📱 WebRTCCallScreen**: Schermata chiamata dedicata per WebRTC
- **🎥 Video Renderer**: Visualizzazione stream video locale e remoto
- **🎛️ Controlli Avanzati**: Mute, speaker, switch camera, end call
- **⏱️ Timer Sincronizzato**: Durata chiamata real-time tra dispositivi
- **🔊 Feedback Audio**: Suoni per tutte le azioni (successo, errore, avviso, info)

#### 🔒 **Sicurezza e Privacy**
- **🏠 Self-Hosted**: Audio/video non passano mai da server terzi
- **🔐 Token-based Auth**: JWT con scadenza per ogni chiamata
- **🛡️ Input Validation**: Validazione completa su tutti gli endpoint
- **📡 Secure WebSocket**: Autenticazione obbligatoria per signaling
- **🔒 CORS Protection**: Configurazione sicurezza per produzione

#### 🐛 **Bug Fixes Chiamate**
- **✅ UI Consistency**: Footer nascosto correttamente in tutte le schermate chiamata
- **✅ Timer Sync**: Timer sincronizzato con timestamp backend tra caller/receiver
- **✅ Navigation Fix**: Navigazione corretta alla chat detail reale dopo chiamate
- **✅ Call History**: Aggiornamento real-time dello storico chiamate
- **✅ Dispose Issues**: Risolti errori "used after disposed" con singleton management
- **✅ Notification Flow**: Correzione navigazione da notifiche chiamata

#### 🎵 **Sistema Audio Completo**
- **🔊 CallSoundService**: Gestione suoni chiamate (ringing, connected, ended)
- **📱 AppSoundService**: Suoni per messaggi, notifiche, toast
- **🎶 Pattern Vibrazione**: Feedback tattile per ogni tipo di evento
- **🔇 Fallback Robusti**: Vibrazione quando file audio non disponibili

## [1.0.0] - 2024-12-19

### 🎉 **Versione Stabile - Chat, Contatti, Stati, Allegati Funzionanti**

#### ✅ **Nuove Funzionalità**
- Sistema chat completo con messaggi real-time
- Sistema contatti con ricerca e esclusione utente corrente
- Stati utente real-time con indicatori colorati
- Sistema allegati multimediali (immagini, video, documenti)
- Sistema chiamate audio e video con WebRTC
- Autenticazione sicura con gestione token

#### 🔧 **Miglioramenti**
- Interfaccia utente pulita e moderna
- Navigazione fluida tra schermate
- Indicatori di stato visivi (pallini colorati)
- Esclusione automatica dell'utente corrente dai contatti
- Gestione errori migliorata
- Performance ottimizzate

#### 🧹 **Pulizia Codice**
- Rimossi servizi avatar legacy deprecati
- Eliminati file di test e debug temporanei
- Consolidato sistema avatar con MasterAvatarService
- Pulizia imports e dipendenze non utilizzate
- Codice stabilizzato e ottimizzato

#### 🐛 **Bug Fixes**
- Risolto problema contatti che mostrava l'utente corrente
- Corretto filtro backend per esclusione utente
- Sincronizzazione ID utente tra frontend e backend
- Gestione corretta stati utente real-time

#### 🔐 **Sicurezza**
- Endpoint autenticazione protetti
- Validazione input migliorata
- Gestione token sicura
- Esclusione dati sensibili dalle API

#### 📱 **Frontend (Flutter)**
- Schermata Home con chat recenti
- Schermata Contatti con ricerca
- Schermata Chat con messaggi real-time
- Schermata Chiamate con storico
- Navigazione bottom tab
- Tema moderno con colori SecureVOX

#### 🖥️ **Backend (Django)**
- API REST complete e documentate
- Sistema autenticazione robusto
- Gestione database ottimizzata
- WebRTC integrato per chiamate
- Sistema notifiche real-time

### 📋 **Componenti Funzionanti**
- ✅ Chat system completo
- ✅ Sistema contatti (no auto-contatto)
- ✅ Stati utente real-time
- ✅ Sistema chiamate audio/video
- ✅ Allegati multimediali
- ✅ Autenticazione sicura
- ✅ Interfaccia utente moderna

### 🚫 **Note**
- Modulo sicurezza temporaneamente disabilitato per sviluppo
- Tutte le funzionalità core sono operative e testate
- Sistema pronto per produzione con funzionalità base

---

## [0.9.x] - Versioni Precedenti

### Sviluppo e Testing
- Implementazione iniziale architettura
- Sviluppo servizi base
- Testing e debug
- Ottimizzazioni performance
