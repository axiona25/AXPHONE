# 🔧 Risoluzione Pagina Bianca - SecureVOX Dashboard

## 🚨 Problema
La pagina `http://localhost:8001/admin/` mostra una pagina bianca.

## ✅ Soluzione Completa

### 1. **Verifica Prerequisiti**

Assicurati di avere installato:
- **Python 3.8+** (`python3 --version`)
- **Node.js 18+** (`node --version`) 
- **npm** (`npm --version`)

### 2. **Avvia il Server Django**

Apri un terminale e esegui:

```bash
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/server
python3 manage.py runserver 8001
```

**Oppure se python3 non funziona:**
```bash
python manage.py runserver 8001
```

### 3. **Builda la Dashboard React**

Apri un **secondo terminale** e esegui:

```bash
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack/admin
npm install
npm run build
```

### 4. **Verifica il Risultato**

Ora ricarica la pagina `http://localhost:8001/admin/` nel browser.

## 🚀 Script Automatici

Se preferisci, puoi usare gli script forniti:

### Opzione A: Script Completo
```bash
cd /Users/r.amoroso/Desktop/securevox-complete-cursor-pack
./fix_dashboard.sh
```

### Opzione B: Script Separati
```bash
# Build dashboard
./build_admin_dashboard.sh

# Avvia server
./start_server_8001.sh
```

## 🔍 Diagnostica

Se il problema persiste, esegui:

```bash
python3 diagnose_dashboard.py
```

Questo script ti dirà esattamente cosa manca.

## 📋 Checklist Rapida

- [ ] Python installato e funzionante
- [ ] Node.js installato e funzionante  
- [ ] npm installato e funzionante
- [ ] Server Django in esecuzione su porta 8001
- [ ] Dashboard React buildata (`admin/dist/` esiste)
- [ ] Browser ricaricato

## 🎯 Risultato Atteso

Dopo aver seguito questi passaggi, dovresti vedere:

1. **Prima**: Una pagina con istruzioni dettagliate su cosa fare
2. **Dopo**: La dashboard React completa con:
   - Form di login
   - Statistiche sistema
   - Gestione utenti
   - Monitoraggio in tempo reale

## 🆘 Se Nulla Funziona

1. **Verifica i log del server Django** nel terminale
2. **Controlla la console del browser** (F12) per errori JavaScript
3. **Prova a visitare** `http://localhost:8001/health/` per verificare che Django funzioni
4. **Riavvia tutto** chiudendo i processi e ripartendo da capo

## 📞 Supporto

Se continui ad avere problemi, controlla:
- Che la porta 8001 sia libera
- Che non ci siano firewall che bloccano la connessione
- Che tutti i file del progetto siano presenti
- Che i permessi sui file siano corretti

---

**🎉 Una volta risolto, la dashboard sarà disponibile su: http://localhost:8001/admin**
