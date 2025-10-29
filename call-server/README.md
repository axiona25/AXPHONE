# 🚀 SecureVOX Call Server

**Proprietary WebRTC signaling server for secure audio/video calls**

SecureVOX Call è un server di signaling WebRTC completamente proprietario, progettato come alternativa self-hosted ad Agora, Twilio e altri servizi commerciali.

## 🎯 **Caratteristiche**

### ✅ **Core Features**
- **WebRTC Signaling**: Gestione completa offer/answer/ICE candidates
- **Real-time Communication**: Socket.IO per comunicazione istantanea
- **Multi-participant Calls**: Supporto chiamate di gruppo
- **Django Integration**: Integrazione nativa con backend SecureVOX
- **JWT Authentication**: Autenticazione sicura con token temporanei
- **Call Management**: Gestione stati chiamate e partecipanti

### 🔒 **Sicurezza**
- **Token-based Auth**: JWT con scadenza per ogni chiamata
- **Django Backend Integration**: Verifica token con backend esistente
- **HTTPS Ready**: Supporto TLS/SSL per produzione
- **CORS Protection**: Configurazione CORS per sicurezza
- **Input Validation**: Validazione completa input utente

### 📊 **Monitoring & Stats**
- **Health Checks**: Endpoint `/health` per monitoring
- **Call Statistics**: Statistiche chiamate attive in tempo reale
- **Logging**: Log dettagliati per debugging e audit
- **Graceful Shutdown**: Gestione corretta shutdown server

## 🏗️ **Architettura**

```
┌─────────────────────────────────────────────────────────────┐
│                 SecureVOX Call Architecture                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Flutter App                                                │
│      ↓                                                      │
│  SecureVOXCallService (WebRTC Client)                      │
│      ↓                                                      │
│  Socket.IO Connection                                       │
│      ↓                                                      │
│  ┌─────────────────────────────────────────────────────┐    │
│  │           SecureVOX Call Server                     │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │    │
│  │  │  Signaling  │  │    Auth     │  │    Call     │  │    │
│  │  │   Handler   │  │  Manager    │  │  Manager    │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  │    │
│  └─────────────────────────────────────────────────────┘    │
│      ↓                                                      │
│  Django Backend (Token Verification)                       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 **Quick Start**

### 1. **Installazione**
```bash
cd call-server
npm install
```

### 2. **Configurazione**
Crea file `.env`:
```env
SECUREVOX_CALL_PORT=8002
DJANGO_BACKEND_URL=http://localhost:8001
SECUREVOX_CALL_JWT_SECRET=your-secret-key-here
NODE_ENV=development
```

### 3. **Avvio**
```bash
# Sviluppo
npm run dev

# Produzione
npm start
```

### 4. **Docker**
```bash
# Build
docker build -t securevox-call-server .

# Run
docker run -p 8002:8002 securevox-call-server

# Docker Compose (con tutto l'stack)
docker-compose -f docker-compose.securevox-call.yml up
```

## 📡 **API Endpoints**

### **HTTP REST API**

#### `GET /health`
Health check del server
```json
{
  "status": "healthy",
  "service": "SecureVOX Call Server",
  "version": "1.0.0",
  "activeCalls": 5,
  "connectedUsers": 12
}
```

#### `POST /api/call/token`
Genera token JWT per chiamata
```json
{
  "userId": "user123",
  "sessionId": "call_123_456_789",
  "role": "participant"
}
```

#### `GET /api/call/stats`
Statistiche chiamate attive
```json
{
  "activeCalls": [...],
  "totalActiveCalls": 3,
  "connectedUsers": 8
}
```

### **WebSocket Events**

#### **Client → Server**
- `authenticate` - Autentica utente con JWT
- `join_call` - Unisciti a chiamata
- `leave_call` - Esci da chiamata
- `offer` - Invia WebRTC offer
- `answer` - Invia WebRTC answer
- `ice_candidate` - Invia ICE candidate
- `mute_audio` - Mute/unmute audio
- `mute_video` - Mute/unmute video

#### **Server → Client**
- `authenticated` - Conferma autenticazione
- `call_joined` - Confermato ingresso chiamata
- `participant_joined` - Nuovo partecipante
- `participant_left` - Partecipante uscito
- `offer` - WebRTC offer ricevuto
- `answer` - WebRTC answer ricevuto
- `ice_candidate` - ICE candidate ricevuto

## 🔧 **Integrazione Flutter**

### **1. Aggiungi Dipendenza**
```yaml
dependencies:
  flutter_webrtc: ^0.9.48
  socket_io_client: ^2.0.3+1
```

### **2. Usa SecureVOXCallService**
```dart
final callService = SecureVOXCallService();
await callService.initialize();
await callService.authenticate(userId);
await callService.startCall(targetUserId, sessionId);
```

## 🐳 **Deployment**

### **Docker Compose**
```bash
docker-compose -f docker-compose.securevox-call.yml up -d
```

### **Kubernetes**
```yaml
# TODO: Aggiungere manifesti K8s
```

### **Nginx Proxy**
```nginx
upstream securevox_call {
    server localhost:8002;
}

server {
    listen 443 ssl;
    server_name call.securevox.com;
    
    location / {
        proxy_pass http://securevox_call;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 📊 **Monitoring**

### **Health Checks**
```bash
curl http://localhost:8002/health
```

### **Logs**
```bash
# Docker
docker logs securevox-call-server

# PM2
pm2 logs securevox-call
```

### **Metrics**
- Chiamate attive
- Utenti connessi
- Durata media chiamate
- Errori di connessione

## 🔒 **Sicurezza**

### **Produzione Checklist**
- [ ] Configura HTTPS/TLS
- [ ] Imposta CORS correttamente
- [ ] Usa JWT secrets forti
- [ ] Configura firewall
- [ ] Abilita rate limiting
- [ ] Setup monitoring/alerting
- [ ] Backup configurazioni

### **TURN Server**
Per NAT traversal in produzione:
```bash
# Coturn (incluso in docker-compose)
docker run -d --name coturn \
  -p 3478:3478/udp \
  -p 49152-65535:49152-65535/udp \
  coturn/coturn
```

## 🚀 **Roadmap**

### **v1.1** (Next)
- [ ] Screen sharing support
- [ ] Call recording
- [ ] End-to-end encryption
- [ ] Mobile push notifications
- [ ] Advanced call controls

### **v1.2** (Future)
- [ ] SFU (Selective Forwarding Unit)
- [ ] Bandwidth adaptation
- [ ] Call quality metrics
- [ ] Admin dashboard
- [ ] Load balancing

## 🤝 **Contributing**

1. Fork repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 **License**

MIT License - see LICENSE file

## 🆘 **Support**

- **Issues**: GitHub Issues
- **Docs**: `/docs` folder
- **Email**: support@securevox.com

---

**Made with ❤️ by SecureVOX Team**
