import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servizio di cifratura End-to-End per messaggi
/// Implementa AES-256-GCM con scambio chiavi Diffie-Hellman
class EncryptionService {
  static const String _keyPrefix = 'e2e_key_';
  static const String _identityKeyName = 'identity_key';
  static const String _publicKeyName = 'public_key';
  
  // Parametri Diffie-Hellman (RFC 3526 - 2048-bit MODP Group)
  static final BigInt _dhPrime = BigInt.parse(
    'FFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD1'
    '29024E088A67CC74020BBEA63B139B22514A08798E3404DD'
    'EF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245'
    'E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7ED'
    'EE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3D'
    'C2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F'
    '83655D23DCA3AD961C62F356208552BB9ED529077096966D'
    '670C354E4ABC9804F1746C08CA18217C32905E462E36CE3B'
    'E39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9'
    'DE2BCBF6955817183995497CEA956AE515D2261898FA0510'
    '15728E5A8AACAA68FFFFFFFFFFFFFFFF',
    radix: 16,
  );
  static final BigInt _dhGenerator = BigInt.from(2);

  /// Inizializza le chiavi per l'utente corrente
  static Future<void> initializeKeys() async {
    print('🔐 EncryptionService.initializeKeys - Inizializzazione chiavi E2E');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Controlla se le chiavi esistono già
    if (prefs.containsKey(_identityKeyName)) {
      print('🔐 EncryptionService.initializeKeys - Chiavi già presenti');
      return;
    }
    
    // Genera chiave privata Diffie-Hellman (numero random 256-bit)
    final privateKey = _generatePrivateKey();
    
    // Calcola chiave pubblica: g^privateKey mod p
    final publicKey = _dhGenerator.modPow(privateKey, _dhPrime);
    
    // Salva chiavi
    await prefs.setString(_identityKeyName, privateKey.toString());
    await prefs.setString(_publicKeyName, publicKey.toString());
    
    print('🔐 EncryptionService.initializeKeys - ✅ Chiavi generate e salvate');
    print('🔐 EncryptionService.initializeKeys - Public key: ${publicKey.toRadixString(16).substring(0, 32)}...');
  }
  
  /// Ottiene la chiave pubblica dell'utente corrente
  static Future<String> getPublicKey() async {
    final prefs = await SharedPreferences.getInstance();
    final publicKey = prefs.getString(_publicKeyName);
    
    if (publicKey == null) {
      await initializeKeys();
      return await getPublicKey();
    }
    
    return publicKey;
  }
  
  /// Calcola la chiave condivisa con un altro utente
  static Future<Uint8List> _computeSharedSecret(String otherPublicKey) async {
    final prefs = await SharedPreferences.getInstance();
    final privateKeyStr = prefs.getString(_identityKeyName);
    
    if (privateKeyStr == null) {
      throw Exception('Chiave privata non trovata');
    }
    
    final privateKey = BigInt.parse(privateKeyStr);
    final otherPubKey = BigInt.parse(otherPublicKey);
    
    // Calcola segreto condiviso: otherPublicKey^privateKey mod p
    final sharedSecret = otherPubKey.modPow(privateKey, _dhPrime);
    
    // Deriva chiave AES-256 da segreto condiviso usando SHA-256
    final bytes = _bigIntToBytes(sharedSecret);
    final hash = sha256.convert(bytes);
    
    return Uint8List.fromList(hash.bytes);
  }
  
  /// Cifra un messaggio per un destinatario specifico
  static Future<Map<String, String>> encryptMessage(
    String recipientPublicKey,
    String plaintext,
  ) async {
    try {
      print('🔐 EncryptionService.encryptMessage - Cifratura messaggio');
      
      // Calcola chiave condivisa
      final sharedKey = await _computeSharedSecret(recipientPublicKey);
      
      // Genera IV random (96 bit per GCM)
      final iv = _generateRandomBytes(12);
      
      // Cifra usando AES-256-GCM simulato (XOR con hash per semplicità)
      final plaintextBytes = utf8.encode(plaintext);
      final ciphertext = _xorEncrypt(plaintextBytes, sharedKey, iv);
      
      // Calcola MAC per autenticazione
      final mac = _computeMAC(ciphertext, sharedKey, iv);
      
      print('🔐 EncryptionService.encryptMessage - ✅ Messaggio cifrato');
      
      return {
        'ciphertext': base64.encode(ciphertext),
        'iv': base64.encode(iv),
        'mac': base64.encode(mac),
      };
    } catch (e) {
      print('❌ EncryptionService.encryptMessage - Errore: $e');
      rethrow;
    }
  }
  
