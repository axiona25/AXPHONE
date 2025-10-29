# Architettura SecureVOX

## Obiettivi
- E2EE per chat, chiamate 1:1 e 1:many.
- Metadati minimi (no contenuti sul server, solo routing/quotas/telemetria aggregata anonima opzionale).
- Private cloud (on‑prem o VPC) con hardening, zero trust e rotazione chiavi.

## Panoramica
```
mobile (Flutter) <----> TURN <----> SFU WebRTC <----> mobile (Flutter)
        |                                 ^
        v                                 |
     Backend API (Django/DRF)  <----------+ (signaling/token/key-dir)
        |
        +-- Postgres, Redis, Vault/KMS
```

### Messaggistica
- Protocollo stile Signal: **X3DH** (curve25519, Ed25519) + **Double Ratchet** (HKDF, AES‑GCM).
- Librerie consigliate: `libsignal-client` via FFI (Flutter), wrapper Python per funzioni server-lato *non-segrete* (es. gestione pre-keys).

### Chiamate Audio/Video
- **WebRTC** con **DTLS‑SRTP**. Per 1:many usare **SFU** (es. Pion/ion‑sfu o Janus). Abilitare **Insertable Streams / SFrame** per E2EE end‑to‑end: l'SFU non accede al media.
- **TURN (coturn)** obbligatorio per NAT traversal (UDP/TCP/TLS).

### Notifiche
- FCM/APNs **data‑only**. Payload cifrato con chiavi di sessione. Il server invia solo blob non interpretabili.

### Storage locale & Remote Wipe
- Allegati **solo cifrati** (AES‑256‑GCM) con chiavi per‑file in **KeyStore/Keychain** (hardware‑backed quando disponibile).
- **Secure delete** (overwrite + unlink) dove supportato; su iOS/Android la reale sanitizzazione dipende dal filesystem/driver.
- “Remote wipe” best‑effort: l’app, alla ricezione del comando Admin, **pulisce chiavi e blob** e invalida il profilo (logout distruttivo).

### Integrità dispositivo
- **Root/Jailbreak detection**, **anti‑debugging**, **Play Integrity / DeviceCheck**, **FLAG_SECURE** (no screenshot), **Clipboard opt‑out**, verifica IME (Android) con warning se tastiera non di sistema.
- **Non è possibile** terminare app terze o garantire assenza assoluta di keylogger/screen recorder a livello OS.

### Logging
- Logging **in‑memory** volatile con soglia bassa; nessun log persistente di eventi sensibili.
- Server: audit minimale, no contenuti, retention ridotta con log hashing + chiavi rotanti.
