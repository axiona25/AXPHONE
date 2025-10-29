# 📱 SecureVOX App Distribution

Sistema di distribuzione app iOS e Android integrato in SecureVOX, simile a TestFlight ma con controllo completo.

## 🚀 Quick Start

### Setup Automatico

```bash
# Esegui lo script di setup
./setup_app_distribution.sh
```

### Setup Manuale

```bash
cd server

# Crea e applica migrazioni
python3 manage.py makemigrations app_distribution
python3 manage.py migrate

# Setup iniziale
python3 manage.py setup_app_distribution --create-demo-data

# Avvia server
python3 manage.py runserver 0.0.0.0:8001
```

## 🌐 Accesso al Sistema

- **Interfaccia Web**: http://localhost:8001/app-distribution/
- **Admin Panel**: http://localhost:8001/admin/
- **API REST**: http://localhost:8001/app-distribution/api/

## 📱 Funzionalità Principali

### ✅ Distribuzione Multi-Platform
- **iOS**: File .ipa con installazione Over-the-Air
- **Android**: File .apk/.aab con download diretto

### ✅ Installazione Semplificata
- **iOS**: Link `itms-services://` per installazione diretta su Safari
- **Android**: Download APK e installazione guidata
- **QR Code**: Per accesso rapido da mobile

### ✅ Gestione Completa
- Upload file tramite admin panel o API
- Controllo versioni e build number
- Gestione utenti autorizzati
- Attivazione/disattivazione build

### ✅ Interfaccia Moderna
- Design responsive per mobile e desktop
- Filtri per piattaforma (iOS/Android)
- Informazioni dettagliate per ogni build
- Sistema di feedback e rating

### ✅ Notifiche Automatiche
- Email per nuove build disponibili
- Notifiche push (configurabile)
- Log dettagliati per analytics

## 📖 Come Usare

### Per Amministratori

1. **Carica una Build**:
   ```
   Admin Panel → App Distribution → App builds → Aggiungi
   ```

2. **Configura Accesso**:
   - Lascia vuoto "Allowed users" = tutti possono scaricare
   - Aggiungi utenti specifici = solo loro possono scaricare

3. **Attiva Build**:
   - Spunta "Is active" per rendere disponibile
   - "Is beta" per marcare come versione beta

### Per Utenti

1. **Accedi al Sistema**:
   - Vai su http://localhost:8001/app-distribution/
   - Effettua login se richiesto

2. **Scarica App**:
   - **iOS**: Tocca "Installa su iOS" → Conferma installazione → Autorizza certificato in Impostazioni
   - **Android**: Tocca "Scarica APK" → Installa file → Autorizza fonti sconosciute

## 🔧 Configurazione Avanzata

### Email Notifications

Aggiungi in `settings.py`:

```python
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_HOST_USER = 'your-email@gmail.com'
EMAIL_HOST_PASSWORD = 'your-app-password'
DEFAULT_FROM_EMAIL = 'SecureVOX <noreply@securevox.com>'
```

### HTTPS per iOS (Produzione)

iOS richiede HTTPS per l'installazione OTA:

```python
# settings.py
SECURE_SSL_REDIRECT = True
ALLOWED_HOSTS = ['your-domain.com']
```

## 📡 API REST

### Upload Build

```bash
curl -X POST http://localhost:8001/app-distribution/api/builds/ \
  -H "Authorization: Token your-token" \
  -F "name=MyApp" \
  -F "platform=ios" \
  -F "version=1.0.0" \
  -F "build_number=1" \
  -F "bundle_id=com.company.app" \
  -F "app_file=@MyApp.ipa"
```

### Lista Build

```bash
curl http://localhost:8001/app-distribution/api/builds/
```

### Download Build

```bash
curl -X POST http://localhost:8001/app-distribution/api/builds/{id}/download/ \
  -H "Authorization: Token your-token"
```

## 🎯 Esempi d'Uso

### Scenario 1: Team Interno
- Carica build per test interni
- Limita accesso al team di sviluppo
- Raccogli feedback prima del rilascio

### Scenario 2: Beta Testing
- Distribuzione a beta tester selezionati
- Raccolta feedback e rating
- Monitoraggio download e crash

### Scenario 3: Distribuzione Enterprise
- App interne aziendali
- Controllo completo della distribuzione
- Analytics dettagliate sull'adozione

## 📊 Monitoraggio

### Statistiche Disponibili
- Download totali per build
- Utenti unici
- Feedback e rating medi
- Download per giorno
- Dispositivi e versioni OS

### Log e Debug
```bash
# Visualizza log in tempo reale
tail -f /var/log/securevox/django.log

# Debug specifico app distribution
python3 manage.py shell
>>> from app_distribution.models import AppBuild, AppDownload
>>> AppDownload.objects.count()  # Conteggio download
```

## 🔒 Sicurezza

### Controlli Implementati
- ✅ Autenticazione utenti
- ✅ Controllo accessi per build
- ✅ Validazione file upload
- ✅ Rate limiting API
- ✅ Log audit completi

### Best Practices
- Usa HTTPS in produzione
- Limita dimensioni file upload
- Monitora log per attività sospette
- Backup regolari delle build

## 🛠️ Troubleshooting

### Problemi Comuni

**iOS non installa l'app**:
- Verifica HTTPS attivo
- Controlla certificato di firma
- Autorizza sviluppatore in Impostazioni iOS

**File troppo grandi**:
```python
# settings.py
FILE_UPLOAD_MAX_MEMORY_SIZE = 500 * 1024 * 1024  # 500MB
```

**Android non installa**:
- Abilita "Fonti sconosciute"
- Verifica spazio disponibile
- Controlla compatibilità versione Android

## 🚀 Deployment

### Docker
Il sistema è già configurato per Docker:

```bash
docker build -t securevox-server .
docker run -v /path/to/media:/app/media -p 8001:8001 securevox-server
```

### Nginx
```nginx
location /app-distribution/ {
    proxy_pass http://127.0.0.1:8001;
    client_max_body_size 500M;
}
```

## 📞 Supporto

Per problemi:
1. Controlla log: `/var/log/securevox/`
2. Verifica configurazione: `settings.py`
3. Testa con dati demo
4. Consulta documentazione: `docs/APP_DISTRIBUTION_SETUP.md`

---

**🎉 Il tuo sistema di distribuzione app è pronto!**

Simile a TestFlight ma con controllo completo, perfetto per:
- Team di sviluppo
- Beta testing
- Distribuzione enterprise
- App interne aziendali
