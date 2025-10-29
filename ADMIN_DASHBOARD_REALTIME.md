# 🛡️ SecureVOX Admin Dashboard - Real-time Edition

Dashboard amministrativa moderna con connessione **real-time** per una vista a 360° sempre aggiornata del sistema SecureVOX.

## 🚀 Caratteristiche Real-time

### ⚡ **Connessione WebSocket**
- **WebSocket bidirezionale** per aggiornamenti istantanei
- **Fallback polling** automatico se WebSocket non disponibile
- **Riconnessione automatica** con retry intelligente
- **Gestione errori** robusta con notifiche utente

### 📊 **Aggiornamenti Live**
- **Dashboard Stats**: Aggiornate ogni 10 secondi
- **System Health**: Aggiornate ogni 5 secondi  
- **Server Status**: Aggiornate ogni 15 secondi
- **Notifiche**: Istantanee per eventi critici
- **Attività Utenti**: Real-time per login/logout/azioni

### 🔔 **Sistema Notifiche**
- **Centro notifiche** integrato nell'header
- **Badge contatore** notifiche non lette
- **Categorizzazione** per tipo (successo, errore, warning, info)
- **Gestione lettura** con marcatura automatica
- **Storico notifiche** con timestamp

## 🎨 Design System SecureVOX

### 🎨 **Colori Ufficiali**
```css
--primary-color: #26A884;      /* Verde chiaro SecureVOX */
--secondary-color: #0D7557;    /* Verde scuro SecureVOX */
--background-color: #F5F5F5;   /* Grigio chiaro */
--card-color: #E0E0E0;         /* Grigio card */
--success-color: #26A884;      /* Successo */
--warning-color: #FF9800;      /* Avviso */
--error-color: #F44336;        /* Errore */
```

