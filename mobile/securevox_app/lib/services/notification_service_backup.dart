import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Temporaneamente disabilitato
// import 'package:flutter_app_badger/flutter_app_badger.dart'; // Temporaneamente disabilitato
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/message_model.dart';
import 'safe_always_on_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  // final FlutterLocalNotificationsPlugin _localNotifications = 
  //     FlutterLocalNotificationsPlugin(); // Temporaneamente disabilitato

  bool _isInitialized = false;
  String? _deviceToken;
  String? _userId;
  WebSocketChannel? _wsChannel;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnecting = false;
  
  // Callback per gestire tap su notifiche
  Function(Map<String, dynamic>)? onNotificationTap;
  Function(Map<String, dynamic>)? onCallNotification;
  Function(Map<String, dynamic>)? onMessageReceived;

  // URL del servizio SecureVox Notify
  static const String _notifyUrl = 'http://127.0.0.1:8002';
  static const String _wsUrl = 'ws://127.0.0.1:8002';

  Future<void> initialize({required String userId}) async {
    if (_isInitialized) return;
    
    _userId = userId;
    
    try {
      // Genera un device token unico
      _deviceToken = _generateDeviceToken();
      
      // Richiedi permessi
      await _requestPermissions();
      
      // Inizializza notifiche locali
      await _initializeLocalNotifications();
      
      // Inizializza servizio notifiche sempre visibili
      await SafeAlwaysOnNotificationService.instance.initialize();
      
      // Registra dispositivo con SecureVox Notify
      await _registerDevice();
      
      // Connetti WebSocket per notifiche real-time
      await _connectWebSocket();
      
      // Avvia polling di backup
      _startPolling();
      
      _isInitialized = true;
      print('✅ NotificationService inizializzato per utente: $userId');
      
    } catch (e) {
      print('❌ Errore inizializzazione NotificationService: $e');
      rethrow;
    }
  }

  String _generateDeviceToken() {
    // Genera un token unico basato su device info e timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final platform = Platform.isIOS ? 'iOS' : 'Android';
    return 'device_${platform}_${timestamp}_${_userId}';
  }

  Future<void> _requestPermissions() async {
    // Richiedi permessi notifiche locali iOS
    if (Platform.isIOS) {
      // await _localNotifications
      //     .resolvePlatformSpecificImplementation<
      //         IOSFlutterLocalNotificationsPlugin>()
      //     ?.requestPermissions(
      //       alert: true,
      //       badge: true,
      //       sound: true,
      //     ); // Temporaneamente disabilitato
    }
    
    // Richiedi permessi notifiche Android
    if (Platform.isAndroid) {
      // final androidImplementation = _localNotifications
      //     .resolvePlatformSpecificImplementation<
      //         AndroidFlutterLocalNotificationsPlugin>(); // Temporaneamente disabilitato
      
      // Per Android 13+ richiedi permessi per le notifiche
      // if (androidImplementation != null) {
      //   await androidImplementation.requestNotificationsPermission();
      // } // Temporaneamente disabilitato
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // const AndroidInitializationSettings initializationSettingsAndroid =
    //     AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // const DarwinInitializationSettings initializationSettingsIOS =
    //     DarwinInitializationSettings(
    //   requestSoundPermission: true,
    //   requestBadgePermission: true,
    //   requestAlertPermission: true,
    // );

    // const InitializationSettings initializationSettings =
    //     InitializationSettings(
    //   android: initializationSettingsAndroid,
    //   iOS: initializationSettingsIOS,
    // );

    // await _localNotifications.initialize(
    //   initializationSettings,
    //   onDidReceiveNotificationResponse: _onNotificationTap,
    // );

    // // Crea canali notifiche Android
    // if (Platform.isAndroid) {
    //   await _createNotificationChannels();
    // } // Temporaneamente disabilitato
    
    print('🔔 NotificationService - Local notifications temporaneamente disabilitate');
  }

  Future<void> _createNotificationChannels() async { // Temporaneamente disabilitato
    print('🔔 NotificationService - Canali notifiche temporaneamente disabilitati');
    return;
    
    /* // Temporaneamente disabilitato
    // Canale per messaggi
    const AndroidNotificationChannel messageChannel = AndroidNotificationChannel(
      'securevox_messages',
      'Messaggi SecureVox',
      description: 'Notifiche per nuovi messaggi',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      // Usa il suono predefinito del sistema per i messaggi
    );

    // Canale per chiamate audio
    const AndroidNotificationChannel audioCallChannel = AndroidNotificationChannel(
      'securevox_audio_calls',
      'Chiamate Audio SecureVox',
      description: 'Notifiche per chiamate audio in arrivo',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      // Suono specifico per chiamate audio
      sound: RawResourceAndroidNotificationSound('audio_call_ring'),
    );

    // Canale per videochiamate
    const AndroidNotificationChannel videoCallChannel = AndroidNotificationChannel(
      'securevox_video_calls',
      'Videochiamate SecureVox',
      description: 'Notifiche per videochiamate in arrivo',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      // Suono specifico per videochiamate
      sound: RawResourceAndroidNotificationSound('video_call_ring'),
    );

    // Canale per chiamate di gruppo
    const AndroidNotificationChannel groupCallChannel = AndroidNotificationChannel(
      'securevox_group_calls',
      'Chiamate di Gruppo SecureVox',
      description: 'Notifiche per chiamate di gruppo in arrivo',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      // Suono specifico per chiamate di gruppo
      sound: RawResourceAndroidNotificationSound('group_call_ring'),
    );

    // final plugin = _localNotifications.resolvePlatformSpecificImplementation<
    //     AndroidFlutterLocalNotificationsPlugin>();
    
    // await plugin?.createNotificationChannel(messageChannel);
    // await plugin?.createNotificationChannel(audioCallChannel);
    // await plugin?.createNotificationChannel(videoCallChannel);
    // await plugin?.createNotificationChannel(groupCallChannel);
    
    // print('✅ Canali notifiche creati: messaggi, chiamate audio, videochiamate, chiamate di gruppo');
    */ // Fine commento temporaneo
  }

  Future<void> _registerDevice() async {
    if (_deviceToken == null || _userId == null) return;
    
    try {
      final response = await http.post(
        Uri.parse('$_notifyUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_token': _deviceToken,
          'user_id': _userId,
          'platform': Platform.isIOS ? 'iOS' : 'Android',
          'app_version': '1.0.0',
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Dispositivo registrato con SecureVox Notify');
      } else {
        print('❌ Errore registrazione dispositivo: ${response.body}');
      }
    } catch (e) {
      print('❌ Errore registrazione dispositivo: $e');
    }
  }

  Future<void> _connectWebSocket() async {
    if (_isConnecting || _deviceToken == null) return;
    
    _isConnecting = true;
    
    try {
      print('📡 Connessione WebSocket a SecureVox Notify...');
      
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl/ws/$_deviceToken'),
      );
      
      // Ascolta messaggi WebSocket
      _wsChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleWebSocketMessage(data);
          } catch (e) {
            print('❌ Errore parsing messaggio WebSocket: $e');
          }
        },
        onDone: () {
          print('📡 WebSocket disconnesso');
          _scheduleReconnect();
        },
        onError: (error) {
          print('❌ Errore WebSocket: $error');
          _scheduleReconnect();
        },
      );
      
      // Avvia ping periodico
      _startPing();
      
      print('✅ WebSocket connesso a SecureVox Notify');
      _isConnecting = false;
      
    } catch (e) {
      print('❌ Errore connessione WebSocket: $e');
      _isConnecting = false;
      _scheduleReconnect();
    }
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    print('📡 Messaggio WebSocket ricevuto: ${data['type']}');
    
    switch (data['type']) {
      case 'notification':
        _handleNotificationMessage(data);
        break;
      case 'call':
        _handleCallMessage(data);
        break;
      case 'call_status':
        _handleCallStatusMessage(data);
        break;
      case 'chat_deleted':
        _handleChatDeletedMessage(data);
        break;
      case 'pong':
        // Risposta al ping - connessione attiva
        break;
      default:
        print('⚠️ Tipo messaggio WebSocket sconosciuto: ${data['type']}');
    }
  }

  Future<void> _handleNotificationMessage(Map<String, dynamic> data) async {
    final title = data['title'] ?? 'Nuovo messaggio';
    final body = data['body'] ?? '';
    
    // Mostra notifica locale con suono nativo
    // await _showLocalNotification(
    //   title: title,
    //   body: body,
    //   payload: jsonEncode(data['data'] ?? {}),
    //   channelId: 'securevox_messages',
    // ); // Temporaneamente disabilitato
    
    // Attiva notifica sempre visibile per messaggi importanti
        await SafeAlwaysOnNotificationService.instance.activateAlwaysOn(
          title: title,
          body: body,
          badgeCount: await _getUnreadMessagesCount(),
        );
    
    // Callback per l'app
    if (onMessageReceived != null) {
      onMessageReceived!(data);
    }
    
    print('🔔 Notifica messaggio ricevuta con suono nativo e overlay sempre visibile');
  }

  Future<void> _handleCallMessage(Map<String, dynamic> data) async {
    final callType = data['call_type'] ?? 'audio';
    final senderId = data['sender_id'] ?? 'Sconosciuto';
    final callId = data['call_id'];
    final isGroup = data['is_group'] ?? false;
    final groupName = data['room_name'] ?? 'Gruppo';
    
    // Se app è in foreground, usa callback
    if (onCallNotification != null) {
      onCallNotification!(data);
    } else {
      // Se app è in background, mostra notifica di chiamata con suono nativo
      String title;
      if (isGroup) {
        title = callType == 'video' ? 'Videochiamata di gruppo in arrivo' : 'Chiamata di gruppo in arrivo';
      } else {
        title = callType == 'video' ? 'Videochiamata in arrivo' : 'Chiamata in arrivo';
      }
      
      await _showCallNotification(
        title: title,
        body: isGroup ? '$groupName - Da: $senderId' : 'Da: $senderId',
        callId: callId,
        callType: callType,
        senderId: senderId,
      );
    }
    
    // Attiva notifica sempre visibile per chiamate (sia foreground che background)
    final title = isGroup 
        ? 'Chiamata di gruppo $callType' 
        : 'Chiamata $callType';
    final body = isGroup 
        ? '$groupName - Invitato da $senderId'
        : 'Chiamata in arrivo da $senderId';
    
    // Determina tipo di notifica (semplificato)
    String notificationType;
    if (isGroup) {
      notificationType = 'groupCall';
    } else if (callType == 'video') {
      notificationType = 'videoCall';
    } else {
      notificationType = 'audioCall';
    }
    
    await SafeAlwaysOnNotificationService.instance.activateAlwaysOn(
      title: title,
      body: body,
      badgeCount: await _getUnreadMessagesCount(),
    );
    
    print('📞 Notifica chiamata ricevuta con suono nativo specifico per $callType e overlay sempre visibile');
  }

  void _handleCallStatusMessage(Map<String, dynamic> data) {
    // Gestisci aggiornamenti stato chiamata
    print('📞 Stato chiamata: ${data['status']}');
    
    if (onCallNotification != null) {
      onCallNotification!(data);
    }
  }

  void _handleChatDeletedMessage(Map<String, dynamic> data) {
    // Gestisci eliminazione chat
    print('🗑️ Chat eliminata: ${data['chat_name']}');
    
    if (onNotificationTap != null) {
      onNotificationTap!(data);
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_wsChannel != null) {
        try {
          _wsChannel!.sink.add(jsonEncode({
            'type': 'ping',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }));
        } catch (e) {
          print('❌ Errore invio ping: $e');
          _scheduleReconnect();
        }
      }
    });
  }

  void _scheduleReconnect() {
    _wsChannel?.sink.close();
    _wsChannel = null;
    _isConnecting = false;
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connectWebSocket();
    });
  }

  void _startPolling() {
    // Polling di backup ogni 10 secondi quando WebSocket non è disponibile
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_wsChannel == null && _deviceToken != null) {
        await _pollNotifications();
      }
    });
  }

  Future<void> _pollNotifications() async {
    if (_deviceToken == null) return;
    
    try {
      final response = await http.get(
        Uri.parse('$_notifyUrl/poll/$_deviceToken'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = data['notifications'] as List<dynamic>;
        
        for (final notification in notifications) {
          await _handleNotificationMessage(notification);
        }
        
        // Aggiorna badge dopo aver processato tutte le notifiche
        await _updateBadge();
        
        print('🔔 Polling completato: ${notifications.length} notifiche processate');
      }
    } catch (e) {
      print('❌ Errore polling notifiche: $e');
    }
  }

  Future<void> _showCallNotification({
    required String title,
    required String body,
    required String callId,
    required String callType,
    required String senderId,
  }) async {
    // Aggiorna badge per chiamata in arrivo
    // await _updateBadge(); // Temporaneamente disabilitato
    
    print('🔔 NotificationService - Notifica chiamata temporaneamente disabilitata');
    return;
    
    /* // Temporaneamente disabilitato
    
    // Configurazione specifica per tipo di chiamata
    final isVideoCall = callType == 'video';
    final channelId = isVideoCall ? 'securevox_video_calls' : 'securevox_audio_calls';
    final channelName = isVideoCall ? 'Videochiamate SecureVox' : 'Chiamate SecureVox';
    final channelDescription = isVideoCall ? 'Notifiche per videochiamate in arrivo' : 'Notifiche per chiamate audio in arrivo';
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      enableVibration: true,
      playSound: true,
      // Suono specifico per tipo di chiamata
      sound: isVideoCall ? RawResourceAndroidNotificationSound('video_call_ring') : RawResourceAndroidNotificationSound('audio_call_ring'),
      // Fallback al suono predefinito del sistema se i suoni personalizzati non sono disponibili
      actions: [
        AndroidNotificationAction(
          'answer',
          isVideoCall ? 'Rispondi Video' : 'Rispondi',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'reject',
          'Rifiuta',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      categoryIdentifier: isVideoCall ? 'video_call_category' : 'audio_call_category',
      threadIdentifier: 'call_thread',
      interruptionLevel: InterruptionLevel.critical,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Suono specifico per tipo di chiamata su iOS
      sound: isVideoCall ? 'video_call_ring.wav' : 'audio_call_ring.wav',
      // Fallback al suono predefinito del sistema
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      callId.hashCode,
      title,
      body,
      notificationDetails,
      payload: jsonEncode({
        'type': 'call',
        'call_id': callId,
        'call_type': callType,
        'sender_id': senderId,
      }),
    );
    
    print('📞 Notifica chiamata mostrata con suono nativo del sistema');
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    required String channelId,
  }) async { // Temporaneamente disabilitato
    print('🔔 NotificationService - Local notification temporaneamente disabilitata');
    return;
    
    /* // Temporaneamente disabilitato
    // Aggiorna badge per nuovo messaggio
    await _updateBadge();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'securevox_messages',
      'Messaggi SecureVox',
      channelDescription: 'Notifiche per nuovi messaggi',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      // Usa il suono predefinito del sistema per le notifiche
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      // Usa il suono predefinito del sistema per le notifiche
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // await _localNotifications.show(
    //   DateTime.now().millisecondsSinceEpoch ~/ 1000,
    //   title,
    //   body,
    //   notificationDetails,
    //   payload: payload,
    // );
    
    // print('🔔 Notifica locale mostrata con suono nativo del sistema');
    */ // Fine commento temporaneo
  }

  void _onNotificationTap(/* NotificationResponse response */) { // Temporaneamente disabilitato
    // final payload = response.payload; // Temporaneamente disabilitato
    // if (payload != null) {
    //   final data = jsonDecode(payload) as Map<String, dynamic>;
    //   
    //   if (data['type'] == 'call') {
        // // Gestisci azioni chiamata
        // if (response.actionId == 'answer') {
        //   _answerCall(data['call_id']);
        // } else if (response.actionId == 'reject') {
        //   _rejectCall(data['call_id']);
        // }
      // } else if (onNotificationTap != null) {
      //   onNotificationTap!(data);
      // }
    // } // Temporaneamente disabilitato
    
    print('🔔 NotificationService - Tap notifica temporaneamente disabilitato');
  }

  /// Dispose del servizio
  void dispose() {
    print('🔔 NotificationService - Dispose (temporaneamente disabilitato)');
    // Nessuna risorsa da liberare per ora
  }

  Future<void> _answerCall(String callId) async {
    try {
      await http.post(
        Uri.parse('$_notifyUrl/call/answer/$callId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId}),
      );
    } catch (e) {
      print('❌ Errore risposta chiamata: $e');
    }
  }

  Future<void> _rejectCall(String callId) async {
    try {
      await http.post(
        Uri.parse('$_notifyUrl/call/reject/$callId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': _userId}),
      );
    } catch (e) {
      print('❌ Errore rifiuto chiamata: $e');
    }
  }

  Future<void> _updateBadge() async {
    try {
      // Conta messaggi non letti
      int unreadCount = await _getUnreadMessagesCount();
      
      if (unreadCount > 0) {
        // await FlutterAppBadger.updateBadgeCount(unreadCount); // Temporaneamente disabilitato
        print('🔔 Badge aggiornato: $unreadCount messaggi non letti');
      } else {
        // await FlutterAppBadger.removeBadge(); // Temporaneamente disabilitato
        print('🔔 Badge rimosso');
      }
    } catch (e) {
      print('❌ Errore aggiornamento badge: $e');
    }
  }

  Future<int> _getUnreadMessagesCount() async {
    try {
      // Conta le notifiche non consegnate per questo utente
      if (_userId == null) return 0;
      
      final response = await http.get(
        Uri.parse('$_notifyUrl/notifications/$_userId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final notifications = data['notifications'] as List;
        return notifications.length;
      }
      
      return 0;
    } catch (e) {
      print('❌ Errore conteggio messaggi non letti: $e');
      return 0;
    }
  }

  // Metodi pubblici
  Future<void> clearBadge() async {
    try {
      // await FlutterAppBadger.removeBadge(); // Temporaneamente disabilitato
    } catch (e) {
      print('❌ Errore rimozione badge: $e');
    }
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String type = 'message',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_notifyUrl/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipient_id': recipientId,
          'title': title,
          'body': body,
          'data': data,
          'sender_id': _userId,
          'timestamp': DateTime.now().toIso8601String(),
          'notification_type': type,
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Errore invio notifica: ${response.body}');
      }
    } catch (e) {
      print('❌ Errore invio notifica: $e');
    }
  }

  Future<void> startCall({
    required String recipientId,
    required String callType,
    String? callId,
    bool isGroup = false,
    List<String>? groupMembers,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_notifyUrl/call/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recipient_id': recipientId,
          'sender_id': _userId,
          'call_type': callType,
          'call_id': callId ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'is_group': isGroup,
          'group_members': groupMembers,
        }),
      );

      if (response.statusCode != 200) {
        print('❌ Errore avvio chiamata: ${response.body}');
      }
    } catch (e) {
      print('❌ Errore avvio chiamata: $e');
    }
  }

  void dispose() {
    _isInitialized = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _wsChannel?.sink.close();
    onNotificationTap = null;
    onCallNotification = null;
    onMessageReceived = null;
  }
}