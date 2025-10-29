## SFU E2EE

Questa integrazione usa **Janus Gateway** con plugin `videoroom` e flag `e2ee = true`.
- L'E2EE è gestita **lato client** con **SFrame** (insertable streams via libwebrtc/native). L'SFU inoltra solo pacchetti cifrati.
- TURN (coturn) rimane obbligatorio per NAT traversal.
- Per produzione, effettua un build pinned di Janus con dipendenze verificate e hardening.

Nei client Flutter (flutter_webrtc), implementa il layer E2EE applicativo (SFrame) integrando il keying da sessione Signal.
