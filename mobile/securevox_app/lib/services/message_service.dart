import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:image_picker/image_picker.dart'; // Temporaneamente disabilitato per problemi iOS
// import 'package:file_picker/file_picker.dart';  // Temporaneamente disabilitato
// import 'package:geolocator/geolocator.dart'; // Temporaneamente disabilitato per problemi iOS
// import 'package:geocoding/geocoding.dart'; // Temporaneamente disabilitato per problemi iOS
// import 'package:contacts_service/contacts_service.dart'; // Temporaneamente disabilitato
import '../models/message_model.dart';
import '../models/chat_model.dart';
import 'timezone_service.dart';
import 'unified_realtime_service.dart';
import 'real_chat_service.dart';
import 'user_service.dart';
import 'app_sound_service.dart';
import 'e2e_manager.dart'; // 🔐 E2EE Support

/// Servizio unificato per la gestione dei messaggi
/// Usa SOLO SecureVOX Notify per le notifiche real-time
class MessageService extends ChangeNotifier {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  
  // Cache per i messaggi
  final Map<String, List<MessageModel>> _messageCache = {};
  final Map<String, DateTime> _lastFetch = {};
  final Map<String, int> _unreadCounts = {};
  
  // CORREZIONE: Cache per lo stato di lettura persistente
  final Map<String, Set<String>> _readMessageIds = {};
  
  // CORREZIONE: Cache per evitare messaggi duplicati
  final Set<String> _processedMessageIds = {};
  
  // 🔐 Cache per i messaggi inviati cifrati (messageId → plaintext)
  final Map<String, String> _sentMessagesPlaintext = {};
  
  // Traccia quale chat è attualmente visualizzata
  String? _currentlyViewingChatId;
  static const Duration cacheExpiry = Duration(minutes: 5);
  
  // ID utente corrente
  String? _currentUserId;
  
  // Servizio unificato per real-time
  UnifiedRealtimeService? _unifiedRealtime;
  
  // Servizio per i suoni
  final AppSoundService _soundService = AppSoundService();

