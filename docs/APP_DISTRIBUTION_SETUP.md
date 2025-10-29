# 📱 SecureVOX App Distribution - Guida Setup

Sistema di distribuzione app iOS e Android simile a TestFlight, integrato nel backend SecureVOX.

## 🚀 Caratteristiche

- ✅ **Distribuzione iOS e Android**: Supporto per file .ipa e .apk/.aab
- ✅ **Installazione iOS Over-the-Air**: Link `itms-services://` per installazione diretta
- ✅ **Interfaccia Web Responsive**: Accessibile da smartphone e desktop
- ✅ **Sistema di Autenticazione**: Controllo accessi per utenti autorizzati
- ✅ **Feedback e Rating**: Sistema di valutazione delle build
- ✅ **Notifiche Automatiche**: Email per nuove build disponibili
- ✅ **Admin Panel**: Gestione completa delle build
- ✅ **API REST**: Integrazione con sistemi esterni
- ✅ **Analytics**: Tracciamento download e statistiche

## 🏗️ Setup Iniziale

### 1. Installazione

Il sistema è già integrato nel progetto SecureVOX. Per attivarlo:

```bash
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server

# Crea e applica le migrazioni
python manage.py makemigrations app_distribution
python manage.py migrate

# Setup iniziale (crea directory e dati demo)
python manage.py setup_app_distribution --create-demo-data

# Avvia il server
python manage.py runserver 0.0.0.0:8001
```

### 2. Accesso alle Funzionalità

- **Interfaccia Web**: http://localhost:8001/app-distribution/
- **Admin Panel**: http://localhost:8001/admin/
- **API REST**: http://localhost:8001/app-distribution/api/

## 📱 Come Usare il Sistema

### Per Amministratori

1. **Carica una nuova build**:
   - Vai su http://localhost:8001/admin/
   - Sezione "App Distribution" > "App builds"
   - Clicca "Aggiungi app build"
   - Compila i campi e carica il file .ipa/.apk
   - Attiva la build per renderla disponibile

2. **Gestione Utenti**:
   - Lascia vuoto "Allowed users" per permettere a tutti di scaricare
   - Aggiungi utenti specifici per limitare l'accesso

3. **Monitoraggio**:
   - Visualizza download e feedback nell'admin
   - Statistiche disponibili per ogni build

### Per Utenti Finali

1. **Accesso**:
   - Vai su http://localhost:8001/app-distribution/
   - Effettua il login se richiesto

2. **Installazione iOS**:
   - Tocca "Installa su iOS" (solo su dispositivi iOS)
   - Conferma l'installazione quando richiesto
   - Vai in Impostazioni > Generali > Gestione dispositivi
   - Autorizza il certificato dello sviluppatore

3. **Installazione Android**:
   - Tocca "Scarica APK"
   - Installa il file scaricato
   - Autorizza installazioni da fonti sconosciute se necessario

## 🔧 Configurazione Avanzata

### Notifiche Email

Configura le impostazioni email in `settings.py`:

```python
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'your-email@gmail.com'
EMAIL_HOST_PASSWORD = 'your-app-password'
DEFAULT_FROM_EMAIL = 'SecureVOX Distribution <noreply@securevox.com>'
```

### Certificati iOS

Per la distribuzione iOS, assicurati di:

1. Avere un certificato di sviluppatore Apple
2. Firmare le app con il certificato corretto
3. Configurare HTTPS per il server (richiesto da iOS)

### Sicurezza in Produzione

```python
# In settings.py per produzione
DEBUG = False
ALLOWED_HOSTS = ['your-domain.com']
SECURE_SSL_REDIRECT = True
```

## 📡 API REST

### Endpoints Principali

```bash
# Lista build
GET /app-distribution/api/builds/

# Dettagli build
GET /app-distribution/api/builds/{id}/

# Download build
POST /app-distribution/api/builds/{id}/download/

# Manifest iOS
GET /app-distribution/api/builds/{id}/manifest/

# Carica nuova build
POST /app-distribution/api/builds/

# Feedback
GET/POST /app-distribution/api/feedback/
```

### Esempio Upload via API

```bash
curl -X POST http://localhost:8001/app-distribution/api/builds/ \
  -H "Authorization: Token your-token" \
  -F "name=MyApp" \
  -F "platform=ios" \
  -F "version=1.0.0" \
  -F "build_number=1" \
  -F "bundle_id=com.mycompany.myapp" \
  -F "app_file=@MyApp.ipa" \
  -F "description=Test build"
```

## 📊 Monitoraggio e Analytics

### Log Files

I download e le attività sono tracciati nei log:

```bash
tail -f /var/log/securevox/django.log
```

### Statistiche Admin

Ogni build mostra:
- Numero di download totali
- Utenti unici
- Download per giorno
- Feedback medio

## 🔍 Troubleshooting

### Problemi Comuni

1. **File troppo grandi**:
   - Aumenta `FILE_UPLOAD_MAX_MEMORY_SIZE` in settings.py
   - Verifica spazio disco disponibile

2. **iOS non installa**:
   - Verifica HTTPS (richiesto da iOS 9+)
   - Controlla certificato di firma
   - Verifica che il dispositivo sia autorizzato

3. **Android non installa**:
   - Abilita "Fonti sconosciute" nelle impostazioni
   - Verifica firma APK
   - Controlla permessi file

### Debug Mode

Per debug dettagliato:

```python
# In settings.py
LOGGING['loggers']['app_distribution'] = {
    'handlers': ['console', 'file'],
    'level': 'DEBUG',
    'propagate': False,
}
```

## 🔄 Backup e Manutenzione

### Backup Build Files

```bash
# Backup directory media
tar -czf app_builds_backup.tar.gz media/app_builds/
```

### Pulizia File Vecchi

```bash
# Comando personalizzato per pulizia (da implementare)
python manage.py cleanup_old_builds --days=30
```

## 🚀 Deployment

### Docker

Il sistema è già configurato per Docker. Per deployment:

```bash
# Build immagine
docker build -t securevox-server .

# Run con volume per file
docker run -v /path/to/media:/app/media securevox-server
```

### Nginx Configuration

```nginx
location /app-distribution/ {
    proxy_pass http://127.0.0.1:8001;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    client_max_body_size 500M;  # Per file grandi
}

location /media/ {
    alias /path/to/media/;
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## 📞 Supporto

Per problemi o domande:

1. Controlla i log in `/var/log/securevox/`
2. Verifica la configurazione in `settings.py`
3. Testa con i dati demo prima di caricare build reali

## 🔮 Funzionalità Future

- [ ] Integrazione CI/CD per upload automatico
- [ ] Notifiche push mobile
- [ ] Distribuzione automatica per branch Git
- [ ] Integrazione con TestFlight/Play Console
- [ ] Dashboard analytics avanzata
- [ ] Rollback automatico build problematiche
