import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';
import 'real_chat_service.dart';
import 'media_service.dart'; // 🔐 CORREZIONE: Import MediaService per invalidare cache video
import 'e2e_manager.dart';
import 'timezone_service.dart'; // 🔐 CORREZIONE: Import TimezoneService per formattazione timestamp
import '../models/message_model.dart';
import '../models/chat_model.dart';

/// Servizio unificato per la gestione real-time dei messaggi
/// Sostituisce tutti gli altri servizi di notifiche e real-time
class UnifiedRealtimeService extends ChangeNotifier {
  static final UnifiedRealtimeService _instance = UnifiedRealtimeService._internal();
  factory UnifiedRealtimeService() => _instance;
  UnifiedRealtimeService._internal();

  // URL del server SecureVOX Notify
  final String notifyServerUrl = 'http://127.0.0.1:8002';
  
  // Stato del servizio
  bool _isInitialized = false;
  String? _deviceToken;
  
  // CORREZIONE: Riferimento al MessageService esistente
  MessageService? _messageService;
  String? _currentUserId;
  Timer? _pollingTimer;
  
  // WORKAROUND NOTIFICHE: Monitoraggio chat per rilevare gestazioni
  Timer? _chatMonitorTimer;
  Map<String, bool> _lastGestationState = {};
  Set<String> _notifiedGestations = {}; // Traccia notifiche già inviate
  
  // 🔐 REALTIME: Monitoraggio stato crittografia per chat
  Timer? _encryptionStatusTimer;
  Map<String, bool> _lastEncryptionStatus = {}; // chatId -> isEncrypted
  
  // 🚫 REALTIME: Monitoraggio stato utente (bloccato/disabilitato)
  Timer? _userStatusTimer;
  bool? _lastUserStatus; // Ultimo stato is_active dell'utente
  String? _lastUsername; // Username dell'utente (per polling post-logout)

  // Getters
  bool get isInitialized => _isInitialized;
  String? get deviceToken => _deviceToken;
  
  /// CORREZIONE: Imposta il MessageService esistente
  void setMessageService(MessageService messageService) {
    _messageService = messageService;
    print('📱 UnifiedRealtimeService - MessageService impostato');
  }
  String? get currentUserId => _currentUserId;

  /// Forza la re-inizializzazione (utile dopo login)
  Future<void> forceReInit() async {
    print('🔄 UnifiedRealtimeService - FORZANDO re-inizializzazione...');
    _isInitialized = false;
    await initialize();
  }

