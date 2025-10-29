/// API astratta per libsignal (X3DH + Double Ratchet) lato Dart.
/// Implementazione concreta via FFI o MethodChannel.
abstract class LibSignal {
  Future<void> initIdentity(); // genera identity keypair
  Future<void> loadPreKeys();  // prekeys per X3DH
  Future<void> establishSession(String peerId); // X3DH
  Future<List<int>> encryptMessage(String peerId, List<int> plaintext); // Double Ratchet
  Future<List<int>> decryptMessage(String peerId, List<int> ciphertext);
  Future<List<int>> deriveSFrameKey(String peerId); // derivazione chiave media
}
