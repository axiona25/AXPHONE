# 🚀 Guida Avvio Backend SecureVOX

Questa guida mostra tutti i comandi per avviare i vari backend del progetto SecureVOX.

## 📋 Prerequisiti

Assicurati di avere installato:
- Python 3.11+ con venv attivato nella cartella `server`
- Node.js 18+ installato
- Redis (opzionale, per real-time)

## 🎯 Scenari di Avvio

### 1️⃣ Setup Completo con Dashboard Real-time

**Usa questo per avere tutto: Django + Dashboard Admin con WebSocket**

```bash
# Script automatico che avvia tutto
./start_securevox_realtime.sh
```

**Oppure manualmente:**

```bash
# Terminale 1: Django con WebSocket (porta 8001)
cd server
source venv/bin/activate
python manage.py migrate
daphne -b 0.0.0.0 -p 8001 src.asgi:application

# Terminale 2: Notify Server (porta 8002)
cd server
source venv/bin/activate
python securevox_notify.py

# Terminale 3: Call Server (porta 8003)
cd call-server
export SECUREVOX_CALL_PORT=8003
export DJANGO_BACKEND_URL=http://localhost:8001
npm start
```

**URL disponibili:**
- 🌐 Dashboard: http://localhost:8001/admin
- 📡 WebSocket: ws://localhost:8001/ws/admin
- 🔔 Notify: http://localhost:8002
- 📞 Call Server: http://localhost:8002

---

### 2️⃣ Setup Semplice Django + Call Server

**Per testare solo le chiamate video/audio**

```bash
# Script automatico
./start_securevox_call_stack.sh
```

**Oppure manualmente:**

```bash
# Terminale 1: Django Backend (porta 8001)
cd server
source venv/bin/activate
python manage.py runserver 0.0.0.0:8001

# Terminale 2: SecureVOX Call Server (porta 8002)
cd call-server
export SECUREVOX_CALL_PORT=8002
export DJANGO_BACKEND_URL=http://localhost:8001
npm start
```

---

### 3️⃣ Solo Django (per sviluppo base)

```bash
# Usa lo script
./start_server_8001.sh

# Oppure manualmente
cd server
source venv/bin/activate
python manage.py runserver 8001
```

**Oppure con WebSocket:**

```bash
./start_server_8001_realtime.sh
```

---

### 4️⃣ Setup Completo Manuale (3 terminali)

**Terminale 1 - Django:**
```bash
cd server
source venv/bin/activate
python manage.py makemigrations
python manage.py migrate
python manage.py runserver 0.0.0.0:8001
```

**Terminale 2 - Notify Server:**
```bash
cd server
source venv/bin/activate
python securevox_notify.py
```

**Terminale 3 - Call Server:**
```bash
cd call-server
npm install  # Solo la prima volta
export SECUREVOX_CALL_PORT=8003
export DJANGO_BACKEND_URL=http://localhost:8001
npm start
```

---

## 🔧 Utilizzo Makefile

Il progetto include un Makefile con comandi utili:

```bash
# Vedi tutti i comandi disponibili
make help

# Avvia app Flutter con cleanup automatico
make dev-run

# Avvia solo server Django
make dev-server

# Cleanup token scaduti
make dev-clean
```

---

## ✅ Verifica Stato Servizi

```bash
# Script automatico di controllo
./check_services.sh

# Oppure manualmente
curl http://localhost:8001/health        # Django
curl http://localhost:8002/health        # Notify/Call
```

---

## 🛑 Fermare i Servizi

```bash
# Ferma tutto lo stack
./stop_securevox_call_stack.sh

# Oppure manualmente (kill porta)
lsof -ti:8001 | xargs kill -9  # Django
lsof -ti:8002 | xargs kill -9  # Notify/Call
```

---

## 📝 Note Importanti

### Porte Utilizzate

- **8001**: Django Backend principale
- **8002**: Notify Server OPPURE Call Server (vengono in conflitto!)
- **8003**: Alternativa per Call Server

### Conflitto Porte 8002

⚠️ **ATTENZIONE**: Il Notify Server e il Call Server entrambi vogliono usare la porta 8002.

**Soluzioni:**
1. Avvia solo uno dei due a seconda delle tue necessità
2. Modifica la porta di uno dei due servizi
3. Usa lo script `start_securevox_call_stack.sh` che gestisce il conflitto

### Ambiente Virtuale

Ricordati sempre di attivare l'ambiente virtuale Python:

```bash
cd server
source venv/bin/activate
```

---

## 🐛 Troubleshooting

### Errore "Redis non in esecuzione"
```bash
redis-server --daemonize yes
```

### Errore "Port already in use"
```bash
# Vedere quali processi usano le porte
lsof -i :8001
lsof -i :8002
lsof -i :8003

# Killare il processo
kill -9 <PID>
```

### Errore "Module not found"
```bash
cd server
source venv/bin/activate
pip install -r requirements.txt

# Per Call Server
cd call-server
npm install
```

---

## 🎯 Raccomandazioni

Per lo sviluppo quotidiano, usa:

```bash
# In un terminale
./start_server_8001_realtime.sh

# In un altro terminale
cd mobile/securevox_app
flutter run
```

Per testare le chiamate:

```bash
# In un terminale
./start_securevox_call_stack.sh

# In due terminali separati
cd mobile/securevox_app
flutter run
```

---

## 📚 Riferimenti

- `README.md` - Overview generale del progetto
- `docs/ARCHITECTURE.md` - Architettura dettagliata
- `SECUREVOX_CALL_SETUP.md` - Setup dettagliato del Call Server
