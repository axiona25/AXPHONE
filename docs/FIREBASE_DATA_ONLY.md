# Firebase Data-Only Messaging (E2EE)

## Obiettivo
Ricevere **solo** notifiche `data` (niente `notification`) e decifrare il payload **solo lato client** con chiavi di sessione (Signal Double Ratchet).

## Passi
1. Configura il progetto Firebase per Android e iOS **senza** canali `notification`. Usa *data-only*.
2. Invia dal server un payload cifrato (es. AES-256-GCM) strutturato come:
   ```json
   {
     "type": "msg|call|wipe",
     "iv": "<base64>",
     "ct": "<base64>",
     "ad": "<base64 optional>"
   }
   ```
3. Il client Flutter decifra leggendo la chiave dalla sessione (ratchet) e gestisce l'azione.

> Il server **non** ha accesso al contenuto. Effettua solo il *relay* del blob cifrato.
