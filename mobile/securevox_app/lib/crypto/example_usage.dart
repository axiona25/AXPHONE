import 'dart:convert';
import 'libsignal_stub.dart';
import 'key_store.dart';

Future<void> exampleCryptoFlow() async {
  final ks = InMemoryKeyStore();
  final lib = LibSignalStub(ks);
  await lib.initIdentity();
  await lib.loadPreKeys();
  await lib.establishSession('peerA');
  final ct = await lib.encryptMessage('peerA', utf8.encode('hello securevox'));
  final pt = await lib.decryptMessage('peerA', ct);
  assert(utf8.decode(pt) == 'hello securevox');
}
