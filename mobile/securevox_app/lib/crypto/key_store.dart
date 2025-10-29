import 'dart:async';

/// Interfaccia per archiviazione sicura di chiavi (KeyStore/Keychain)
abstract class KeyStore {
  Future<void> save(String key, List<int> value);
  Future<List<int>?> read(String key);
  Future<void> delete(String key);
}

/// Placeholder: in produzione usare flutter_secure_storage o plugin nativo hardware-backed
class InMemoryKeyStore implements KeyStore {
  final Map<String, List<int>> _mem = {};
  @override Future<void> save(String key, List<int> value) async { _mem[key] = List.of(value); }
  @override Future<List<int>?> read(String key) async => _mem[key];
  @override Future<void> delete(String key) async { _mem.remove(key); }
}
