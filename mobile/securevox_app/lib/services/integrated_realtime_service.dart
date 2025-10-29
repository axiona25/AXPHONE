import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';
import 'real_chat_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

/// Servizio integrato per la sincronizzazione realtime
/// Combina Django API, SecureVOX Notify e gestione locale
class IntegratedRealtimeService extends ChangeNotifier {
  static final IntegratedRealtimeService _instance = IntegratedRealtimeService._internal();
  factory IntegratedRealtimeService() => _instance;
  IntegratedRealtimeService._internal();

  // URL dei server
  final String djangoBaseUrl = 'http://127.0.0.1:8001/api';
  final String notifyServerUrl = 'http://127.0.0.1:8002';
  
  // Stato del servizio
  bool _isInitialized = false;
  bool _isConnected = false;
  String? _deviceToken;
  String? _currentUserId;
  Timer? _pollingTimer;
  Timer? _heartbeatTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  String? get deviceToken => _deviceToken;
  String? get currentUserId => _currentUserId;

  /// Inizializza il servizio completo
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🚀 IntegratedRealtimeService - Inizializzazione...');
      
      // 1. Ottieni i dati dell'utente corrente
      await _loadUserData();
      
      // 2. Genera token dispositivo
      await _generateDeviceToken();
      
      // 3. Registra dispositivo con Django
      await _registerWithDjango();
      
      // 4. Registra dispositivo con SecureVOX Notify
      await _registerWithNotifyServer();
      
      // 5. Avvia servizi realtime
      await _startRealtimeServices();
      
      _isInitialized = true;
      _isConnected = true;
      
