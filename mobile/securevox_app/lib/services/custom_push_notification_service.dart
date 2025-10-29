import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'user_service.dart';

/// SecureVOX Notify - Servizio di notifiche push personalizzato
/// Sostituisce completamente Firebase per iOS, Android e Web
class CustomPushNotificationService {
  static final CustomPushNotificationService _instance = CustomPushNotificationService._internal();
  factory CustomPushNotificationService() => _instance;
  CustomPushNotificationService._internal();

  // Server di notifiche personalizzato
  static const String _notificationServerUrl = 'http://127.0.0.1:8002';
  
  // Stream per i messaggi in arrivo
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Timer per il polling delle notifiche (fallback se WebSocket non funziona)
  Timer? _pollingTimer;
  static const Duration pollingInterval = Duration(seconds: 5); // Polling ogni 5 secondi
  
  // WebSocket per notifiche real-time
  WebSocketChannel? _webSocketChannel;
  Timer? _heartbeatTimer;
  static const Duration heartbeatInterval = Duration(seconds: 30);
  
  // Token del dispositivo per le notifiche
  String? _deviceToken;
  String? _userId;
  
  bool _isInitialized = false;
  bool _isWebSocketConnected = false;

  /// Stream per ricevere messaggi in tempo reale
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Inizializza il servizio di notifiche personalizzato
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Genera un token univoco per questo dispositivo
      _deviceToken = await _generateDeviceToken();
      
      // Ottieni l'ID utente corrente
      _userId = await _getCurrentUserId();
      
      // Registra il dispositivo sul server
      await _registerDevice();
      
      // Prova prima WebSocket per notifiche real-time
      await _initializeWebSocket();
      
      // Se WebSocket fallisce, usa polling come fallback
      if (!_isWebSocketConnected) {
        _startPolling();
        print('📱 CustomPushNotificationService - WebSocket non disponibile, usando polling');
      }
      
