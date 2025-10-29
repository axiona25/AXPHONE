import 'dart:math';
import 'libsignal_api.dart';
import 'key_store.dart';

/// Stub che simula le primitive: **DA SOSTITUIRE** con FFI reale a libsignal-client.
class LibSignalStub implements LibSignal {
  final KeyStore store;
  LibSignalStub(this.store);

  @override
  Future<void> initIdentity() async {
    await store.save('identity_key', List<int>.generate(32, (i) => i));
  }

  @override
  Future<void> loadPreKeys() async {
    await store.save('prekeys', List<int>.generate(32, (i) => 255 - i));
  }

  @override
  Future<void> establishSession(String peerId) async {
    await store.save('session_$peerId', List<int>.generate(32, (i) => (i * 7) & 0xff));
  }

  @override
  Future<List<int>> encryptMessage(String peerId, List<int> plaintext) async {
    final s = await store.read('session_$peerId') ?? List<int>.filled(32, 1);
    // XOR toy cipher — PLACEHOLDER
    return List<int>.generate(plaintext.length, (i) => plaintext[i] ^ s[i % s.length]);
  }

  @override
  Future<List<int>> decryptMessage(String peerId, List<int> ciphertext) async {
    return encryptMessage(peerId, ciphertext); // XOR again
  }

  @override
  Future<List<int>> deriveSFrameKey(String peerId) async {
    final rnd = Random();
    return List<int>.generate(16, (_) => rnd.nextInt(256));
  }
}
