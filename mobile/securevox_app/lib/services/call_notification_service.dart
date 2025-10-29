import '../models/call_model.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/call_model.dart';
import '../screens/incoming_call_overlay.dart';
// import 'webrtc_call_service.dart'; // RIMOSSO: File eliminato
import 'native_audio_call_service.dart';
import 'api_service.dart';
import 'emergency_polling_fix.dart';
import 'call_state_manager.dart';
import 'unified_realtime_service.dart';

class CallNotificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer;
  String? _lastCheckedCallId;
  bool _isPolling = false;
  
  // Callback per chiamate in arrivo
  Function(Map<String, dynamic>)? onIncomingCall;
  
  // Callback per chiamate terminate
  Function(Map<String, dynamic>)? onCallEnded;
  
  // Context per mostrare overlay
  BuildContext? _context;
  OverlayEntry? _currentCallOverlay;
  
  // Subscription per notifiche real-time
  StreamSubscription? _realtimeSubscription;
  
  // Gestione errori per evitare loop infiniti
  int _consecutiveErrors = 0;
  int _maxConsecutiveErrors = 5;
  bool _authErrorDetected = false;
  DateTime? _lastErrorTime;
  
  /// Avvia il polling per controllare chiamate in arrivo
  void startPolling() {
    if (_isPolling) return;
    
    print('📞 CallNotificationService.startPolling - Avvio polling chiamate...');
    _isPolling = true;
    
    // Inizializza listener per notifiche real-time
    _initializeRealtimeListener();
    
    // Intervallo normale: 2 secondi (non 500ms per evitare spam)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _checkForIncomingCalls();
    });
  }

  /// Inizializza il listener per notifiche real-time (call_ended, etc.)
  void _initializeRealtimeListener() {
    try {
      // Ascolta le notifiche globali da UnifiedRealtimeService
      _realtimeSubscription = UnifiedRealtimeService.globalEvents.listen((notification) {
        _handleRealtimeNotification(notification);
      });
      
      print('✅ CallNotificationService - Listener notifiche real-time inizializzato');
      
    } catch (e) {
      print('❌ CallNotificationService - Errore init listener real-time: $e');
    }
  }

  /// Gestisce le notifiche real-time (call_ended, etc.)
  void _handleRealtimeNotification(Map<String, dynamic> notification) {
    try {
      final data = notification['data'] as Map<String, dynamic>?;
      final action = data?['action'];
      
      if (action == 'call_ended') {
        print('📞 CallNotificationService - Ricevuta notifica call_ended: ${data?['session_id']}');
        
        // Chiama il callback se disponibile
        if (onCallEnded != null) {
          onCallEnded!(data!);
        }
      }
      
    } catch (e) {
      print('❌ CallNotificationService - Errore gestione notifica real-time: $e');
    }
  }
  
  /// Ferma il polling
  void stopPolling() {
    print('📞 CallNotificationService.stopPolling - Fermando polling...');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    
    // Ferma listener notifiche real-time
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    print('📞 CallNotificationService - Listener real-time fermato');
  }
  
  /// Ripristina il polling (da chiamare dopo nuovo login)
  void restartPolling() {
    print('🔄 CallNotificationService.restartPolling - Riavvio polling...');
    stopPolling();
    
    // Reset contatori errori
    _consecutiveErrors = 0;
    _authErrorDetected = false;
    _lastErrorTime = null;
    
    // Reset emergency stop
    final emergencyFix = EmergencyPollingFix();
    emergencyFix.reset();
    
    // Riavvia polling normale
    startPolling();
  }

  /// Forza restart immediato (per debug)
  void forceRestart() {
    print('🚨 CallNotificationService.forceRestart - FORZANDO restart immediato...');
    
    // Reset controllo duplicazione per permettere nuove chiamate
    _lastCheckedCallId = null;
    print('🔄 CallNotificationService - Reset _lastCheckedCallId per permettere nuove chiamate');
    
    restartPolling();
  }

  /// Reset del controllo chiamate (per permettere nuove chiamate dopo terminazione)
  void resetLastCheckedCall() {
    _lastCheckedCallId = null;
    print('🔄 CallNotificationService - Reset controllo chiamate per permettere nuove');
  }
  
  /// Controlla chiamate in arrivo dal server con gestione errori intelligente
  Future<void> _checkForIncomingCalls() async {
    // EMERGENZA: Controlla se il polling deve essere fermato
    final emergencyFix = EmergencyPollingFix();
    if (emergencyFix.shouldStopPolling) {
      print('🚨 CallNotificationService - STOP EMERGENZA attivo');
      stopPolling();
      return;
    }
    
    // Se abbiamo rilevato errori di autenticazione, ferma il polling
    if (_authErrorDetected) {
      print('🔒 CallNotificationService - Polling fermato per errore autenticazione');
      stopPolling();
      return;
    }
    
    // Se troppi errori consecutivi, rallenta il polling
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      print('⚠️ CallNotificationService - Troppi errori, rallentando polling...');
      _slowDownPolling();
      return;
    }
    
    try {
      // Solo log occasionale per evitare spam
      if (_consecutiveErrors == 0) {
        print('📞 CallNotificationService._checkForIncomingCalls - Controllando chiamate...');
      }
      
      final response = await _apiService.getPendingCalls();
      final pendingCalls = response['pending_calls'] as List?;
      
      // Reset contatore errori se la richiesta è riuscita
      _consecutiveErrors = 0;
      _authErrorDetected = false;
      
      if (pendingCalls != null && pendingCalls.isNotEmpty) {
        print('📞 CallNotificationService - Trovate ${pendingCalls.length} chiamate in arrivo');
        
        for (final callData in pendingCalls) {
          final callId = callData['session_id'];
          
          // DEBUG: Controlla se la chiamata è già stata processata
          print('📞 DEBUG - Call ID: $callId, Last checked: $_lastCheckedCallId');
          
          // CORREZIONE: Evita loop ma permette chiamate nuove
          if (_lastCheckedCallId != callId) {
            _lastCheckedCallId = callId;
            
            print('📞 Chiamata in arrivo rilevata: $callId');
            print('📞 Dati chiamata: $callData');
            
            // CORREZIONE: Usa solo il callback, non il metodo overlay interno
            // _showIncomingCallOverlay(callData); // DISABILITATO
            
            // Notifica l'app della chiamata in arrivo
            if (onIncomingCall != null) {
              print('📞 DEBUG - Chiamando callback onIncomingCall...');
              onIncomingCall!(callData);
            } else {
              print('❌ DEBUG - Callback onIncomingCall è NULL!');
            }
          } else {
            print('📞 DEBUG - Chiamata $callId già processata, saltando...');
          }
        }
      } else {
        // Reset controllo quando non ci sono più chiamate
        if (_lastCheckedCallId != null) {
          print('📞 DEBUG - Reset _lastCheckedCallId (nessuna chiamata attiva)');
          _lastCheckedCallId = null;
        }
      }
      
    } catch (e) {
      _handlePollingError(e);
    }
  }
  
  /// Gestisce errori di polling in modo intelligente
  void _handlePollingError(dynamic error) {
    _consecutiveErrors++;
    _lastErrorTime = DateTime.now();
    
    final errorString = error.toString();
    
    // EMERGENZA: Attiva stop se necessario
    final emergencyFix = EmergencyPollingFix();
    if (emergencyFix.shouldActivateEmergencyStop(error)) {
      print('🚨 CallNotificationService - Attivando STOP EMERGENZA per loop infinito');
      emergencyFix.activateEmergencyStop();
      stopPolling();
      return;
    }
    
    // Rileva errori di autenticazione
    if (errorString.contains('401') || errorString.contains('autenticazione')) {
      _authErrorDetected = true;
      print('🔒 CallNotificationService - Errore autenticazione rilevato, fermando polling');
      stopPolling();
      return;
    }
    
    // Log errore solo se non è ripetitivo
    if (_consecutiveErrors <= 3) {
      print('❌ CallNotificationService._checkForIncomingCalls - Errore ${_consecutiveErrors}: $error');
    } else if (_consecutiveErrors == 4) {
      print('⚠️ CallNotificationService - Troppi errori, silenziando log...');
    }
    
    // Se troppi errori, rallenta il polling
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      print('🔄 CallNotificationService - Rallentando polling per troppi errori');
      _slowDownPolling();
    }
  }
  
  /// Rallenta il polling quando ci sono errori
  void _slowDownPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      
      // Riavvia con intervallo più lungo (10 secondi)
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _checkForIncomingCalls();
      });
      
      print('🐌 CallNotificationService - Polling rallentato a 10 secondi');
    }
  }
  
  /// Ripristina polling normale
  void _restoreNormalPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      
      // Riavvia con intervallo normale
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _checkForIncomingCalls();
      });
      
      _consecutiveErrors = 0;
      _authErrorDetected = false;
      print('⚡ CallNotificationService - Polling ripristinato a velocità normale');
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
  
  /// Marca una chiamata come vista
  Future<void> markCallAsSeen(String callId) async {
    try {
      await _apiService.markCallSeen(callId: callId);
      print('✅ Chiamata marcata come vista: $callId');
      
    } catch (e) {
      print('❌ Errore nel marcare chiamata come vista: $e');
    }
  }
  
  /// Imposta il context per mostrare overlay
  void setContext(BuildContext context) {
    _context = context;
  }
  
  /// Mostra overlay di chiamata in arrivo
  void _showIncomingCallOverlay(Map<String, dynamic> callData) {
    print('📞 DEBUG - _showIncomingCallOverlay CHIAMATO con: $callData');
    
    if (_context == null) {
      print('⚠️ Context non disponibile per mostrare overlay chiamata');
      return;
    }
    
    print('📞 DEBUG - Context disponibile, procedendo con overlay...');
    
    try {
      final callerId = callData['caller_id'].toString();
      final callerName = callData['caller_name'] ?? 'Utente Sconosciuto';
      final callTypeStr = callData['call_type'] ?? 'audio';
      
      print('📞 CallNotificationService - Navigando a incoming call per: $callerName');
      
      // Usa GoRouter per navigare alla schermata di chiamata in arrivo
      final videoParam = callTypeStr == 'video' ? '?video=true' : '';
      _context!.push('/incoming-call/$callerId$videoParam');
      
      print('✅ CallNotificationService - Navigazione completata');
      
    } catch (e) {
      print('❌ Errore navigazione incoming call: $e');
      
      // Fallback: prova overlay
      try {
        print('🔄 CallNotificationService - Tentando fallback overlay...');
        _showOverlayFallback(callData);
      } catch (fallbackError) {
        print('❌ Anche il fallback overlay è fallito: $fallbackError');
      }
    }
  }
  
  /// Fallback overlay se la navigazione fallisce
  void _showOverlayFallback(Map<String, dynamic> callData) {
    // Rimuovi overlay precedente se esiste
    _removeCurrentOverlay();
    
    final callerId = callData['caller_id'].toString();
    final callerName = callData['caller_name'] ?? 'Utente Sconosciuto';
    final sessionId = callData['session_id'];
    final callTypeStr = callData['call_type'] ?? 'audio';
    
    // Converti string a enum
    final callType = callTypeStr == 'video' 
        ? CallType.video 
        : CallType.audio;
    
    _currentCallOverlay = OverlayEntry(
      builder: (context) => IncomingCallOverlay(
        callerId: callerId,
        callerName: callerName,
        callerAvatar: '', // TODO: Implementare avatar
        sessionId: sessionId,
        callType: callType,
      ),
    );
    
    Overlay.of(_context!).insert(_currentCallOverlay!);
    print('✅ Fallback overlay mostrato');
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

  /// Naviga alla schermata di chiamata
  void _navigateToCallScreen(Map<String, dynamic> callData) {
    if (_context == null) return;
    
    try {
      // Usa GoRouter per navigare alla call screen
      // context.go('/call', extra: callData); // TODO: Implementare route
      print('📞 CallNotificationService - Navigazione a call screen: ${callData['session_id']}');
      
    } catch (e) {
      print('❌ Errore navigazione call screen: $e');
    }
  }

  /// Rifiuta chiamata sul server
  void _rejectCallOnServer(String sessionId) {
    // TODO: Implementare API call per rifiutare chiamata
    print('📞 CallNotificationService - Rifiutando chiamata sul server: $sessionId');
  }
  
  @override
  void dispose() {
    stopPolling();
    _removeCurrentOverlay();
    super.dispose();
  }
}