      _isInitialized = true;
      print('🔥 CustomPushNotificationService - Servizio inizializzato con successo');
      print('🔥 Device Token: ${_deviceToken?.substring(0, 20)}...');
      print('🔥 User ID: $_userId');
      print('🔥 WebSocket: ${_isWebSocketConnected ? "Connesso" : "Disconnesso"}');
      
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nell\'inizializzazione: $e');
      _isInitialized = true; // Continua comunque
    }
  }

  /// Genera un token univoco per il dispositivo
  Future<String> _generateDeviceToken() async {
    try {
      // Controlla se esiste già un token salvato
      final prefs = await SharedPreferences.getInstance();
      String? savedToken = prefs.getString('device_push_token');
      
      if (savedToken != null && savedToken.isNotEmpty) {
        return savedToken;
      }
      
      // Genera un nuovo token univoco
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = (timestamp * 1000 + (timestamp % 1000)).toString();
      final deviceToken = 'securevox_${Platform.operatingSystem}_${random}';
      
      // Salva il token
      await prefs.setString('device_push_token', deviceToken);
      
      return deviceToken;
    } catch (e) {
      // Fallback: token basato su timestamp
      return 'securevox_${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Ottiene l'ID utente corrente
  Future<String?> _getCurrentUserId() async {
    try {
      // Usa UserService per ottenere l'ID utente corrente
      return UserService.getCurrentUserIdSync();
    } catch (e) {
      print('❌ CustomPushNotificationService._getCurrentUserId - Errore: $e');
      return null;
    }
  }

  /// Registra il dispositivo sul server
  Future<void> _registerDevice() async {
    try {
      if (_deviceToken == null || _userId == null) return;

      final response = await http.post(
        Uri.parse('$_notificationServerUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_token': _deviceToken,
          'user_id': _userId,
          'platform': Platform.operatingSystem,
          'app_version': '1.0.0',
        }),
      );

      if (response.statusCode == 200) {
        print('🔥 CustomPushNotificationService - Dispositivo registrato con successo');
      } else {
        print('⚠️ CustomPushNotificationService - Errore nella registrazione: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nella registrazione: $e');
    }
  }

  /// Inizializza WebSocket per notifiche real-time
  Future<void> _initializeWebSocket() async {
    try {
      if (_deviceToken == null) return;

      final wsUrl = 'ws://127.0.0.1:8002/ws/$_deviceToken';
      _webSocketChannel = IOWebSocketChannel.connect(wsUrl);
      
      // Ascolta i messaggi WebSocket
      _webSocketChannel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data);
            _handleWebSocketMessage(message);
          } catch (e) {
            print('❌ CustomPushNotificationService - Errore nel parsing WebSocket: $e');
          }
        },
        onError: (error) {
          print('❌ CustomPushNotificationService - Errore WebSocket: $error');
          _isWebSocketConnected = false;
          _startPolling(); // Fallback a polling
        },
        onDone: () {
          print('📡 CustomPushNotificationService - WebSocket disconnesso');
          _isWebSocketConnected = false;
          _startPolling(); // Fallback a polling
        },
      );
      
      _isWebSocketConnected = true;
      _startHeartbeat();
      print('📡 CustomPushNotificationService - WebSocket connesso');
      
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nell\'inizializzazione WebSocket: $e');
      _isWebSocketConnected = false;
    }
  }

  /// Gestisce i messaggi ricevuti via WebSocket
  void _handleWebSocketMessage(Map<String, dynamic> message) {
    try {
      final type = message['type'];
      
      if (type == 'notification') {
        // Notifica normale
        _messageController.add({
          'title': message['title'] ?? 'Nuovo messaggio',
          'body': message['body'] ?? '',
          'data': message['data'] ?? {},
          'timestamp': message['timestamp'] ?? DateTime.now().toIso8601String(),
          'notification_type': message['notification_type'] ?? 'message',
        });
      } else if (type == 'call') {
        // Notifica di chiamata
        _messageController.add({
          'title': 'Chiamata in arrivo',
          'body': message['sender_id'] ?? 'Sconosciuto',
          'data': {
            'call_id': message['call_id'],
            'call_type': message['call_type'],
            'is_group': message['is_group'] ?? false,
            'sender_id': message['sender_id'],
          },
          'timestamp': message['timestamp'] ?? DateTime.now().toIso8601String(),
          'notification_type': 'call',
        });
      } else if (type == 'call_status') {
        // Aggiornamento stato chiamata
        _messageController.add({
          'title': 'Stato chiamata',
          'body': message['status'] ?? 'Sconosciuto',
          'data': {
            'call_id': message['call_id'],
            'status': message['status'],
            'duration': message['duration'],
          },
          'timestamp': message['timestamp'] ?? DateTime.now().toIso8601String(),
          'notification_type': 'call_status',
        });
      } else if (type == 'pong') {
        // Heartbeat response
        print('📡 CustomPushNotificationService - Heartbeat ricevuto');
      }
      
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nella gestione messaggio WebSocket: $e');
    }
  }

  /// Avvia heartbeat per mantenere WebSocket attivo
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (timer) {
      if (_isWebSocketConnected && _webSocketChannel != null) {
        try {
          _webSocketChannel!.sink.add(jsonEncode({
            'type': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }));
        } catch (e) {
          print('❌ CustomPushNotificationService - Errore heartbeat: $e');
          _isWebSocketConnected = false;
          _startPolling();
        }
      }
    });
  }

  /// Avvia il polling per le notifiche
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(pollingInterval, (timer) {
      _checkForNotifications();
    });
    print('🔥 CustomPushNotificationService - Polling avviato ogni ${pollingInterval.inSeconds}s');
  }

  /// Controlla se ci sono nuove notifiche
  Future<void> _checkForNotifications() async {
    try {
      if (_deviceToken == null || _userId == null) return;

      final response = await http.get(
        Uri.parse('$_notificationServerUrl/poll/$_deviceToken'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['notifications'] != null && data['notifications'].isNotEmpty) {
          for (final notification in data['notifications']) {
            _handleNotification(notification);
          }
        }
      }
    } catch (e) {
      // Non loggare errori di polling per evitare spam
    }
  }

  /// Gestisce una notifica ricevuta
  void _handleNotification(Map<String, dynamic> notification) {
    try {
      print('📨 CustomPushNotificationService - Notifica ricevuta: ${notification['title']}');
      
      // Invia la notifica al stream
      _messageController.add({
        'title': notification['title'] ?? 'Nuovo messaggio',
        'body': notification['body'] ?? '',
        'data': notification['data'] ?? {},
        'timestamp': notification['timestamp'] ?? DateTime.now().toIso8601String(),
      });
      
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nella gestione notifica: $e');
    }
  }

  /// Invia una notifica a un destinatario
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String content,
    required Map<String, dynamic> data,
  }) async {
    try {
      print('📤 CustomPushNotificationService - Invio notifica a: $recipientId');
      print('📤 Titolo: $title');
      print('📤 Contenuto: $content');

      final response = await http.post(
        Uri.parse('$_notificationServerUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipient_id': recipientId, // Il server si aspetta recipient_id
          'title': title,
          'body': content,
          'data': data,
          'sender_id': _userId,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        print('✅ CustomPushNotificationService - Notifica inviata con successo');
      } else {
        print('❌ CustomPushNotificationService - Errore nell\'invio: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nell\'invio notifica: $e');
    }
  }

  /// Invia una notifica di messaggio
  Future<void> sendMessageNotification({
    required String recipientId,
    required String chatId,
    required String content,
    required String senderId,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'Nuovo messaggio',
      content: content,
      data: {
        'chat_id': chatId,
        'content': content,
        'sender_id': senderId,
        'type': 'message',
        'message_id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      },
    );
  }

  /// Inizia una chiamata audio
  Future<Map<String, dynamic>?> startAudioCall({
    required String recipientId,
    String? callId,
  }) async {
    return await _startCall(
      recipientId: recipientId,
      callType: 'audio',
      isGroup: false,
      callId: callId,
    );
  }

  /// Inizia una videochiamata
  Future<Map<String, dynamic>?> startVideoCall({
    required String recipientId,
    String? callId,
  }) async {
    return await _startCall(
      recipientId: recipientId,
      callType: 'video',
      isGroup: false,
      callId: callId,
    );
  }

  /// Inizia una chiamata di gruppo
  Future<Map<String, dynamic>?> startGroupCall({
    required List<String> recipientIds,
    required String callType, // 'audio' o 'video'
    String? callId,
  }) async {
    if (recipientIds.isEmpty) return null;
    
    // Per ora invia solo al primo destinatario (in futuro gestire multipli)
    return await _startCall(
      recipientId: recipientIds.first,
      callType: callType,
      isGroup: true,
      groupMembers: recipientIds,
      callId: callId,
    );
  }

  /// Metodo interno per iniziare una chiamata
  Future<Map<String, dynamic>?> _startCall({
    required String recipientId,
    required String callType,
    required bool isGroup,
    List<String>? groupMembers,
    String? callId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_notificationServerUrl/call/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipient_id': recipientId,
          'sender_id': _userId,
          'call_type': callType,
          'is_group': isGroup,
          'group_members': groupMembers ?? [],
          'call_id': callId ?? 'call_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📞 CustomPushNotificationService - Chiamata $callType iniziata: ${data['call_id']}');
        return data;
      } else {
        print('❌ CustomPushNotificationService - Errore nell\'inizio chiamata: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore nell\'inizio chiamata: $e');
      return null;
    }
  }

  /// Risponde a una chiamata
  Future<bool> answerCall(String callId) async {
    return await _callAction(callId, 'answer');
  }

  /// Rifiuta una chiamata
  Future<bool> rejectCall(String callId) async {
    return await _callAction(callId, 'reject');
  }

  /// Termina una chiamata
  Future<bool> endCall(String callId) async {
    return await _callAction(callId, 'end');
  }

  /// Metodo interno per azioni sulle chiamate
  Future<bool> _callAction(String callId, String action) async {
    try {
      final endpoint = action == 'answer' ? 'answer' : 
                     action == 'reject' ? 'reject' : 'end';
      
      final response = await http.post(
        Uri.parse('$_notificationServerUrl/call/$endpoint/$callId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId}),
      );

      if (response.statusCode == 200) {
        print('📞 CustomPushNotificationService - Chiamata $action: $callId');
        return true;
      } else {
        print('❌ CustomPushNotificationService - Errore $action chiamata: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ CustomPushNotificationService - Errore $action chiamata: $e');
      return false;
    }
  }

  /// Invia risposta chiamata via WebSocket (più veloce)
  void sendCallResponseViaWebSocket(String callId, String action) {
    if (_isWebSocketConnected && _webSocketChannel != null) {
      try {
        _webSocketChannel!.sink.add(jsonEncode({
          'type': 'call_response',
          'call_id': callId,
          'action': action,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }));
        print('📡 CustomPushNotificationService - Risposta chiamata inviata via WebSocket');
      } catch (e) {
        print('❌ CustomPushNotificationService - Errore WebSocket risposta chiamata: $e');
      }
    }
  }

  /// Ottiene il token del dispositivo
  String? get deviceToken => _deviceToken;

  /// Ottiene l'ID utente
  String? get userId => _userId;

  /// Controlla se il servizio è inizializzato
  bool get isInitialized => _isInitialized;

  /// Chiude il servizio
  void dispose() {
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    // Chiudi WebSocket
    if (_webSocketChannel != null) {
      try {
        _webSocketChannel!.sink.close();
      } catch (e) {
        print('❌ CustomPushNotificationService - Errore chiusura WebSocket: $e');
      }
      _webSocketChannel = null;
    }
    
    _messageController.close();
    _isInitialized = false;
    _isWebSocketConnected = false;
    print('🔥 CustomPushNotificationService - Servizio chiuso');
  }
}
