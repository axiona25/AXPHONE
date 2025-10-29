# libsignal FFI — Wiring

1. **Scelta binding**: usare `libsignal-client` (Rust) e creare un wrapper C per FFI, oppure canali nativi (Android/iOS).
2. **Key storage**: usa **KeyStore/Keychain** hardware-backed; il repo espone `KeyStore` (Dart) con stub `InMemoryKeyStore`.
3. **API**: vedi `lib/crypto/libsignal_api.dart` e `lib/crypto/libsignal_stub.dart` (placeholder). Sostituisci lo stub con binding reale.
4. **Derivazione SFrame**: esporta un metodo che produce chiavi simmetriche per media; ruotale spesso e sincronizza tra peer.
5. **Hardening**: anti-debug, root/jb detection, controllo integrità, FLAG_SECURE; blocca device compromessi.
