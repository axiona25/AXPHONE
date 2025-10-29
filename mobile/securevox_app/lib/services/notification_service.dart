import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
// import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Temporaneamente disabilitato
// import 'package:flutter_app_badger/flutter_app_badger.dart'; // Temporaneamente disabilitato
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'safe_always_on_notification_service.dart';

/// Servizio per gestire le notifiche push e locali
/// TEMPORANEAMENTE SEMPLIFICATO - Solo funzionalità essenziali
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  static NotificationService get instance => _instance;
  NotificationService._internal();

  // Configurazione
  String? _deviceToken;
  String? _userId;
  String? _notifyUrl;
  
  // Timer per polling
  Timer? _pollingTimer;
  
  // Callback per tap notifiche
  Function(Map<String, dynamic>)? onNotificationTap;
  Function(Map<String, dynamic>)? onCallNotification;
  Function(Map<String, dynamic>)? onMessageReceived;

  /// Inizializza il servizio
  Future<void> initialize({
    required String userId,
    String? notifyUrl,
    Function(Map<String, dynamic>)? onTap,
  }) async {
    try {
      print('🔔 NotificationService - Inizializzazione semplificata...');
      
      _userId = userId;
      _notifyUrl = notifyUrl ?? 'http://127.0.0.1:8001';
      onNotificationTap = onTap;
      
      // Richiedi permessi notifiche
      await _requestPermissions();
      
      print('✅ NotificationService - Inizializzato (versione semplificata)');
      
    } catch (e) {
      print('❌ Errore inizializzazione NotificationService: $e');
    }
  }

  /// Richiedi permessi notifiche
  Future<void> _requestPermissions() async {
    try {
      // Richiedi permessi notifiche
      final status = await Permission.notification.request();
      
      if (status != PermissionStatus.granted) {
        print('⚠️ NotificationService - Permessi notifiche negati');
      } else {
        print('✅ NotificationService - Permessi notifiche concessi');
      }
    } catch (e) {
      print('❌ Errore richiesta permessi: $e');
    }
  }

  /// Mostra notifica locale semplificata
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('🔔 NotificationService - Notifica locale: $title - $body');
      
      // Per ora solo stampa in console
      // In futuro si può implementare un sistema di notifiche alternative
      
    } catch (e) {
      print('❌ Errore notifica locale: $e');
    }
  }

  /// Mostra notifica chiamata semplificata
  Future<void> showCallNotification({
    required String title,
    required String body,
    required String callId,
    required String callType,
    required String senderId,
  }) async {
    try {
      print('📞 NotificationService - Notifica chiamata: $title - $body');
      print('   - Call ID: $callId');
      print('   - Tipo: $callType');
      print('   - Sender: $senderId');
      
      // Per ora solo stampa in console
      // In futuro si può implementare un sistema di notifiche alternative
      
    } catch (e) {
      print('❌ Errore notifica chiamata: $e');
    }
  }

  /// Gestisci messaggio di notifica
  Future<void> handleNotificationMessage(Map<String, dynamic> data) async {
    try {
      final title = data['title'] ?? 'Nuovo messaggio';
      final body = data['body'] ?? '';
      
      print('🔔 NotificationService - Messaggio ricevuto: $title - $body');
      
      // Mostra notifica locale semplificata
      await showLocalNotification(
        title: title,
        body: body,
        data: data['data'],
      );
      
    } catch (e) {
      print('❌ Errore gestione messaggio: $e');
    }
  }

  /// Gestisci chiamata in arrivo
  Future<void> handleIncomingCall(Map<String, dynamic> data) async {
    try {
      final title = data['title'] ?? 'Chiamata in arrivo';
      final body = data['body'] ?? '';
      final callId = data['call_id'] ?? '';
      final callType = data['call_type'] ?? 'audio';
      final senderId = data['sender_id'] ?? '';
      
      print('📞 NotificationService - Chiamata ricevuta: $title - $body');
      
      // Mostra notifica chiamata semplificata
      await showCallNotification(
        title: title,
        body: body,
        callId: callId,
        callType: callType,
        senderId: senderId,
      );
      
    } catch (e) {
      print('❌ Errore gestione chiamata: $e');
    }
  }

  /// Avvia polling notifiche
  Future<void> startPolling() async {
    try {
      print('🔔 NotificationService - Avvio polling notifiche...');
      
      // Per ora disabilitato - in futuro si può implementare
      print('⚠️ NotificationService - Polling temporaneamente disabilitato');
      
    } catch (e) {
      print('❌ Errore avvio polling: $e');
    }
  }

  /// Ferma polling notifiche
  Future<void> stopPolling() async {
    try {
      print('🔔 NotificationService - Fermata polling notifiche...');
      
      _pollingTimer?.cancel();
      _pollingTimer = null;
      
    } catch (e) {
      print('❌ Errore fermata polling: $e');
    }
  }

  /// Registra device token
  Future<void> registerDeviceToken(String token) async {
    try {
      print('🔔 NotificationService - Registrazione device token...');
      
      _deviceToken = token;
      
      // Salva token localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_token', token);
      
      print('✅ NotificationService - Device token registrato');
      
    } catch (e) {
      print('❌ Errore registrazione token: $e');
    }
  }

  /// Ottieni device token salvato
  Future<String?> getSavedDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('device_token');
    } catch (e) {
      print('❌ Errore recupero token: $e');
      return null;
    }
  }

  /// Dispose del servizio
  void dispose() {
    try {
      print('🔔 NotificationService - Dispose...');
      
      stopPolling();
      onNotificationTap = null;
      
      print('✅ NotificationService - Disposed');
      
    } catch (e) {
      print('❌ Errore dispose: $e');
    }
  }
}