  /// Inizializza il servizio
  /// Funziona sia con utente loggato che senza (per polling stato utente dopo logout)
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔄 UnifiedRealtimeService - Già inizializzato, skip');
      return;
    }
    
    try {
      print('🚀 UnifiedRealtimeService - Inizializzazione...');
      
      // 1. Ottieni i dati dell'utente corrente
      await _loadUserData();
      print('👤 UnifiedRealtimeService - User data caricati: $_currentUserId');
      
      // 🚫 REALTIME: Se non c'è userId ma c'è un username salvato, avvia solo il polling stato utente
      if (_currentUserId == null) {
        if (_lastUsername != null) {
          print('⚠️ UnifiedRealtimeService - Nessun userId, ma username presente: $_lastUsername');
          print('🚫 Avvio SOLO polling stato utente (senza registrazione dispositivo)');
          
          // Avvia solo il polling dello stato utente (senza registrazione dispositivo)
          _startUserStatusPolling();
          
          _isInitialized = true;
          print('✅ UnifiedRealtimeService - Inizializzazione completata (solo polling stato utente)');
          return;
        } else {
          print('❌ UnifiedRealtimeService - ATTENZIONE: _currentUserId è NULL e nessun username salvato!');
          return;
        }
      }
      
      // 2. Genera token dispositivo
      await _generateDeviceToken();
      print('📱 UnifiedRealtimeService - Device token generato: $_deviceToken');
      
      if (_deviceToken == null) {
        print('❌ UnifiedRealtimeService - ATTENZIONE: _deviceToken è NULL! Impossibile registrare dispositivo.');
        return;
      }
      
      // 3. Registra dispositivo con SecureVOX Notify
      await _registerDevice();
      print('📡 UnifiedRealtimeService - Dispositivo registrato');
      
      // 4. Avvia il polling per i messaggi
      _startMessagePolling();
      print('🔄 UnifiedRealtimeService - Polling avviato');
      
      // 🚫 REALTIME: Avvia anche il polling stato utente (sempre attivo)
      _startUserStatusPolling();
      
      _isInitialized = true;
      print('✅ UnifiedRealtimeService - Inizializzazione completata');
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore inizializzazione: $e');
      print('❌ Stack trace: ${StackTrace.current}');
    }
  }

  /// Carica i dati dell'utente corrente
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // DEBUG: Mostra tutte le chiavi salvate
      final allKeys = prefs.getKeys();
      print('🔍 UnifiedRealtimeService - Chiavi salvate: $allKeys');
      
      // CORREZIONE: Prova prima con securevox_current_user_id, poi con securevox_current_user
      _currentUserId = prefs.getString('securevox_current_user_id');
      print('🔍 UnifiedRealtimeService - securevox_current_user_id: $_currentUserId');
      
      if (_currentUserId == null) {
        // Fallback: estrai l'ID dall'oggetto user salvato
        final userJson = prefs.getString('securevox_current_user');
        print('🔍 UnifiedRealtimeService - securevox_current_user: $userJson');
        if (userJson != null) {
          try {
            final userData = jsonDecode(userJson);
            _currentUserId = userData['id']?.toString();
            print('👤 UnifiedRealtimeService - User ID da user object: $_currentUserId');
          } catch (e) {
            print('❌ UnifiedRealtimeService - Errore parsing user object: $e');
          }
        }
      }
      
      print('👤 UnifiedRealtimeService - User ID finale: $_currentUserId');
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore caricamento user data: $e');
    }
  }

  /// Genera un token univoco per questo dispositivo
  Future<void> _generateDeviceToken() async {
    try {
      _deviceToken = 'securevox_ios_${DateTime.now().millisecondsSinceEpoch}';
      print('📱 UnifiedRealtimeService - Device Token: $_deviceToken');
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore generazione token: $e');
    }
  }

  /// Registra il dispositivo con SecureVOX Notify
  Future<void> _registerDevice() async {
    if (_deviceToken == null || _currentUserId == null) {
      print('❌ UnifiedRealtimeService._registerDevice - Token o UserId mancanti: $_deviceToken, $_currentUserId');
      return;
    }
    
    try {
      final payload = {
        'device_token': _deviceToken,
        'user_id': _currentUserId,
        'platform': 'ios',
        'app_version': '1.0.0',
      };
      
      print('🔥 UnifiedRealtimeService - FORZANDO registrazione dispositivo:');
      print('🔥   Device Token: $_deviceToken');
      print('🔥   User ID: $_currentUserId');
      print('🔥   URL: $notifyServerUrl/register');
      
      final response = await http.post(
        Uri.parse('$notifyServerUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('🔥 UnifiedRealtimeService - Risposta registrazione: ${response.statusCode}');
      print('🔥 UnifiedRealtimeService - Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ UnifiedRealtimeService - Dispositivo registrato con successo nel server notify');
        
        // CORREZIONE: Verifica immediatamente la registrazione
        await _verifyDeviceRegistration();
      } else {
        print('❌ UnifiedRealtimeService - Errore registrazione: ${response.statusCode} - ${response.body}');
        // CORREZIONE: Riprova dopo 2 secondi
        await Future.delayed(Duration(seconds: 2));
        await _registerDevice();
      }
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore registrazione: $e');
    }
  }

  /// Verifica che il dispositivo sia registrato correttamente
  Future<void> _verifyDeviceRegistration() async {
    try {
      final response = await http.get(
        Uri.parse('$notifyServerUrl/devices'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devices = data['devices'] as List;
        
        bool found = false;
        for (var device in devices) {
          if (device['device_token'] == _deviceToken && device['user_id'] == _currentUserId) {
            found = true;
            print('✅ UnifiedRealtimeService - Dispositivo verificato nel server: ${device['user_id']} -> ${device['device_token']}');
            break;
          }
        }
        
        if (!found) {
          print('❌ UnifiedRealtimeService - Dispositivo NON trovato nel server, riprovo registrazione...');
          await Future.delayed(Duration(seconds: 1));
          await _registerDevice();
        }
      }
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore verifica registrazione: $e');
    }
  }

  /// Avvia il polling per i messaggi
  void _startMessagePolling() {
    if (_deviceToken == null) {
      print('❌ UnifiedRealtimeService - Device token non disponibile, skip polling');
      return;
    }
    
    print('🔄 UnifiedRealtimeService - Avvio polling con token: $_deviceToken');
    print('🔄 UnifiedRealtimeService - URL polling: $notifyServerUrl/poll/$_deviceToken');
    
      // WORKAROUND: Avvia monitoraggio chat per rilevare gestazioni
      _startChatMonitoring();
      
      // 🔐 REALTIME: Avvia monitoraggio stato crittografia
      _startEncryptionStatusPolling();
      
      // NOTA: Il polling stato utente viene avviato anche in initialize() quando non c'è userId
      // Qui viene avviato solo se non era già stato avviato (per utenti loggati)
      if (_userStatusTimer == null) {
        _startUserStatusPolling();
      }
      
      // CORREZIONE: Polling ridotto (5 secondi) per evitare throttling server
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        print('🔄 UnifiedRealtimeService - Polling in corso...');
        final response = await http.get(
          Uri.parse('$notifyServerUrl/poll/$_deviceToken'),
          headers: {
            'Content-Type': 'application/json',
          },
        );

        print('🔄 UnifiedRealtimeService - Risposta polling: ${response.statusCode}');
        print('🔄 UnifiedRealtimeService - Body polling: ${response.body}');

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // CORREZIONE: Il server restituisce 'notifications' non 'messages'
          if (data['notifications'] != null && (data['notifications'] as List).isNotEmpty) {
            print('');
            print('📨 ===== NOTIFICHE RICEVUTE DAL POLLING =====');
            print('📨 UnifiedRealtimeService - Trovate ${(data['notifications'] as List).length} notifiche');
            
            // 🔄 REFRESH AUTO: Reset contatore quando troviamo notifiche
            _noNotificationCount = 0;
            
            for (final notification in data['notifications']) {
              final notifType = notification['notification_type'] ?? notification['type'] ?? 'unknown';
              final messageType = notification['data']?['message_type'] ?? 'unknown';
              final messageId = notification['data']?['message_id'] ?? notification['message_id'] ?? 'unknown';
              print('📨 Notifica: type=$notifType, messageType=$messageType, messageId=$messageId');
              _handleIncomingMessage(notification);
            }
            print('📨 ==========================================');
            print('');
            
            // Pulisci la cache dei messaggi processati periodicamente
            _cleanupProcessedMessageIds();
            _cleanupSentNotificationIds();
          } else {
            print('🔄 UnifiedRealtimeService - Nessun messaggio nuovo');
            
            // 🔄 REFRESH AUTO: Incrementa contatore e verifica se è necessario fare refresh
            _noNotificationCount++;
            print('🔄 UnifiedRealtimeService - Polling senza notifiche: $_noNotificationCount/$_maxNoNotificationCount');
            
            if (_noNotificationCount >= _maxNoNotificationCount) {
              print('');
              print('🔄 ===== TRIGGER REFRESH AUTOMATICO =====');
              print('🔄 Nessuna notifica ricevuta per ${_maxNoNotificationCount * 5} secondi');
              print('🔄 Eseguo refresh automatico messaggi per chat attive...');
              print('🔄 =======================================');
              print('');
              
              // Reset contatore per evitare refresh continui
              _noNotificationCount = 0;
              
              // Esegui refresh delle chat attive
              await _refreshActiveChats();
            }
          }
        } else {
          print('❌ UnifiedRealtimeService - Errore polling: ${response.statusCode}');
          // FALLBACK: Se il server non risponde, prova a caricare i messaggi dal backend
          await _fallbackLoadMessages();
        }
      } catch (e) {
        print('❌ UnifiedRealtimeService - Errore polling: $e');
        // FALLBACK: Se c'è un errore di rete, prova a caricare i messaggi dal backend
        await _fallbackLoadMessages();
      }
    });
  }

  // Cache per evitare messaggi duplicati
  final Set<String> _processedMessageIds = {};
  
  // Cache per evitare invii duplicati di notifiche
  final Set<String> _sentNotificationIds = {};
  
  // 🔄 REFRESH AUTO: Contatore per polling senza notifiche
  int _noNotificationCount = 0;
  static const int _maxNoNotificationCount = 6; // 6 polling = 30 secondi (6 * 5s)

  /// Gestisce le notifiche in arrivo (messaggi e eliminazioni chat)
  void _handleIncomingMessage(Map<String, dynamic> notification) async {
    String? messageId; // Dichiarata qui per essere visibile nel catch
    try {
      print('📨 UnifiedRealtimeService - Gestione notifica: ${notification['id']}');
      
      // CORREZIONE: Il server restituisce le notifiche in un formato specifico
      var data = notification['data'] ?? notification;
      
      // 🔐 E2EE: Decifra la notifica se cifrata
      if (data['encrypted'] == true && data['encrypted_payload'] != null) {
        print('🔐 UnifiedRealtimeService - Notifica CIFRATA ricevuta');
        
        final senderId = data['sender_id'];
        if (senderId != null) {
          try {
            final encryptedPayload = data['encrypted_payload'] as Map<String, dynamic>;
            final decrypted = await E2EManager.decryptMessage(
              senderId.toString(),
              encryptedPayload,
            );
            
            if (decrypted != null) {
              // Decifra il payload JSON
              final decryptedData = jsonDecode(decrypted) as Map<String, dynamic>;
              print('🔐 UnifiedRealtimeService - ✅ Notifica decifrata con successo');
              
              // 🔐 FIX CRITICO: Preserva i metadata del file (iv, mac, encrypted) anche dopo decifratura
              final originalMetadata = data['metadata'] as Map<String, dynamic>?;
              final decryptedPayload = decryptedData['data'] ?? decryptedData;
              
              // Sostituisci data con i dati decifrati
              data = Map<String, dynamic>.from(decryptedPayload);
              
              // 🔐 RI-INSERISCI i metadata del file se presenti nella notifica originale
              if (originalMetadata != null && originalMetadata.isNotEmpty) {
                print('🔐 UnifiedRealtimeService - Preservo metadata file dalla notifica originale');
                print('🔐   Metadata originali: ${originalMetadata.keys}');
                
                // Assicurati che i metadata siano nel posto giusto
                if (data['metadata'] == null) {
                  data['metadata'] = <String, dynamic>{};
                }
                final currentMetadata = data['metadata'] as Map<String, dynamic>;
                
                // Copia i metadata di cifratura del file (iv, mac, encrypted, original_size, etc.)
                if (originalMetadata['iv'] != null) currentMetadata['iv'] = originalMetadata['iv'];
                if (originalMetadata['mac'] != null) currentMetadata['mac'] = originalMetadata['mac'];
                if (originalMetadata['encrypted'] != null) currentMetadata['encrypted'] = originalMetadata['encrypted'];
                if (originalMetadata['original_size'] != null) currentMetadata['original_size'] = originalMetadata['original_size'];
                if (originalMetadata['original_file_name'] != null) currentMetadata['original_file_name'] = originalMetadata['original_file_name'];
                if (originalMetadata['original_file_extension'] != null) currentMetadata['original_file_extension'] = originalMetadata['original_file_extension'];
                if (originalMetadata['local_file_name'] != null) currentMetadata['local_file_name'] = originalMetadata['local_file_name'];
                
                print('🔐   Metadata preservati: iv=${currentMetadata['iv'] != null}, mac=${currentMetadata['mac'] != null}, encrypted=${currentMetadata['encrypted']}');
              }
              
              // Log del contenuto decifrato (per debug)
              print('🔐 UnifiedRealtimeService - Sender: ${decryptedData['sender_name']}');
              print('🔐 UnifiedRealtimeService - Content: ${data['content']}');
            } else {
              print('❌ UnifiedRealtimeService - Impossibile decifrare notifica');
              // Continua con data minimo disponibile
            }
          } catch (e) {
            print('❌ UnifiedRealtimeService - Errore decifratura: $e');
            // Continua con data minimo disponibile
          }
        }
      }
      
      final notificationType = data['notification_type'] ?? data['type'];
      
      // NUOVO: Gestisci diversi tipi di notifiche
      if (notificationType == 'chat_deletion_request') {
        _handleChatDeletionNotification(data);
        return;
      }
      
      // Gestione messaggi normali
      final chatId = data['chat_id'];
      messageId = data['message_id']; // Assegna alla variabile dichiarata fuori dal try
      
      // 🔐 FIX: sender_id può essere sia in notification root che in data
      final senderId = notification['sender_id'] ?? data['sender_id'];
      print('🔑 DEBUG sender_id:');
      print('   notification[sender_id]: ${notification['sender_id']}');
      print('   data[sender_id]: ${data['sender_id']}');
      print('   senderId finale: $senderId');
      
      final content = data['content'];
      final messageType = data['message_type'];
      final timestamp = data['timestamp'];

      if (chatId == null || messageId == null) {
        print('❌ UnifiedRealtimeService - Dati mancanti nella notifica');
        print('❌ UnifiedRealtimeService - Dati ricevuti: $data');
        return;
      }

      // CORREZIONE: Controlla se il messaggio è già stato processato per evitare duplicati
      print('');
      print('📨 ===== CONTROLLO DUPLICATI =====');
      print('📨 MessageId: $messageId');
      print('📨 Messaggi già processati: ${_processedMessageIds.length}');
      print('📨 Messaggio già presente: ${_processedMessageIds.contains(messageId)}');
      if (_processedMessageIds.contains(messageId)) {
        print('⚠️⚠️⚠️ MESSAGGIO GIÀ PROCESSATO - SKIP: $messageId');
        print('📨 Questo potrebbe essere il motivo per cui il messaggio non appare!');
        print('📨 =======================================');
        print('');
        return;
      }
      print('📨 ✅ Messaggio non ancora processato - procedo');
      print('📨 =======================================');
      print('');

      // CORREZIONE: Controlla se la chat è attualmente visualizzata per determinare lo stato di lettura
      final isCurrentlyViewing = _messageService?.isChatCurrentlyViewing(chatId) ?? false;
      final currentlyViewingChatId = _messageService?.getCurrentlyViewingChatId();
      
      print('📨 UnifiedRealtimeService - ===== DEBUG MESSAGGIO IN ARRIVO =====');
      print('📨 UnifiedRealtimeService - Chat destinatario: $chatId');
      print('📨 UnifiedRealtimeService - Chat attualmente visualizzata: $currentlyViewingChatId');
      print('📨 UnifiedRealtimeService - Chat $chatId attualmente visualizzata: $isCurrentlyViewing');
      
      // CORREZIONE: Logica di sicurezza - se la chat visualizzata non corrisponde alla chat destinatario, forza isRead: false
      // CORREZIONE: Se _currentlyViewingChatId è null, l'utente è nella home, quindi isRead: false
      final shouldBeRead = isCurrentlyViewing && currentlyViewingChatId == chatId && currentlyViewingChatId != null;
      print('📨 UnifiedRealtimeService - Messaggio sarà creato con isRead: $shouldBeRead');
      print('📨 UnifiedRealtimeService - Controllo finale: isCurrentlyViewing=$isCurrentlyViewing, currentlyViewingChatId=$currentlyViewingChatId, chatId=$chatId');
      print('📨 UnifiedRealtimeService - ==========================================');
      
      // CORREZIONE: Debug completo del payload in arrivo
      print('📨 UnifiedRealtimeService._handleIncomingMessage - DEBUG PAYLOAD COMPLETO:');
      print('📨   messageId: $messageId');
      print('📨   chatId: $chatId');
      print('📨   senderId: $senderId');
      print('📨   content: $content');
      print('📨   messageType: $messageType');
      print('📨   timestamp: $timestamp');
      print('📨   data keys: ${data.keys}');
      print('📨   data values: $data');
      
      // Crea il messaggio dal payload
      final now = DateTime.now();
      final parsedMessageType = _parseMessageType(messageType ?? 'text');
      String messageContent = content ?? '';
      
      // 🔐 CORREZIONE: Decifra il content del messaggio se cifrato
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final isEncrypted = metadata?['encrypted'] == true || metadata?['iv'] != null;
      final isMe = senderId == _currentUserId;
      
      print('');
      print('╔════════════════════════════════════════════════════════════╗');
      print('║ 🔐 DEBUG DECIFRATURA REAL-TIME (ChatDetail → ChatDetail) ║');
      print('╚════════════════════════════════════════════════════════════╝');
      print('📨 Message ID: $messageId');
      print('👤 Sender ID: $senderId');
      print('👤 Current User ID: $_currentUserId');
      print('🔍 Is Me: $isMe');
      print('🔐 E2EManager.isEnabled: ${E2EManager.isEnabled}');
      print('📦 Metadata presente: ${metadata != null}');
      if (metadata != null) {
        print('📦 Metadata keys: ${metadata.keys.toList()}');
        print('📦 Metadata encrypted: ${metadata['encrypted']}');
        final ivStr = metadata['iv']?.toString() ?? '';
        final ivPreview = ivStr.length > 0 ? "presente (${ivStr.substring(0, ivStr.length > 20 ? 20 : ivStr.length)}${ivStr.length > 20 ? '...' : ''})" : "assente";
        print('📦 Metadata iv: $ivPreview');
        print('📦 Metadata mac: ${metadata['mac'] != null ? "presente" : "assente"}');
        print('📦 Metadata recipient_id: ${metadata['recipient_id']}');
      }
      print('🔐 isEncrypted: $isEncrypted');
      print('📝 Content length: ${content?.length ?? 0}');
      print('───────────────────────────────────────────────────────────');
      
      if (isEncrypted && E2EManager.isEnabled) {  // 🔐 FIX: Rimosso !isMe per decifrare anche messaggi inviati
        print('✅ CONDIZIONE SODDISFATTA: Procedo con decifratura');
        
        final iv = metadata?['iv'] as String?;
        final mac = metadata?['mac'] as String?;
        final recipientId = metadata?['recipient_id'] as String?;
        
        print('🔑 IV presente: ${iv != null}');
        print('🔑 MAC presente: ${mac != null}');
        print('🔑 Recipient ID presente: ${recipientId != null}');
        
        if (iv != null) {
          print('✅ IV disponibile, continuo decifratura...');
          try {
            final encryptedData = {
              'ciphertext': content,
              'iv': iv,
              if (mac != null) 'mac': mac,
            };
            
            // 🔐 FIX CRITICO: Per messaggi inviati da me, usa recipientId!
            // Per messaggi ricevuti, usa senderId
            String decryptionUserId;
            if (isMe && recipientId != null) {
              decryptionUserId = recipientId;
              print('🔐 MESSAGGIO INVIATO DA ME:');
              print('   → Uso recipientId = $recipientId per decifrare');
            } else if (isMe && recipientId == null) {
              print('⚠️  MESSAGGIO INVIATO DA ME MA recipientId MANCANTE!');
              print('   → Uso senderId = $senderId (potrebbe fallire)');
              decryptionUserId = senderId.toString();
            } else {
              decryptionUserId = senderId.toString();
              print('🔐 MESSAGGIO RICEVUTO:');
              print('   → Uso senderId = $senderId per decifrare');
            }
            
            print('🔓 Chiamata E2EManager.decryptMessage...');
            final decryptedText = await E2EManager.decryptMessage(
              decryptionUserId,
              encryptedData,
            );
            
            if (decryptedText != null) {
              messageContent = decryptedText;
              print('✅ ✅ ✅ DECIFRATURA RIUSCITA!');
              print('   Plaintext: ${decryptedText.substring(0, decryptedText.length > 50 ? 50 : decryptedText.length)}...');
            } else {
              messageContent = '...';  // ⚡ FIX: Non mostrare "Messaggio cifrato" per evitare flash
              print('❌ ❌ ❌ DECIFRATURA FALLITA: E2EManager ha restituito null');
            }
          } catch (e, stackTrace) {
            print('❌ ❌ ❌ ERRORE DURANTE DECIFRATURA:');
            print('   Errore: $e');
            print('   StackTrace: $stackTrace');
            messageContent = '...';  // ⚡ FIX: Non mostrare errore per evitare flash
          }
        } else {
          print('❌ IV NON DISPONIBILE - impossibile decifrare');
          messageContent = '...';  // ⚡ FIX: Non mostrare "IV mancante" per evitare flash
        }
      } else {
        if (!isEncrypted) {
          print('📝 Messaggio NON cifrato');
        } else if (!E2EManager.isEnabled) {
          print('⚠️  E2EE NON ABILITATO - messaggio rimane cifrato');
        }
      }
      print('═══════════════════════════════════════════════════════════');
      print('');
      
      print('📨   parsedMessageType: $parsedMessageType');
      print('📨   messageContent: $messageContent');
      
      final incomingMessage = MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: senderId ?? 'unknown',
        isMe: isMe,
        type: parsedMessageType,
        content: messageContent, // ← Ora è decifrato!
        time: TimezoneService.formatCallTime(timestamp != null ? DateTime.parse(timestamp) : now),
        timestamp: timestamp != null ? DateTime.parse(timestamp) : now,
        metadata: _createMetadataForMessageType(parsedMessageType, messageContent, data),
        isRead: shouldBeRead, // CORREZIONE: Solo se la chat destinatario è effettivamente visualizzata
      );

      // CORREZIONE: Usa il MessageService esistente invece di crearne uno nuovo
      if (_messageService == null) {
        print('❌ UnifiedRealtimeService - MessageService non impostato, impossibile aggiungere messaggio');
        return;
      }
      
      // ⚡ FIX: Aggiorna la lista chat SOLO se il messaggio è decifrato
      // NON aggiornare con placeholder "..." per evitare flash
      if (messageContent != '...' && 
          !messageContent.contains('[Messaggio cifrato]') && 
          !messageContent.contains('[Errore decifratura]')) {
        print('✅ UnifiedRealtimeService - Aggiorno chat list con messaggio decifrato');
        _updateChatList(chatId, messageContent);
      } else {
        print('⏸️ UnifiedRealtimeService - NON aggiorno chat list (messaggio non decifrato o placeholder)');
        print('   → Mantengo l\'ultimo messaggio valido nella lista');
      }
      
      _messageService!.addMessageToCache(chatId, incomingMessage, isRealtimeMessage: true);
      
      // CORREZIONE: Se la chat è attualmente visualizzata, aggiorna lo stato di lettura
      if (isCurrentlyViewing) {
        _messageService!.updateChatReadStatus(chatId);
        print('📨 UnifiedRealtimeService - Stato lettura aggiornato per chat visualizzata: $chatId');
      }
      
      // ✅ Aggiungi l'ID del messaggio alla cache per evitare duplicati SOLO DOPO il successo
      _processedMessageIds.add(messageId);
      
      print('');
      print('✅ ===== MESSAGGIO PROCESSATO CON SUCCESSO =====');
      print('✅ UnifiedRealtimeService - Messaggio aggiunto alla cache: $chatId');
      print('✅ MessageId aggiunto ai processati: $messageId');
      print('✅ Totale messaggi processati: ${_processedMessageIds.length}');
      print('✅ ============================================');
      print('');
      
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore gestione messaggio: $e');
      print('❌ MessageId NON aggiunto ai processati (verrà riprocessato): $messageId');
    }
  }

  /// Aggiorna la lista chat con il nuovo messaggio
  void _updateChatList(String chatId, String content) {
    try {
      if (_messageService == null) {
        print('❌ UnifiedRealtimeService - MessageService non impostato, impossibile aggiornare chat');
        return;
      }
      
      final unreadCount = _messageService!.getUnreadCount(chatId);
      
      // CORREZIONE: Aggiorna sia RealChatService che la cache del MessageService
      RealChatService.updateChatLastMessage(chatId, content, unreadCount);
      
      // Forza l'aggiornamento della home screen
      _messageService!.forceHomeScreenUpdate();
      
      print('📋 UnifiedRealtimeService - Chat aggiornata: $chatId ($unreadCount non letti)');
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore aggiornamento chat: $e');
    }
  }

  /// NUOVO: Gestisce le notifiche di eliminazione chat
  void _handleChatDeletionNotification(Map<String, dynamic> data) {
    try {
      print('🗑️ UnifiedRealtimeService - Notifica eliminazione chat ricevuta');
      print('🗑️ Dati: $data');
      
      final chatId = data['chat_id'];
      final requestingUserId = data['requesting_user_id'];
      final requestingUserName = data['requesting_user_name'];
      final expiresAt = data['expires_at'];
      
      if (chatId == null || requestingUserName == null) {
        print('❌ Dati mancanti nella notifica eliminazione');
        return;
      }
      
      // 1. Aggiorna la chat nella cache come in gestazione
      _updateChatToGestation(chatId, requestingUserId, requestingUserName, expiresAt);
      
      // 2. Mostra toast di notifica
      _showChatDeletionToast(requestingUserName, expiresAt);
      
      // 3. Forza refresh della home per mostrare l'icona timer
      _forceHomeRefresh();
      
    } catch (e) {
      print('❌ Errore gestione notifica eliminazione: $e');
    }
  }
  
  /// Aggiorna una chat per metterla in gestazione
  void _updateChatToGestation(String chatId, String? requestingUserId, String requestingUserName, String? expiresAt) {
    try {
      // Aggiorna la cache del RealChatService
      final cachedChats = RealChatService.cachedChats;
      final chatIndex = cachedChats.indexWhere((chat) => chat.id == chatId);
      
      if (chatIndex != -1) {
        final originalChat = cachedChats[chatIndex];
        final updatedChat = originalChat.copyWith(
          isInGestation: true,
          deletionRequestedBy: requestingUserId,
          deletionRequestedByName: requestingUserName,
          gestationExpiresAt: expiresAt != null ? DateTime.tryParse(expiresAt) : null,
          isReadOnly: true,
        );
        
        cachedChats[chatIndex] = updatedChat;
        print('✅ Chat $chatId aggiornata in gestazione nella cache');
        
        // Notifica i widget che i dati sono cambiati
        RealChatService.notifyWidgets();
      } else {
        print('⚠️ Chat $chatId non trovata nella cache per aggiornamento gestazione');
      }
    } catch (e) {
      print('❌ Errore aggiornamento chat in gestazione: $e');
    }
  }
  
  /// Mostra toast di notifica eliminazione chat
  void _showChatDeletionToast(String requestingUserName, String? expiresAt) {
    print('🍞 UnifiedRealtimeService - Mostra toast eliminazione chat');
    
    // Invia evento globale per mostrare il toast nella home
    _broadcastChatDeletionEvent(requestingUserName, expiresAt);
  }
  
  // Stream controller per eventi globali
  static final StreamController<Map<String, dynamic>> _globalEventsController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream per ascoltare eventi globali
  static Stream<Map<String, dynamic>> get globalEvents => _globalEventsController.stream;
  
  /// Invia evento globale di eliminazione chat
  void _broadcastChatDeletionEvent(String requestingUserName, String? expiresAt) {
    final event = {
      'type': 'chat_deletion_notification',
      'requesting_user_name': requestingUserName,
      'expires_at': expiresAt,
      'message': '$requestingUserName ha eliminato la chat. Andrà eliminata automaticamente entro 7 giorni.',
    };
    
    _globalEventsController.add(event);
    print('📡 Evento eliminazione chat inviato: $event');
  }
  
  /// Forza refresh della home per aggiornare le icone
  void _forceHomeRefresh() {
    // Notifica il RealChatService che i dati sono cambiati
    RealChatService.notifyWidgets();
    print('🔄 Home refresh forzato per aggiornare icone timer');
  }

  /// Fallback: Carica i messaggi dal backend quando il server di notifiche non risponde
  Future<void> _fallbackLoadMessages() async {
    try {
      print('🔄 UnifiedRealtimeService - Fallback: caricamento messaggi dal backend');
      
      if (_messageService == null) {
        print('❌ UnifiedRealtimeService - MessageService non impostato, impossibile caricare messaggi');
        return;
      }
      
      // Carica i messaggi per tutte le chat
      final chats = RealChatService.cachedChats;
      
      for (final chat in chats) {
        try {
          final messages = await _messageService!.getChatMessages(chat.id);
          if (messages.isNotEmpty) {
            // Aggiorna la chat con l'ultimo messaggio
            final lastMessage = messages.last;
            _updateChatList(chat.id, lastMessage.content);
          }
        } catch (e) {
          print('❌ UnifiedRealtimeService - Errore fallback per chat ${chat.id}: $e');
        }
      }
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore fallback: $e');
    }
  }

  /// Invia una notifica push
  Future<void> sendPushNotification({
    required String recipientId,
    required String chatId,
    required String messageId,
    required String content,
    required String messageType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // CORREZIONE: Controlla se la notifica è già stata inviata per evitare duplicati
      final notificationKey = '${messageId}_${recipientId}';
      if (_sentNotificationIds.contains(notificationKey)) {
        print('⚠️ UnifiedRealtimeService - Notifica già inviata, skip: $notificationKey');
        return;
      }

      print('📤 UnifiedRealtimeService - Invio notifica:');
      print('📤   Recipient ID: $recipientId');
      print('📤   Chat ID: $chatId');
      print('📤   Message ID: $messageId');
      print('📤   Content: $content');
      print('📤   Message Type: $messageType');
      
      final senderName = await _getSenderName();
      final notificationBody = _getNotificationBodyForMessageType(messageType, content);
      
      // CORREZIONE: Crea il payload base con tipo corretto
      final Map<String, dynamic> baseData = {
        'chat_id': chatId,
        'message_id': messageId,
        'content': content,
        'message_type': messageType,
        'sender_name': senderName,
      };
      
      // CORREZIONE: Aggiungi dati aggiuntivi se presenti (come imageUrl, videoUrl, etc.)
      if (additionalData != null) {
        baseData.addAll(additionalData);
        print('📤 UnifiedRealtimeService - Dati aggiuntivi aggiunti al payload: $additionalData');
      }
      
      // 🔐 E2EE: Cifra la notifica prima di inviarla
      Map<String, dynamic> payload;
      
      if (E2EManager.isEnabled) {
        print('🔐 UnifiedRealtimeService - Cifratura notifica per E2EE');
        
        // Crea il payload sensibile da cifrare
        final sensitiveData = {
          'title': 'Nuovo messaggio da $senderName',
          'body': notificationBody,
          'sender_name': senderName,
          'data': baseData,
        };
        
        // Cifra il payload
        final encrypted = await E2EManager.encryptMessage(
          recipientId,
          jsonEncode(sensitiveData),
        );
        
        if (encrypted != null) {
          // Invia notifica cifrata con placeholder generico
          payload = {
            'recipient_id': recipientId,
            'title': '🔐 Nuovo messaggio',  // Placeholder generico
            'body': 'Hai ricevuto un nuovo messaggio',  // Placeholder generico
            'data': {
              'encrypted': true,
            },
            'sender_id': _currentUserId ?? 'unknown',
            'timestamp': DateTime.now().toIso8601String(),
            'notification_type': 'message',
            'encrypted': true,
            'encrypted_payload': encrypted,
          };
          print('🔐 UnifiedRealtimeService - ✅ Notifica cifrata con successo');
        } else {
          // Fallback: invia in chiaro se cifratura fallisce
          print('⚠️  UnifiedRealtimeService - Cifratura fallita, invio in chiaro');
          payload = {
            'recipient_id': recipientId,
            'title': 'Nuovo messaggio da $senderName',
            'body': notificationBody,
            'data': baseData,
            'sender_id': _currentUserId ?? 'unknown',
            'timestamp': DateTime.now().toIso8601String(),
            'notification_type': 'message',
          };
        }
      } else {
        // E2EE disabilitato: invia in chiaro (legacy)
        payload = {
          'recipient_id': recipientId,
          'title': 'Nuovo messaggio da $senderName',
          'body': notificationBody,
          'data': baseData,
          'sender_id': _currentUserId ?? 'unknown',
          'timestamp': DateTime.now().toIso8601String(),
          'notification_type': 'message',
        };
      }
      
      final response = await http.post(
        Uri.parse('$notifyServerUrl/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('📤 UnifiedRealtimeService - Risposta server: ${response.statusCode}');
      print('📤 UnifiedRealtimeService - Body: ${response.body}');

      if (response.statusCode == 200) {
        // Aggiungi la notifica alla cache per evitare duplicati
        _sentNotificationIds.add(notificationKey);
        print('✅ UnifiedRealtimeService - Notifica inviata con successo');
      } else {
        print('❌ UnifiedRealtimeService - Errore invio: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore invio notifica: $e');
    }
  }

  /// Ottiene il nome del mittente
  Future<String> _getSenderName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('securevox_current_user');
      if (userJson != null) {
        final user = jsonDecode(userJson);
        return user['name'] ?? 'Unknown';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  /// Converte il tipo di messaggio
  MessageType _parseMessageType(String type) {
    print('🚨 DEBUG _parseMessageType - Input: "$type"');
    switch (type.toLowerCase()) {
      case 'text':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.text');
        return MessageType.text;
      case 'image':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.image');
        return MessageType.image;
      case 'audio':
      case 'voice':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.voice');
        return MessageType.voice;
      case 'video':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.video');
        return MessageType.video;
      case 'file':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.file ✅');
        return MessageType.file; // CORREZIONE: file → MessageType.file
      case 'attachment':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.attachment');
        return MessageType.attachment;
      case 'location':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.location');
        return MessageType.location;
      case 'contact':
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.contact');
        return MessageType.contact;
      default:
        print('🚨 DEBUG _parseMessageType - Risultato: MessageType.text (DEFAULT)');
        return MessageType.text;
    }
  }

  /// Formatta il tempo
  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays}g fa';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h fa';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m fa';
      } else {
        return 'Ora';
      }
    } catch (e) {
      return 'Ora';
    }
  }

  /// Pulisce la cache dei messaggi processati (mantiene solo gli ultimi 1000)
  void _cleanupProcessedMessageIds() {
    if (_processedMessageIds.length > 1000) {
      final idsToRemove = _processedMessageIds.take(_processedMessageIds.length - 1000).toList();
      for (final id in idsToRemove) {
        _processedMessageIds.remove(id);
      }
      print('🧹 UnifiedRealtimeService - Cache messaggi processati pulita: ${idsToRemove.length} ID rimossi');
    }
  }

  /// Pulisce la cache delle notifiche inviate (mantiene solo gli ultimi 1000)
  void _cleanupSentNotificationIds() {
    if (_sentNotificationIds.length > 1000) {
      final idsToRemove = _sentNotificationIds.take(_sentNotificationIds.length - 1000).toList();
      for (final id in idsToRemove) {
        _sentNotificationIds.remove(id);
      }
      print('🧹 UnifiedRealtimeService - Cache notifiche inviate pulita: ${idsToRemove.length} ID rimossi');
    }
  }

  /// Crea il corpo della notifica appropriato per il tipo di messaggio
  String _getNotificationBodyForMessageType(String messageType, String content) {
    switch (messageType.toLowerCase()) {
      case 'text':
        return content.isNotEmpty ? content : 'Nuovo messaggio di testo';
        
      case 'image':
        return content.isNotEmpty ? '📷 Immagine: $content' : '📷 Immagine';
        
      case 'video':
        return content.isNotEmpty ? '🎥 Video: $content' : '🎥 Video';
        
      case 'audio':
      case 'voice':
        return '🎤 Audio';
        
      case 'file':
      case 'attachment':
        return '📎 Documento';
        
      case 'location':
        return '📍 Posizione';
        
      case 'contact':
        return '👤 Contatto';
        
      default:
        return content.isNotEmpty ? content : 'Nuovo messaggio';
    }
  }

  /// Crea i metadati appropriati per il tipo di messaggio
  Map<String, dynamic> _createMetadataForMessageType(MessageType messageType, String content, Map<String, dynamic> data) {
    switch (messageType) {
      case MessageType.text:
        return TextMessageData(text: content).toJson();
        
      case MessageType.image:
        // CORREZIONE: Debug dei dati ricevuti per le immagini
        print('🖼️ UnifiedRealtimeService._createMetadataForMessageType - DEBUG IMAGE:');
        print('🖼️   data keys: ${data.keys}');
        print('🖼️   data values: $data');
        print('🖼️   image_url: ${data['image_url']}');
        print('🖼️   imageUrl: ${data['imageUrl']}');
        print('🖼️   content: $content');
        print('🖼️   metadata: ${data['metadata']}');
        
        final imageUrl = data['image_url'] ?? data['imageUrl'] ?? '';
        print('🖼️   URL finale estratto: $imageUrl');
        
        // 🔐 Estrai i metadata di cifratura se presenti
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        print('🔐 UnifiedRealtimeService - Metadata cifratura immagine:');
        print('🔐   iv: ${metadata['iv']}');
        print('🔐   mac: ${metadata['mac']}');
        print('🔐   encrypted: ${metadata['encrypted']}');
        
        // Crea i metadata dell'immagine includendo i dati di cifratura
        final imageMetadata = {
          'imageUrl': imageUrl,
          'caption': data['caption'] ?? content,
          // 🔐 Includi i metadata di cifratura
          if (metadata['iv'] != null) 'iv': metadata['iv'],
          if (metadata['mac'] != null) 'mac': metadata['mac'],
          if (metadata['encrypted'] != null) 'encrypted': metadata['encrypted'],
          if (metadata['original_size'] != null) 'original_size': metadata['original_size'],
        };
        
        print('🔐   Metadata finali per ImageMessageData: $imageMetadata');
        
        return imageMetadata;
        
      case MessageType.video:
        print('');
        print('🎥 ===== CREAZIONE METADATA VIDEO REAL-TIME =====');
        print('🎥 data keys: ${data.keys.toList()}');
        print('🎥 data completo: $data');
        print('🎥 video_url: ${data['video_url']}');
        print('🎥 videoUrl: ${data['videoUrl']}');
        print('🎥 thumbnail_url: ${data['thumbnail_url']}');
        print('🎥 thumbnailUrl: ${data['thumbnailUrl']}');
        print('🎥 metadata in data: ${data['metadata']}');
        
        final videoUrl = data['video_url'] ?? data['videoUrl'] ?? '';
        final thumbnailUrl = data['thumbnail_url'] ?? data['thumbnailUrl'] ?? '';
        print('🎥 Video URL finale: $videoUrl');
        print('🎥 Thumbnail URL finale: $thumbnailUrl');
        
        // 🔐 FIX CRITICO: Estrai i metadata di cifratura da più possibili posizioni
        Map<String, dynamic> metadata = {};
        
        // Prova prima da data['metadata']
        if (data['metadata'] != null && data['metadata'] is Map) {
          metadata = Map<String, dynamic>.from(data['metadata'] as Map);
          print('🔐 Metadata trovati in data[\'metadata\']: ${metadata.keys.toList()}');
        }
        
        // 🔐 FALLBACK: Se non trovati, prova direttamente da data (per notifiche E2EE)
        if ((metadata['iv'] == null || metadata['mac'] == null) && data['iv'] != null) {
          print('🔐 FALLBACK: Metadata trovati direttamente in data (notifica E2EE)');
          metadata['iv'] = data['iv'];
          metadata['mac'] = data['mac'];
          metadata['encrypted'] = data['encrypted'];
          if (data['original_size'] != null) metadata['original_size'] = data['original_size'];
          if (data['original_file_name'] != null) metadata['original_file_name'] = data['original_file_name'];
          if (data['original_file_extension'] != null) metadata['original_file_extension'] = data['original_file_extension'];
          if (data['local_file_name'] != null) metadata['local_file_name'] = data['local_file_name'];
        }
        
        print('🔐 Metadata cifratura video estratti:');
        print('🔐   iv presente: ${metadata['iv'] != null}');
        print('🔐   mac presente: ${metadata['mac'] != null}');
        print('🔐   encrypted: ${metadata['encrypted']}');
        print('🔐   original_size: ${metadata['original_size']}');
        print('🔐   original_file_name: ${metadata['original_file_name']}');
        print('🔐   original_file_extension: ${metadata['original_file_extension']}');
        print('🔐   local_file_name: ${metadata['local_file_name']}');

        final videoMetadata = <String, dynamic>{
          'videoUrl': videoUrl,
          'thumbnailUrl': thumbnailUrl,
          'caption': data['caption'] ?? content,
          // 🔐 CRITICO: Includi TUTTI i metadata cifratura se presenti
          if (metadata['iv'] != null) 'iv': metadata['iv'],
          if (metadata['mac'] != null) 'mac': metadata['mac'],
          if (metadata['encrypted'] != null) 'encrypted': metadata['encrypted'],
          if (metadata['original_size'] != null) 'original_size': metadata['original_size'],
          if (metadata['original_file_name'] != null) 'original_file_name': metadata['original_file_name'],
          if (metadata['original_file_extension'] != null) 'original_file_extension': metadata['original_file_extension'],
          if (metadata['local_file_name'] != null) 'local_file_name': metadata['local_file_name'],
        };

        print('🎥 Metadata finali per VideoMessageData:');
        print('🎥   keys: ${videoMetadata.keys.toList()}');
        print('🎥   videoUrl: ${videoMetadata['videoUrl']}');
        print('🎥   🔐 iv presente: ${videoMetadata['iv'] != null}');
        print('🎥   🔐 mac presente: ${videoMetadata['mac'] != null}');
        print('🎥   🔐 encrypted: ${videoMetadata['encrypted']}');
        print('🎥   🔐 local_file_name: ${videoMetadata['local_file_name']}');
        print('🎥 ================================================');
        print('');
        return videoMetadata;
        
      case MessageType.voice:
        // CORREZIONE: Debug dei dati ricevuti per l'audio
        print('🎤 UnifiedRealtimeService._createMetadataForMessageType - DEBUG AUDIO:');
        print('🎤   data keys: ${data.keys}');
        print('🎤   audio_url: ${data['audio_url']}');
        print('🎤   audioUrl: ${data['audioUrl']}');
        print('🎤   duration: ${data['duration']}');
        
        final audioUrl = data['audio_url'] ?? data['audioUrl'] ?? '';
        final duration = data['duration']?.toString() ?? '0';
        print('🎤   Audio URL finale: $audioUrl');
        print('🎤   Duration finale: $duration');
        
        return VoiceMessageData(
          duration: duration,
          audioUrl: audioUrl,
        ).toJson();
        
      case MessageType.attachment:
      case MessageType.file:
        // CORREZIONE: Debug dei dati ricevuti per i file
        print('📎 UnifiedRealtimeService._createMetadataForMessageType - DEBUG FILE:');
        print('📎   data keys: ${data.keys}');
        print('📎   file_url: ${data['file_url']}');
        print('📎   fileUrl: ${data['fileUrl']}');
        print('📎   file_name: ${data['file_name']}');
        print('📎   fileName: ${data['fileName']}');
        print('📎   metadata: ${data['metadata']}');
        
        // CORREZIONE: Usa PRIMA i metadati da 'metadata' che sono completi
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final fileUrl = metadata['file_url'] ?? data['file_url'] ?? data['fileUrl'] ?? '';
        final fileName = metadata['file_name'] ?? data['file_name'] ?? data['fileName'] ?? 'Documento';
        final fileType = metadata['file_type'] ?? metadata['mime_type'] ?? data['file_type'] ?? data['fileType'] ?? 'application/pdf';
        final fileSize = int.tryParse(metadata['file_size']?.toString() ?? data['file_size']?.toString() ?? data['fileSize']?.toString() ?? '0') ?? 0;
        final fileExtension = metadata['file_extension'] ?? data['file_extension'] ?? data['fileExtension'] ?? '';
        
        // NUOVO: Estrai pdfPreviewUrl per documenti Office
        final pdfPreviewUrl = metadata['pdfPreviewUrl']?.toString() ?? 
                             metadata['pdf_preview_url']?.toString() ?? 
                             data['pdfPreviewUrl']?.toString() ?? 
                             data['pdf_preview_url']?.toString() ?? '';
        
        print('📎   File URL finale: $fileUrl');
        print('📎   File Name finale: $fileName');
        print('📎   File Type finale: $fileType');
        print('📎   File Size finale: $fileSize');
        print('📎   File Extension finale: $fileExtension');
        print('📎   PDF Preview URL finale: $pdfPreviewUrl');
        
        final fileMetadata = {
          'file_url': fileUrl,
          'file_name': fileName,
          'file_type': fileType,
          'file_size': fileSize,
          'file_extension': fileExtension,
          'mime_type': fileType,
        };
        
        // CORREZIONE CRITICA: Aggiungi pdfPreviewUrl se presente
        if (pdfPreviewUrl.isNotEmpty) {
          fileMetadata['pdfPreviewUrl'] = pdfPreviewUrl;
          fileMetadata['pdf_preview_url'] = pdfPreviewUrl;
        }
        
        return fileMetadata;
        
      case MessageType.location:
        // CORREZIONE: Debug dei dati ricevuti per la posizione
        print('📍 UnifiedRealtimeService._createMetadataForMessageType - DEBUG LOCATION:');
        print('📍   data keys: ${data.keys}');
        print('📍   latitude: ${data['latitude']}');
        print('📍   longitude: ${data['longitude']}');
        print('📍   address: ${data['address']}');
        
        final latitude = double.tryParse(data['latitude']?.toString() ?? '0') ?? 0.0;
        final longitude = double.tryParse(data['longitude']?.toString() ?? '0') ?? 0.0;
        final address = data['address']?.toString() ?? '';
        final city = data['city']?.toString() ?? '';
        final country = data['country']?.toString() ?? '';
        
        print('📍   Latitude finale: $latitude');
        print('📍   Longitude finale: $longitude');
        print('📍   Address finale: $address');
        
        return LocationMessageData(
          latitude: latitude,
          longitude: longitude,
          address: address,
          city: city,
          country: country,
        ).toJson();
        
      case MessageType.contact:
        // CORREZIONE: Debug dei dati ricevuti per i contatti
        print('👤 UnifiedRealtimeService._createMetadataForMessageType - DEBUG CONTACT:');
        print('👤   data keys: ${data.keys}');
        print('👤   contact_name: ${data['contact_name']}');
        print('👤   phone: ${data['phone']}');
        print('👤   email: ${data['email']}');
        
        final contactName = data['contact_name']?.toString() ?? '';
        final phone = data['phone']?.toString() ?? '';
        final email = data['email']?.toString() ?? '';
        final organization = data['organization']?.toString() ?? '';
        
        print('👤   Contact Name finale: $contactName');
        print('👤   Phone finale: $phone');
        
        return ContactMessageData(
          name: contactName,
          phone: phone,
          email: email,
          organization: organization,
        ).toJson();
        
      default:
        return TextMessageData(text: content).toJson();
    }
  }

  /// WORKAROUND: Monitoraggio chat per rilevare nuove gestazioni
  void _startChatMonitoring() {
    if (_chatMonitorTimer != null) {
      _chatMonitorTimer!.cancel();
    }
    
    print('👀 UnifiedRealtimeService - Avvio monitoraggio chat per gestazioni');
    
    _chatMonitorTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        await _checkForNewGestations();
      } catch (e) {
        print('❌ UnifiedRealtimeService - Errore monitoraggio chat: $e');
      }
    });
  }
  
  /// Controlla se ci sono nuove chat in gestazione
  Future<void> _checkForNewGestations() async {
    try {
      // FORZA refresh della cache per rilevare gestazioni
      await RealChatService.getRealChats();
      
      // Ottieni le chat correnti dal RealChatService
      final chats = RealChatService.cachedChats;
      
      for (final chat in chats) {
        final chatId = chat.id;
        final isCurrentlyInGestation = chat.isInGestation;
        final wasInGestation = _lastGestationState[chatId] ?? false;
        
        // Se la chat è appena entrata in gestazione E la notifica non è già stata mostrata
        if (isCurrentlyInGestation && !wasInGestation && !chat.gestationNotificationShown) {
          print('🚨 Nuova gestazione: ${chat.name}');
          
          // Simula notifica di eliminazione chat
          await _simulateGestationNotification(chat);
          
          // Aggiorna la cache delle icone timer
          RealChatService.updateTimerCache(chatId, true);
          
          // Marca come notificata nel server
          await _markNotificationAsSeen(chatId);
          
          print('✅ Gestazione ${chatId} - notifica mostrata e marcata nel server');
        } else if (isCurrentlyInGestation && chat.gestationNotificationShown) {
          print('⏭️ Gestazione ${chatId} - notifica già mostrata, skip');
        }
        
        // Aggiorna lo stato
        _lastGestationState[chatId] = isCurrentlyInGestation;
      }
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore controllo gestazioni: $e');
    }
  }
  
  /// Marca la notifica come vista nel server
  Future<void> _markNotificationAsSeen(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        print('❌ Token non disponibile per marcare notifica');
        return;
      }
      
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8001/api/chats/$chatId/mark-notification-seen/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        print('✅ Notifica marcata come vista nel server per $chatId');
      } else {
        print('❌ Errore marcatura notifica: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Errore chiamata server per marcatura notifica: $e');
    }
  }

  /// Simula una notifica di gestazione
  Future<void> _simulateGestationNotification(ChatModel chat) async {
    try {
      // Crea una notifica simulata
      final simulatedNotification = {
        'notification_type': 'chat_deletion_request',
        'chat_id': chat.id,
        'requesting_user_name': chat.deletionRequestedByName ?? 'Altro utente',
        'title': '${chat.deletionRequestedByName ?? 'Altro utente'} ha eliminato la chat',
        'body': 'Vuoi eliminare definitivamente la chat o mantenerla per 7 giorni?',
      };
      
      print('📢 UnifiedRealtimeService - Simulazione notifica gestazione: $simulatedNotification');
      
      // Processa come se fosse arrivata dal server notify
      _handleChatDeletionNotification(simulatedNotification);
      
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore simulazione notifica: $e');
    }
  }

  /// 🔐 REALTIME: Avvia il polling dello stato di crittografia per tutte le chat attive
  void _startEncryptionStatusPolling() {
    if (_encryptionStatusTimer != null) {
      _encryptionStatusTimer!.cancel();
    }
    
    print('🔐 UnifiedRealtimeService - Avvio polling stato crittografia');
    
    // Polling ogni 3 secondi per stato crittografia (molto frequente per realtime)
    _encryptionStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        await _checkEncryptionStatusForAllChats();
      } catch (e) {
        // 🚫 Gestisci errori silenziosamente - potrebbero essere problemi di rete temporanei
        // Solo logga se è un errore critico (non errori di rete)
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('Connection refused')) {
          // Errore di rete: silenzioso per non disturbare l'utente
        } else {
          print('⚠️ UnifiedRealtimeService - Errore polling stato crittografia: $e');
        }
      }
    });
  }
  
  /// 🔐 REALTIME: Verifica lo stato di crittografia per tutte le chat attive
  Future<void> _checkEncryptionStatusForAllChats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        // 🚫 NON loggare come errore - è normale quando l'utente non è ancora loggato
        return;
      }
      
      // Ottieni tutte le chat attive dalla cache
      final chats = RealChatService.cachedChats;
      
      if (chats.isEmpty) {
        return; // Nessuna chat da verificare
      }
      
      // Verifica lo stato per ogni chat
      print('🔐 UnifiedRealtimeService - Inizio polling stato crittografia per ${chats.length} chat(s)');
      
      for (final chat in chats) {
        try {
          final response = await http.get(
            Uri.parse('http://127.0.0.1:8001/api/chats/${chat.id}/encryption-status/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
          );
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            // 🔐 REALTIME: Gestisci null per campo booleano (cast sicuro)
            final isEncrypted = (data['is_encrypted'] as bool?) ?? true; // Default: cifrata
            
            // 🔐 DEBUG: Log dettagliato per tracciare il polling
            print('');
            print('🔐 ===== POLLING STATO CRITTOGRAFIA CHAT =====');
            print('🔐 Chat ID: ${chat.id}');
            print('🔐 Chat Name: ${chat.name}');
            print('🔐 Response from server:');
            print('   • is_encrypted: $isEncrypted');
            print('   • participants_status: ${data['participants_status']}');
            print('   • timestamp: ${data['timestamp']}');
            
            // 🔐 REALTIME: Aggiorna sempre lo stato, anche se non è cambiato (per sincronizzazione)
            final lastStatus = _lastEncryptionStatus[chat.id];
            final chatIndex = RealChatService.cachedChats.indexWhere((c) => c.id == chat.id);
            
            if (chatIndex != -1) {
              final currentChat = RealChatService.cachedChats[chatIndex];
              final currentState = currentChat.isEncrypted;
              final needsUpdate = currentState != isEncrypted;
              
              print('🔐 Stato corrente nella cache:');
              print('   • currentChat.isEncrypted: $currentState');
              print('   • lastStatus (memoria): $lastStatus');
              print('   • nuovo isEncrypted dal server: $isEncrypted');
              print('   • needsUpdate: $needsUpdate');
              
              if (needsUpdate || lastStatus == null) {
                if (lastStatus != null && lastStatus != isEncrypted) {
                  print('');
                  print('⚠️⚠️⚠️ CAMBIO STATO CRITTOGRAFIA RILEVATO! ⚠️⚠️⚠️');
                  print('🔐 Chat: ${chat.name} (${chat.id})');
                  print('🔐 Stato precedente: $lastStatus');
                  print('🔐 Nuovo stato: $isEncrypted');
                  print('🔐 Azione: ${isEncrypted ? "CRITTOTAGGIO ABILITATO" : "CRITTOTAGGIO DISABILITATO"}');
                  print('⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️⚠️');
                  print('');
                } else if (lastStatus == null) {
                  print('🔐 UnifiedRealtimeService - Stato crittografia inizializzato per chat ${chat.id}: isEncrypted=$isEncrypted');
                }
                
                // Aggiorna la chat nella cache
                final updatedChat = currentChat.copyWith(
                  isEncrypted: isEncrypted,
                );
                RealChatService.cachedChats[chatIndex] = updatedChat;
                
                print('🔐 Cache aggiornata:');
                print('   • RealChatService.cachedChats[$chatIndex].isEncrypted = ${updatedChat.isEncrypted}');
                
                // 🔐 REALTIME: Invalida SOLO cache media quando cambia lo stato di cifratura
                // CORREZIONE BUG 1: Non invalidare tutta la cache per evitare ricaricamento video vecchi
                // Invalida solo media (video/immagini/file) mantenendo messaggi di testo
                try {
                  final messageService = MessageService();
                  messageService.invalidateMediaCacheForChat(chat.id);
                  
                  // 🔐 CORREZIONE BUG VIDEO UGUALI: Invalida anche il mapping videoUrl -> local_file_name
                  // Questo previene che video vecchi vengano caricati usando il mapping errato
                  final mediaService = MediaService();
                  await mediaService.clearVideoCacheMapping();
                  
                  print('🔐 Cache media e mapping video invalidati per chat ${chat.id}');
                } catch (e) {
                  print('⚠️ Errore invalidazione cache media: $e');
                }
                
                // Notifica i widget che lo stato è cambiato
                RealChatService.notifyWidgets();
                notifyListeners();
                
                print('🔐 Notifiche inviate:');
                print('   • RealChatService.notifyWidgets() chiamato');
                print('   • UnifiedRealtimeService.notifyListeners() chiamato');
                print('   • Cache messaggi invalidata');
                print('✅ UnifiedRealtimeService - Chat ${chat.id} aggiornata: isEncrypted=$isEncrypted');
                print('🔐 =======================================');
                print('');
              } else {
                print('🔐 Nessun cambio rilevato - stato invariato');
                print('🔐 =======================================');
                print('');
              }
            } else {
              print('⚠️ Chat ${chat.id} non trovata nella cache!');
              print('🔐 =======================================');
              print('');
            }
            
            // Aggiorna lo stato memorizzato
            _lastEncryptionStatus[chat.id] = isEncrypted;
            
          } else if (response.statusCode == 401 || response.statusCode == 403) {
            // Token non valido: silenzioso (utente potrebbe non essere ancora loggato)
          } else if (response.statusCode >= 500) {
            // Errore server: silenzioso per non disturbare l'utente
          }
          // Altri errori: silenziosi
        } catch (e) {
          // 🚫 Gestisci errori silenziosamente - potrebbero essere problemi di rete temporanei
          if (e.toString().contains('SocketException') || 
              e.toString().contains('Failed host lookup') ||
              e.toString().contains('Connection refused')) {
            // Errore di rete: silenzioso
          } else {
            // Altri errori: logga solo se critico
            print('⚠️ UnifiedRealtimeService - Errore verifica stato crittografia per chat ${chat.id}: $e');
          }
        }
      }
    } catch (e) {
      // 🚫 Gestisci errori silenziosamente - potrebbero essere problemi di rete temporanei
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Failed host lookup') ||
          e.toString().contains('Connection refused')) {
        // Errore di rete: silenzioso
      } else {
        print('⚠️ UnifiedRealtimeService - Errore generale polling stato crittografia: $e');
      }
    }
  }

  /// 🚫 REALTIME: Avvia il polling dello stato utente (bloccato/disabilitato)
  /// Funziona sia durante la sessione che dopo il logout (quando c'è un username salvato)
  void _startUserStatusPolling() {
    if (_userStatusTimer != null) {
      _userStatusTimer!.cancel();
    }
    
    print('🚫 UnifiedRealtimeService - Avvio polling stato utente');
    
    // Polling ogni 3 secondi per stato utente (stessa frequenza del polling crittografia)
    _userStatusTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        // 🚫 REALTIME: Continua il polling anche senza token se abbiamo un username salvato
        await _checkUserStatus();
      } catch (e) {
        print('❌ UnifiedRealtimeService - Errore polling stato utente: $e');
      }
    });
  }
  
  /// 🚫 REALTIME: Verifica lo stato dell'utente corrente (se è bloccato/disabilitato)
  /// Funziona sia con token (utente loggato) che senza (utente bloccato che deve verificare)
  Future<void> _checkUserStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      // Ottieni l'username (sia da token che da SharedPreferences)
      String? username;
      if (_lastUsername != null) {
        username = _lastUsername;
      } else {
        // Prova a ottenere l'username dall'utente salvato
        final userJson = prefs.getString('securevox_current_user');
        if (userJson != null) {
          try {
            final userData = jsonDecode(userJson);
            username = userData['username']?.toString();
            _lastUsername = username;
          } catch (e) {
            print('⚠️ UnifiedRealtimeService - Errore parsing user JSON: $e');
          }
        }
      }
      
      http.Response response;
      
      try {
        if (token != null && username == null) {
          // Utente loggato: usa endpoint con autenticazione
          response = await http.get(
            Uri.parse('http://127.0.0.1:8001/api/users/my-status/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
          ).timeout(const Duration(seconds: 5)); // Timeout per evitare attese infinite
        } else if (username != null) {
          // Utente non loggato o bloccato: usa endpoint senza autenticazione
          response = await http.get(
            Uri.parse('http://127.0.0.1:8001/api/users/status-by-username/?username=$username'),
            headers: {
              'Content-Type': 'application/json',
            },
          ).timeout(const Duration(seconds: 5)); // Timeout per evitare attese infinite
        } else {
          // Nessun username e nessun token: non possiamo verificare
          // 🚫 NON loggare come errore - è normale quando l'utente non è ancora loggato
          return;
        }
      } catch (e) {
        // 🚫 Gestisci errori di connessione silenziosamente
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('Connection refused') ||
            e.toString().contains('TimeoutException')) {
          // Errore di rete o timeout: silenzioso (non mostrare all'utente)
          return;
        }
        // Rilancia altri errori per gestirli nel catch principale
        rethrow;
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 🚫 REALTIME: Gestisci null per campi booleani (cast sicuro)
        final isActive = (data['is_active'] as bool?) ?? true; // Default: attivo
        final isBlocked = (data['is_blocked'] as bool?) ?? false; // Default: non bloccato
        final message = (data['message'] as String?) ?? 'Utente attivo';
        
        // Salva l'username per polling futuro (anche dopo logout)
        if (data['username'] != null) {
          _lastUsername = data['username'] as String;
        }
        
        // Controlla se lo stato è cambiato
        if (_lastUserStatus != null && _lastUserStatus! && !isActive) {
          // L'utente è stato appena bloccato!
          print('🚫 UnifiedRealtimeService - ⚠️ UTENTE BLOCCATO!');
          print('   Stato precedente: attivo');
          print('   Stato corrente: bloccato');
          print('   Messaggio: $message');
          
          // 🚫 CRITICO: Forza logout immediato quando l'utente viene bloccato
          _forceLogoutDueToBlock(message);
          
          // Invia anche evento globale per mostrare il toast (prima del logout)
          _broadcastUserBlockedEvent(message);
        } else if (_lastUserStatus != null && !_lastUserStatus! && isActive) {
          // 🎉 L'utente è stato appena SBLOCCATO!
          print('✅ UnifiedRealtimeService - ⚠️ UTENTE SBLOCCATO!');
          print('   Stato precedente: bloccato');
          print('   Stato corrente: attivo');
          print('   Messaggio: $message');
          
          // Invia evento globale per notificare che l'utente può rifare login
          _broadcastUserUnblockedEvent(message);
        }
        
        // Aggiorna lo stato memorizzato
        _lastUserStatus = isActive;
        
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Token non valido o utente non autorizzato - probabilmente bloccato
        print('🚫 UnifiedRealtimeService - Token non valido o utente bloccato (${response.statusCode})');
        if (_lastUserStatus != null && _lastUserStatus!) {
          // L'utente era attivo prima e ora il token non funziona più
          print('🚫 UnifiedRealtimeService - ⚠️ UTENTE BLOCCATO (token non valido)!');
          
          // 🚫 CRITICO: Forza logout immediato quando il token non è più valido (utente bloccato)
          _forceLogoutDueToBlock('Utente disabilitato temporaneamente');
          
          _broadcastUserBlockedEvent('Utente disabilitato temporaneamente');
          _lastUserStatus = false;
        }
      }
    } catch (e) {
      // 🚫 NON loggare come errore critico se l'utente non è ancora loggato
      // Solo logga se c'era un token/username disponibile (significa che era un errore reale)
      if (_currentUserId != null || _lastUsername != null) {
        print('⚠️ UnifiedRealtimeService - Errore verifica stato utente (utente loggato/bloccato): $e');
      } else {
        // Utente non loggato: è normale che il polling fallisca silenziosamente
        // Non loggare per evitare messaggi di errore confusi nella login screen
      }
    }
  }
  
  /// 🚫 REALTIME: Invia evento globale di utente bloccato
  void _broadcastUserBlockedEvent(String message) {
    final event = {
      'type': 'user_blocked',
      'message': message,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _globalEventsController.add(event);
    print('📡 UnifiedRealtimeService - Evento utente bloccato inviato: $event');
  }
  
  /// 🚫 REALTIME: Forza logout quando l'utente viene bloccato
  Future<void> _forceLogoutDueToBlock(String reason) async {
    try {
      print('🚫 UnifiedRealtimeService - FORZANDO LOGOUT per utente bloccato');
      print('   Motivo: $reason');
      
      // Salva l'username PRIMA del logout per continuare il polling
      if (_lastUsername == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final userJson = prefs.getString('securevox_current_user');
          if (userJson != null) {
            final userData = jsonDecode(userJson);
            _lastUsername = userData['username']?.toString();
            print('📡 UnifiedRealtimeService - Username salvato per polling post-logout: $_lastUsername');
          }
        } catch (e) {
          print('⚠️ UnifiedRealtimeService - Errore salvataggio username: $e');
        }
      }
      
      // Importa AuthService per eseguire il logout
      // NOTA: Devo usare un approccio globale per evitare dipendenze circolari
      // Usiamo un callback o un service locator
      _broadcastForceLogoutEvent(reason);
      
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore forzatura logout: $e');
    }
  }
  
  /// 🚫 REALTIME: Invia evento globale per forzare logout
  void _broadcastForceLogoutEvent(String reason) {
    final event = {
      'type': 'force_logout',
      'reason': reason,
      'message': 'Utente disabilitato temporaneamente. Logout forzato.',
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _globalEventsController.add(event);
    print('📡 UnifiedRealtimeService - Evento logout forzato inviato: $event');
  }
  
  /// ✅ REALTIME: Invia evento globale quando l'utente viene sbloccato
  void _broadcastUserUnblockedEvent(String message) {
    final event = {
      'type': 'user_unblocked',
      'message': message,
      'username': _lastUsername,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    _globalEventsController.add(event);
    print('📡 UnifiedRealtimeService - Evento utente sbloccato inviato: $event');
  }
  
  /// Imposta l'username per il polling (chiamato dopo logout o dalla login screen)
  void setUsernameForPolling(String? username) {
    _lastUsername = username;
    print('📡 UnifiedRealtimeService - Username impostato per polling: $username');
  }

  /// 🔄 REFRESH AUTO: Refresh automatico messaggi per chat attive
  Future<void> _refreshActiveChats() async {
    try {
      print('🔄 UnifiedRealtimeService._refreshActiveChats - Inizio refresh chat attive...');
      
      // Verifica che MessageService sia disponibile
      if (_messageService == null) {
        print('⚠️ UnifiedRealtimeService._refreshActiveChats - MessageService non disponibile');
        return;
      }
      
      // Ottieni le chat attive dalla cache
      final activeChats = RealChatService.cachedChats;
      print('🔄 UnifiedRealtimeService._refreshActiveChats - Chat attive trovate: ${activeChats.length}');
      
      if (activeChats.isEmpty) {
        print('🔄 UnifiedRealtimeService._refreshActiveChats - Nessuna chat attiva, skip refresh');
        return;
      }
      
      // Per ogni chat, forza il refresh dei messaggi
      int refreshedCount = 0;
      for (final chat in activeChats) {
        try {
          print('🔄 UnifiedRealtimeService._refreshActiveChats - Refresh chat: ${chat.id}');
          
          // Forza il refresh dei messaggi per questa chat
          await _messageService!.forceLoadMessagesForChatDetail(chat.id);
          
          refreshedCount++;
          print('✅ UnifiedRealtimeService._refreshActiveChats - Chat ${chat.id} refreshata');
          
          // Piccolo delay per evitare sovraccarico
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          print('❌ UnifiedRealtimeService._refreshActiveChats - Errore refresh chat ${chat.id}: $e');
        }
      }
      
      print('');
      print('✅ UnifiedRealtimeService._refreshActiveChats - Refresh completato: $refreshedCount/${activeChats.length} chat');
      print('');
    } catch (e) {
      print('❌ UnifiedRealtimeService._refreshActiveChats - Errore generale: $e');
    }
  }

  /// Ferma il servizio
  void dispose() {
    _pollingTimer?.cancel();
    _chatMonitorTimer?.cancel();
    _encryptionStatusTimer?.cancel(); // 🔐 REALTIME: Ferma anche polling crittografia
    _userStatusTimer?.cancel(); // 🚫 REALTIME: Ferma anche polling stato utente
    _isInitialized = false;
    _processedMessageIds.clear();
    _sentNotificationIds.clear();
    _lastEncryptionStatus.clear(); // 🔐 REALTIME: Pulisci cache stato crittografia
    _lastUserStatus = null; // 🚫 REALTIME: Pulisci cache stato utente
    print('🛑 UnifiedRealtimeService - Servizio fermato');
  }
}
