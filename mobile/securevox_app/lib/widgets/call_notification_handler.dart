import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/call_notification_service.dart';
// import '../services/webrtc_call_service.dart'; // RIMOSSO: File eliminato
import '../services/native_audio_call_service.dart';
import '../services/auth_service.dart';
import '../services/global_navigation_service.dart';
import '../services/call_sound_service.dart';
import '../services/real_chat_service.dart';
import '../services/user_service.dart';
import '../models/chat_model.dart';
import '../screens/incoming_call_overlay.dart';

class CallNotificationHandler extends StatefulWidget {
  final Widget child;

  const CallNotificationHandler({
    super.key,
    required this.child,
  });

  @override
  State<CallNotificationHandler> createState() => _CallNotificationHandlerState();
}

class _CallNotificationHandlerState extends State<CallNotificationHandler> {
  CallNotificationService? _notificationService;
  AuthService? _authService;
  final CallSoundService _soundService = CallSoundService();
  bool _isInitialized = false;
  bool _wasLoggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
      _setupAuthListener();
      _initializeSoundService();
    });
  }
  
  /// Inizializza il servizio suoni
  void _initializeSoundService() async {
    try {
      await _soundService.initialize();
      print('✅ CallNotificationHandler - Servizio suoni inizializzato');
    } catch (e) {
      print('❌ CallNotificationHandler - Errore inizializzazione suoni: $e');
    }
  }

  /// Setup listener per cambiamenti di autenticazione
  void _setupAuthListener() {
    try {
      _authService = Provider.of<AuthService>(context, listen: false);
      _authService?.addListener(_onAuthChanged);
      _wasLoggedIn = _authService?.currentUser != null;
      print('✅ CallNotificationHandler - Auth listener setup');
    } catch (e) {
      print('❌ CallNotificationHandler - Errore setup auth listener: $e');
    }
  }

  /// Gestisce cambiamenti di autenticazione
  void _onAuthChanged() {
    final isLoggedIn = _authService?.currentUser != null;
    
    if (isLoggedIn != _wasLoggedIn) {
      print('🔄 CallNotificationHandler - Auth status changed: $isLoggedIn');
      
      if (isLoggedIn) {
        // Utente appena loggato → riavvia polling
        print('🔄 CallNotificationHandler - Utente loggato, riavvio polling...');
        _notificationService?.forceRestart();
      } else {
        // Utente sloggato → ferma polling
        print('🔄 CallNotificationHandler - Utente sloggato, fermo polling...');
        _notificationService?.stopPolling();
      }
      
      _wasLoggedIn = isLoggedIn;
    }
  }

  void _initializeNotifications() {
    if (_isInitialized) return;
    
    try {
      _notificationService = Provider.of<CallNotificationService>(context, listen: false);
      
      // Imposta il context per overlay
      _notificationService!.setContext(context);
      
      // Setup callback per chiamate in arrivo
      _notificationService!.onIncomingCall = _handleIncomingCall;
      
      // Setup callback per chiamate terminate
      _notificationService!.onCallEnded = _handleCallEnded;
      
      // Avvia polling per chiamate in arrivo
      _notificationService!.startPolling();
      
      _isInitialized = true;
      print('✅ CallNotificationHandler inizializzato');
      
    } catch (e) {
      print('❌ Errore inizializzazione CallNotificationHandler: $e');
    }
  }

  void _handleIncomingCall(Map<String, dynamic> callData) {
    print('📞 CallNotificationHandler - Chiamata in arrivo: $callData');
    
    // Mostra overlay chiamata in arrivo usando il context del MaterialApp
    _showIncomingCallOverlay(callData);
  }

  void _handleCallEnded(Map<String, dynamic> callEndedData) {
    print('📞 CallNotificationHandler - Chiamata terminata: $callEndedData');
    
    try {
      final sessionId = callEndedData['session_id'];
      final endedByName = callEndedData['ended_by_name'] ?? 'Qualcuno';
      final endedById = callEndedData['ended_by_id'];
      
      print('📞 CallNotificationHandler - Chiamata $sessionId terminata da $endedByName (ID: $endedById)');
      
      // SEMPRE chiudi qualsiasi notifica di chiamata attiva
      ScaffoldMessenger.of(context).clearSnackBars();
      print('✅ CallNotificationHandler - Notifiche di chiamata chiuse');
      
      // Se l'utente corrente è in una call screen, chiudila
      _closeCallScreenIfActive(sessionId);
      
      // Reset del controllo chiamate per permettere nuove chiamate
      if (_notificationService != null) {
        _notificationService!.resetLastCheckedCall();
      }
      
      // Mostra notifica informativa di chiamata terminata
      _showCallEndedNotification(endedByName);
      
      print('✅ CallNotificationHandler - Chiamata terminata gestita completamente per: $sessionId');
      
    } catch (e) {
      print('❌ CallNotificationHandler - Errore gestione chiamata terminata: $e');
    }
  }

  void _closeCallScreenIfActive(String sessionId) {
    try {
      // Se siamo in una call screen, torna indietro
      final currentRoute = GoRouterState.of(context).uri.toString();
      
      if (currentRoute.contains('/call/') || currentRoute.contains('/answer-call/') || currentRoute.contains('/audio-call/') || currentRoute.contains('/video-call/')) {
        print('📞 CallNotificationHandler - Chiudendo call screen attiva per: $sessionId');
        context.pop(); // Torna alla schermata precedente (chat detail)
      }
      
    } catch (e) {
      print('❌ CallNotificationHandler - Errore chiusura call screen: $e');
    }
  }

  void _showCallEndedNotification(String endedByName) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.call_end, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Chiamata terminata da $endedByName',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      
    } catch (e) {
      print('❌ CallNotificationHandler - Errore notifica chiamata terminata: $e');
    }
  }
  
  OverlayEntry? _currentOverlay;

  void _showIncomingCallOverlay(Map<String, dynamic> callData) async {
    try {
      final callerId = callData['caller_id'].toString();
      final callerName = callData['caller_name'] ?? 'Utente Sconosciuto';
      final sessionId = callData['session_id'];
      final callTypeStr = callData['call_type'] ?? 'audio';

      print('📞 CallNotificationHandler - Mostra notifica PROFESSIONALE per: $callerName');

      // SUONO: Avvia suoneria per chiamata in arrivo
      await _soundService.startIncomingCallSound();
      print('🔊 Suoneria avviata per notifica chiamata in arrivo');

      // CORREZIONE: Usa SnackBar professionale con pulsanti cornetta
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars(); // Rimuovi snackbar precedenti
      
      messenger.showSnackBar(
        SnackBar(
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Avatar o icona del chiamante
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Icon(
                    callTypeStr == 'video' ? Icons.videocam : Icons.phone,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Info chiamata
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chiamata in arrivo',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      Text(
                        callerName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Chiamata ${callTypeStr == 'video' ? 'video' : 'audio'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Pulsanti cornetta
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pulsante RIFIUTA (cornetta rossa)
                    GestureDetector(
                      onTap: () {
                        messenger.clearSnackBars();
                        _soundService.stopIncomingCallSound(); // Ferma suoneria
                        _rejectCall(sessionId);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Pulsante ACCETTA (cornetta verde)
                    GestureDetector(
                      onTap: () {
                        messenger.clearSnackBars();
                        _soundService.stopIncomingCallSound(); // Ferma suoneria
                        _acceptCall(sessionId, callerId, callerName, callTypeStr);
                      },
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          backgroundColor: const Color(0xFF2E7D32), // Verde scuro professionale
          duration: const Duration(seconds: 30), // Lunga durata per permettere risposta
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        ),
      );
      
      print('✅ CallNotificationHandler - SnackBar chiamata mostrato con successo');
      
    } catch (e) {
      print('❌ CallNotificationHandler - Errore dialog: $e');
    }
  }



  /// Aggiorna lo status di una chiamata nel database
  Future<void> _updateCallStatus(String sessionId, String newStatus) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ CallNotificationHandler - Token non disponibile per aggiornare status');
        return;
      }

      print('📞 CallNotificationHandler - Aggiornando status chiamata $sessionId a: $newStatus');

      // Chiamata all'endpoint per aggiornare lo status (creeremo questo endpoint)
      final response = await http.patch(
        Uri.parse('http://127.0.0.1:8001/api/webrtc/calls/update-status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'session_id': sessionId,
          'status': newStatus,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ CallNotificationHandler - Status chiamata aggiornato: $sessionId → $newStatus');
      } else {
        print('❌ CallNotificationHandler - Errore aggiornamento status: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ CallNotificationHandler - Errore aggiornamento status: $e');
    }
  }

  /// Chiama l'API per terminare una chiamata
  Future<void> _endCallAPI(String sessionId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      
      if (token == null) {
        print('❌ CallNotificationHandler - Token non disponibile per terminare chiamata');
        return;
      }

      // Chiamata all'endpoint end_call
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8001/api/webrtc/calls/end/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'session_id': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ CallNotificationHandler - Chiamata terminata via API: $sessionId');
      } else {
        print('❌ CallNotificationHandler - Errore API terminazione chiamata: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ CallNotificationHandler - Errore chiamata API: $e');
    }
  }

  /// Accetta la chiamata dalla notifica
  void _acceptCall(String sessionId, String callerId, String callerName, String callType) async {
    try {
      print('📞 CallNotificationHandler._acceptCall - Accettando chiamata $sessionId');
      
      // Rimuovi overlay
      _removeCurrentOverlay();
      
      // Aggiorna status chiamata
      await _updateCallStatus(sessionId, 'accepted');
      
      // CORREZIONE: Usa la route corretta per rispondere alla chiamata
      // La route /answer-call/:sessionId porta al CallScreen unificato a tutto schermo
      final route = '/answer-call/$sessionId?caller_id=$callerId&caller_name=${Uri.encodeComponent(callerName)}&type=$callType';
      
      print('📞 CallNotificationHandler - Navigando a schermata chiamata: $route');
      
      // Usa context.go() per navigazione isolata senza footer
      try {
        context.go(route);
        print('✅ CallNotificationHandler - Navigazione con context.go() riuscita');
      } catch (e) {
        print('❌ CallNotificationHandler - Errore context.go(): $e');
        
        // Fallback: usa GlobalNavigationService
        try {
          final success = GlobalNavigationService.go(route);
          if (success) {
            print('✅ CallNotificationHandler - Navigazione con GlobalNavigationService riuscita');
          } else {
            print('❌ CallNotificationHandler - Anche GlobalNavigationService fallito');
          }
        } catch (globalError) {
          print('❌ CallNotificationHandler - Errore GlobalNavigationService: $globalError');
        }
      }
      
      print('✅ CallNotificationHandler - Chiamata accettata e navigazione completata');
      
    } catch (e) {
      print('❌ CallNotificationHandler._acceptCall - Errore: $e');
    }
  }

  /// Rifiuta la chiamata dalla notifica
  void _rejectCall(String sessionId) async {
    try {
      print('📞 CallNotificationHandler._rejectCall - Rifiutando chiamata $sessionId');
      
      // Rimuovi overlay
      _removeCurrentOverlay();
      
      // Aggiorna status chiamata
      await _updateCallStatus(sessionId, 'rejected');
      
      // Termina chiamata via API
      await _endCallAPI(sessionId);
      
      // Naviga alla chat detail REALE (come nel CallScreen)
      await _navigateToRealChatDetail(sessionId);
      
      print('✅ CallNotificationHandler - Chiamata rifiutata e navigazione completata');
      
    } catch (e) {
      print('❌ CallNotificationHandler._rejectCall - Errore: $e');
    }
  }

  /// Naviga alla chat detail reale dopo aver chiuso la chiamata dalla notifica
  Future<void> _navigateToRealChatDetail(String sessionId) async {
    try {
      print('📞 CallNotificationHandler._navigateToRealChatDetail - sessionId: $sessionId');
      
      // Estrai userId dal sessionId (formato: call_[callerId]_[calleeId]_[timestamp])
      if (sessionId.startsWith('call_')) {
        final parts = sessionId.split('_');
        if (parts.length >= 3) {
          final callerId = parts[1];
          final calleeId = parts[2];
          
          print('📞 CallNotificationHandler - callerId: $callerId, calleeId: $calleeId');
          
          // Determina l'altro utente (non l'utente corrente)
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentUser = authService.currentUser;
          final currentUserId = currentUser?.id;
          final otherUserId = (callerId == currentUserId) ? calleeId : callerId;
          
          print('📞 CallNotificationHandler - Cercando chat con utente: $otherUserId');
          
          // Usa la stessa logica del CallScreen
          final chats = RealChatService.cachedChats;
          ChatModel? targetChat;
          
          for (final chat in chats) {
            if (chat.participants.contains(otherUserId) || chat.userId == otherUserId) {
              targetChat = chat;
              break;
            }
          }
          
          if (targetChat != null) {
            print('📞 CallNotificationHandler - Navigando alla chat detail reale: ${targetChat.id}');
            context.go('/chat-detail/${targetChat.id}');
            print('✅ CallNotificationHandler - Navigazione alla chat detail completata');
          } else {
            print('⚠️ CallNotificationHandler - Chat non trovata nella cache, navigando alla home');
            context.go('/home');
          }
        } else {
          print('❌ CallNotificationHandler - Formato sessionId non valido: $sessionId');
          context.go('/home');
        }
      } else {
        print('❌ CallNotificationHandler - SessionId non inizia con call_: $sessionId');
        context.go('/home');
      }
      
    } catch (e) {
      print('❌ CallNotificationHandler._navigateToRealChatDetail - Errore: $e');
      try {
        context.go('/home');
        print('✅ CallNotificationHandler - Fallback navigazione home completata');
      } catch (fallbackError) {
        print('❌ CallNotificationHandler - Errore fallback navigazione: $fallbackError');
      }
    }
  }

  void _removeCurrentOverlay() {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
      print('🗑️ CallNotificationHandler - Overlay precedente rimosso');
    }
  }


  @override
  void dispose() {
    // Rimuovi overlay se esiste
    _removeCurrentOverlay();
    
    // Rimuovi listener AuthService
    _authService?.removeListener(_onAuthChanged);
    
    // Ferma polling
    _notificationService?.stopPolling();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

