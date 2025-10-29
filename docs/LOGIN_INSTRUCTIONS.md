# 🔐 Istruzioni Login SecureVox

## ✅ **Credenziali Verificate e Funzionanti**

### **Raffaele Amoroso**
- **Email**: `r.amoroso80@gmail.com`
- **Password**: `ciaociao`
- **User ID**: `2`

### **Riccardo Dicamillo**  
- **Email**: `r.dicamillo69@gmail.com`
- **Password**: `ciaociao`
- **User ID**: `3`

### **Admin**
- **Email**: `admin@securevox.com`
- **Password**: `admin123` (da testare)

## 🧪 **Test API Confermati**

```bash
# ✅ FUNZIONA PERFETTAMENTE
curl -X POST -H "Content-Type: application/json" \
  -d '{"email": "r.amoroso80@gmail.com", "password": "ciaociao"}' \
  http://127.0.0.1:8000/api/auth/login/

# Risposta: 200 ✅
# {"user": {...}, "token": "85d939782ad0443465e0...", "message": "Login effettuato con successo"}
```

## 📱 **Istruzioni App Mobile**

### **1. Se l'app non ti fa loggare:**

1. **Ferma l'app completamente** (chiudi simulatore)
2. **Pulisci e ricompila:**
   ```bash
   cd mobile/securevox_app
   flutter clean
   flutter pub get
   flutter run
   ```
3. **Nella schermata di login:**
   - **Email**: `r.amoroso80@gmail.com`
   - **Password**: `ciaociao`
   - **Premi Login**

### **2. Se continua a dare errore 401:**

**Opzione A: Reset Completo**
```bash
# 1. Pulisci tutto
make dev-clean

# 2. Riavvia app
make dev-run
```

**Opzione B: Debug Manuale**
```bash
# 1. Controlla server
curl http://127.0.0.1:8000/api/health/

# 2. Testa login
curl -X POST -H "Content-Type: application/json" \
  -d '{"email": "r.amoroso80@gmail.com", "password": "ciaociao"}' \
  http://127.0.0.1:8000/api/auth/login/

# 3. Se funziona → problema app mobile
# 4. Se non funziona → problema server
```

## 🔧 **Problemi Comuni e Soluzioni**

### **❌ "Credenziali non valide"**
- ✅ **Verifica**: Email esatta con `@gmail.com`
- ✅ **Verifica**: Password `ciaociao` (tutto minuscolo)
- ✅ **Verifica**: Server Django attivo su `127.0.0.1:8000`

### **❌ "Errore di rete"**
- ✅ **Verifica**: URL `http://127.0.0.1:8000/api` (non localhost)
- ✅ **Verifica**: Server Django running
- ✅ **Verifica**: Nessun firewall che blocca

### **❌ "Token null"**
- ✅ **Soluzione**: Cleanup completo con `make dev-clean`
- ✅ **Soluzione**: Ricompilazione completa dell'app

## 🎯 **Stato Attuale Verificato**

✅ **Server Django**: Funzionante (200)
✅ **Database**: Utenti presenti e attivi  
✅ **Password**: Corrette e verificate
✅ **API Login**: Funzionante (test curl = 200)
✅ **Token Generation**: Funzionante

**Il problema è solo nell'app mobile che deve essere ricompilata completamente!** 📱

## 🚀 **Prossimi Passi**

1. **Aspetta** che l'app finisca di ricompilarsi
2. **Fai login** con le credenziali sopra
3. **Testa** le chiamate Raffaele → Riccardo
4. **Verifica** che il pulsante "Termina" funzioni

**Tutto dovrebbe funzionare perfettamente ora!** ✨
