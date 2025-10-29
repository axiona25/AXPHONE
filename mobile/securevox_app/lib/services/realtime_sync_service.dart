import 'dart:async';
import 'dart:convert';
// Firebase rimosso - usando SecureVOX Notify
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'message_service.dart';
import 'timezone_service.dart';
import 'real_chat_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';

/// Servizio per la sincronizzazione real-time dei messaggi tramite Firebase
class RealtimeSyncService extends ChangeNotifier {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  // URL del server principale Django
  final String baseUrl = 'http://127.0.0.1:8001/api';
  
  // URL del server SecureVOX Notify per le notifiche realtime
  final String notifyServerUrl = 'http://127.0.0.1:8002';
  
  StreamSubscription? _messageSubscription;
  bool _isInitialized = false;
  String? _fcmToken;
  String? _currentUserId;

  /// Inizializza il servizio di sincronizzazione real-time
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Richiedi permessi per le notifiche
      await _requestNotificationPermissions();
      
      // Genera un token univoco per questo dispositivo
      _fcmToken = 'securevox_ios_${DateTime.now().millisecondsSinceEpoch}';
      
      // Registra il dispositivo per le notifiche push
      await _registerDeviceForPush();
      
      // Configura i listener per i messaggi in arrivo
      await _setupMessageListeners();
      
      // Ottieni l'ID utente corrente
      await _getCurrentUserId();
      