  /// Pulisce completamente la cache dei messaggi e chat
  Future<void> clearAllCache() async {
    try {
      print('🧹 MessageService.clearAllCache - Pulizia completa cache messaggi...');
      
      // Pulisci tutte le cache
      _messageCache.clear();
      _lastFetch.clear();
      _unreadCounts.clear();
      _readMessageIds.clear();
      _processedMessageIds.clear();
      _loadingFlags.clear(); // CORREZIONE: Pulisci anche i flag di caricamento
      _sentMessagesPlaintext.clear(); // 🔐 Pulisci anche i plaintext dei messaggi cifrati
      
      // Pulisci SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (String key in keys) {
        if (key.startsWith('message_') || 
            key.startsWith('chat_') ||
            key.startsWith('unread_') ||
            key == 'securevox_read_state' ||
            key == 'securevox_sent_messages_plaintext') {  // 🔐 Pulisci anche i plaintext salvati
          await prefs.remove(key);
          print('🗑️ Rimosso: $key');
        }
      }
      
      print('✅ MessageService.clearAllCache - Cache pulita con successo');
      
      // Notifica i listener
      notifyListeners();
    } catch (e) {
      print('❌ MessageService.clearAllCache - Errore: $e');
    }
  }

  /// Forza il refresh di tutte le chat dal server
  Future<void> forceRefreshChats() async {
    try {
      print('🔄 MessageService.forceRefreshChats - Forzando refresh chat...');
      
      // Pulisci la cache delle chat
      _lastFetch.clear();
      
      // Notifica i listener per forzare il refresh
      notifyListeners();
      
      print('✅ MessageService.forceRefreshChats - Refresh forzato');
    } catch (e) {
      print('❌ MessageService.forceRefreshChats - Errore: $e');
    }
  }

  /// Reset dei flag di caricamento bloccati (utile dopo hot reload)
  void resetLoadingFlags() {
    print('🔄 MessageService.resetLoadingFlags - Reset di tutti i flag di caricamento');
    _loadingFlags.clear();
    print('✅ MessageService.resetLoadingFlags - Flag resettati');
  }

  /// Inizializza il servizio realtime unificato
  Future<void> _initializeRealtimeSync() async {
    if (_unifiedRealtime == null) {
      try {
        print('📱 MessageService._initializeRealtimeSync - Inizializzazione UnifiedRealtimeService...');
        _unifiedRealtime = UnifiedRealtimeService();
        
        // CORREZIONE: Imposta il riferimento al MessageService
        _unifiedRealtime!.setMessageService(this);
        
        await _unifiedRealtime!.initialize();
        print('✅ MessageService - UnifiedRealtimeService inizializzato');
      } catch (e) {
        print('❌ MessageService - Errore inizializzazione UnifiedRealtimeService: $e');
      }
    }
  }

  /// CORREZIONE: Carica lo stato di lettura salvato
  Future<void> _loadReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readStateJson = prefs.getString('securevox_read_state');
      
      if (readStateJson != null) {
        final Map<String, dynamic> readState = jsonDecode(readStateJson);
        _readMessageIds.clear();
        
        for (final entry in readState.entries) {
          final chatId = entry.key;
          final messageIds = (entry.value as List).cast<String>();
          _readMessageIds[chatId] = messageIds.toSet();
        }
        
        print('📱 MessageService._loadReadState - Stato di lettura caricato per ${_readMessageIds.length} chat');
      }
    } catch (e) {
      print('❌ MessageService._loadReadState - Errore: $e');
    }
  }

  /// CORREZIONE: Salva lo stato di lettura
  Future<void> _saveReadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final readState = <String, dynamic>{};
      
      for (final entry in _readMessageIds.entries) {
        readState[entry.key] = entry.value.toList();
      }
      
      await prefs.setString('securevox_read_state', jsonEncode(readState));
      print('📱 MessageService._saveReadState - Stato di lettura salvato per ${_readMessageIds.length} chat');
    } catch (e) {
      print('❌ MessageService._saveReadState - Errore: $e');
    }
  }

  /// 🔐 CORREZIONE: Carica i plaintext dei messaggi inviati cifrati
  Future<void> _loadSentMessagesPlaintext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final plaintextJson = prefs.getString('securevox_sent_messages_plaintext');
      
      if (plaintextJson != null) {
        final Map<String, dynamic> plaintextMap = jsonDecode(plaintextJson);
        _sentMessagesPlaintext.clear();
        
        for (final entry in plaintextMap.entries) {
          _sentMessagesPlaintext[entry.key] = entry.value.toString();
        }
        
        print('🔐 MessageService._loadSentMessagesPlaintext - ${_sentMessagesPlaintext.length} plaintext caricati');
      } else {
        print('🔐 MessageService._loadSentMessagesPlaintext - Nessun plaintext salvato');
      }
    } catch (e) {
      print('❌ MessageService._loadSentMessagesPlaintext - Errore: $e');
    }
  }

  /// 🔐 CORREZIONE: Salva i plaintext dei messaggi inviati cifrati
  Future<void> _saveSentMessagesPlaintext() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('securevox_sent_messages_plaintext', jsonEncode(_sentMessagesPlaintext));
      print('🔐 MessageService._saveSentMessagesPlaintext - ${_sentMessagesPlaintext.length} plaintext salvati');
    } catch (e) {
      print('❌ MessageService._saveSentMessagesPlaintext - Errore: $e');
    }
  }

  /// Invia un messaggio di testo
  Future<bool> sendTextMessage({
    required String chatId,
    required String recipientId,
    required String text,
  }) async {
    try {
      print('📱 MessageService.sendTextMessage - Invio messaggio di testo');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendTextMessage - Token non disponibile');
        return false;
      }

      // 🔐 VERIFICA E2EE: Cifra il messaggio se E2EE è abilitato
      String contentToSend = text;
      Map<String, dynamic>? encryptionMetadata;
      bool isEncrypted = false;
      
      if (E2EManager.isEnabled) {
        print('🔐 MessageService.sendTextMessage - E2EE ABILITATO, cifratura del messaggio...');
        try {
          // Cifra il contenuto usando E2EE (parametri posizionali!)
          // Converti recipientId a String se necessario
          final recipientIdStr = recipientId.toString();
          final encryptedData = await E2EManager.encryptMessage(
            recipientIdStr,  // recipientUserId (String, posizionale)
            text,            // plaintext (String, posizionale)
          );
          
          if (encryptedData != null) {
            contentToSend = encryptedData['ciphertext'] ?? text;
            encryptionMetadata = {
              'iv': encryptedData['iv'],
              'mac': encryptedData['mac'],
              'encrypted': true,
            };
            isEncrypted = true;
            print('✅ MessageService.sendTextMessage - Messaggio cifrato con successo');
            print('   Ciphertext length: ${contentToSend.length}');
            print('   IV: ${encryptionMetadata['iv']}');
          } else {
            print('⚠️ MessageService.sendTextMessage - Cifratura fallita, invio in chiaro');
          }
        } catch (e) {
          print('❌ MessageService.sendTextMessage - Errore cifratura: $e');
          print('⚠️ Invio messaggio in chiaro come fallback');
        }
      } else {
        print('📝 MessageService.sendTextMessage - E2EE NON abilitato, invio in chiaro');
      }

      // Prepara il body della richiesta
      final requestBody = {
        'content': contentToSend,
        'message_type': 'text',
        if (isEncrypted && encryptionMetadata != null) 'metadata': {
          ...encryptionMetadata,
          'recipient_id': recipientId,  // 🔐 CORREZIONE: Salva recipientId per decifratura corretta
        },
      };
      
      print('📤 MessageService.sendTextMessage - Invio al backend:');
      print('   Encrypted: $isEncrypted');
      print('   Content length: ${contentToSend.length}');

      // Invia il messaggio al backend
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final messageId = responseData['message_id'];
        print('📱 MessageService.sendTextMessage - Messaggio inviato al backend: $messageId');
        
        // 🔐 CORREZIONE: Se il messaggio è cifrato, salva il plaintext nella mappatura
        if (isEncrypted) {
          _sentMessagesPlaintext[messageId] = text;
          await _saveSentMessagesPlaintext(); // Persist to SharedPreferences
          print('🔐 MessageService.sendTextMessage - Plaintext salvato e persistito per messageId: $messageId');
        }
        
        // Aggiorna la cache locale con il messaggio inviato (sempre in plaintext!)
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: messageId,
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.text,
          content: text,  // SEMPRE plaintext nella cache locale
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: TextMessageData(text: text).toJson(),
          isRead: true,
        );
        
        // Aggiungi alla cache
        addMessageToCache(chatId, message);
        
        // Sincronizza con RealChatService per aggiornare la lista chat
        _syncWithRealChatService(chatId, text);
        
        // CORREZIONE: Aggiorna lo stato di lettura della chat dopo aver inviato il messaggio
        updateChatReadStatus(chatId);
        
        // CORREZIONE: Notifica immediatamente per aggiornare la home
        notifyListeners();
        forceHomeScreenUpdate();
        
        // INVIO NOTIFICA VIA SECUREVOX NOTIFY
        print('📱 MessageService.sendMessage - Inizializzazione UnifiedRealtimeService...');
        await _initializeRealtimeSync();
        print('📱 MessageService.sendMessage - UnifiedRealtimeService inizializzato: ${_unifiedRealtime != null}');
        
        if (_unifiedRealtime != null) {
          print('📱 MessageService.sendMessage - Invio notifica via SecureVOX Notify...');
          print('📱   Chat ID: $chatId');
          print('📱   Recipient ID: $recipientId');
          print('📱   Message ID: ${responseData['message_id']}');
          print('📱   Content: $text');
          
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: text,
            messageType: 'text',
          );
          print('📱 MessageService.sendMessage - Notifica inviata via SecureVOX Notify');
        } else {
          print('📱 MessageService.sendMessage - UnifiedRealtimeService non disponibile');
        }
        
        print('📱 MessageService.sendTextMessage - Messaggio aggiunto alla cache: $chatId');
        print('📱 MessageService.sendTextMessage - Contenuto: $text');
        
        return true;
      } else {
        print('📱 MessageService.sendTextMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendTextMessage - Errore: $e');
      return false;
    }
  }

  /// Ottiene i messaggi di una chat
  Future<List<MessageModel>> getChatMessages(String chatId) async {
    try {
      print('📱 MessageService.getChatMessages - INIZIO caricamento per chat: $chatId');
      
      // CORREZIONE: Reset del flag di caricamento per evitare blocchi dopo hot reload
      print('📱 MessageService.getChatMessages - Loading flag per $chatId: ${_loadingFlags[chatId]}');
      
      // Controlla se la cache è ancora valida
      if (_messageCache.containsKey(chatId) && 
          _lastFetch.containsKey(chatId) &&
          DateTime.now().difference(_lastFetch[chatId]!) < cacheExpiry) {
        print('📱 MessageService.getChatMessages - Cache valida per chat: $chatId (${_messageCache[chatId]!.length} messaggi)');
        return _messageCache[chatId]!;
      }

      // CORREZIONE: Se il flag è bloccato da più di 30 secondi, resettalo
      if (_loadingFlags[chatId] == true) {
        final lastFetch = _lastFetch[chatId];
        if (lastFetch == null || DateTime.now().difference(lastFetch) > Duration(seconds: 30)) {
          print('📱 MessageService.getChatMessages - Reset flag bloccato per chat: $chatId');
          _loadingFlags[chatId] = false;
        } else {
          print('📱 MessageService.getChatMessages - Caricamento già in corso per chat: $chatId');
          return _messageCache[chatId] ?? [];
        }
      }

      // Carica i messaggi dal backend
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.getChatMessages - Token non disponibile');
        return [];
      }

      print('📱 MessageService.getChatMessages - Chiamata API per chat: $chatId');
      print('📱 MessageService.getChatMessages - Token utilizzato: ${token?.substring(0, 20)}...');
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );

      print('📱 MessageService.getChatMessages - Risposta API: ${response.statusCode}');
      print('📱 MessageService.getChatMessages - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📱 MessageService.getChatMessages - Data ricevuta: $data');
        
        List<MessageModel> messages = [];
        
        // Gestisce diversi formati di risposta (con decifratura asincrona)
        if (data is List) {
          messages = await Future.wait(
            data.map((msg) => _parseMessageFromBackend(msg, chatId))
          );
        } else if (data is Map && data.containsKey('messages')) {
          messages = await Future.wait(
            (data['messages'] as List).map((msg) => _parseMessageFromBackend(msg, chatId))
          );
        } else if (data is Map && data.containsKey('results')) {
          messages = await Future.wait(
            (data['results'] as List).map((msg) => _parseMessageFromBackend(msg, chatId))
          );
        }

        // CORREZIONE: Ordina per timestamp (dal più vecchio al più recente)
        messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        // 🧹 CORREZIONE: Se il backend restituisce MENO messaggi della cache locale, pulisci la cache
        final cachedCount = _messageCache[chatId]?.length ?? 0;
        if (cachedCount > 0 && messages.length < cachedCount) {
          print('🧹 MessageService.getChatMessages - PULIZIA CACHE: Backend ha ${messages.length} messaggi, cache locale ha $cachedCount');
          print('🧹   Eliminazione messaggi obsoleti dalla cache...');
          _messageCache.remove(chatId);
          _readMessageIds.remove(chatId);
          _processedMessageIds.clear(); // Pulisci anche la cache dei messaggi processati
          await _saveReadState();
        }
        
        // Aggiorna la cache
        _messageCache[chatId] = messages;
        _lastFetch[chatId] = DateTime.now();
        
        print('📱 MessageService.getChatMessages - ✅ Caricati ${messages.length} messaggi per chat: $chatId');
        
        // Debug: mostra un riassunto dei messaggi
        for (int i = 0; i < messages.length && i < 3; i++) {
          final msg = messages[i];
          print('📱   Messaggio ${i + 1}: "${msg.content}" (isMe: ${msg.isMe}, senderId: ${msg.senderId})');
        }
        if (messages.length > 3) {
          print('📱   ... e altri ${messages.length - 3} messaggi');
        }
        
        return messages;
      } else {
        print('📱 MessageService.getChatMessages - ❌ Errore backend: ${response.statusCode}');
        print('📱 MessageService.getChatMessages - Body errore: ${response.body}');
        return [];
      }
    } catch (e) {
      print('📱 MessageService.getChatMessages - ❌ Errore: $e');
      return [];
    }
  }

  /// Aggiunge un messaggio alla cache
  void addMessageToCache(String chatId, MessageModel message, {bool isRealtimeMessage = false}) {
    // CORREZIONE: Controlla se il messaggio è già stato processato per evitare duplicati
    if (_processedMessageIds.contains(message.id)) {
      print('⚠️ MessageService.addMessageToCache - Messaggio già processato, skip: ${message.id}');
      return;
    }

    // Aggiungi l'ID del messaggio alla cache per evitare duplicati
    _processedMessageIds.add(message.id);

    if (!_messageCache.containsKey(chatId)) {
      _messageCache[chatId] = [];
    }
    
    // CORREZIONE: Se la chat è attualmente visualizzata E è un messaggio real-time, marca come letto
    // CORREZIONE: Logica di sicurezza - controlla che la chat visualizzata corrisponda alla chat del messaggio
    // CORREZIONE: Se _currentlyViewingChatId è null, l'utente è nella home, quindi non marcare come letto
    final isCurrentlyViewingThisChat = isChatCurrentlyViewing(chatId) && _currentlyViewingChatId == chatId && _currentlyViewingChatId != null;
    if (isCurrentlyViewingThisChat && isRealtimeMessage) {
      print('📱 MessageService.addMessageToCache - Chat visualizzata + messaggio real-time, marcatura come letto: ${message.content}');
      
      // CORREZIONE: Inizializza il set per questa chat se non esiste
      if (!_readMessageIds.containsKey(chatId)) {
        _readMessageIds[chatId] = <String>{};
      }
      
      // CORREZIONE: Crea sempre un messaggio con isRead: true se la chat è visualizzata E è real-time
      final updatedMessage = MessageModel(
        id: message.id,
        chatId: message.chatId,
        senderId: message.senderId,
        isMe: message.isMe,
        type: message.type,
        content: message.content,
        time: message.time,
        timestamp: message.timestamp,
        metadata: message.metadata,
        isRead: true, // CORREZIONE: Sempre true se la chat è visualizzata E è real-time
      );
      
      // CORREZIONE: Aggiungi l'ID del messaggio al set dei messaggi letti
      _readMessageIds[chatId]!.add(message.id);
      
      // CORREZIONE: Salva lo stato di lettura
      _saveReadState();
      
      _messageCache[chatId]!.add(updatedMessage);
    } else {
      // CORREZIONE: Per messaggi non real-time o chat non visualizzate, usa lo stato originale
      _messageCache[chatId]!.add(message);
    }
    
    // CORREZIONE: Ordina i messaggi per timestamp dopo l'aggiunta
    _messageCache[chatId]!.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    print('🔄 DEBUG STREAM - Chat ID: $chatId');
    print('🔄 DEBUG STREAM - StreamController exists: ${_streamControllers.containsKey(chatId)}');
    print('🔄 DEBUG STREAM - Messaggi in cache: ${_messageCache[chatId]!.length}');
    
    // Emetti i messaggi aggiornati attraverso lo stream controller
    if (_streamControllers.containsKey(chatId)) {
      print('🔄 DEBUG STREAM - Emetto ${_messageCache[chatId]!.length} messaggi nello stream');
      try {
        _streamControllers[chatId]!.add(_messageCache[chatId]!);
        print('✅ DEBUG STREAM - Stream aggiornato con successo!');
      } catch (e) {
        print('❌ DEBUG STREAM - Errore emissione stream: $e');
      }
    } else {
      print('⚠️  DEBUG STREAM - StreamController NON ESISTE per chat $chatId');
      print('⚠️  DEBUG STREAM - Stream controllers disponibili: ${_streamControllers.keys.toList()}');
    }
    
    print('📱 MessageService.addMessageToCache - Messaggio aggiunto alla cache: $chatId');
    print('📱 MessageService.addMessageToCache - Contenuto: ${message.content}');
    
    // CORREZIONE: Se la chat è attualmente visualizzata, aggiorna lo stato di lettura
    if (isChatCurrentlyViewing(chatId)) {
      updateChatReadStatus(chatId);
    }
    
    // Pulisci la cache dei messaggi processati periodicamente
    _cleanupProcessedMessageIds();
    
    notifyListeners();
  }

  /// Marca una chat come attualmente visualizzata
  void markChatAsCurrentlyViewing(String chatId) {
    _currentlyViewingChatId = chatId;
    print('📱 MessageService.markChatAsCurrentlyViewing - Chat $chatId marcata come visualizzata');
    
    // Carica i messaggi per questa chat
    _loadMessagesForStream(chatId);
    
    // Marca automaticamente tutti i messaggi non letti come letti
    markChatAsRead(chatId);
    
    // Sincronizza lo stato di lettura con il backend (temporaneamente disabilitato)
    // syncReadStatusWithBackend(chatId);
  }

  /// Marca una chat come non più visualizzata
  void markChatAsNotViewing() {
    // CORREZIONE: Salva l'ID della chat che stavi visualizzando prima di resettarlo
    final previousChatId = _currentlyViewingChatId;
    _currentlyViewingChatId = null;
    print('📱 MessageService.markChatAsNotViewing - Nessuna chat visualizzata');
    
    // CORREZIONE: Se c'era una chat visualizzata, marca TUTTI i messaggi come letti e aggiorna lo stato
    if (previousChatId != null) {
      print('📱 MessageService.markChatAsNotViewing - Marcatura finale messaggi come letti per chat: $previousChatId');
      
      // CORREZIONE: Marca TUTTI i messaggi come letti prima di uscire dalla chat
      markChatAsRead(previousChatId);
      
      // CORREZIONE: Aggiorna lo stato di lettura per sincronizzare con la home
      updateChatReadStatus(previousChatId);
      
      print('📱 MessageService.markChatAsNotViewing - Chat $previousChatId: tutti i messaggi marcati come letti');
    }
    
    // CORREZIONE: Resetta esplicitamente lo stato di visualizzazione
    resetViewingState();
    
    // CORREZIONE: Forza l'aggiornamento dei listener per sincronizzare la home
    notifyListeners();
  }

  /// Controlla se una chat è attualmente visualizzata
  bool isChatCurrentlyViewing(String chatId) {
    return _currentlyViewingChatId == chatId;
  }

  /// Ottiene l'ID della chat attualmente visualizzata (per debug)
  String? getCurrentlyViewingChatId() {
    return _currentlyViewingChatId;
  }

  /// Resetta lo stato di visualizzazione (per quando si torna alla home)
  void resetViewingState() {
    _currentlyViewingChatId = null;
    print('📱 MessageService.resetViewingState - Stato di visualizzazione resettato');
  }

  /// Forza il reset dello stato quando si torna alla home (per sicurezza)
  void forceResetForHome() {
    _currentlyViewingChatId = null;
    print('📱 MessageService.forceResetForHome - Stato forzato a null per home');
  }

  /// Aggiunge un messaggio al set dei messaggi letti (per uso interno)
  void addMessageToReadIds(String chatId, String messageId) {
    _readMessageIds[chatId] ??= <String>{};
    _readMessageIds[chatId]!.add(messageId);
    _saveReadState();
    print('📱 MessageService.addMessageToReadIds - Messaggio $messageId aggiunto a _readMessageIds per chat $chatId');
  }

  /// Pulisce la cache dei messaggi processati (mantiene solo gli ultimi 1000)
  void _cleanupProcessedMessageIds() {
    if (_processedMessageIds.length > 1000) {
      final idsToRemove = _processedMessageIds.take(_processedMessageIds.length - 1000).toList();
      for (final id in idsToRemove) {
        _processedMessageIds.remove(id);
      }
      print('🧹 MessageService - Cache messaggi processati pulita: ${idsToRemove.length} ID rimossi');
    }
  }

  /// Chiude tutti gli stream controllers
  void dispose() {
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    _processedMessageIds.clear();
  }

  /// Marca tutti i messaggi di una chat come letti
  void markChatAsRead(String chatId) {
    print('📱 MessageService.markChatAsRead - Chat $chatId marcata come letta');
    
    final messages = _messageCache[chatId] ?? [];
    bool hasChanges = false;
    int markedCount = 0;
    
    // CORREZIONE: Inizializza il set per questa chat se non esiste
    if (!_readMessageIds.containsKey(chatId)) {
      _readMessageIds[chatId] = <String>{};
    }
    
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      // CORREZIONE: Marca TUTTI i messaggi come letti quando entri nella chat, indipendentemente da chi li ha inviati
      if (!message.isRead) {
        // Crea una copia del messaggio con isRead = true
        final updatedMessage = MessageModel(
          id: message.id,
          chatId: message.chatId,
          senderId: message.senderId,
          isMe: message.isMe,
          type: message.type,
          content: message.content,
          time: message.time,
          timestamp: message.timestamp,
          metadata: message.metadata,
          isRead: true,
        );
        messages[i] = updatedMessage;
        
        // CORREZIONE: Aggiungi l'ID del messaggio al set dei messaggi letti
        _readMessageIds[chatId]!.add(message.id);
        
        hasChanges = true;
        markedCount++;
        print('📱 MessageService.markChatAsRead - Messaggio marcato come letto: ${message.content} (isMe: ${message.isMe})');
      }
    }
    
    if (hasChanges) {
      _messageCache[chatId] = messages;
      
      // Emetti i messaggi aggiornati attraverso lo stream controller
      if (_streamControllers.containsKey(chatId)) {
        _streamControllers[chatId]!.add(messages);
      }
      
      // CORREZIONE: Salva lo stato di lettura
      _saveReadState();
      
      // CORREZIONE: Aggiorna sempre lo stato di lettura, anche se non ci sono cambiamenti
      updateChatReadStatus(chatId);
      notifyListeners();
      print('📱 MessageService.markChatAsRead - ✅ $markedCount messaggi marcati come letti');
    } else {
      // CORREZIONE: Aggiorna comunque lo stato anche se non ci sono messaggi da marcare
      updateChatReadStatus(chatId);
      notifyListeners();
      print('📱 MessageService.markChatAsRead - ⚠️ Nessun messaggio da marcare, aggiornato stato comunque');
    }
  }

  /// Sincronizza lo stato di lettura con il backend
  Future<void> syncReadStatusWithBackend(String chatId) async {
    try {
      print('📱 MessageService.syncReadStatusWithBackend - Sincronizzazione stato lettura per chat: $chatId');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.syncReadStatusWithBackend - Token non disponibile');
        return;
      }

      print('📱 MessageService.syncReadStatusWithBackend - Chiamata a: $baseUrl/chats/$chatId/mark-read/');
      
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/mark-read/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('📱 MessageService.syncReadStatusWithBackend - Status: ${response.statusCode}');
      print('📱 MessageService.syncReadStatusWithBackend - Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedCount = data['updated_count'] ?? 0;
        print('📱 MessageService.syncReadStatusWithBackend - ✅ $updatedCount messaggi sincronizzati con backend');
      } else {
        print('📱 MessageService.syncReadStatusWithBackend - ❌ Errore backend: ${response.statusCode}');
        print('📱 MessageService.syncReadStatusWithBackend - Risposta: ${response.body}');
      }
    } catch (e) {
      print('📱 MessageService.syncReadStatusWithBackend - ❌ Errore: $e');
    }
  }

  /// Calcola il numero di messaggi non letti per una chat
  int getUnreadCount(String chatId) {
    final messages = _messageCache[chatId] ?? [];
    final readMessageIds = _readMessageIds[chatId] ?? <String>{};
    
    // CORREZIONE: Conta i messaggi non letti usando lo stato persistente
    int unreadCount = 0;
    for (final message in messages) {
      if (!message.isMe && !readMessageIds.contains(message.id)) {
        unreadCount++;
        print('📱 MessageService.getUnreadCount - Messaggio non letto: ${message.content} (ID: ${message.id}, isMe: ${message.isMe})');
      }
    }
    
    if (messages.isEmpty) {
      return 0;
    }
    
    // Log dettagliato per debug
    print('📱 MessageService.getUnreadCount - Chat $chatId: $unreadCount messaggi non letti su ${messages.length} totali');
    print('📱 MessageService.getUnreadCount - ReadMessageIds: ${readMessageIds.length} messaggi letti');
    print('📱 MessageService.getUnreadCount - ReadMessageIds: $readMessageIds');
    
    _unreadCounts[chatId] = unreadCount;
    
    return unreadCount;
  }

  /// Ottiene l'ultimo messaggio di una chat
  String getLastMessage(String chatId) {
    final messages = _messageCache[chatId] ?? [];
    if (messages.isEmpty) {
      return '';
    }
    
    // CORREZIONE: Ordina per timestamp invece che per time (stringa)
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages.first.content;
  }

  /// Ottiene gli ultimi N messaggi di una chat (per mostrare gli ultimi 7)
  List<MessageModel> getLastMessages(String chatId, int count) {
    final messages = _messageCache[chatId] ?? [];
    if (messages.isEmpty) {
      return [];
    }
    
    // Ordina per timestamp (dal più recente al più vecchio)
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Prendi solo gli ultimi N messaggi
    return messages.take(count).toList();
  }

  /// Sincronizza con RealChatService per aggiornare la lista chat
  void _syncWithRealChatService(String chatId, String lastMessage) {
    try {
      final unreadCount = getUnreadCount(chatId);
      RealChatService.updateChatLastMessage(chatId, lastMessage, unreadCount);
      print('📱 MessageService._syncWithRealChatService - Chat $chatId aggiornata: "$lastMessage" ($unreadCount non letti)');
    } catch (e) {
      print('📱 MessageService._syncWithRealChatService - Errore critico: $e');
    }
  }

  /// Aggiorna lo stato di lettura della chat
  void updateChatReadStatus(String chatId) {
    try {
      final unreadCount = getUnreadCount(chatId);
      final lastMessage = getLastMessage(chatId);
      _unreadCounts[chatId] = unreadCount;
      RealChatService.updateChatLastMessage(chatId, lastMessage, unreadCount);
      print('📱 MessageService.updateChatReadStatus - Chat $chatId: $unreadCount messaggi non letti, ultimo: "$lastMessage"');
    } catch (e) {
      print('📱 MessageService.updateChatReadStatus - Errore critico: $e');
    }
  }

  /// Ottiene il token di autenticazione e l'ID utente
  Future<String?> _getAuthToken() async {
    try {
      print('📱 MessageService._getAuthToken - INIZIO recupero token');
      final prefs = await SharedPreferences.getInstance();
      
      // Debug: mostra tutte le chiavi salvate
      final allKeys = prefs.getKeys();
      print('📱 MessageService._getAuthToken - Chiavi disponibili: ${allKeys.where((k) => k.startsWith('securevox_')).toList()}');
      
      final token = prefs.getString('securevox_auth_token');
      final isLoggedIn = prefs.getBool('securevox_is_logged_in') ?? false;
      
      print('📱 MessageService._getAuthToken - Token presente: ${token != null}');
      print('📱 MessageService._getAuthToken - Token length: ${token?.length ?? 0}');
      print('📱 MessageService._getAuthToken - Is logged in: $isLoggedIn');
      if (token != null) {
        print('📱 MessageService._getAuthToken - Token preview: ${token.substring(0, math.min(20, token.length))}...');
      }
      
      // Recupera l'ID utente dall'oggetto user salvato
      final userJson = prefs.getString('securevox_current_user');
      if (userJson != null) {
        try {
          final userData = jsonDecode(userJson);
          _currentUserId = userData['id']?.toString();
          print('📱 MessageService._getAuthToken - User ID recuperato: $_currentUserId');
          print('📱 MessageService._getAuthToken - User data: ${userData.keys}');
        } catch (e) {
          print('📱 MessageService._getAuthToken - Errore parsing user: $e');
        }
      } else {
        print('📱 MessageService._getAuthToken - Nessun user JSON salvato');
      }
      
      // CORREZIONE: Non pulire i token personalizzati cifrati che iniziano con 'Z0FBQUFBQm'
      // Questi sono token validi del sistema di autenticazione personalizzato
      
      // Se il token è null o vuoto, pulisci lo stato di login
      if (token == null || token.isEmpty) {
        print('📱 MessageService._getAuthToken - Token non disponibile, pulizia stato login');
        await prefs.setBool('securevox_is_logged_in', false);
        return null;
      }
      
      print('📱 MessageService._getAuthToken - Token recuperato con successo');
      return token;
    } catch (e) {
      print('📱 MessageService._getAuthToken - Errore: $e');
      return null;
    }
  }

  /// Inizializza la sincronizzazione real-time
  Future<void> initializeRealtimeSync() async {
    print('📱 MessageService.initializeRealtimeSync - Inizializzazione sincronizzazione real-time');
    
    // CORREZIONE: Reset dei flag di caricamento all'inizializzazione (utile dopo hot reload)
    resetLoadingFlags();
    
    // CORREZIONE: Assicurati che _currentUserId sia impostato
    await _getAuthToken(); // Questo imposta _currentUserId se non è già impostato
    print('📱 MessageService.initializeRealtimeSync - Current User ID: $_currentUserId');
    
    // CORREZIONE: Carica lo stato di lettura salvato
    await _loadReadState();
    
    // 🔐 CORREZIONE: Carica i plaintext dei messaggi inviati cifrati
    await _loadSentMessagesPlaintext();
    
    // CORREZIONE: Inizializza sempre il UnifiedRealtimeService all'avvio
    await _initializeRealtimeSync();
    if (_unifiedRealtime != null) {
      print('✅ MessageService.initializeRealtimeSync - Sincronizzazione real-time inizializzata');
      
      // CORREZIONE: Forza l'aggiornamento della home screen quando arrivano notifiche
      // Questo assicura che il listener sia sempre attivo
      print('📱 MessageService.initializeRealtimeSync - Forzando aggiornamento home screen');
      notifyListeners();
      
      // CORREZIONE: Aggiungi un listener globale per assicurarsi che le notifiche vengano sempre gestite
      print('📱 MessageService.initializeRealtimeSync - Aggiungendo listener globale per notifiche');
      _unifiedRealtime!.addListener(_onRealtimeNotification);
    } else {
      print('❌ MessageService.initializeRealtimeSync - UnifiedRealtimeService non disponibile');
    }
  }
  
  /// Listener per le notifiche real-time
  void _onRealtimeNotification() {
    print('📱 MessageService._onRealtimeNotification - Notifica real-time ricevuta');
    notifyListeners();
  }
  
  /// Aggiunge un listener per le notifiche real-time
  void addRealtimeListener(VoidCallback listener) {
    print('📱 MessageService.addRealtimeListener - Aggiungendo listener real-time');
    addListener(listener);
    
    // Se il servizio real-time è già inizializzato, aggiungi anche il listener diretto
    if (_unifiedRealtime != null) {
      _unifiedRealtime!.addListener(_onRealtimeNotification);
    }
  }
  
  /// Rimuove un listener per le notifiche real-time
  void removeRealtimeListener(VoidCallback listener) {
    print('📱 MessageService.removeRealtimeListener - Rimuovendo listener real-time');
    removeListener(listener);
  }
      
  /// Sincronizza i dati in background
  Future<void> syncInBackground() async {
    try {
      // La sincronizzazione è gestita dal UnifiedRealtimeService
      print('📱 MessageService.syncInBackground - Sincronizzazione gestita da UnifiedRealtimeService');
    } catch (e) {
      print('❌ MessageService.syncInBackground - Errore: $e');
    }
  }

  /// Forza l'aggiornamento della home screen quando si torna dalla chat
  void forceHomeScreenUpdate() {
    print('📱 MessageService.forceHomeScreenUpdate - Forzando aggiornamento home screen');
    notifyListeners();
  }

  /// CORREZIONE: Pulisce lo stato di lettura per una chat (per debug)
  void clearReadStateForChat(String chatId) {
    _readMessageIds.remove(chatId);
    _saveReadState();
    print('📱 MessageService.clearReadStateForChat - Stato di lettura pulito per chat: $chatId');
  }

  /// CORREZIONE: Pulisce tutto lo stato di lettura (per debug)
  void clearAllReadState() {
    _readMessageIds.clear();
    _saveReadState();
    print('📱 MessageService.clearAllReadState - Tutto lo stato di lettura pulito');
  }

  /// Forza il caricamento dei messaggi per una chat (versione originale per home)
  Future<void> forceLoadMessages(String chatId) async {
    try {
      print('📱 MessageService.forceLoadMessages - Forzando caricamento messaggi per chat: $chatId');
      
      // Rimuovi dalla cache per forzare il reload
      _messageCache.remove(chatId);
      _lastFetch.remove(chatId);
      
      // Carica i messaggi
      await _loadMessagesForStream(chatId);
      
      print('📱 MessageService.forceLoadMessages - ✅ Messaggi caricati per chat: $chatId');
    } catch (e) {
      print('❌ MessageService.forceLoadMessages - Errore: $e');
    }
  }

  /// Forza il caricamento dei messaggi per una chat visualizzata (preserva stato lettura)
  Future<void> forceLoadMessagesForChatDetail(String chatId) async {
    try {
      print('📱 MessageService.forceLoadMessagesForChatDetail - Forzando caricamento messaggi per chat detail: $chatId');
      
      // 🔐 CORREZIONE: Forza SEMPRE il refresh della cache per permettere la decifratura
      // Salva lo stato di lettura prima di pulire la cache
      final readMessageIds = _readMessageIds[chatId]?.toSet() ?? <String>{};
      
      _messageCache.remove(chatId);
      _lastFetch.remove(chatId);
      print('📱 MessageService.forceLoadMessagesForChatDetail - Cache invalidata per forzare decifratura');
      
      // Carica i messaggi
      await _loadMessagesForStream(chatId);
      
      // Ripristina lo stato di lettura
      if (readMessageIds.isNotEmpty) {
        _readMessageIds[chatId] = readMessageIds;
        await _saveReadState();
        print('📱 MessageService.forceLoadMessagesForChatDetail - Stato di lettura ripristinato: ${readMessageIds.length} messaggi');
      }
      
      // CORREZIONE: Se la chat è visualizzata, marca tutti i messaggi come letti dopo il caricamento
      if (isChatCurrentlyViewing(chatId)) {
        markChatAsRead(chatId);
        print('📱 MessageService.forceLoadMessagesForChatDetail - Messaggi marcati come letti per chat visualizzata: $chatId');
      }
      
      print('📱 MessageService.forceLoadMessagesForChatDetail - ✅ Messaggi caricati per chat: $chatId');
    } catch (e) {
      print('❌ MessageService.forceLoadMessagesForChatDetail - Errore: $e');
    }
  }

  /// Parsing specifico per i dati del backend
  Future<MessageModel> _parseMessageFromBackend(Map<String, dynamic> data, String chatId) async {
    try {
      // Gestisci i valori null in modo sicuro
      final messageId = data['id']?.toString() ?? '';
      final senderId = data['sender_id']?.toString() ?? '';
      final content = data['content']?.toString() ?? '';
      final messageType = data['message_type']?.toString() ?? 'text';
      final createdAt = data['created_at']?.toString() ?? DateTime.now().toIso8601String();
      final isRead = data['is_read'] ?? false;
      
      if (messageId.isEmpty) {
        throw Exception('Message ID is empty');
      }
      
      final timestamp = DateTime.parse(createdAt);
      
      // CORREZIONE: Usa sempre UserService per l'ID utente corrente per evitare inconsistenze
      final currentUserId = UserService.getCurrentUserIdSync();
      
      // Se UserService non ha l'ID, usa quello del MessageService come fallback
      final finalCurrentUserId = currentUserId ?? _currentUserId;
      final isMe = senderId == finalCurrentUserId;
      
      // CORREZIONE: Usa lo stato di lettura persistente invece di quello dal backend
      final readMessageIds = _readMessageIds[chatId] ?? <String>{};
      final isReadPersistent = readMessageIds.contains(messageId) || isRead || isMe;
      
      // 🔐 DECIFRATURA AUTOMATICA: Decifra TUTTI i messaggi cifrati nell'app
      String displayContent = content;
      final metadata = data['metadata'] as Map<String, dynamic>?;
      final isEncrypted = metadata?['encrypted'] == true || metadata?['iv'] != null;
      
      if (isEncrypted && E2EManager.isEnabled) {
        print('');
        print('╔═══════════════════════════════════════════════════════════╗');
        print('║ 🔐 DECIFRATURA MESSAGGIO CIFRATO                         ║');
        print('╚═══════════════════════════════════════════════════════════╝');
        print('📋 Message ID: $messageId');
        print('👤 Sender ID: $senderId');
        print('👤 Current User ID: $finalCurrentUserId');
        print('🔍 Is Me: $isMe');
        print('📊 Ciphertext Length: ${content.length}');
        print('🔑 IV: ${metadata?['iv']}');
        print('🔑 MAC: ${metadata?['mac']}');
        print('📦 _sentMessagesPlaintext cache size: ${_sentMessagesPlaintext.length}');
        print('📦 Message in cache: ${_sentMessagesPlaintext.containsKey(messageId)}');
        if (_sentMessagesPlaintext.isNotEmpty) {
          print('📦 Cache keys (first 5): ${_sentMessagesPlaintext.keys.take(5).toList()}');
        }
        print('─────────────────────────────────────────────────────────');
        
        // CORREZIONE: Per messaggi inviati da me, usa la cache plaintext se disponibile
        if (isMe && _sentMessagesPlaintext.containsKey(messageId)) {
          displayContent = _sentMessagesPlaintext[messageId]!;
          print('✅ PLAINTEXT RECUPERATO DALLA CACHE!');
          print('   Message ID: $messageId');
          print('   Plaintext: ${displayContent.substring(0, displayContent.length > 50 ? 50 : displayContent.length)}...');
          print('═══════════════════════════════════════════════════════════');
          print('');
        } else {
          print('🔄 Plaintext NON in cache, procedo con decifratura...');
          if (isMe) {
            print('⚠️  ATTENZIONE: Messaggio inviato da me MA non in cache!');
            print('   Questo non dovrebbe accadere per messaggi recenti.');
          }
          // Per messaggi ricevuti (o messaggi inviati senza cache), decifrali
          try {
            final iv = metadata?['iv'] as String?;
            final mac = metadata?['mac'] as String?;
            final recipientId = metadata?['recipient_id'] as String?;
            
            if (iv != null) {
              // Prepara i dati cifrati nel formato richiesto da E2EManager
              final encryptedData = {
                'ciphertext': content,
                'iv': iv,
                if (mac != null) 'mac': mac,
              };
              
              // 🔐 CORREZIONE CRITICA: Per messaggi inviati da me, usa recipientId!
              // Per messaggi ricevuti, usa senderId
              String decryptionUserId;
              if (isMe && recipientId != null) {
                decryptionUserId = recipientId;
                print('🔐 Decifratura messaggio INVIATO: uso recipientId = $recipientId');
              } else {
                decryptionUserId = senderId;
                print('🔐 Decifratura messaggio RICEVUTO: uso senderId = $senderId');
              }
              
              final decryptedText = await E2EManager.decryptMessage(
                decryptionUserId,
                encryptedData,
              );
              
              if (decryptedText != null) {
                displayContent = decryptedText;
                print('✅ MessageService._parseMessageFromBackend - Messaggio decifrato con successo (isMe: $isMe)');
                print('   Original length: ${content.length}');
                print('   Decrypted: ${displayContent.substring(0, displayContent.length > 50 ? 50 : displayContent.length)}...');
              } else {
                print('⚠️ MessageService._parseMessageFromBackend - Decifratura fallita, mostro messaggio cifrato (isMe: $isMe)');
                displayContent = '🔒 [Messaggio cifrato]';
              }
            }
          } catch (e) {
            print('❌ MessageService._parseMessageFromBackend - Errore decifratura (isMe: $isMe): $e');
            displayContent = '🔒 [Errore decifratura]';
          }
        }
      } else if (!isEncrypted) {
        print('📝 MessageService._parseMessageFromBackend - Messaggio NON cifrato');
      }
      
      print('📱 MessageService._parseMessageFromBackend - Parsing messaggio:');
      print('📱   ID: $messageId');
      print('📱   Sender ID: $senderId (type: ${senderId.runtimeType})');
      print('📱   UserService Current ID: ${UserService.getCurrentUserIdSync()} (type: ${UserService.getCurrentUserIdSync().runtimeType})');
      print('📱   MessageService Current ID: $_currentUserId (type: ${_currentUserId.runtimeType})');
      print('📱   Final Current ID: $finalCurrentUserId (type: ${finalCurrentUserId.runtimeType})');
      print('📱   Comparison: "$senderId" == "$finalCurrentUserId" = ${senderId == finalCurrentUserId}');
      print('📱   Is Me: $isMe');
      print('📱   Is Encrypted: $isEncrypted');
      print('📱   Content: $displayContent');
      print('📱   Is Read (persistent): $isReadPersistent');
      
      return MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: senderId,
        isMe: isMe,
        type: _parseMessageType(messageType),
        content: displayContent,  // 🔐 Contenuto decifrato se era cifrato
        time: TimezoneService.formatCallTime(timestamp),
        timestamp: timestamp,
        metadata: _parseMessageMetadata(data),
        isRead: isReadPersistent,
      );
    } catch (e) {
      print('📱 MessageService._parseMessageFromBackend - Errore parsing: $e');
      print('📱 MessageService._parseMessageFromBackend - Dati: $data');
      
      // Restituisce un messaggio di errore come fallback
      return MessageModel(
        id: 'error_${DateTime.now().millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: 'system',
        isMe: false,
        type: MessageType.text,
        content: 'Errore nel caricamento del messaggio',
        time: TimezoneService.formatCallTime(DateTime.now()),
        timestamp: DateTime.now(),
        metadata: TextMessageData(text: 'Errore nel caricamento del messaggio').toJson(),
        isRead: true,
      );
    }
  }

  /// Parsing dei metadati del messaggio
  Map<String, dynamic> _parseMessageMetadata(Map<String, dynamic> data) {
    final messageType = data['message_type']?.toString() ?? 'text';
    
    switch (messageType) {
      case 'text':
        return TextMessageData(text: data['content']?.toString() ?? '').toJson();
      case 'image':
        // CORREZIONE: Cerca nei metadati del messaggio invece che nei campi diretti
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final imageUrl = metadata['imageUrl']?.toString() ?? 
                        metadata['image_url']?.toString() ?? 
                        data['imageUrl']?.toString() ?? 
                        data['image_url']?.toString() ?? '';
        final caption = metadata['caption']?.toString() ?? data['caption']?.toString();
        
        print('🖼️ CORREZIONE Parsing immagine - metadata: $metadata');
        print('🖼️ CORREZIONE imageUrl estratto: $imageUrl, caption: $caption');
        
        return ImageMessageData(
          imageUrl: imageUrl,
          caption: caption,
        ).toJson();
      case 'video':
        // CORREZIONE: Cerca nei metadati del messaggio invece che nei campi diretti
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final videoUrl = metadata['videoUrl']?.toString() ?? 
                        metadata['video_url']?.toString() ?? 
                        data['video_url']?.toString() ?? '';
        final thumbnailUrl = metadata['thumbnailUrl']?.toString() ?? 
                            metadata['thumbnail_url']?.toString() ?? 
                            data['thumbnail_url']?.toString() ?? '';
        final caption = metadata['caption']?.toString() ?? data['caption']?.toString();
        
        print('🎥 CORREZIONE Parsing video - metadata: $metadata');
        print('🎥 CORREZIONE videoUrl: $videoUrl, thumbnailUrl: $thumbnailUrl, caption: $caption');
        
        return VideoMessageData(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          caption: caption,
        ).toJson();
      case 'voice':
        // CORREZIONE: Cerca nei metadati del messaggio invece che nei campi diretti
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final duration = metadata['duration']?.toString() ?? data['duration']?.toString() ?? '0';
        final audioUrl = metadata['audioUrl']?.toString() ?? 
                        metadata['audio_url']?.toString() ?? 
                        data['audio_url']?.toString() ?? '';
        
        print('🎵 CORREZIONE Parsing audio - metadata: $metadata');
        print('🎵 CORREZIONE audioUrl: $audioUrl, duration: $duration');
        
        return VoiceMessageData(
          duration: duration,
          audioUrl: audioUrl,
        ).toJson();
      case 'file':
        // CORREZIONE: Cerca nei metadati del messaggio invece che nei campi diretti
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final fileName = metadata['fileName']?.toString() ?? 
                        metadata['file_name']?.toString() ?? 
                        data['file_name']?.toString() ?? '';
        final fileType = metadata['fileType']?.toString() ?? 
                        metadata['file_type']?.toString() ?? 
                        data['file_type']?.toString() ?? '';
        final fileUrl = metadata['fileUrl']?.toString() ?? 
                       metadata['file_url']?.toString() ?? 
                       data['file_url']?.toString() ?? '';
        final fileSize = int.tryParse(metadata['fileSize']?.toString() ?? 
                                     metadata['file_size']?.toString() ?? '0') ?? 0;
        
        // NUOVO: Estrai pdfPreviewUrl per file Office
        final pdfPreviewUrl = metadata['pdfPreviewUrl']?.toString() ?? 
                             metadata['pdf_preview_url']?.toString() ?? '';
        
        print('📎 CORREZIONE Parsing file - metadata: $metadata');
        print('📎 CORREZIONE fileName: $fileName, fileType: $fileType, fileUrl: $fileUrl, fileSize: $fileSize');
        print('📎 CORREZIONE pdfPreviewUrl: $pdfPreviewUrl');
        
        // NUOVO: Crea metadata completi con pdfPreviewUrl
        final fileMetadata = {
          'fileName': fileName,
          'fileType': fileType,
          'fileUrl': fileUrl,
          'fileSize': fileSize,
          if (pdfPreviewUrl.isNotEmpty) 'pdfPreviewUrl': pdfPreviewUrl,
          if (pdfPreviewUrl.isNotEmpty) 'pdf_preview_url': pdfPreviewUrl,
        };
        
        return fileMetadata;
      case 'location':
        return LocationMessageData(
          latitude: double.tryParse(data['latitude']?.toString() ?? '0') ?? 0.0,
          longitude: double.tryParse(data['longitude']?.toString() ?? '0') ?? 0.0,
          address: data['address']?.toString() ?? '',
          city: data['city']?.toString() ?? '',
          country: data['country']?.toString() ?? '',
        ).toJson();
      case 'contact':
        // CORREZIONE: Cerca nei metadati e nei campi diretti
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final contactName = metadata['name']?.toString() ?? 
                           data['contact_name']?.toString() ?? 
                           '';
        final contactPhone = metadata['phone']?.toString() ?? 
                            data['contact_phone']?.toString() ?? 
                            data['phone']?.toString() ?? 
                            '';
        final contactEmail = metadata['email']?.toString() ?? 
                            data['contact_email']?.toString() ?? 
                            data['email']?.toString() ?? 
                            '';
        
        print('👤 CORREZIONE Parsing contatto - metadata: $metadata');
        print('👤 CORREZIONE name: $contactName, phone: $contactPhone, email: $contactEmail');
        
        return ContactMessageData(
          name: contactName,
          phone: contactPhone,
          email: contactEmail,
          organization: '',
        ).toJson();
      default:
        return TextMessageData(text: data['content']?.toString() ?? '').toJson();
    }
  }

  /// Parsing del tipo di messaggio
  MessageType _parseMessageType(String messageType) {
    switch (messageType.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'file':
        return MessageType.file;
      case 'location':
        return MessageType.location;
      case 'contact':
        return MessageType.contact;
      default:
        return MessageType.text;
    }
  }

  /// Stream controllers per ogni chat
  final Map<String, StreamController<List<MessageModel>>> _streamControllers = {};
  
  /// Flag per evitare caricamenti multipli simultanei
  final Map<String, bool> _loadingFlags = {};

  /// Ottiene lo stream dei messaggi per una chat
  Stream<List<MessageModel>> getChatMessagesStream(String chatId) {
    // Crea un nuovo stream controller SOLO se non esiste
    if (!_streamControllers.containsKey(chatId)) {
      print('📱 MessageService.getChatMessagesStream - Creazione nuovo stream per: $chatId');
      _streamControllers[chatId] = StreamController<List<MessageModel>>.broadcast();
      
      // 🔄 FIX: Invalida la cache SOLO alla prima creazione per forzare decifratura
      // Questo evita loop infiniti ma assicura che i messaggi vengano decifrati
      _lastFetch.remove(chatId);
      _messageCache.remove(chatId);
      
      // Carica i messaggi iniziali
      _loadMessagesForStream(chatId);
    }
    
    return _streamControllers[chatId]!.stream;
  }
  
  /// Carica i messaggi per lo stream
  Future<void> _loadMessagesForStream(String chatId) async {
    // Evita caricamenti multipli simultanei
    if (_loadingFlags[chatId] == true) {
      print('📱 MessageService._loadMessagesForStream - Caricamento già in corso per chat: $chatId');
      return;
    }
    
    _loadingFlags[chatId] = true;
    
    try {
      final messages = await getChatMessages(chatId);
      
      // Emetti sempre i messaggi (anche se vuoti) per aggiornare l'UI
      _messageCache[chatId] = messages;
      notifyListeners();
      
      // Emetti i messaggi attraverso lo stream controller
      if (_streamControllers.containsKey(chatId)) {
        _streamControllers[chatId]!.add(messages);
      }
      
      print('📱 MessageService._loadMessagesForStream - ✅ Caricati ${messages.length} messaggi per stream: $chatId');
    } catch (e) {
      print('📱 MessageService._loadMessagesForStream - Errore: $e');
    } finally {
      _loadingFlags[chatId] = false;
    }
  }

  /// Simula l'arrivo di un messaggio per un altro utente (per testing)
  void simulateIncomingMessageForOtherUser(String chatId, String content, String senderId) {
    try {
      print('📱 MessageService.simulateIncomingMessageForOtherUser - Simulazione messaggio in arrivo per altro utente: $chatId');
      
      final now = DateTime.now();
      final incomingMessage = MessageModel(
        id: 'sim_${now.millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: senderId,
        isMe: false,
        type: MessageType.text,
        content: content,
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: TextMessageData(text: content).toJson(),
        isRead: false,
      );
      
      addMessageToCache(chatId, incomingMessage);
      _syncWithRealChatService(chatId, content);
      notifyListeners();
      
      print('📱 MessageService.simulateIncomingMessageForOtherUser - Messaggio in arrivo aggiunto: $content');
    } catch (e) {
      print('❌ MessageService.simulateIncomingMessageForOtherUser - Errore: $e');
    }
  }

  /// Invia un messaggio con immagine
  Future<bool> sendImageMessage({
    required String chatId,
    required String recipientId,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      print('📱 MessageService.sendImageMessage - Invio messaggio con immagine');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendImageMessage - Token non disponibile');
        return false;
      }

      // Invia il messaggio al backend
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': caption ?? '📷 Immagine',
          'message_type': 'image',
          'image_url': imageUrl,
          'caption': caption,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendImageMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        // Aggiorna la cache locale con il messaggio inviato
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.image,
          content: caption ?? '📷 Immagine',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: ImageMessageData(
            imageUrl: imageUrl,
            caption: caption,
          ).toJson(),
          isRead: true,
        );
        
        // Aggiungi alla cache
        addMessageToCache(chatId, message);
        
        // Sincronizza con RealChatService per aggiornare la lista chat
        _syncWithRealChatService(chatId, message.content);
        
        // Aggiorna lo stato di lettura della chat dopo aver inviato il messaggio
        updateChatReadStatus(chatId);
        
        // Notifica immediatamente per aggiornare la home
        notifyListeners();
        forceHomeScreenUpdate();
        
        // INVIO NOTIFICA VIA SECUREVOX NOTIFY
        print('📱 MessageService.sendImageMessage - Inizializzazione UnifiedRealtimeService...');
        await _initializeRealtimeSync();
        print('📱 MessageService.sendImageMessage - UnifiedRealtimeService inizializzato: ${_unifiedRealtime != null}');
        
        if (_unifiedRealtime != null) {
          print('📱 MessageService.sendImageMessage - Invio notifica via SecureVOX Notify...');
          print('📱   Chat ID: $chatId');
          print('📱   Recipient ID: $recipientId');
          print('📱   Message ID: ${responseData['message_id']}');
          print('📱   Content: ${caption ?? '📷 Immagine'}');
          
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: caption ?? '📷 Immagine',
            messageType: 'image',
            additionalData: {
              'image_url': imageUrl,
              'imageUrl': imageUrl, // Compatibilità con entrambi i formati
              'caption': caption,
            },
          );
          print('📱 MessageService.sendImageMessage - Notifica inviata via SecureVOX Notify');
        } else {
          print('📱 MessageService.sendImageMessage - UnifiedRealtimeService non disponibile');
        }
        
        print('📱 MessageService.sendImageMessage - Messaggio aggiunto alla cache: $chatId');
        print('📱 MessageService.sendImageMessage - Contenuto: ${caption ?? '📷 Immagine'}');
        
        return true;
      } else if (response.statusCode == 403) {
        print('📱 MessageService.sendImageMessage - Token scaduto, tentativo di refresh...');
        
        // Pulisci il token vecchio
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('securevox_auth_token');
        await prefs.setBool('securevox_is_logged_in', false);
        
        // Mostra messaggio di errore all'utente
        print('❌ Token di autenticazione scaduto. Effettua nuovamente il login.');
        return false;
      } else {
        print('📱 MessageService.sendImageMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendImageMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con video - CORREZIONE: Usa la stessa logica del testo
  Future<bool> sendVideoMessage({
    required String chatId,
    required String recipientId,
    required String videoUrl,
    String? thumbnailUrl,
    String? caption,
  }) async {
    try {
      print('📱 MessageService.sendVideoMessage - Invio messaggio con video');
      print('📱 MessageService.sendVideoMessage - Video URL: $videoUrl');
      print('📱 MessageService.sendVideoMessage - Thumbnail URL: $thumbnailUrl');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendVideoMessage - Token non disponibile');
        return false;
      }

      // CORREZIONE: Invia il messaggio al backend come per il testo
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': caption ?? '🎥 Video',
          'message_type': 'video',
          'video_url': videoUrl,
          'thumbnail_url': thumbnailUrl,
          'caption': caption,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendVideoMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        // CORREZIONE: Aggiorna la cache locale con il messaggio inviato
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.video,
          content: caption ?? '🎥 Video',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: VideoMessageData(
            videoUrl: videoUrl,
            thumbnailUrl: thumbnailUrl ?? '',
            caption: caption,
          ).toJson(),
          isRead: true,
        );
        
        // Aggiungi alla cache
        addMessageToCache(chatId, message);
        
        // Sincronizza con RealChatService per aggiornare la lista chat
        _syncWithRealChatService(chatId, message.content);
        
        // CORREZIONE: Aggiorna lo stato di lettura della chat dopo aver inviato il messaggio
        updateChatReadStatus(chatId);
        
        // CORREZIONE: Notifica immediatamente per aggiornare la home
        notifyListeners();
        forceHomeScreenUpdate();
        
        // INVIO NOTIFICA VIA SECUREVOX NOTIFY
        print('📱 MessageService.sendVideoMessage - Inizializzazione UnifiedRealtimeService...');
        await _initializeRealtimeSync();
        print('📱 MessageService.sendVideoMessage - UnifiedRealtimeService inizializzato: ${_unifiedRealtime != null}');
        
        if (_unifiedRealtime != null) {
          print('📱 MessageService.sendVideoMessage - Invio notifica via SecureVOX Notify...');
          print('📱   Chat ID: $chatId');
          print('📱   Recipient ID: $recipientId');
          print('📱   Message ID: ${responseData['message_id']}');
          print('📱   Content: ${caption ?? '🎥 Video'}');
          
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: caption ?? '🎥 Video',
            messageType: 'video',
            additionalData: {
              'video_url': videoUrl,
              'videoUrl': videoUrl, // Compatibilità con entrambi i formati
              'thumbnail_url': thumbnailUrl ?? '',
              'thumbnailUrl': thumbnailUrl ?? '', // Compatibilità con entrambi i formati
              'caption': caption,
            },
          );
          print('📱 MessageService.sendVideoMessage - Notifica inviata via SecureVOX Notify');
        } else {
          print('📱 MessageService.sendVideoMessage - UnifiedRealtimeService non disponibile');
        }
        
        print('📱 MessageService.sendVideoMessage - Messaggio aggiunto alla cache: $chatId');
        print('📱 MessageService.sendVideoMessage - Contenuto: ${caption ?? '🎥 Video'}');
        
        return true;
      } else {
        print('📱 MessageService.sendVideoMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendVideoMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con file - COPIATO DA sendVideoMessage
  Future<bool> sendFileMessage({
    required String chatId,
    required String recipientId,
    required String fileUrl,
    required String fileName,
    String? caption,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('📱 MessageService.sendFileMessage - Invio messaggio con file');
      print('📱 MessageService.sendFileMessage - File URL: $fileUrl');
      print('📱 MessageService.sendFileMessage - File Name: $fileName');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendFileMessage - Token non disponibile');
        return false;
      }

      // CORREZIONE: Invia il messaggio al backend come per il testo
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': caption ?? '📎 $fileName',
          'message_type': 'file',
          'file_url': fileUrl,
          'file_name': fileName,
          'caption': caption,
          'metadata': metadata,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendFileMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        // CORREZIONE: Aggiorna la cache locale con il messaggio inviato
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.file,
          content: caption ?? '📎 $fileName',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: {
            'file_url': fileUrl,
            'file_name': fileName,
            if (caption?.isNotEmpty == true) 'caption': caption,
            ...?metadata,
          },
          isRead: true,
        );

        addMessageToCache(chatId, message);
        notifyListeners();
        forceHomeScreenUpdate();
        
        // INVIO NOTIFICA VIA SECUREVOX NOTIFY
        print('📱 MessageService.sendFileMessage - Inizializzazione UnifiedRealtimeService...');
        await _initializeRealtimeSync();
        print('📱 MessageService.sendFileMessage - UnifiedRealtimeService inizializzato: ${_unifiedRealtime != null}');
        
        if (_unifiedRealtime != null) {
          print('📱 MessageService.sendFileMessage - Invio notifica via SecureVOX Notify...');
          print('📱   Chat ID: $chatId');
          print('📱   Recipient ID: $recipientId');
          print('📱   Message ID: ${responseData['message_id']}');
          print('📱   Content: ${caption ?? '📎 $fileName'}');
          
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: caption ?? '📎 $fileName',
            messageType: 'file',
            additionalData: {
              'file_url': fileUrl,
              'file_name': fileName,
              if (caption?.isNotEmpty == true) 'caption': caption,
              ...?metadata,
            },
          );
          print('📱 MessageService.sendFileMessage - Notifica inviata via SecureVOX Notify');
        } else {
          print('📱 MessageService.sendFileMessage - UnifiedRealtimeService non disponibile');
        }
        
        print('📱 MessageService.sendFileMessage - Messaggio aggiunto alla cache: $chatId');
        print('📱 MessageService.sendFileMessage - Contenuto: ${caption ?? '📎 $fileName'}');
        
        // CORREZIONE: Forza refresh locale per aggiornare UI
        print('📱 MessageService.sendFileMessage - Forzando refresh locale...');
        await Future.delayed(Duration(milliseconds: 500)); // Aspetta che il backend salvi
        
        // Forza aggiornamento locale
        notifyListeners();
        forceHomeScreenUpdate();
        
        return true;
      } else {
        print('📱 MessageService.sendFileMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendFileMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con documento
  Future<bool> sendDocumentMessage({
    required String chatId,
    required String recipientId,
  }) async {
    try {
      print('📱 MessageService.sendDocumentMessage - Invio messaggio con documento');
      
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.attachment,
        content: '📎 Documento.pdf',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: AttachmentMessageData(
          fileName: 'Documento.pdf',
          fileType: 'application/pdf',
          fileUrl: '',
          fileSize: 1024,
        ).toJson(),
        isRead: true,
      );

      addMessageToCache(chatId, message);
      _syncWithRealChatService(chatId, message.content);
      
      // CORREZIONE: Aggiorna lo stato di lettura della chat dopo aver inviato il messaggio
      updateChatReadStatus(chatId);
      
      notifyListeners();
          
      print('📱 MessageService.sendDocumentMessage - Documento inviato con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendDocumentMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con contatto
  Future<bool> sendContactMessage({
    required String chatId,
    required String recipientId,
    required String contactName,
    required String contactPhone,
    String? contactEmail,
  }) async {
    try {
      print('📱 MessageService.sendContactMessage - Invio messaggio con contatto');
      print('📱 MessageService.sendContactMessage - Name: $contactName');
      print('📱 MessageService.sendContactMessage - Phone: $contactPhone');
      print('📱 MessageService.sendContactMessage - Email: $contactEmail');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendContactMessage - Token non disponibile');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': '👤 $contactName',
          'message_type': 'contact',
          'contact_name': contactName,
          'contact_phone': contactPhone,
          'contact_email': contactEmail ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendContactMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.contact,
          content: '👤 $contactName',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: ContactMessageData(
            name: contactName,
            phone: contactPhone,
            email: contactEmail,
            organization: '',
          ).toJson(),
          isRead: true,
        );

        addMessageToCache(chatId, message);
        notifyListeners();
        forceHomeScreenUpdate();
        
        await _initializeRealtimeSync();
        if (_unifiedRealtime != null) {
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: '👤 $contactName',
            messageType: 'contact',
            additionalData: {
              'contact_name': contactName,
              'contact_phone': contactPhone,
              'contact_email': contactEmail ?? '',
            },
          );
        }
        
        return true;
      } else {
        print('📱 MessageService.sendContactMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendContactMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con posizione
  Future<bool> sendLocationMessage({
    required String chatId,
    required String recipientId,
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? country,
  }) async {
    try {
      print('📱 MessageService.sendLocationMessage - Invio messaggio con posizione');
      print('📱 MessageService.sendLocationMessage - Lat: $latitude, Lng: $longitude');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendLocationMessage - Token non disponibile');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': '📍 Posizione',
          'message_type': 'location',
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? '',
          'city': city ?? '',
          'country': country ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendLocationMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.location,
          content: '📍 Posizione',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: LocationMessageData(
            latitude: latitude,
            longitude: longitude,
            address: address ?? '',
            city: city ?? '',
            country: country ?? '',
          ).toJson(),
          isRead: true,
        );

        addMessageToCache(chatId, message);
        notifyListeners();
        forceHomeScreenUpdate();
        
        await _initializeRealtimeSync();
        if (_unifiedRealtime != null) {
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: '📍 Posizione',
            messageType: 'location',
            additionalData: {
              'latitude': latitude,
              'longitude': longitude,
              'address': address ?? '',
              'city': city ?? '',
              'country': country ?? '',
            },
          );
        }
        
        return true;
      } else {
        print('📱 MessageService.sendLocationMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendLocationMessage - Errore: $e');
      return false;
    }
  }

  /// Elimina un messaggio solo per l'utente corrente (eliminazione locale)
  Future<bool> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    try {
      print('🗑️ MessageService.deleteMessage - Eliminazione messaggio: $messageId dalla chat: $chatId');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('🗑️ MessageService.deleteMessage - Token non disponibile');
        return false;
      }

      // Chiama l'API per eliminare il messaggio
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/messages/$messageId/delete/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      print('🗑️ MessageService.deleteMessage - Risposta API: ${response.statusCode}');
      print('🗑️ MessageService.deleteMessage - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('🗑️ MessageService.deleteMessage - Messaggio eliminato dal backend: ${responseData['message_id']}');
        
        // Rimuovi il messaggio dalla cache locale
        if (_messageCache.containsKey(chatId)) {
          _messageCache[chatId]!.removeWhere((msg) => msg.id == messageId);
          
          // Emetti i messaggi aggiornati attraverso lo stream controller
          if (_streamControllers.containsKey(chatId)) {
            _streamControllers[chatId]!.add(_messageCache[chatId]!);
          }
          
          print('🗑️ MessageService.deleteMessage - Messaggio rimosso dalla cache locale');
        }
        
        // Aggiorna lo stato di lettura della chat
        updateChatReadStatus(chatId);
        
        // Notifica i listener per aggiornare l'UI
        notifyListeners();
        forceHomeScreenUpdate();
        
        print('✅ MessageService.deleteMessage - Eliminazione completata con successo');
        return true;
      } else {
        print('❌ MessageService.deleteMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ MessageService.deleteMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio audio
  Future<bool> sendVoiceMessage({
    required String chatId,
    required String recipientId,
    required String audioPath,
    required String duration,
  }) async {
    try {
      print('📱 MessageService.sendVoiceMessage - Invio messaggio audio');
      
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.voice,
        content: '🎤 Audio',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: VoiceMessageData(
          duration: duration,
          audioUrl: '',
        ).toJson(),
        isRead: true,
      );

      addMessageToCache(chatId, message);
      _syncWithRealChatService(chatId, message.content);
      
      // CORREZIONE: Aggiorna lo stato di lettura della chat dopo aver inviato il messaggio
      updateChatReadStatus(chatId);
      
      notifyListeners();
      
      print('📱 MessageService.sendVoiceMessage - Audio inviato con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendVoiceMessage - Errore: $e');
      return false;
    }
  }
}
