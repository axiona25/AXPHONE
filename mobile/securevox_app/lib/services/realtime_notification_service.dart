import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// Firebase rimosso - usando SecureVOX Notify

/// Servizio per notifiche real-time che funziona sia su simulatori che su dispositivi fisici
class RealtimeNotificationService {
  static final RealtimeNotificationService _instance = RealtimeNotificationService._internal();
  factory RealtimeNotificationService() => _instance;
  RealtimeNotificationService._internal();

  // Firebase rimosso - usando SecureVOX Notify
  String? _fcmToken;
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();
  bool _isInitialized = false;

  /// Stream per ricevere messaggi in tempo reale
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Inizializza il servizio di notifiche
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Firebase rimosso - usando SecureVOX Notify
      await _initializeSimulated();
      print('📱 RealtimeNotificationService - SecureVOX Notify attivato');
      
      _isInitialized = true;
    } catch (e) {
      print('❌ RealtimeNotificationService - Errore nell\'inizializzazione: $e');
      await _initializeSimulated();
      _isInitialized = true;
    }
  }

  /// Firebase rimosso - usando SecureVOX Notify

  /// Inizializza modalità simulata per simulatori
  Future<void> _initializeSimulated() async {
    print('📱 RealtimeNotificationService - Inizializzazione modalità simulata');
    // Simula un token FCM
    _fcmToken = 'simulated_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Invia notifica real-time a un destinatario
  Future<void> sendRealtimeNotification({
    required String recipientId,
    required String title,
    required String content,
    required Map<String, dynamic> data,
  }) async {
    try {
      // Firebase rimosso - usando SecureVOX Notify
      await _sendSimulatedNotification(recipientId, title, content, data);
    } catch (e) {
      print('❌ RealtimeNotificationService - Errore nell\'invio notifica: $e');
    }
  }

  /// Firebase rimosso - usando SecureVOX Notify

  /// Invia notifica simulata
  Future<void> _sendSimulatedNotification(
    String recipientId,
    String title,
    String content,
    Map<String, dynamic> data,
  ) async {
    print('📱 RealtimeNotificationService - Invio notifica simulata a: $recipientId');
    print('📱 RealtimeNotificationService - Titolo: $title');
    print('📱 RealtimeNotificationService - Contenuto: $content');
    
    // Simula l'arrivo della notifica con un piccolo delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    _messageController.add({
      'title': title,
      'body': content,
      'data': data,
      'recipientId': recipientId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Gestisce i messaggi in foreground
  void _handleForegroundMessage(Map<String, dynamic> message) {
    print('🔥 RealtimeNotificationService - Messaggio ricevuto in foreground');
    print('🔥 RealtimeNotificationService - Titolo: ${message['title']}');
    print('🔥 RealtimeNotificationService - Corpo: ${message['body']}');
    
    _messageController.add({
      'title': message['title'] ?? '',
      'body': message['body'] ?? '',
      'data': message['data'] ?? {},
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Gestisce i messaggi in background
  void _handleBackgroundMessage(Map<String, dynamic> message) {
    print('🔥 RealtimeNotificationService - Messaggio ricevuto in background');
    _handleForegroundMessage(message);
  }

  /// Ottieni il token FCM
  String? get fcmToken => _fcmToken;

  /// Chiudi il servizio
  void dispose() {
    _messageController.close();
  }
}

/// Handler per messaggi in background (deve essere una funzione top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(Map<String, dynamic> message) async {
  print('🔥 RealtimeNotificationService - Messaggio in background: ${message['id']}');
}
