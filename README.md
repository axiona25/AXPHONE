# Comandi avvio Server e Client

#SERVER CALL
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/call-server
SECUREVOX_CALL_PORT=8003 JWT_SECRET=test-secret NODE_ENV=development HOST=0.0.0.0 MAIN_SERVER_URL=http://localhost:8001 NOTIFY_SERVER_URL=http://localhost:8002 node src/securevox-call-server.js

#SERVER DJANGO
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server
source venv/bin/activate
python manage.py runserver 0.0.0.0:8001


#SERVER NOTIFY
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server
source venv/bin/activate
python securevox_notify.py


#TEST SERVERS
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack
./check_services.sh

# FLUTTER

cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/mobile/securevox_app
flutter pub get
flutter run

# AXPHONE - Sistema di Comunicazione Sicura

**v1.2.0** - Sistema completo di comunicazione sicura end-to-end con **chiamate audio/video reali** tramite SecureVOX Call Server proprietario.

## 🎉 **NOVITÀ v1.2.0: SecureVOX Call**

### 🚀 **Chiamate Audio/Video REALI**
- **📞 Audio bidirezionale** reale tra dispositivi fisici
- **📹 Video streaming** reale con camera
- **🖥️ Server proprietario** - Zero dipendenze da Agora/Twilio
- **🔒 Privacy totale** - Audio/video sui tuoi server
- **💰 Costi zero** - Nessun vendor fee

## 🚀 Funzionalità Implementate

### ✅ **Chat System**
- Chat real-time con messaggi testuali
- Supporto allegati (immagini, video, documenti)
- Indicatori di lettura e consegna
- Eliminazione messaggi per utente
- Chat di gruppo

### ✅ **Sistema Contatti**
- Lista contatti con ricerca
- Esclusione automatica dell'utente corrente
- Stati utente (online/offline) con indicatori colorati
- Avatar personalizzati

### ✅ **Sistema Stati**
- Stati utente real-time
- Indicatori visivi con pallini colorati
- Sincronizzazione automatica

### ✅ **Sistema Chiamate**
- Chiamate audio
- Videochiamate
- Chiamate di gruppo
- WebRTC integrato

### ✅ **Autenticazione**
- Login/Logout sicuro
- Gestione token
- Profili utente

## 🏗️ Architettura

### **Backend (Django)**
```
server/
├── src/
│   ├── api/           # API endpoints
│   ├── admin_panel/   # Pannello amministrativo
│   ├── crypto/        # Crittografia
│   ├── devices/       # Gestione dispositivi
│   └── notifications/ # Sistema notifiche
```

### **Frontend (Flutter)**
```
mobile/securevox_app/
├── lib/
│   ├── screens/       # Schermate app
│   ├── services/      # Servizi backend
│   ├── models/        # Modelli dati
│   ├── widgets/       # Widget riutilizzabili
│   └── theme/         # Tema e styling
```

## 🛠️ Setup Sviluppo

### Prerequisiti
- Python 3.11+
- Flutter 3.22+
- Django 4.2+
- Node.js (per WebRTC)

### Backend Setup
```bash
cd server
python -m venv venv
source venv/bin/activate  # Linux/Mac
# o
venv\Scripts\activate     # Windows

pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

### Frontend Setup
```bash
cd mobile/securevox_app
flutter pub get
flutter run
```

## 📱 Schermate Principali

### **Home Screen**
- Chat recenti
- Azioni rapide
- Statistiche sicurezza

### **Contatti Screen**
- Lista contatti alfabetica
- Ricerca contatti
- Stati utente real-time

### **Chat Screen**
- Messaggi real-time
- Allegati multimediali
- Indicatori di stato

### **Calls Screen**
- Storico chiamate
- Inizia chiamata
- Gestione chiamate

## 🔐 Sicurezza

- Crittografia end-to-end
- Token sicuri
- Validazione input
- Protezione CSRF
- Headers di sicurezza

## 📊 Stato Progetto

**Versione**: 1.0.0  
**Stato**: Funzionante e stabile  
**Ultimo aggiornamento**: Dicembre 2024

### Componenti Funzionanti
- ✅ Chat system completo
- ✅ Sistema contatti
- ✅ Stati utente real-time
- ✅ Sistema chiamate
- ✅ Autenticazione
- ✅ Allegati multimediali

### Note
- Il modulo sicurezza è stato temporaneamente disabilitato per agevolare lo sviluppo
- Tutte le funzionalità core sono operative e testate

## 🤝 Contributi

Il progetto è in fase di sviluppo attivo. Per contribuire:

1. Fork del repository
2. Crea un branch per la feature
3. Commit delle modifiche
4. Push e crea una Pull Request

## 📄 Licenza

Proprietario: SecureVOX Team  
Riservato - Non distribuire senza autorizzazione
