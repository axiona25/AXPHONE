# Sistema Automatico Cleanup Token - Soluzione Definitiva

## 🎯 **Problema Risolto**

**Prima**: Quando ricompilavi l'app Flutter, il token rimaneva salvato ma era scaduto/non sincronizzato, causando:
- 🟡 **Pallino giallo** invece di verde (stato instabile)
- 🔄 **Loop infinito** di polling con errori 401
- 🔋 **Consumo batteria** eccessivo
- 📱 **App lenta** per errori continui
- 👥 **Altri utenti** rimanevano online con token vecchi (problema Raffaele/Riccardo)

**Ora**: Sistema completamente automatizzato che **forza logout UNIVERSALE** di tutti gli utenti! 🚀

## ✅ **Sistema Automatico Implementato**

### **1. Cleanup Automatico all'App Lifecycle**

#### **Hook nel `main.dart`**
```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  switch (state) {
    case AppLifecycleState.paused:
    case AppLifecycleState.inactive:
      // App fermata per ricompilazione → Cleanup automatico
      if (kDebugMode) {
        _runAutomaticCleanup('App paused/inactive');
      }
      break;
      
    case AppLifecycleState.detached:
      // App chiusa completamente → Cleanup automatico
      if (kDebugMode) {
        _runAutomaticCleanup('App detached');
      }
      break;
  }
}
```

#### **Cleanup Script** (`scripts/auto_cleanup_tokens.py`)
```python
def force_logout_all_via_api():
    # NUOVO: Forza logout di TUTTI gli utenti tramite API Django
    response = requests.post(f"{API_BASE_URL}/dev/force-logout-all/")
    # Elimina TUTTI i token, sessioni, stati online

def cleanup_expired_tokens():
    # Fallback: Elimina TUTTI i token (non solo scaduti)
    cursor.execute("DELETE FROM authtoken_token")  # TUTTI i token
    cursor.execute("DELETE FROM django_session")   # TUTTE le sessioni

def reset_user_online_status():
    # Reset TUTTI gli utenti offline
    cursor.execute("UPDATE api_userstatus SET is_logged_in = 0, status = 'offline'")
```

### **2. Comandi di Sviluppo Semplificati**

#### **Makefile Aggiornato**
```bash
# Avvia app con cleanup automatico
make dev-run

# Cleanup manuale se necessario  
make dev-clean

# Solo server Django
make dev-server
```

### **3. Verifica Token all'Avvio**

#### **AuthService Migliorato**
```dart
void _initializeCurrentUser() async {
  await getCurrentUser();
  
  // NUOVO: Verifica automatica token all'avvio
  await _verifyAndRefreshTokenOnStartup();
}

Future<void> _verifyAndRefreshTokenOnStartup() async {
  final token = await _getAuthToken();
  if (token == null) return;
  
  final isValid = await verifyToken();
  
  if (isValid) {
    // Token valido → Aggiorna stato online
    await _updateUserOnlineStatus();
  } else {
    // Token scaduto → Logout automatico
    await forceLogout('Token scaduto');
  }
}
```

## 🚀 **Come Usare il Sistema**

### **Opzione 1: Comando Automatico (Raccomandato)**
```bash
# Questo comando fa tutto automaticamente:
# 1. Pulisce token scaduti
# 2. Reset stati utenti  
# 3. Elimina chiamate vecchie
# 4. Avvia Flutter app
make dev-run
```

### **Opzione 2: Cleanup Manuale**
```bash
# Solo cleanup senza avviare app
make dev-clean

# Poi avvia app normalmente
cd mobile/securevox_app && flutter run
```

### **Opzione 3: Script Diretto**
```bash
# Cleanup diretto
python3 scripts/auto_cleanup_tokens.py
```

## 🔧 **Cosa Succede Automaticamente**

### **Quando Fermi l'App (Ctrl+C, ricompilazione, etc.)**
```
📱 App lifecycle: paused/detached
         ↓
🧹 Trigger automatico cleanup
         ↓
🌐 API Django: force-logout-all
         ↓
🗄️ Elimina TUTTI i token dal DB
         ↓
👥 TUTTI gli utenti → offline (incluso Raffaele!)
         ↓
📞 Pulisce chiamate vecchie
         ↓
✅ TUTTI dovranno fare re-login
```

### **Quando Riavvii l'App**
```
📱 App startup
         ↓
🔐 Verifica token salvato
         ↓
✅ Token valido → Stato online
❌ Token scaduto → Logout automatico
         ↓
🟢 Pallino verde (online)
🔴 Schermata login (se scaduto)
```

## 📊 **Risultati**

### **✅ Problemi Risolti**
- 🟢 **Pallino sempre verde** quando loggato
- 🛑 **Nessun loop infinito** di polling
- 🔋 **Batteria risparmiata** (no richieste inutili)
- 🚀 **App veloce** senza errori ripetitivi
- 🔄 **Ricompilazione pulita** senza problemi di stato
- 👥 **RISOLTO**: Altri utenti (Raffaele) non restano più online con token vecchi
- 🔄 **LOGOUT UNIVERSALE**: Tutti gli utenti vengono disconnessi automaticamente

### **✅ Workflow Sviluppo Ottimizzato**
- **Un solo comando**: `make dev-run`
- **Cleanup automatico**: Nessun intervento manuale
- **Stato sempre pulito**: Ogni riavvio parte da zero
- **Token sempre validi**: Verifica automatica all'avvio

## 🎯 **Istruzioni Immediate**

### **Per Risolvere Subito il Problema:**

1. **Ferma l'app Flutter** attuale (Ctrl+C)

2. **Usa il comando automatico:**
   ```bash
   make dev-run
   ```

3. **Oppure manualmente:**
   ```bash
   # Pulisci token
   python3 scripts/auto_cleanup_tokens.py
   
   # Ricompila app
   cd mobile/securevox_app
   flutter clean
   flutter pub get
   flutter run
   ```

### **Risultato Atteso:**
- ✅ **Nessun pallino giallo** - solo verde o rosso
- ✅ **Nessun loop polling** - log puliti
- ✅ **Login funzionante** - token sempre sincronizzati
- ✅ **Chiamate funzionanti** - notifiche corrette

**D'ora in poi, usa sempre `make dev-run` per avviare l'app in sviluppo!** 🚀

---

**Il sistema è ora completamente automatizzato e non richiede più interventi manuali.** 🎉
