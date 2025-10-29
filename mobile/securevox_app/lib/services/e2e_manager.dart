import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';
import 'e2e_api_service.dart';

/// Manager per la cifratura End-to-End
/// Gestisce l'abilitazione/disabilitazione e lo scambio chiavi
class E2EManager {
  static const String _e2eEnabledKey = 'e2e_enabled';
  static const String _e2eForceDisabledKey = 'e2e_force_disabled';
  static const String _publicKeysPrefix = 'user_pubkey_';
  
  static bool _isEnabled = false;
  static bool _isForceDisabled = false; // Flag admin: se true, la cifratura è disabilitata dall'admin
  static bool _isInitialized = false;
  
  /// Inizializza il sistema E2EE
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    print('🔐 E2EManager.initialize - Inizializzazione sistema E2EE');
    
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_e2eEnabledKey) ?? false;
    _isForceDisabled = prefs.getBool(_e2eForceDisabledKey) ?? false;
    
    if (_isEnabled && !_isForceDisabled) {
      await EncryptionService.initializeKeys();
      print('🔐 E2EManager.initialize - ✅ Sistema E2EE attivo');
    } else if (_isForceDisabled) {
      print('🔐 E2EManager.initialize - ⛔ Sistema E2EE disabilitato dall\'admin');
    } else {
      print('🔐 E2EManager.initialize - ⚠️  Sistema E2EE disabilitato');
    }
    
    _isInitialized = true;
  }
  
  /// Abilita la cifratura E2EE
  static Future<void> enable() async {
    print('🔐 E2EManager.enable - Abilitazione E2EE');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_e2eEnabledKey, true);
    _isEnabled = true;
    
    await EncryptionService.initializeKeys();
    
    // Sincronizza chiave pubblica con il backend
    await syncPublicKeyWithBackend();
    
    print('🔐 E2EManager.enable - ✅ E2EE abilitato');
  }
  
  /// Sincronizza la chiave pubblica con il backend
  static Future<void> syncPublicKeyWithBackend() async {
    try {
      print('🔐 E2EManager.syncPublicKeyWithBackend - Sincronizzazione chiave con backend');
      
      final publicKey = await EncryptionService.getPublicKey();
      final success = await E2EApiService.uploadPublicKey(publicKey);
      
      if (success) {
        print('✅ E2EManager.syncPublicKeyWithBackend - Chiave sincronizzata con successo');
      } else {
        print('⚠️  E2EManager.syncPublicKeyWithBackend - Errore sincronizzazione chiave');
      }
    } catch (e) {
      print('❌ E2EManager.syncPublicKeyWithBackend - Errore: $e');
    }
  }
  
  /// Disabilita la cifratura E2EE
  static Future<void> disable() async {
    print('🔐 E2EManager.disable - Disabilitazione E2EE');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_e2eEnabledKey, false);
    _isEnabled = false;
    
    print('🔐 E2EManager.disable - ✅ E2EE disabilitato');
  }
  
  /// Verifica se E2EE è abilitato
  /// Controlla sia il flag utente che il flag admin (force_disabled)
  static bool get isEnabled => _isEnabled && !_isForceDisabled;
  
  /// Salva la chiave pubblica di un utente
  static Future<void> saveUserPublicKey(String userId, String publicKey) async {
    print('🔐 E2EManager.saveUserPublicKey - Salvando chiave per utente $userId');
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_publicKeysPrefix$userId', publicKey);
    
    print('🔐 E2EManager.saveUserPublicKey - ✅ Chiave salvata');
  }
  
  /// Ottiene la chiave pubblica di un utente
  static Future<String?> getUserPublicKey(String userId) async {
    // Prova prima dalla cache locale
    final prefs = await SharedPreferences.getInstance();
    var publicKey = prefs.getString('$_publicKeysPrefix$userId');
    
    // Se non è in cache, prova a recuperarla dal backend
    if (publicKey == null) {
      print('🔐 E2EManager.getUserPublicKey - Chiave non in cache, recupero dal backend');
      publicKey = await E2EApiService.getUserPublicKey(userId);
      
      // Se trovata, salvala in cache
      if (publicKey != null) {
        await saveUserPublicKey(userId, publicKey);
      }
    }
    
    return publicKey;
  }
  
  /// Ottiene la chiave pubblica dell'utente corrente
  static Future<String> getMyPublicKey() async {
    if (!_isEnabled) {
      throw Exception('E2EE non abilitato');
    }
    
    return await EncryptionService.getPublicKey();
  }
  
  /// Cifra un messaggio per un destinatario
  static Future<Map<String, String>?> encryptMessage(
    String recipientUserId,
    String plaintext,
  ) async {
    if (!_isEnabled) {
      print('🔐 E2EManager.encryptMessage - E2EE disabilitato, messaggio in chiaro');
      return null;
    }
    
    // Ottieni chiave pubblica del destinatario
    final recipientPubKey = await getUserPublicKey(recipientUserId);
    
    if (recipientPubKey == null) {
      print('⚠️  E2EManager.encryptMessage - Chiave pubblica destinatario non trovata, invio in chiaro');
      return null;
    }
    
    try {
      print('🔐 E2EManager.encryptMessage - Cifratura messaggio per utente $recipientUserId');
      
      final encrypted = await EncryptionService.encryptMessage(
        recipientPubKey,
        plaintext,
      );
      
      print('🔐 E2EManager.encryptMessage - ✅ Messaggio cifrato');
      
      return encrypted;
    } catch (e) {
      print('❌ E2EManager.encryptMessage - Errore: $e');
      return null;
    }
  }
  
  /// Decifra un messaggio ricevuto
  static Future<String?> decryptMessage(
    String senderUserId,
    Map<String, dynamic> encryptedData,
  ) async {
    if (!_isEnabled) {
      return null;
    }
    
    // Ottieni chiave pubblica del mittente
    final senderPubKey = await getUserPublicKey(senderUserId);
    
    if (senderPubKey == null) {
      print('⚠️  E2EManager.decryptMessage - Chiave pubblica mittente non trovata');
      return null;
    }
    
    try {
      print('🔐 E2EManager.decryptMessage - Decifratura messaggio da utente $senderUserId');
      
      final plaintext = await EncryptionService.decryptMessage(
        senderPubKey,
        encryptedData['ciphertext'] as String,
        encryptedData['iv'] as String,
        encryptedData['mac'] as String,
      );
      
      print('🔐 E2EManager.decryptMessage - ✅ Messaggio decifrato');
      
      return plaintext;
    } catch (e) {
      print('❌ E2EManager.decryptMessage - Errore: $e');
      return null;
    }
  }
  
  /// Verifica se un messaggio è cifrato
  static bool isMessageEncrypted(Map<String, dynamic> messageData) {
    return messageData.containsKey('encrypted') && 
           messageData['encrypted'] == true &&
           messageData.containsKey('ciphertext');
  }
  
  /// 🔧 CORREZIONE: Pulisce la cache delle chiavi pubbliche degli altri utenti
  /// Questo DEVE essere chiamato al login per evitare di usare chiavi vecchie
  static Future<void> clearPublicKeysCache() async {
    try {
      print('🧹 E2EManager.clearPublicKeysCache - Pulizia cache chiavi pubbliche...');
      
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int cleared = 0;
      for (String key in keys) {
        if (key.startsWith(_publicKeysPrefix)) {
          await prefs.remove(key);
          cleared++;
        }
      }
      
      print('✅ E2EManager.clearPublicKeysCache - $cleared chiavi pubbliche pulite dalla cache');
    } catch (e) {
      print('❌ E2EManager.clearPublicKeysCache - Errore: $e');
    }
  }
  
  /// Scarica lo stato E2E force_disabled dal backend
  /// Chiamato durante il login per sincronizzare lo stato admin
  static Future<void> syncForceDisabledStatus() async {
    try {
      print('🔐 E2EManager.syncForceDisabledStatus - Sincronizzazione stato force_disabled...');
      print('🔐 Stato PRIMA della sync:');
      print('   _isEnabled: $_isEnabled');
      print('   _isForceDisabled: $_isForceDisabled');
      print('   isEnabled (computed): ${isEnabled}');
      
      final status = await E2EApiService.getUserE2EStatus();
      if (status != null) {
        print('📥 Risposta backend ricevuta:');
        print('   e2e_enabled: ${status['e2e_enabled']}');
        print('   e2e_force_disabled: ${status['e2e_force_disabled']}');
        print('   has_public_key: ${status['has_public_key']}');
        
        // ⚡ FIX: Sincronizza ENTRAMBI i flag dal backend
        final e2eEnabled = status['e2e_enabled'] as bool? ?? false;
        final forceDisabled = status['e2e_force_disabled'] as bool? ?? false;
        final hasPublicKey = status['has_public_key'] as bool? ?? false;
        
        // Se il backend dice che E2E è abilitato E l'utente ha chiavi, abilita _isEnabled
        if (e2eEnabled && hasPublicKey) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_e2eEnabledKey, true);
          _isEnabled = true;
          print('🔐 Sincronizzato _isEnabled = true dal backend');
        }
        
        await setForceDisabled(forceDisabled);
        
        print('🔐 Stato DOPO la sync:');
        print('   _isEnabled: $_isEnabled');
        print('   _isForceDisabled: $_isForceDisabled');
        print('   isEnabled (computed): ${isEnabled}');
        
        if (forceDisabled) {
          print('⛔ E2EManager.syncForceDisabledStatus - Cifratura disabilitata dall\'admin');
        } else {
          print('✅ E2EManager.syncForceDisabledStatus - Cifratura abilitata');
        }
      } else {
        print('❌ Status è null, backend non ha risposto correttamente');
      }
    } catch (e) {
      print('❌ E2EManager.syncForceDisabledStatus - Errore: $e');
    }
  }
  
  /// Imposta il flag force_disabled (usato dall'admin)
  static Future<void> setForceDisabled(bool forceDisabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_e2eForceDisabledKey, forceDisabled);
    _isForceDisabled = forceDisabled;
    
    print('🔐 E2EManager.setForceDisabled - Flag impostato a: $forceDisabled');
  }
  
  /// Getter per verificare se è forzatamente disabilitato dall'admin
  static bool get isForceDisabled => _isForceDisabled;
}