### 📝 **Typography**
- **Font**: Poppins (stesso dell'app mobile)
- **Weights**: 300, 400, 500, 600, 700, 800
- **Responsive**: Ottimizzato per tutti i dispositivi

## 🏗️ Architettura Real-time

### 🔌 **Frontend (React)**
```
src/
├── services/
│   ├── websocket.ts          # Gestione WebSocket
│   └── api.ts               # API REST fallback
├── hooks/
│   └── useRealtimeData.ts   # Hook per dati real-time
├── components/
│   ├── notifications/       # Centro notifiche
│   └── dashboard/          # Componenti dashboard
└── contexts/
    └── AuthContext.tsx     # Autenticazione
```

### ⚙️ **Backend (Django + Channels)**
```
src/
├── asgi.py                 # Configurazione ASGI
├── admin_panel/
│   ├── consumers.py        # WebSocket Consumer
│   ├── routing.py          # WebSocket Routing
│   └── dashboard_views.py  # API REST
└── settings.py            # Configurazione Channels
```

## 🚀 Setup e Installazione

### 1. **Prerequisiti**
```bash
# Redis (per WebSocket)
brew install redis
redis-server

# Node.js 18+
node --version

# Python 3.13+
python --version
```

### 2. **Installazione Frontend**
```bash
cd admin
npm install
npm run build:securevox
```

### 3. **Installazione Backend**
```bash
cd server
source venv/bin/activate
pip install django-channels channels-redis daphne
python manage.py migrate
```

### 4. **Avvio Real-time**
```bash
# Avvia Redis
redis-server --daemonize yes

# Avvia server con WebSocket
./start_server_8001_realtime.sh

# Oppure manualmente:
daphne -b 0.0.0.0 -p 8001 src.asgi:application
```

## 📡 Configurazione WebSocket

### 🔗 **URL WebSocket**
```
ws://localhost:8001/ws/admin/
```

### 📨 **Eventi Supportati**

#### **Client → Server**
```javascript
// Richiesta dati
{ "type": "request_dashboard_stats" }
{ "type": "request_system_health" }
{ "type": "request_server_status" }

// Sottoscrizioni
{ "type": "subscribe_user", "user_id": 123 }
{ "type": "subscribe_server", "server_id": "django-server" }

// Azioni
{ "type": "server_action", "server_id": "django-server", "action": "restart" }
{ "type": "user_action", "user_id": 123, "action": "block" }
```

#### **Server → Client**
```javascript
// Aggiornamenti automatici
{ "type": "dashboard_stats_update", "data": {...} }
{ "type": "system_health_update", "data": {...} }
{ "type": "server_status_update", "servers": [...] }

// Notifiche
{ "type": "user_activity", "user": {...}, "activity": "login" }
{ "type": "security_alert", "message": "...", "severity": "high" }
{ "type": "new_message", "count": 5 }
{ "type": "new_call", "count": 2, "duration": 180 }
```

## 🎯 Funzionalità Dashboard

### 📊 **Dashboard Principale**
- ✅ **Card statistiche** con aggiornamento real-time
- ✅ **Grafici interattivi** (line, bar, pie charts)
- ✅ **System health** con metriche live
- ✅ **Sicurezza** con monitoraggio continuo
- ✅ **Indicatori connessione** WebSocket

### 👥 **Gestione Utenti** (Prossima implementazione)
- 📋 Lista utenti con filtri real-time
- ➕ Creazione/modifica/eliminazione utenti
- 🔍 Ricerca istantanea
- 📊 Statistiche per utente

### 🏷️ **Gestione Gruppi** (Prossima implementazione)
- 📋 Lista gruppi con contatori live
- 👥 Assegnazione utenti a gruppi
- 🎨 Gestione colori e permessi
- 📊 Statistiche per gruppo

### 🖥️ **Gestione Server** (Prossima implementazione)
- 📋 Lista server con stato real-time
- 🔧 Controlli server (start/stop/restart)
- 💻 Terminale integrato per ogni server
- 📊 Metriche performance live

### ⚙️ **Impostazioni** (Prossima implementazione)
- 🌐 Gestione lingue (IT/EN)
- 🎨 Personalizzazione colori (whitelabel)
- 🖼️ Caricamento logo aziendale
- 📄 Dati societari

## 🔧 Configurazione Avanzata

### 🌐 **Variabili Ambiente**
```bash
# Frontend (.env)
REACT_APP_API_URL=http://localhost:8001/admin/api
REACT_APP_WS_URL=ws://localhost:8001

# Backend (settings.py)
CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            "hosts": [('127.0.0.1', 6379)],
        },
    },
}
```

### 📊 **Intervalli Aggiornamento**
```javascript
// Configurabili nei hook
const dashboardData = useRealtimeDashboard({
    pollingInterval: 10000,    // 10 secondi
    enableWebSocket: true,     // Abilita WebSocket
    enablePolling: true,       // Fallback polling
    autoFetch: true,           // Fetch automatico
});
```

### 🔒 **Sicurezza**
- ✅ **Autenticazione** obbligatoria per WebSocket
- ✅ **Autorizzazione** solo per admin/superuser
- ✅ **Rate limiting** per protezione DDoS
- ✅ **CORS** configurato per sicurezza
- ✅ **CSRF** protection per API

## 🐛 Troubleshooting

### ❌ **WebSocket non si connette**
```bash
# Verifica Redis
redis-cli ping

# Verifica porta 8001
lsof -i :8001

# Controlla log server
tail -f /var/log/securevox/django.log
```

### ⚠️ **Dati non si aggiornano**
```bash
# Verifica connessione WebSocket nel browser
# Console → Network → WS → localhost:8001

# Test manuale WebSocket
wscat -c ws://localhost:8001/ws/admin/
```

### 🔄 **Fallback Polling**
Se WebSocket fallisce, il sistema passa automaticamente a polling HTTP:
- Dashboard: ogni 10 secondi
- System Health: ogni 5 secondi  
- Server Status: ogni 15 secondi

## 📈 Performance

### ⚡ **Ottimizzazioni**
- **Lazy loading** componenti
- **Memoization** dati pesanti
- **Debounced** aggiornamenti
- **Connection pooling** Redis
- **Compression** WebSocket

### 📊 **Metriche Target**
- **WebSocket latency**: < 100ms
- **Polling fallback**: < 500ms
- **Dashboard load**: < 2s
- **Memory usage**: < 50MB
- **CPU usage**: < 5%

## 🎉 Risultato

**Dashboard admin enterprise-grade** con:

✅ **Real-time completo** - Vista a 360° sempre aggiornata  
✅ **WebSocket + Polling** - Connessione robusta e affidabile  
✅ **Notifiche live** - Sistema notifiche integrato  
✅ **Design SecureVOX** - Coerenza visiva con l'app mobile  
✅ **Performance ottimizzate** - Aggiornamenti fluidi e veloci  
✅ **Sicurezza enterprise** - Autenticazione e autorizzazione complete  

**La dashboard è pronta per gestire migliaia di utenti con aggiornamenti real-time!** 🚀

## 🔮 Roadmap

### 🚀 **Prossime Funzionalità**
- [ ] Gestione utenti completa con real-time
- [ ] Gestione gruppi con assegnazione live
- [ ] Terminale integrato per server
- [ ] Impostazioni whitelabel
- [ ] Export dati real-time
- [ ] Dashboard personalizzabili
- [ ] Alert configurabili
- [ ] Multi-tenant support

### 🎯 **Miglioramenti**
- [ ] WebRTC per video chiamate admin
- [ ] Machine Learning per predizioni
- [ ] Integrazione Slack/Teams
- [ ] Mobile app admin
- [ ] Offline mode
- [ ] PWA support
