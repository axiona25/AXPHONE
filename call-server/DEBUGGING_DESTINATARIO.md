# 🔍 DEBUGGING FILE DESTINATARIO

## Domande per capire il problema:

1. **Cosa vede esattamente il destinatario?**
   - Errore specifico? Quale?
   - Schermata bianca?
   - File corrotto/inutilizzabile?
   - File non si carica?

2. **Il file viene decifrato correttamente?**
   - Controlla i log Flutter quando il destinatario clicca sul file
   - Cerca log con "🔐" per vedere la decifratura

3. **Tipo di file problematica?**
   - Solo PDF?
   - Solo Office (Word, Excel)?
   - Tutti i file?

## Check automatico:

Gli errori più comuni sono:

1. **sender_id mancante nei metadata** → File non può essere decifrato
2. **Metadata di cifratura (iv/mac) mancanti** → File non cifrato o cache errata
3. **Backend non converte il file** → Conversione PDF fallisce

## Debug log da controllare:

```bash
# Log Flutter quando destinatario apre file
tail -f /tmp/flutter_general.log | grep -E "🔐|FILE|PDF|ERROR"

# Log Django per la conversione
tail -f /tmp/django.log | grep -i "pdf\|convert\|office"
```