      _isInitialized = true;
      
    } catch (e) {
      print('🔄 RealtimeSyncService.initialize - Errore: $e');
    }
  }

  /// Richiede i permessi per le notifiche
  Future<void> _requestNotificationPermissions() async {
    try {
      // Firebase rimosso - SecureVOX Notify gestisce i permessi
      print('📱 RealtimeSyncService._requestNotificationPermissions - Permessi gestiti da SecureVOX Notify');
    } catch (e) {
      print('🔄 RealtimeSyncService._requestNotificationPermissions - Errore: $e');
    }
  }

  /// Registra il dispositivo per ricevere notifiche push
  Future<void> _registerDeviceForPush() async {
    if (_fcmToken == null) return;
    
    try {
      final token = await _getAuthToken();
      if (token == null) return;

      // Verifica che il token di autenticazione sia disponibile
      
      final response = await http.post(
        Uri.parse('$baseUrl/devices/register/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'device_name': 'Flutter App',
          'device_type': 'mobile',
          'device_fingerprint': 'flutter_${DateTime.now().millisecondsSinceEpoch}',
          'fcm_token': _fcmToken,
        }),
      );

      if (response.statusCode == 200) {
        // Debug: dispositivo registrato per push
      } else {
        print('🔄 RealtimeSyncService._registerDeviceForPush - Errore registrazione: ${response.statusCode}');
      }
    } catch (e) {
      print('🔄 RealtimeSyncService._registerDeviceForPush - Errore: $e');
    }
  }

  /// Configura i listener per i messaggi in arrivo
  Future<void> _setupMessageListeners() async {
    try {
      // Registra il dispositivo con SecureVOX Notify
      await _registerWithSecureVoxNotify();
      
      // Avvia il polling per i messaggi
      _startMessagePolling();
      
      print('📱 RealtimeSyncService._setupMessageListeners - Listener configurati con SecureVOX Notify');
    } catch (e) {
      print('🔄 RealtimeSyncService._setupMessageListeners - Errore: $e');
    }
  }

  /// Registra il dispositivo con SecureVOX Notify
  Future<void> _registerWithSecureVoxNotify() async {
    if (_fcmToken == null) return;
    
    try {
      final payload = {
        'device_token': _fcmToken,
        'user_id': _currentUserId ?? 'unknown',
        'platform': 'ios',
        'app_version': '1.0.0',
      };
      
      print('🔄 RealtimeSyncService._registerWithSecureVoxNotify - Registrazione dispositivo:');
      print('🔄   Device Token: $_fcmToken');
      print('🔄   User ID: $_currentUserId');
      print('🔄   Payload: ${jsonEncode(payload)}');
      
      final response = await http.post(
        Uri.parse('$notifyServerUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('🔄 RealtimeSyncService._registerWithSecureVoxNotify - Risposta server: ${response.statusCode}');
      print('🔄 RealtimeSyncService._registerWithSecureVoxNotify - Body risposta: ${response.body}');

      if (response.statusCode == 200) {
        print('📱 RealtimeSyncService._registerWithSecureVoxNotify - Dispositivo registrato con SecureVOX Notify');
      } else {
        print('🔄 RealtimeSyncService._registerWithSecureVoxNotify - Errore registrazione: ${response.statusCode}');
      }
    } catch (e) {
      print('🔄 RealtimeSyncService._registerWithSecureVoxNotify - Errore: $e');
    }
  }

  /// Avvia il polling per i messaggi
  void _startMessagePolling() {
    if (_fcmToken == null) return;
    
    print('🔄 RealtimeSyncService._startMessagePolling - Avvio polling con token: $_fcmToken');
    
    // Polling ogni 2 secondi per i messaggi
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final response = await http.get(
          Uri.parse('$notifyServerUrl/poll/$_fcmToken'),
          headers: {
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('🔄 RealtimeSyncService._startMessagePolling - Risposta polling: ${data.toString()}');
          
          if (data['messages'] != null && (data['messages'] as List).isNotEmpty) {
            print('🔄 RealtimeSyncService._startMessagePolling - Trovati ${(data['messages'] as List).length} messaggi');
            for (final message in data['messages']) {
              _handleIncomingMessage(message);
            }
          } else {
            print('🔄 RealtimeSyncService._startMessagePolling - Nessun messaggio in arrivo');
          }
        } else {
          print('🔄 RealtimeSyncService._startMessagePolling - Errore polling: ${response.statusCode}');
        }
      } catch (e) {
        print('🔄 RealtimeSyncService._startMessagePolling - Errore polling: $e');
      }
    });
  }

  /// Gestisce i messaggi in arrivo
  void _handleIncomingMessage(Map<String, dynamic> message) {
    try {
      print('🔄 RealtimeSyncService._handleIncomingMessage - Gestione messaggio: ${message['id']}');
      
      final data = message;
      final chatId = data['chat_id'];
      final messageId = data['message_id'];
      final senderId = data['sender_id'];
      final content = data['content'];
      final messageType = data['message_type'];
      final timestamp = data['timestamp'];

      if (chatId == null || messageId == null) {
        print('🔄 RealtimeSyncService._handleIncomingMessage - Dati mancanti nel messaggio');
        return;
      }

      // Crea il messaggio dal payload
      final now = DateTime.now();
      final incomingMessage = MessageModel(
        id: messageId,
        chatId: chatId,
        senderId: senderId ?? 'unknown',
        isMe: senderId == _currentUserId,
        type: _parseMessageType(messageType ?? 'text'),
        content: content ?? '',
        time: _formatTime(timestamp ?? now.toIso8601String()),
        timestamp: timestamp != null ? DateTime.parse(timestamp) : now,
        metadata: TextMessageData(text: content ?? '').toJson(),
        isRead: false,
      );

      // Aggiungi il messaggio alla cache del MessageService
      final messageService = MessageService();
      messageService.addMessageToCache(chatId, incomingMessage);
      
      // Aggiorna la lista chat in background senza forzare l'UI
      _updateChatListWithNewMessage(chatId, content ?? '');
      
      print('🔄 RealtimeSyncService._handleIncomingMessage - Messaggio aggiunto alla cache: $chatId');
      
      // Notifica i listener solo se necessario (evita refresh inutili)
      messageService.notifyListeners();
      
    } catch (e) {
      print('🔄 RealtimeSyncService._handleIncomingMessage - Errore: $e');
    }
  }

  /// Aggiorna la lista chat con un nuovo messaggio in background
  void _updateChatListWithNewMessage(String chatId, String content) {
    try {
      print('🔄 RealtimeSyncService._updateChatListWithNewMessage - Aggiornamento chat $chatId in background');
      
      // Aggiorna solo la cache, non l'UI
      RealChatService.updateChatInCache(ChatModel(
        id: chatId,
        name: 'Chat $chatId', // Nome generico, sarà aggiornato dal backend
        lastMessage: content,
        timestamp: DateTime.now(),
        avatarUrl: '',
        isOnline: false,
        unreadCount: 1, // Nuovo messaggio non letto
        isGroup: false,
      ));
      
      print('🔄 RealtimeSyncService._updateChatListWithNewMessage - Chat aggiornata in background: $chatId');
    } catch (e) {
      print('🔄 RealtimeSyncService._updateChatListWithNewMessage - Errore: $e');
    }
  }

  /// Ottiene l'ID utente corrente
  Future<void> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('securevox_user_id');
      // Debug: user ID recuperato
    } catch (e) {
      print('🔄 RealtimeSyncService._getCurrentUserId - Errore: $e');
    }
  }

  /// Ottiene il token di autenticazione
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      print('🔄 RealtimeSyncService._getAuthToken - Errore: $e');
      return null;
    }
  }

  /// Converte il tipo di messaggio dal backend
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

  /// Formatta il tempo dal backend
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return TimezoneService.formatCallTime(dateTime);
    } catch (e) {
      return TimezoneService.formatCallTime(DateTime.now());
    }
  }

  /// Invia una notifica push per un nuovo messaggio
  Future<void> sendPushNotification({
    required String chatId,
    required String recipientId,
    required String messageId,
    required String content,
    required String messageType,
  }) async {
    try {
      // Ottieni il nome del mittente
      final senderName = await _getSenderName();
      
      // Invia direttamente tramite SecureVOX Notify per la consegna realtime
      await _sendViaSecureVoxNotify(
        recipientId: recipientId,
        chatId: chatId,
        messageId: messageId,
        content: content,
        messageType: messageType,
        senderName: senderName,
      );
      
      print('🔄 RealtimeSyncService.sendPushNotification - Notifica inviata via SecureVOX Notify');
    } catch (e) {
      print('🔄 RealtimeSyncService.sendPushNotification - Errore: $e');
    }
  }

  /// Invia notifica tramite SecureVOX Notify
  Future<void> _sendViaSecureVoxNotify({
    required String recipientId,
    required String chatId,
    required String messageId,
    required String content,
    required String messageType,
    required String senderName,
  }) async {
    try {
      final payload = {
        'recipient_id': recipientId,
        'chat_id': chatId,
        'message_id': messageId,
        'content': content,
        'message_type': messageType,
        'sender_name': senderName,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      print('🔄 RealtimeSyncService._sendViaSecureVoxNotify - Invio notifica:');
      print('🔄   Recipient ID: $recipientId');
      print('🔄   Chat ID: $chatId');
      print('🔄   Message ID: $messageId');
      print('🔄   Content: $content');
      print('🔄   Payload: ${jsonEncode(payload)}');
      
      final response = await http.post(
        Uri.parse('$notifyServerUrl/send'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      print('🔄 RealtimeSyncService._sendViaSecureVoxNotify - Risposta server: ${response.statusCode}');
      print('🔄 RealtimeSyncService._sendViaSecureVoxNotify - Body risposta: ${response.body}');

      if (response.statusCode == 200) {
        print('🔄 RealtimeSyncService._sendViaSecureVoxNotify - Notifica inviata via SecureVOX Notify');
      } else {
        print('🔄 RealtimeSyncService._sendViaSecureVoxNotify - Errore: ${response.statusCode}');
      }
    } catch (e) {
      print('🔄 RealtimeSyncService._sendViaSecureVoxNotify - Errore: $e');
    }
  }

  /// Ottiene il nome del mittente per le notifiche
  Future<String> _getSenderName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_user_name') ?? 'Utente';
    } catch (e) {
      print('🔄 RealtimeSyncService._getSenderName - Errore: $e');
      return 'Utente';
    }
  }

  /// Disconnette il servizio
  @override
  void dispose() {
    _messageSubscription?.cancel();
    super.dispose();
  }
}

/// Handler per i messaggi in background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(Map<String, dynamic> message) async {
  print('🔄 _firebaseMessagingBackgroundHandler - Messaggio in background: ${message['id']}');
  
  // Firebase rimosso - SecureVOX Notify gestisce i messaggi in background
}
