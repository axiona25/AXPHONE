# 🌐 Configurazione DNS per securevox.it

## 📋 ISTRUZIONI PER CONFIGURARE IL DOMINIO

### **1. Accedi al pannello di controllo del tuo provider DNS**
- Vai su Register.it (o il tuo provider DNS)
- Accedi al pannello di controllo del dominio `securevox.it`

### **2. Configura i record DNS**

#### **Record A (Principale)**
```
Tipo: A
Nome: @
Valore: 130.110.3.186
TTL: 3600
```

#### **Record A (www)**
```
Tipo: A
Nome: www
Valore: 130.110.3.186
TTL: 3600
```

#### **Record CNAME (App Distribution)**
```
Tipo: CNAME
Nome: app
Valore: securevox.it
TTL: 3600
```

### **3. Verifica la configurazione**
Dopo aver configurato i DNS, verifica con:
```bash
nslookup securevox.it
nslookup www.securevox.it
```

### **4. Tempi di propagazione**
- **Propagazione DNS**: 15-60 minuti
- **Propagazione completa**: fino a 24 ore

## 🔧 CONFIGURAZIONE SERVER

### **IP Pubblico**: 130.110.3.186
### **Porte Aperte**:
- **80** (HTTP)
- **443** (HTTPS) - da configurare
- **8001** (Django Backend)
- **8002** (Call Server)
- **8003** (Notify Server)

## 📱 CONFIGURAZIONE APP MOBILE

Le app mobile sono già configurate per puntare a:
- **API Base**: `http://securevox.it:8001`
- **WebSocket**: `ws://securevox.it:8002`
- **Notifiche**: `ws://securevox.it:8003`

## 🚀 PROSSIMI PASSI

1. ✅ Configura i record DNS come sopra
2. 🔧 Esegui il deploy su Oracle Cloud
3. 📱 Compila le app mobile
4. 🔒 Configura HTTPS con Let's Encrypt
5. 🎉 Testa tutto il sistema

## 📞 SUPPORTO

Se hai problemi:
1. Verifica che i DNS siano configurati correttamente
2. Controlla che il server Oracle Cloud sia accessibile
3. Testa la connessione: `curl http://130.110.3.186:8001`
