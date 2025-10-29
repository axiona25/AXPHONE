import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/incoming_call_overlay.dart';
import 'api_service.dart';

class UnifiedNotificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  // Context per overlay
  BuildContext? _context;
  OverlayEntry? _currentCallOverlay;
  
  // Callback per diversi tipi di notifiche
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(Map<String, dynamic>)? onCallEnded;
  Function(Map<String, dynamic>)? onMessage;
  
  // Set per tracciare notifiche già gestite
  final Set<String> _processedNotifications = {};

  /// Imposta il context per overlay
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Avvia il polling unificato per tutte le notifiche
  void startPolling() {
    if (_isPolling) return;
    
    print('📞 UnifiedNotificationService.startPolling - Avvio polling notifiche...');
    _isPolling = true;
    
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      _checkForNotifications();
    });
  }
  
  /// Ferma il polling
  void stopPolling() {
    print('📞 UnifiedNotificationService.stopPolling - Fermando polling...');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }
  
  /// Controlla tutte le notifiche dal server
  Future<void> _checkForNotifications() async {
    try {
      // Controlla chiamate in arrivo
      await _checkIncomingCalls();
      
      // Controlla notifiche generali (chiamate terminate, messaggi, etc.)
      await _checkGeneralNotifications();
      
    } catch (e) {
      print('❌ UnifiedNotificationService._checkForNotifications - Errore: $e');
    }
  }
  
  /// Controlla chiamate in arrivo
  Future<void> _checkIncomingCalls() async {
    try {
      final response = await _apiService.getPendingCalls();
      final pendingCalls = response['pending_calls'] as List?;
      
      if (pendingCalls != null && pendingCalls.isNotEmpty) {
        print('📞 UnifiedNotificationService - Trovate ${pendingCalls.length} chiamate in arrivo');
        
        for (final callData in pendingCalls) {
          final callId = callData['session_id'];
          
          // Evita di processare la stessa chiamata più volte
          if (!_processedNotifications.contains(callId)) {
            _processedNotifications.add(callId);
            
            print('📞 Nuova chiamata in arrivo: $callId');
            print('📞 Dati chiamata: $callData');
            
            // Mostra overlay di chiamata in arrivo
            _showIncomingCallOverlay(callData);
            
            // Notifica callback
            if (onIncomingCall != null) {
              onIncomingCall!(callData);
            }
          }
        }
      }
      
    } catch (e) {
      print('❌ UnifiedNotificationService._checkIncomingCalls - Errore: $e');
    }
  }
  
  /// Controlla notifiche generali (messaggi, chiamate terminate, etc.)
  Future<void> _checkGeneralNotifications() async {
    try {
      // Per ora, questo endpoint non esiste, ma possiamo implementarlo
      // o usare il polling dei messaggi esistente per notifiche generali
      
      // TODO: Implementare endpoint per notifiche generali
      // final response = await _apiService.getGeneralNotifications();
      
    } catch (e) {
      print('❌ UnifiedNotificationService._checkGeneralNotifications - Errore: $e');
    }
  }
  
  /// Mostra overlay di chiamata in arrivo
  void _showIncomingCallOverlay(Map<String, dynamic> callData) {
    if (_context == null) {
      print('⚠️ Context non disponibile per mostrare overlay chiamata');
      return;
    }
    
    // Rimuovi overlay precedente se esiste
    _removeCurrentOverlay();
    
    try {
      _currentCallOverlay = OverlayEntry(
        builder: (context) => IncomingCallOverlay(
          callData: callData,
          onDismiss: _removeCurrentOverlay,
        ),
      );
      
      Overlay.of(_context!).insert(_currentCallOverlay!);
      print('✅ Overlay chiamata in arrivo mostrato');
      
    } catch (e) {
      print('❌ Errore mostrando overlay chiamata: $e');
    }
  }
  
  /// Rimuove l'overlay corrente
  void _removeCurrentOverlay() {
    try {
      if (_currentCallOverlay != null) {
        _currentCallOverlay!.remove();
        _currentCallOverlay = null;
        print('✅ Overlay chiamata rimosso');
      }
    } catch (e) {
      print('❌ Errore rimozione overlay: $e');
    }
  }
  
  /// Gestisce notifica di chiamata terminata
  void handleCallEnded(Map<String, dynamic> notificationData) {
    try {
      final sessionId = notificationData['session_id'];
      final endedByName = notificationData['ended_by_name'];
      final duration = notificationData['duration'];
      
      print('🔚 Chiamata terminata remotamente: $sessionId');
      print('🔚 Terminata da: $endedByName');
      print('🔚 Durata: $duration');
      
      // Rimuovi overlay se presente
      _removeCurrentOverlay();
      
      // Mostra notifica di chiamata terminata
      if (_context != null) {
        ScaffoldMessenger.of(_context!).showSnackBar(
          SnackBar(
            content: Text('📞 $endedByName ha terminato la chiamata'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      
      // Notifica callback
      if (onCallEnded != null) {
        onCallEnded!(notificationData);
      }
      
    } catch (e) {
      print('❌ Errore gestione chiamata terminata: $e');
    }
  }
  
  /// Marca una notifica come processata
  void markNotificationProcessed(String notificationId) {
    _processedNotifications.add(notificationId);
  }
  
  /// Pulisce notifiche processate (per evitare memory leak)
  void cleanupProcessedNotifications() {
    if (_processedNotifications.length > 100) {
      // Mantieni solo le ultime 50 notifiche
      final notifications = _processedNotifications.toList();
      _processedNotifications.clear();
      _processedNotifications.addAll(notifications.skip(50));
    }
  }
  
  @override
  void dispose() {
    stopPolling();
    _removeCurrentOverlay();
    super.dispose();
  }
}