      print('✅ IntegratedRealtimeService - Inizializzazione completata');
      notifyListeners();
      
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore inizializzazione: $e');
      _isConnected = false;
    }
  }

  /// Carica i dati dell'utente corrente
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('securevox_user_id');
      
      if (_currentUserId == null) {
        throw Exception('Utente non autenticato');
      }
      
      print('👤 IntegratedRealtimeService - Utente caricato: $_currentUserId');
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore caricamento utente: $e');
      rethrow;
    }
  }

  /// Genera un token dispositivo univoco
  Future<void> _generateDeviceToken() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _deviceToken = 'securevox_ios_$timestamp';
      
      // Salva il token localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_token', _deviceToken!);
      
      print('🔑 IntegratedRealtimeService - Token dispositivo generato: $_deviceToken');
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore generazione token: $e');
      rethrow;
    }
  }

  /// Registra il dispositivo con Django
  Future<void> _registerWithDjango() async {
    if (_deviceToken == null || _currentUserId == null) return;
    
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) return;

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('securevox_user_name') ?? 'user';
      
      final response = await http.post(
        Uri.parse('$djangoBaseUrl/devices/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({
          'username': username,
          'device_name': 'Flutter App',
          'device_type': 'mobile',
          'device_fingerprint': 'flutter_${DateTime.now().millisecondsSinceEpoch}',
          'fcm_token': _deviceToken,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ IntegratedRealtimeService - Dispositivo registrato con Django');
      } else {
        print('⚠️ IntegratedRealtimeService - Errore registrazione Django: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore registrazione Django: $e');
    }
  }

  /// Registra il dispositivo con SecureVOX Notify
  Future<void> _registerWithNotifyServer() async {
    if (_deviceToken == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$notifyServerUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'device_token': _deviceToken,
          'device_type': 'ios',
          'device_id': 'flutter_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ IntegratedRealtimeService - Dispositivo registrato con SecureVOX Notify');
      } else {
        print('⚠️ IntegratedRealtimeService - Errore registrazione SecureVOX Notify: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore registrazione SecureVOX Notify: $e');
    }
  }

  /// Avvia i servizi realtime
  Future<void> _startRealtimeServices() async {
    try {
      // Avvia polling per messaggi
      _startMessagePolling();
      
      // Avvia heartbeat
      _startHeartbeat();
      
      print('🔄 IntegratedRealtimeService - Servizi realtime avviati');
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore avvio servizi: $e');
      rethrow;
    }
  }

  /// Avvia il polling per i messaggi
  void _startMessagePolling() {
    if (_deviceToken == null) return;
    
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        await _pollForMessages();
      } catch (e) {
        print('❌ IntegratedRealtimeService - Errore polling: $e');
      }
    });
    
    print('📡 IntegratedRealtimeService - Polling messaggi avviato');
  }

  /// Polling per i messaggi dal server SecureVOX Notify
  Future<void> _pollForMessages() async {
    if (_deviceToken == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('$notifyServerUrl/poll/$_deviceToken'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['messages'] != null && (data['messages'] as List).isNotEmpty) {
            for (final message in data['messages']) {
              await _handleIncomingMessage(message);
            }
          }
          
          // Gestisci anche notifiche di eliminazione chat
          if (data['notifications'] != null && (data['notifications'] as List).isNotEmpty) {
            for (final notification in data['notifications']) {
              await _handleIncomingNotification(notification);
            }
          }
        }
    } catch (e) {
      // Non loggare errori di polling per evitare spam
    }
  }

  /// Gestisce i messaggi in arrivo
  Future<void> _handleIncomingMessage(Map<String, dynamic> messageData) async {
    try {
      print('📨 IntegratedRealtimeService - Nuovo messaggio ricevuto: ${messageData['message_id']}');
      
      final chatId = messageData['chat_id']?.toString();
      final messageId = messageData['message_id']?.toString();
      final senderId = messageData['sender_id']?.toString();
      final content = messageData['content']?.toString() ?? '';
      final messageType = messageData['message_type']?.toString() ?? 'text';
      final timestamp = messageData['timestamp']?.toString();

      if (chatId == null || messageId == null) {
        print('⚠️ IntegratedRealtimeService - Dati messaggio incompleti');
        return;
      }

      // Crea il modello del messaggio
      final now = DateTime.now();
      final incomingMessage = MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: senderId ?? 'unknown',
        isMe: senderId == _currentUserId,
        type: _parseMessageType(messageType),
        content: content,
        time: _formatTime(timestamp ?? now.toIso8601String()),
        timestamp: timestamp != null ? DateTime.parse(timestamp) : now,
        metadata: TextMessageData(text: content).toJson(),
        isRead: false,
      );

      // Aggiungi il messaggio alla cache
      final messageService = MessageService();
      messageService.addMessageToCache(chatId, incomingMessage);
      
      // Aggiorna la chat nella cache
      _updateChatWithNewMessage(chatId, content);
      
      // Notifica i listener
      messageService.notifyListeners();
      notifyListeners();
      
      print('✅ IntegratedRealtimeService - Messaggio processato: $messageId');
      
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore gestione messaggio: $e');
    }
  }

  /// Aggiorna la chat con un nuovo messaggio
  void _updateChatWithNewMessage(String chatId, String content) {
    try {
      RealChatService.updateChatInCache(ChatModel(
        id: chatId,
        name: 'Chat $chatId',
        lastMessage: content,
        timestamp: DateTime.now(),
        avatarUrl: '',
        isOnline: false,
        unreadCount: 1,
        isGroup: false,
      ));
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore aggiornamento chat: $e');
    }
  }

  /// Gestisce le notifiche in arrivo (eliminazione chat, ecc.)
  Future<void> _handleIncomingNotification(Map<String, dynamic> notificationData) async {
    try {
      final type = notificationData['type']?.toString();
      
      if (type == 'chat_deleted') {
        await _handleChatDeletionNotification(notificationData);
      } else {
        print('📨 IntegratedRealtimeService - Notifica sconosciuta: $type');
      }
      
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore gestione notifica: $e');
    }
  }

  /// Gestisce la notifica di eliminazione chat
  Future<void> _handleChatDeletionNotification(Map<String, dynamic> data) async {
    try {
      final chatId = data['chat_id']?.toString();
      final chatName = data['chat_name']?.toString() ?? 'Chat';
      final deletedBy = data['deleted_by_name']?.toString() ?? 'Utente';
      
      if (chatId == null) {
        print('⚠️ IntegratedRealtimeService - Chat ID mancante nella notifica eliminazione');
        return;
      }

      print('🗑️ IntegratedRealtimeService - Chat eliminata: $chatName (da $deletedBy)');
      
      // Rimuovi la chat dalla cache locale
      RealChatService.removeChatFromCache(chatId);
      
      // Rimuovi i messaggi della chat dalla cache
      final messageService = MessageService();
      messageService.clearChatMessages(chatId);
      
      // Notifica i listener per aggiornare l'UI
      messageService.notifyListeners();
      notifyListeners();
      
      print('✅ IntegratedRealtimeService - Chat $chatId rimossa dalla cache locale');
      
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore gestione eliminazione chat: $e');
    }
  }

  /// Avvia il heartbeat per mantenere la connessione
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      try {
        await _sendHeartbeat();
      } catch (e) {
        print('❌ IntegratedRealtimeService - Errore heartbeat: $e');
        _isConnected = false;
        notifyListeners();
      }
    });
  }

  /// Invia heartbeat al server
  Future<void> _sendHeartbeat() async {
    if (_deviceToken == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('$notifyServerUrl/health'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _isConnected = true;
      } else {
        _isConnected = false;
      }
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  /// Invia un messaggio con notifica realtime
  Future<bool> sendMessageWithNotification({
    required String chatId,
    required String recipientId,
    required String content,
    required String messageType,
  }) async {
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) return false;

      // 1. Invia il messaggio tramite Django API
      final response = await http.post(
        Uri.parse('$djangoBaseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({
          'content': content,
          'message_type': messageType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messageId = data['message_id'];
        
        // 2. Invia notifica realtime
        await _sendRealtimeNotification(
          chatId: chatId,
          recipientId: recipientId,
          messageId: messageId,
          content: content,
          messageType: messageType,
        );
        
        return true;
      } else {
        print('❌ IntegratedRealtimeService - Errore invio messaggio: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore invio messaggio: $e');
      return false;
    }
  }

  /// Invia notifica realtime
  Future<void> _sendRealtimeNotification({
    required String chatId,
    required String recipientId,
    required String messageId,
    required String content,
    required String messageType,
  }) async {
    try {
      final authToken = await _getAuthToken();
      if (authToken == null) return;

      final prefs = await SharedPreferences.getInstance();
      final senderName = prefs.getString('securevox_user_name') ?? 'Utente';
      
      // Invia tramite Django API
      await http.post(
        Uri.parse('$djangoBaseUrl/notifications/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $authToken',
        },
        body: jsonEncode({
          'chat_id': chatId,
          'recipient_id': recipientId,
          'message_id': messageId,
          'content': content,
          'message_type': messageType,
          'sender_name': senderName,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      
      print('✅ IntegratedRealtimeService - Notifica inviata');
    } catch (e) {
      print('❌ IntegratedRealtimeService - Errore notifica: $e');
    }
  }

  /// Ottiene il token di autenticazione
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      return null;
    }
  }

  /// Converte il tipo di messaggio
  MessageType _parseMessageType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.voice;
      case 'file':
        return MessageType.attachment;
      default:
        return MessageType.text;
    }
  }

  /// Formatta il tempo
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return DateTime.now().toString().substring(11, 16);
    }
  }

  /// Disconnette il servizio
  @override
  void dispose() {
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
    _isConnected = false;
    super.dispose();
  }
}
