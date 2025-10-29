# SFrame E2EE — Client Hooks (Flutter)

- Deriva chiavi SFrame **dalla sessione Signal** (Double Ratchet).
- Aggancia le chiavi a sender/receiver (quando API disponibili nel plugin o via layer nativo).
- Effettua **key rotation** frequente (per speaker-change/interval).

> Questo repo include `webrtc_demo.dart` con placeholder per `setEncryptionKey(...)`.
> Integrare appena disponibili le API insertable streams/SFrame su flutter_webrtc o via native plugin custom.
