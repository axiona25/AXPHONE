import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';  // Temporaneamente disabilitato
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
// import 'package:contacts_service/contacts_service.dart'; // Temporaneamente disabilitato
import '../models/message_model.dart';
import '../models/chat_model.dart';
import 'timezone_service.dart';
import 'unified_realtime_service.dart';
import 'real_chat_service.dart';
import 'user_service.dart';

/// Servizio unificato per la gestione dei messaggi
/// Usa SOLO SecureVOX Notify per le notifiche real-time
class MessageService extends ChangeNotifier {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  
  // Cache per i messaggi
  final Map<String, List<MessageModel>> _messageCache = {};
  final Map<String, DateTime> _lastFetch = {};
  final Map<String, int> _unreadCounts = {};
  
  // Traccia quale chat è attualmente visualizzata
  String? _currentlyViewingChatId;
  static const Duration cacheExpiry = Duration(minutes: 5);
  
  // Servizio unificato per real-time
  UnifiedRealtimeService? _unifiedRealtime;

  /// Inizializza il servizio realtime unificato
  Future<void> _initializeRealtimeSync() async {
    if (_unifiedRealtime == null) {
      try {
        print('📱 MessageService._initializeRealtimeSync - Inizializzazione UnifiedRealtimeService...');
        _unifiedRealtime = UnifiedRealtimeService();
        await _unifiedRealtime!.initialize();
        print('✅ MessageService - UnifiedRealtimeService inizializzato');
      } catch (e) {
        print('❌ MessageService - Errore inizializzazione UnifiedRealtimeService: $e');
      }
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

      // Invia il messaggio al backend
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': text,
          'message_type': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendTextMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        // Aggiorna la cache locale con il messaggio inviato
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true,
          type: MessageType.text,
          content: text,
          time: TimezoneService.formatTime(now),
          timestamp: now,
          metadata: TextMessageData(text: text).toJson(),
          isRead: true,
        );

        // Aggiungi alla cache
        addMessageToCache(chatId, message);
        
        // Sincronizza con RealChatService per aggiornare la lista chat
        _syncWithRealChatService(chatId, text);
        
        notifyListeners();
        
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
      // Controlla se la cache è ancora valida
      if (_messageCache.containsKey(chatId) && 
          _lastFetch.containsKey(chatId) &&
          DateTime.now().difference(_lastFetch[chatId]!) < cacheExpiry) {
        print('📱 MessageService.getChatMessages - Usando cache per chat: $chatId');
        return _messageCache[chatId]!;
      }

      // Carica i messaggi dal backend
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.getChatMessages - Token non disponibile');
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = (data['messages'] as List)
            .map((msg) => MessageModel.fromJson(msg))
            .toList();

        // Ordina per timestamp
        messages.sort((a, b) => a.time.compareTo(b.time));
        
        // Aggiorna la cache
        _messageCache[chatId] = messages;
        _lastFetch[chatId] = DateTime.now();
        
        print('📱 MessageService.getChatMessages - Caricati ${messages.length} messaggi per chat: $chatId');
        return messages;
      } else {
        print('📱 MessageService.getChatMessages - Errore backend: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('📱 MessageService.getChatMessages - Errore: $e');
      return [];
    }
  }

  /// Aggiunge un messaggio alla cache
  void addMessageToCache(String chatId, MessageModel message) {
    if (!_messageCache.containsKey(chatId)) {
      _messageCache[chatId] = [];
    }
    _messageCache[chatId]!.add(message);
    
    print('📱 MessageService.addMessageToCache - Messaggio aggiunto alla cache: $chatId');
    print('📱 MessageService.addMessageToCache - Contenuto: ${message.content}');
    
    notifyListeners();
  }

  /// Marca una chat come attualmente visualizzata
  void markChatAsCurrentlyViewing(String chatId) {
    _currentlyViewingChatId = chatId;
    print('📱 MessageService.markChatAsCurrentlyViewing - Chat $chatId marcata come visualizzata');
    
    // Marca automaticamente tutti i messaggi non letti come letti
    markChatAsRead(chatId);
  }

  /// Marca una chat come non più visualizzata
  void markChatAsNotViewing() {
    _currentlyViewingChatId = null;
    print('📱 MessageService.markChatAsNotViewing - Nessuna chat visualizzata');
  }

  /// Marca tutti i messaggi di una chat come letti
  void markChatAsRead(String chatId) {
    print('📱 MessageService.markChatAsRead - Chat $chatId marcata come letta');
    
    final messages = _messageCache[chatId] ?? [];
    bool hasChanges = false;
    
    for (int i = 0; i < messages.length; i++) {
      final message = messages[i];
      if (!message.isMe && !message.isRead) {
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
        hasChanges = true;
        print('📱 MessageService.markChatAsRead - ✅ Messaggio marcato come letto: ${message.content}');
      }
    }
    
    if (hasChanges) {
      _messageCache[chatId] = messages;
      _updateChatReadStatus(chatId);
      notifyListeners();
      print('📱 MessageService.markChatAsRead - ✅ Cache aggiornata e stato salvato');
    } else {
      print('📱 MessageService.markChatAsRead - ⚠️ Nessun cambiamento necessario');
    }
  }

  /// Calcola il numero di messaggi non letti per una chat
  int getUnreadCount(String chatId) {
    final messages = _messageCache[chatId] ?? [];
    final unreadCount = messages.where((msg) => !msg.isMe && !msg.isRead).length;
    
    if (messages.isEmpty) {
      print('📱 MessageService.getUnreadCount - Chat $chatId: 0 messaggi non letti (cache vuota)');
      return 0;
    }
    
    print('📱 MessageService.getUnreadCount - Chat $chatId: $unreadCount messaggi non letti');
    return unreadCount;
  }

  /// Ottiene l'ultimo messaggio di una chat
  String getLastMessage(String chatId) {
    final messages = _messageCache[chatId] ?? [];
    if (messages.isEmpty) {
      return '';
    }
    
    messages.sort((a, b) => b.time.compareTo(a.time));
    return messages.first.content;
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
  void _updateChatReadStatus(String chatId) {
    try {
      final unreadCount = getUnreadCount(chatId);
      final lastMessage = getLastMessage(chatId);
      _unreadCounts[chatId] = unreadCount;
      RealChatService.updateChatLastMessage(chatId, lastMessage, unreadCount);
      print('📱 MessageService._updateChatReadStatus - Chat $chatId: $unreadCount messaggi non letti, ultimo: "$lastMessage"');
    } catch (e) {
      print('📱 MessageService._updateChatReadStatus - Errore critico: $e');
    }
  }

  /// Ottiene il token di autenticazione
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      print('📱 MessageService._getAuthToken - Errore: $e');
      return null;
    }
  }

  /// Inizializza la sincronizzazione real-time
  Future<void> initializeRealtimeSync() async {
    print('📱 MessageService.initializeRealtimeSync - Inizializzazione sincronizzazione real-time');
    await _initializeRealtimeSync();
    if (_unifiedRealtime != null) {
      await _unifiedRealtime!.initialize();
      print('✅ MessageService.initializeRealtimeSync - Sincronizzazione real-time inizializzata');
    } else {
      print('❌ MessageService.initializeRealtimeSync - UnifiedRealtimeService non disponibile');
    }
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
}
