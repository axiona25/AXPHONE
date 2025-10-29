# Threat Model (STRIDE sintesi)

- **Spoofing**: forte autenticazione (passkey/WebAuthn opzionale), pin locale + biometria, binding device‑key.
- **Tampering**: E2EE, integrity dei pacchetti, firma messaggi, anti‑rollback.
- **Repudiation**: log minimi; opz. *sealed-sender* (deniability).
- **Information Disclosure**: Double Ratchet, SFrame; policy di metadati minima.
- **DoS**: rate limiting, token gating, TURN hardening.
- **Elevation of Privilege**: RBAC per admin; principle of least privilege; secret rotation.

Limitazioni note: OS e carrier possono avere tracce non eliminabili; non garantita detection di malware di sistema.
