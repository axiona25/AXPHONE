import '../models/call_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Servizio per gestire le chiamate attive nell'app
/// Gestisce lo stato delle chiamate e la navigazione
class ActiveCallService {
  static bool _isCallActive = false;
  static String? _callType;
  static String? _userId;
  static List<String>? _userIds;
  static String? _chatId;
  static DateTime? _callStartTime;
  
  // Callback per aggiornamenti di stato
  static Function(bool isActive)? _onCallStateChanged;
  
  /// Verifica se c'è una chiamata attiva
  static bool get isCallActive => _isCallActive;
  
  /// Ottiene il tipo di chiamata (audio/video)
  static String? get callType => _callType;
  
  /// Ottiene l'ID dell'utente per chiamate 1-to-1
  static String? get userId => _userId;
  
  /// Ottiene gli ID degli utenti per chiamate di gruppo
  static List<String>? get userIds => _userIds;
  
  /// Ottiene l'ID della chat associata
  static String? get chatId => _chatId;
  
  /// Ottiene il tempo di inizio della chiamata
  static DateTime? get callStartTime => _callStartTime;
  
  /// Ottiene la durata della chiamata
  static Duration? get callDuration {
    if (_callStartTime != null) {
      return DateTime.now().difference(_callStartTime!);
    }
    return null;
  }
  
  /// Inizia una chiamata
  static void startCall({
    required String callType,
    String? userId,
    List<String>? userIds,
    String? chatId,
    Function(bool isActive)? onStateChanged,
  }) {
    _isCallActive = true;
    _callType = callType;
    _userId = userId;
    _userIds = userIds;
    _chatId = chatId;
    _callStartTime = DateTime.now();
    _onCallStateChanged = onStateChanged;
    
    // Notifica il cambio di stato
    _onCallStateChanged?.call(true);
    
    print('📞 ActiveCallService - Chiamata iniziata: $callType');
  }
  
  /// Termina la chiamata corrente
  static void endCall() {
    _isCallActive = false;
    _callType = null;
    _userId = null;
    _userIds = null;
    _chatId = null;
    _callStartTime = null;
    
    // Notifica il cambio di stato
    _onCallStateChanged?.call(false);
    _onCallStateChanged = null;
    
    print('📞 ActiveCallService - Chiamata terminata');
  }
  
  /// Termina la chiamata e torna alla chat
  static void endCallAndReturnToChat(BuildContext context) {
    final currentChatId = _chatId;
    
    // Termina la chiamata
    endCall();
    
    // Naviga alla chat se disponibile
    if (currentChatId != null) {
      context.go('/chat/$currentChatId');
      print('📞 ActiveCallService - Navigazione alla chat: $currentChatId');
    } else {
      // Fallback: torna alla home
      context.go('/');
      print('📞 ActiveCallService - Navigazione alla home (no chat ID)');
    }
  }
  
  /// Mette in pausa la chiamata
  static void pauseCall() {
    if (_isCallActive) {
      print('📞 ActiveCallService - Chiamata in pausa');
      // Implementa logica di pausa se necessario
    }
  }
  
  /// Riprende la chiamata
  static void resumeCall() {
    if (_isCallActive) {
      print('📞 ActiveCallService - Chiamata ripresa');
      // Implementa logica di ripresa se necessario
    }
  }
  
  /// Cambia il tipo di chiamata (audio ↔ video)
  static void toggleCallType() {
    if (_isCallActive && _callType != null) {
      _callType = _callType == 'audio' ? 'video' : 'audio';
      print('📞 ActiveCallService - Tipo chiamata cambiato a: $_callType');
    }
  }
  
  /// Naviga alla schermata a schermo intero della chiamata
  static void navigateToFullScreen(BuildContext context) {
    if (_isCallActive) {
      // Naviga alla schermata di chiamata a schermo intero
      context.push('/call-fullscreen', extra: {
        'callType': _callType,
        'userId': _userId,
        'userIds': _userIds,
        'chatId': _chatId,
      });
      print('📞 ActiveCallService - Navigazione a schermo intero');
    }
  }
  
  /// Naviga alla schermata di chiamata PIP (Picture-in-Picture)
  static void navigateToPIP(BuildContext context) {
    if (_isCallActive) {
      // Implementa logica PIP se necessario
      print('📞 ActiveCallService - Modalità PIP attivata');
    }
  }
  
  /// Ottiene informazioni dettagliate sulla chiamata
  static Map<String, dynamic> getCallInfo() {
    return {
      'isActive': _isCallActive,
      'callType': _callType,
      'userId': _userId,
      'userIds': _userIds,
      'chatId': _chatId,
      'startTime': _callStartTime?.toIso8601String(),
      'duration': callDuration?.inSeconds,
    };
  }
  
  /// Verifica se la chiamata è di gruppo
  static bool get isGroupCall => _userIds != null && _userIds!.length > 1;
  
  /// Verifica se la chiamata è 1-to-1
  static bool get isOneToOneCall => _userId != null && (_userIds == null || _userIds!.isEmpty);
  
  /// Ottiene il numero di partecipanti
  static int get participantCount {
    if (_userIds != null) {
      return _userIds!.length;
    } else if (_userId != null) {
      return 1;
    }
    return 0;
  }
  
  /// Formatta la durata della chiamata
  static String getFormattedDuration() {
    final duration = callDuration;
    if (duration == null) return '00:00';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  
  /// Resetta completamente il servizio
  static void reset() {
    _isCallActive = false;
    _callType = null;
    _userId = null;
    _userIds = null;
    _chatId = null;
    _callStartTime = null;
    _onCallStateChanged = null;
    
    print('📞 ActiveCallService - Servizio resettato');
  }
}
