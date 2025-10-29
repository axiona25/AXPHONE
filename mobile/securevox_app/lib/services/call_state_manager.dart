import '../models/call_model.dart';
import 'package:flutter/material.dart';

enum UserCallState {
  idle,           // Nessuna chiamata
  ringing,        // Chiamata in arrivo
  calling,        // Chiamata in uscita
  connected,      // Chiamata attiva
  busy,           // Occupato (in chiamata)
}

class CallStateManager extends ChangeNotifier {
  static final CallStateManager _instance = CallStateManager._internal();
  factory CallStateManager() => _instance;
  CallStateManager._internal();

  UserCallState _currentState = UserCallState.idle;
  String? _currentSessionId;
  String? _currentCallerId;
  String? _currentCalleeId;
  String? _currentCallType;
  Map<String, dynamic>? _currentCallData;

  // Getters
  UserCallState get currentState => _currentState;
  String? get currentSessionId => _currentSessionId;
  String? get currentCallerId => _currentCallerId;
  String? get currentCalleeId => _currentCalleeId;
  String? get currentCallType => _currentCallType;
  Map<String, dynamic>? get currentCallData => _currentCallData;

  bool get isIdle => _currentState == UserCallState.idle;
  bool get isInCall => _currentState == UserCallState.connected;
  bool get isBusy => _currentState != UserCallState.idle;
  bool get canMakeCall => _currentState == UserCallState.idle;
  bool get canReceiveCall => _currentState == UserCallState.idle;

  /// Avvia una chiamata in uscita
  void startOutgoingCall({
    required String sessionId,
    required String calleeId,
    required String callType,
  }) {
    print('📞 CallStateManager.startOutgoingCall - $sessionId');
    
    _currentState = UserCallState.calling;
    _currentSessionId = sessionId;
    _currentCallerId = null; // Sarà impostato dal servizio auth
    _currentCalleeId = calleeId;
    _currentCallType = callType;
    _currentCallData = {
      'session_id': sessionId,
      'callee_id': calleeId,
      'call_type': callType,
      'direction': 'outgoing',
    };
    
    notifyListeners();
  }

  /// Riceve una chiamata in arrivo
  void receiveIncomingCall({
    required String sessionId,
    required String callerId,
    required String callerName,
    required String callType,
    required Map<String, dynamic> callData,
  }) {
    print('📞 CallStateManager.receiveIncomingCall - $sessionId from $callerName');
    
    // Se già in chiamata, la nuova chiamata risulta occupata
    if (!canReceiveCall) {
      print('📞 CallStateManager - Utente occupato, rifiutando chiamata $sessionId');
      return;
    }
    
    _currentState = UserCallState.ringing;
    _currentSessionId = sessionId;
    _currentCallerId = callerId;
    _currentCalleeId = null; // Sarà impostato dal servizio auth
    _currentCallType = callType;
    _currentCallData = {
      ...callData,
      'session_id': sessionId,
      'caller_id': callerId,
      'caller_name': callerName,
      'call_type': callType,
      'direction': 'incoming',
    };
    
    notifyListeners();
  }

  /// Accetta la chiamata in arrivo
  void acceptCall() {
    print('📞 CallStateManager.acceptCall - $currentSessionId');
    
    if (_currentState != UserCallState.ringing) {
      print('❌ CallStateManager.acceptCall - Stato non valido: $_currentState');
      return;
    }
    
    _currentState = UserCallState.connected;
    notifyListeners();
  }

  /// Rifiuta la chiamata in arrivo
  void rejectCall() {
    print('📞 CallStateManager.rejectCall - $currentSessionId');
    
    if (_currentState != UserCallState.ringing) {
      print('❌ CallStateManager.rejectCall - Stato non valido: $_currentState');
      return;
    }
    
    _clearCallState();
  }

  /// Connette la chiamata (da calling a connected)
  void connectCall() {
    print('📞 CallStateManager.connectCall - $currentSessionId');
    
    if (_currentState != UserCallState.calling) {
      print('❌ CallStateManager.connectCall - Stato non valido: $_currentState');
      return;
    }
    
    _currentState = UserCallState.connected;
    notifyListeners();
  }

  /// Termina la chiamata corrente
  void endCall() {
    print('📞 CallStateManager.endCall - $currentSessionId');
    _clearCallState();
  }

  /// Pulisce lo stato delle chiamate
  void _clearCallState() {
    print('📞 CallStateManager._clearCallState');
    
    _currentState = UserCallState.idle;
    _currentSessionId = null;
    _currentCallerId = null;
    _currentCalleeId = null;
    _currentCallType = null;
    _currentCallData = null;
    
    notifyListeners();
  }

  /// Controlla se può fare una chiamata
  bool canMakeCallTo(String userId) {
    if (!canMakeCall) {
      print('📞 CallStateManager.canMakeCallTo - Utente occupato (stato: $_currentState)');
      return false;
    }
    return true;
  }

  /// Ottiene messaggio di stato per UI
  String getStatusMessage() {
    switch (_currentState) {
      case UserCallState.idle:
        return 'Disponibile';
      case UserCallState.ringing:
        return 'Chiamata in arrivo...';
      case UserCallState.calling:
        return 'Chiamata in corso...';
      case UserCallState.connected:
        return 'In chiamata';
      case UserCallState.busy:
        return 'Occupato';
    }
  }

  /// Debug info
  void printStatus() {
    print('📞 CallStateManager Status:');
    print('  - State: $_currentState');
    print('  - Session: $_currentSessionId');
    print('  - Caller: $_currentCallerId');
    print('  - Callee: $_currentCalleeId');
    print('  - Type: $_currentCallType');
    print('  - Can make call: $canMakeCall');
    print('  - Can receive call: $canReceiveCall');
  }
}