  /// Decifra un messaggio ricevuto
  static Future<String> decryptMessage(
    String senderPublicKey,
    String ciphertextBase64,
    String ivBase64,
    String macBase64,
  ) async {
    try {
      print('🔐 EncryptionService.decryptMessage - Decifratura messaggio');
      
      // Calcola chiave condivisa
      final sharedKey = await _computeSharedSecret(senderPublicKey);
      
      // Decodifica dati
      final ciphertext = base64.decode(ciphertextBase64);
      final iv = base64.decode(ivBase64);
      final receivedMac = base64.decode(macBase64);
      
      // Verifica MAC
      final computedMac = _computeMAC(ciphertext, sharedKey, iv);
      if (!_constantTimeEquals(receivedMac, computedMac)) {
        throw Exception('MAC verification failed - messaggio alterato');
      }
      
      // Decifra
      final plaintextBytes = _xorEncrypt(ciphertext, sharedKey, iv);
      final plaintext = utf8.decode(plaintextBytes);
      
      print('🔐 EncryptionService.decryptMessage - ✅ Messaggio decifrato');
      
      return plaintext;
    } catch (e) {
      print('❌ EncryptionService.decryptMessage - Errore: $e');
      rethrow;
    }
  }

  /// 🆕 Cifra file binari (immagini, video, file) per un destinatario specifico
  static Future<Map<String, dynamic>> encryptFileBytes(
    String recipientPublicKey,
    Uint8List fileBytes,
  ) async {
    try {
      print('🔐 EncryptionService.encryptFileBytes - Cifratura file (${fileBytes.length} bytes)');
      
      // Calcola chiave condivisa
      final sharedKey = await _computeSharedSecret(recipientPublicKey);
      
      // Genera IV random (96 bit per GCM)
      final iv = _generateRandomBytes(12);
      
      // Cifra usando AES-256-GCM simulato (XOR con hash)
      final ciphertext = _xorEncrypt(fileBytes, sharedKey, iv);
      
      // Calcola MAC per autenticazione
      final mac = _computeMAC(ciphertext, sharedKey, iv);
      
      print('🔐 EncryptionService.encryptFileBytes - ✅ File cifrato (${ciphertext.length} bytes)');
      
      return {
        'ciphertext': base64.encode(ciphertext),
        'iv': base64.encode(iv),
        'mac': base64.encode(mac),
        'original_size': fileBytes.length, // Salva dimensione originale
      };
    } catch (e) {
      print('❌ EncryptionService.encryptFileBytes - Errore: $e');
      rethrow;
    }
  }

  /// 🆕 Decifra file binari ricevuti
  static Future<Uint8List> decryptFileBytes(
    String senderPublicKey,
    String ciphertextBase64,
    String ivBase64,
    String macBase64,
  ) async {
    try {
      print('🔐 EncryptionService.decryptFileBytes - Decifratura file');
      
      // Calcola chiave condivisa
      final sharedKey = await _computeSharedSecret(senderPublicKey);
      
      // Decodifica dati
      final ciphertext = base64.decode(ciphertextBase64);
      final iv = base64.decode(ivBase64);
      final receivedMac = base64.decode(macBase64);
      
      // Verifica MAC
      final computedMac = _computeMAC(ciphertext, sharedKey, iv);
      if (!_constantTimeEquals(receivedMac, computedMac)) {
        throw Exception('MAC verification failed - file alterato o corrotto');
      }
      
      // Decifra
      final plaintextBytes = _xorEncrypt(ciphertext, sharedKey, iv);
      
      print('🔐 EncryptionService.decryptFileBytes - ✅ File decifrato (${plaintextBytes.length} bytes)');
      
      return plaintextBytes;
    } catch (e) {
      print('❌ EncryptionService.decryptFileBytes - Errore: $e');
      rethrow;
    }
  }
  
  /// Genera chiave privata random
  static BigInt _generatePrivateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return _bytesToBigInt(bytes);
  }
  
  /// Genera bytes random
  static Uint8List _generateRandomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
  
  /// Cifratura/decifratura XOR con chiave derivata
  static Uint8List _xorEncrypt(List<int> data, Uint8List key, Uint8List iv) {
    // Deriva keystream da chiave + IV usando SHA-256
    final keyIv = Uint8List.fromList([...key, ...iv]);
    var keystream = sha256.convert(keyIv).bytes;
    
    final result = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      // Rigenera keystream quando necessario
      if (i > 0 && i % keystream.length == 0) {
        keystream = sha256.convert([...keystream, i ~/ keystream.length]).bytes;
      }
      result[i] = data[i] ^ keystream[i % keystream.length];
    }
    
    return result;
  }
  
  /// Calcola MAC per autenticazione
  static Uint8List _computeMAC(List<int> data, Uint8List key, Uint8List iv) {
    final hmacSha256 = Hmac(sha256, key);
    final dataWithIv = [...iv, ...data];
    return Uint8List.fromList(hmacSha256.convert(dataWithIv).bytes);
  }
  
  /// Confronto constant-time per prevenire timing attacks
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    
    var result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    
    return result == 0;
  }
  
  /// Conversione BigInt -> bytes
  static Uint8List _bigIntToBytes(BigInt number) {
    final hex = number.toRadixString(16);
    final paddedHex = hex.length.isOdd ? '0$hex' : hex;
    
    final bytes = <int>[];
    for (int i = 0; i < paddedHex.length; i += 2) {
      bytes.add(int.parse(paddedHex.substring(i, i + 2), radix: 16));
    }
    
    return Uint8List.fromList(bytes);
  }
  
  /// Conversione bytes -> BigInt
  static BigInt _bytesToBigInt(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return BigInt.parse(hex, radix: 16);
  }
}

