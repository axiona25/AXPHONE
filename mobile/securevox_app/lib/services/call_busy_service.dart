import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'call_audio_service.dart';

/// Servizio per gestire lo stato di occupato durante le chiamate
class CallBusyService {
  static final CallBusyService _instance = CallBusyService._internal();
  static CallBusyService get instance => _instance;
  CallBusyService._internal();

  // Stato chiamate attive
  final Map<String, CallInfo> _activeCalls = {};
  final Map<String, String> _userBusyStatus = {}; // userId -> callId
  
  // Timer per cleanup automatico
  Timer? _cleanupTimer;
  
  // Configurazione
  static const Duration _cleanupInterval = Duration(seconds: 30);
  static const Duration _callTimeout = Duration(minutes: 5);
  static const String _activeCallsKey = 'active_calls';
  static const String _busyStatusKey = 'user_busy_status';

  /// Inizializza il servizio
  Future<void> initialize() async {
    try {
      print('📞 CallBusyService - Inizializzazione...');
      
      // Carica stato salvato
      await _loadSavedState();
      
      // Avvia timer di cleanup
      _startCleanupTimer();
      
      print('✅ CallBusyService - Inizializzato');
      
    } catch (e) {
      print('❌ CallBusyService - Errore inizializzazione: $e');
    }
  }

  /// Registra una chiamata attiva
  Future<void> registerActiveCall({
    required String callId,
    required String userId,
    required String callType,
    required String status, // 'in_progress', 'ringing', 'answered'
  }) async {
    try {
      print('📞 CallBusyService - Registrazione chiamata attiva');
      print('   - Call ID: $callId');
      print('   - User ID: $userId');
      print('   - Tipo: $callType');
      print('   - Status: $status');

      // Crea info chiamata
      final callInfo = CallInfo(
        callId: callId,
        userId: userId,
        callType: callType,
        status: status,
        startTime: DateTime.now(),
      );

      // Registra chiamata
      _activeCalls[callId] = callInfo;
      _userBusyStatus[userId] = callId;

      // Avvia suoni appropriati
      await _startCallSounds(callInfo);

      // Salva stato
      await _saveState();

      print('✅ CallBusyService - Chiamata registrata');

    } catch (e) {
      print('❌ CallBusyService - Errore registrazione chiamata: $e');
    }
  }

  /// Aggiorna stato di una chiamata
  Future<void> updateCallStatus({
    required String callId,
    required String status,
  }) async {
    try {
      print('📞 CallBusyService - Aggiornamento stato chiamata');
      print('   - Call ID: $callId');
      print('   - Nuovo status: $status');

      final callInfo = _activeCalls[callId];
      if (callInfo == null) {
        print('⚠️ CallBusyService - Chiamata non trovata: $callId');
        return;
      }

      // Aggiorna stato
      final updatedCallInfo = callInfo.copyWith(status: status);
      _activeCalls[callId] = updatedCallInfo;

      // Aggiorna suoni in base al nuovo stato
      await _updateCallSounds(updatedCallInfo);

      // Salva stato
      await _saveState();

      print('✅ CallBusyService - Stato aggiornato');

    } catch (e) {
      print('❌ CallBusyService - Errore aggiornamento stato: $e');
    }
  }

  /// Termina una chiamata
  Future<void> endCall({
    required String callId,
  }) async {
    try {
      print('📞 CallBusyService - Terminazione chiamata');
      print('   - Call ID: $callId');

      final callInfo = _activeCalls[callId];
      if (callInfo == null) {
        print('⚠️ CallBusyService - Chiamata non trovata: $callId');
        return;
      }

      // Ferma suoni
      await CallAudioService.instance.stopCallSound(callId);

      // Rimuovi dalla mappa
      _activeCalls.remove(callId);
      _userBusyStatus.remove(callInfo.userId);

      // Salva stato
      await _saveState();

      print('✅ CallBusyService - Chiamata terminata');

    } catch (e) {
      print('❌ CallBusyService - Errore terminazione chiamata: $e');
    }
  }

  /// Verifica se un utente è occupato
  bool isUserBusy(String userId) {
    return _userBusyStatus.containsKey(userId);
  }

  /// Ottiene info chiamata per utente
  CallInfo? getCallInfoForUser(String userId) {
    final callId = _userBusyStatus[userId];
    return callId != null ? _activeCalls[callId] : null;
  }

  /// Ottiene tutte le chiamate attive
  List<CallInfo> getActiveCalls() {
    return _activeCalls.values.toList();
  }

