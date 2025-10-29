# SecureVOX Notify

Servizio di notifiche push personalizzato per SecureVOX che sostituisce completamente Firebase.

## 🚀 Caratteristiche

- **Multi-piattaforma**: Supporta iOS, Android e Web
- **Real-time**: WebSocket per notifiche istantanee
- **Chiamate**: Gestisce chiamate audio e videochiamate
- **Gruppi**: Supporta chiamate di gruppo
- **Fallback**: Polling automatico se WebSocket non disponibile

## 📱 Piattaforme Supportate

- ✅ iOS (Simulatori e dispositivi fisici)
- ✅ Android (Simulatori e dispositivi fisici)  
- ✅ Web (Browser moderni)

## 🔧 Installazione

```bash
# Installa le dipendenze
pip3 install -r notification_requirements.txt

# Avvia il server
python3 securevox_notify.py

# Oppure usa lo script di avvio
chmod +x start_notification_server.sh
./start_notification_server.sh
```

## 🌐 Endpoints

### Notifiche
- `POST /register` - Registra dispositivo
- `POST /send` - Invia notifica
- `GET /poll/{device_token}` - Polling notifiche
- `WS /ws/{device_token}` - WebSocket real-time

### Chiamate
- `POST /call/start` - Inizia chiamata
- `POST /call/answer/{call_id}` - Rispondi chiamata
- `POST /call/reject/{call_id}` - Rifiuta chiamata
- `POST /call/end/{call_id}` - Termina chiamata

### Statistiche
- `GET /stats` - Statistiche servizio
- `GET /calls/active` - Chiamate attive
- `GET /health` - Health check

## 🔥 Vantaggi rispetto a Firebase

1. **Controllo completo**: Nessuna dipendenza esterna
2. **Privacy**: Tutti i dati rimangono sul tuo server
3. **Costi**: Nessun costo per notifiche
4. **Personalizzazione**: Logica di notifiche completamente personalizzabile
5. **Simulatori**: Funziona perfettamente sui simulatori iOS/Android

## 📡 WebSocket

Il server supporta connessioni WebSocket per notifiche real-time:

```javascript
const ws = new WebSocket('ws://localhost:8002/ws/your_device_token');
ws.onmessage = (event) => {
  const notification = JSON.parse(event.data);
  console.log('Notifica ricevuta:', notification);
};
```

## 🔧 Configurazione

Il server è configurato per:
- **Porta**: 8002
- **Host**: 0.0.0.0 (tutte le interfacce)
- **CORS**: Abilitato per tutte le origini
- **Reload**: Abilitato per sviluppo

## 📊 Monitoraggio

Visita `http://localhost:8002` per vedere le statistiche del servizio e la documentazione API completa.
