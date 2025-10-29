import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';
import 'real_chat_service.dart';
import 'e2e_manager.dart';
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

  // Getters
  bool get isInitialized => _isInitialized;
  String? get deviceToken => _deviceToken;
  
  /// CORREZIONE: Imposta il MessageService esistente
  void setMessageService(MessageService messageService) {
    _messageService = messageService;
    print('📱 UnifiedRealtimeService - MessageService impostato');
  }
  String? get currentUserId => _currentUserId;

  /// Inizializza il servizio
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
      
      // 2. Genera token dispositivo
      await _generateDeviceToken();
      print('📱 UnifiedRealtimeService - Device token generato: $_deviceToken');
      
      // 3. Registra dispositivo con SecureVOX Notify
      await _registerDevice();
      print('📡 UnifiedRealtimeService - Dispositivo registrato');
      
      // 4. Avvia il polling per i messaggi
      _startMessagePolling();
      print('🔄 UnifiedRealtimeService - Polling avviato');
      
      _isInitialized = true;
      print('✅ UnifiedRealtimeService - Inizializzazione completata');
    } catch (e) {
      print('❌ UnifiedRealtimeService - Errore inizializzazione: $e');
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
            print('📨 UnifiedRealtimeService - Trovate ${(data['notifications'] as List).length} notifiche');
            for (final notification in data['notifications']) {
              _handleIncomingMessage(notification);
            }
            
            // Pulisci la cache dei messaggi processati periodicamente
            _cleanupProcessedMessageIds();
            _cleanupSentNotificationIds();
          } else {
            print('🔄 UnifiedRealtimeService - Nessun messaggio nuovo');
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
              
              // Sostituisci data con i dati decifrati
              data = decryptedData['data'] ?? decryptedData;
              
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
      final senderId = data['sender_id'];
      final content = data['content'];
      final messageType = data['message_type'];
      final timestamp = data['timestamp'];

      if (chatId == null || messageId == null) {
        print('❌ UnifiedRealtimeService - Dati mancanti nella notifica');
        print('❌ UnifiedRealtimeService - Dati ricevuti: $data');
        return;
      }

      // CORREZIONE: Controlla se il messaggio è già stato processato per evitare duplicati
      if (_processedMessageIds.contains(messageId)) {
        print('⚠️ UnifiedRealtimeService - Messaggio già processato, skip: $messageId');
        return;
      }

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
              messageContent = '🔒 [Messaggio cifrato]';
              print('❌ ❌ ❌ DECIFRATURA FALLITA: E2EManager ha restituito null');
            }
          } catch (e, stackTrace) {
            print('❌ ❌ ❌ ERRORE DURANTE DECIFRATURA:');
            print('   Errore: $e');
            print('   StackTrace: $stackTrace');
            messageContent = '🔒 [Errore decifratura]';
          }
        } else {
          print('❌ IV NON DISPONIBILE - impossibile decifrare');
          messageContent = '🔒 [Messaggio cifrato - IV mancante]';
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
        time: _formatTime(timestamp ?? now.toIso8601String()),
        timestamp: timestamp != null ? DateTime.parse(timestamp) : now,
        metadata: _createMetadataForMessageType(parsedMessageType, messageContent, data),
        isRead: shouldBeRead, // CORREZIONE: Solo se la chat destinatario è effettivamente visualizzata
      );

      // CORREZIONE: Usa il MessageService esistente invece di crearne uno nuovo
      if (_messageService == null) {
        print('❌ UnifiedRealtimeService - MessageService non impostato, impossibile aggiungere messaggio');
        return;
      }
      
      _messageService!.addMessageToCache(chatId, incomingMessage, isRealtimeMessage: true);
      
      // CORREZIONE: Se la chat è attualmente visualizzata, aggiorna lo stato di lettura
      if (isCurrentlyViewing) {
        _messageService!.updateChatReadStatus(chatId);
        print('📨 UnifiedRealtimeService - Stato lettura aggiornato per chat visualizzata: $chatId');
      }
      
      // CORREZIONE: Aggiorna la lista chat con il contenuto DECIFRATO
      // updateChatLastMessage ora chiama automaticamente notifyListeners()
      _updateChatList(chatId, messageContent);
      
      // ✅ Aggiungi l'ID del messaggio alla cache per evitare duplicati SOLO DOPO il successo
      _processedMessageIds.add(messageId);
      
      print('✅ UnifiedRealtimeService - Messaggio aggiunto alla cache: $chatId');
      print('✅ MessageId aggiunto ai processati: $messageId');
      
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
        
        final imageUrl = data['image_url'] ?? data['imageUrl'] ?? '';
        print('🖼️   URL finale estratto: $imageUrl');
        
        return ImageMessageData(
          imageUrl: imageUrl,
          caption: data['caption'] ?? content,
        ).toJson();
        
      case MessageType.video:
        // CORREZIONE: Debug dei dati ricevuti per i video
        print('🎥 UnifiedRealtimeService._createMetadataForMessageType - DEBUG VIDEO:');
        print('🎥   data keys: ${data.keys}');
        print('🎥   video_url: ${data['video_url']}');
        print('🎥   videoUrl: ${data['videoUrl']}');
        
        final videoUrl = data['video_url'] ?? data['videoUrl'] ?? '';
        final thumbnailUrl = data['thumbnail_url'] ?? data['thumbnailUrl'] ?? '';
        print('🎥   Video URL finale: $videoUrl');
        print('🎥   Thumbnail URL finale: $thumbnailUrl');
        
        return VideoMessageData(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          caption: data['caption'] ?? content,
        ).toJson();
        
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

  /// Ferma il servizio
  void dispose() {
    _pollingTimer?.cancel();
    _chatMonitorTimer?.cancel();
    _isInitialized = false;
    _processedMessageIds.clear();
    _sentNotificationIds.clear();
    print('🛑 UnifiedRealtimeService - Servizio fermato');
  }
}