  /// Verifica se ci sono chiamate attive
  bool get hasActiveCalls => _activeCalls.isNotEmpty;

  /// Ottiene numero di chiamate attive
  int get activeCallsCount => _activeCalls.length;

  /// Avvia suoni appropriati per la chiamata
  Future<void> _startCallSounds(CallInfo callInfo) async {
    try {
      switch (callInfo.status) {
        case 'in_progress':
          await CallAudioService.instance.startCallInProgressSound(
            callId: callInfo.callId,
            callType: callInfo.callType,
          );
          break;
        case 'ringing':
          await CallAudioService.instance.startIncomingCallRingtone(
            callId: callInfo.callId,
            callType: callInfo.callType,
          );
          break;
        case 'answered':
          // Ferma suoni quando la chiamata viene risposta
          await CallAudioService.instance.stopCallSound(callInfo.callId);
          break;
        case 'busy':
          await CallAudioService.instance.startBusySound(
            reason: 'User is busy with another call',
          );
          break;
      }
    } catch (e) {
      print('❌ CallBusyService - Errore avvio suoni: $e');
    }
  }

  /// Aggiorna suoni in base al nuovo stato
  Future<void> _updateCallSounds(CallInfo callInfo) async {
    try {
      switch (callInfo.status) {
        case 'in_progress':
          await CallAudioService.instance.startCallInProgressSound(
            callId: callInfo.callId,
            callType: callInfo.callType,
          );
          break;
        case 'ringing':
          await CallAudioService.instance.startIncomingCallRingtone(
            callId: callInfo.callId,
            callType: callInfo.callType,
          );
          break;
        case 'answered':
          // Ferma suoni quando la chiamata viene risposta
          await CallAudioService.instance.stopCallSound(callInfo.callId);
          break;
        case 'busy':
          await CallAudioService.instance.startBusySound(
            reason: 'User is busy with another call',
          );
          break;
        case 'ended':
          // Ferma suoni quando la chiamata termina
          await CallAudioService.instance.stopCallSound(callInfo.callId);
          break;
      }
    } catch (e) {
      print('❌ CallBusyService - Errore aggiornamento suoni: $e');
    }
  }

  /// Avvia timer di cleanup
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) {
      _cleanupExpiredCalls();
    });
  }

  /// Pulisce chiamate scadute
  void _cleanupExpiredCalls() {
    try {
      final now = DateTime.now();
      final expiredCalls = <String>[];

      for (final entry in _activeCalls.entries) {
        final callInfo = entry.value;
        final duration = now.difference(callInfo.startTime);
        
        if (duration > _callTimeout) {
          expiredCalls.add(entry.key);
        }
      }

      for (final callId in expiredCalls) {
        print('🧹 CallBusyService - Cleanup chiamata scaduta: $callId');
        endCall(callId: callId);
      }

    } catch (e) {
      print('❌ CallBusyService - Errore cleanup: $e');
    }
  }

  /// Carica stato salvato
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carica chiamate attive
      final activeCallsJson = prefs.getString(_activeCallsKey);
      if (activeCallsJson != null) {
        // TODO: Implementare deserializzazione JSON
        print('📞 CallBusyService - Stato caricato da storage');
      }

    } catch (e) {
      print('❌ CallBusyService - Errore caricamento stato: $e');
    }
  }

  /// Salva stato corrente
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Salva chiamate attive
      // TODO: Implementare serializzazione JSON
      await prefs.setString(_activeCallsKey, '{}');
      
      print('📞 CallBusyService - Stato salvato');

    } catch (e) {
      print('❌ CallBusyService - Errore salvataggio stato: $e');
    }
  }

  /// Pulisce risorse
  void dispose() {
    _cleanupTimer?.cancel();
    _activeCalls.clear();
    _userBusyStatus.clear();
  }
}

/// Classe per informazioni chiamata
class CallInfo {
  final String callId;
  final String userId;
  final String callType;
  final String status;
  final DateTime startTime;

  CallInfo({
    required this.callId,
    required this.userId,
    required this.callType,
    required this.status,
    required this.startTime,
  });

  CallInfo copyWith({
    String? callId,
    String? userId,
    String? callType,
    String? status,
    DateTime? startTime,
  }) {
    return CallInfo(
      callId: callId ?? this.callId,
      userId: userId ?? this.userId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
    );
  }

  @override
  String toString() {
    return 'CallInfo(callId: $callId, userId: $userId, callType: $callType, status: $status, startTime: $startTime)';
  }
}
