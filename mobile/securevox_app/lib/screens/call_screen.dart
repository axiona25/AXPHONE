import '../models/call_model.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart'; // RIMOSSO: Causa crash su macOS
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/native_audio_call_service.dart';
import '../services/call_state_manager.dart';
import '../services/call_history_service.dart';
import '../services/real_chat_service.dart';
import '../theme/app_theme.dart';
import '../models/call_model.dart';
import '../models/chat_model.dart';

class CallScreen extends StatefulWidget {
  final String calleeId;
  final String calleeName;
  final CallType callType;
  final bool isIncoming;
  final String? sessionId; // ID sessione per chiamate in arrivo

  const CallScreen({
    super.key,
    required this.calleeId,
    required this.calleeName,
    required this.callType,
    this.isIncoming = false,
    this.sessionId,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late NativeAudioCallService _callService;
  bool _isCallStarted = false;
  Duration _callDuration = Duration.zero;
  late DateTime _callStartTime;

  @override
  void initState() {
    super.initState();
    // CORREZIONE: Usa il servizio singleton invece di crearne uno nuovo
    _callService = NativeAudioCallService();
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    try {
      print('📞 CallScreen._initializeCall - Inizializzazione chiamata...');
      
      // CORREZIONE: Reset del servizio prima dell'uso per evitare problemi di dispose
      _callService.reset();
      
      // Initialize service (safe, no WebRTC crash)
      await _callService.initialize();
      
      if (widget.isIncoming) {
        // Per chiamate in arrivo che sono già state accettate, avvia il timer sincronizzato
        await _startIncomingCall();
      } else {
        // Per chiamate in uscita, avvia automaticamente
        await _startCall();
      }
    } catch (e) {
      print('❌ Errore inizializzazione chiamata: $e');
      // Don't exit immediately - show fallback UI
      print('📱 Continuando con interfaccia di fallback');
      setState(() {
        _isCallStarted = true;
        _callStartTime = DateTime.now();
      });
      _startCallTimer();
    }
  }

  Future<void> _startCall() async {
    try {
      final success = await _callService.startCall(
        widget.calleeId,
        widget.calleeName,
        widget.callType,
      );
      
      if (success) {
        // CORREZIONE: Ottieni il sessionId dalla chiamata creata
        final sessionId = _callService.currentSessionId;
        if (sessionId != null) {
          // Sincronizza il timer con il backend per ottenere il timestamp corretto
          await _syncCallTimer(sessionId);
        } else {
          // Fallback: usa il tempo corrente se non c'è sessionId
          _callStartTime = DateTime.now();
        }
        
        setState(() {
          _isCallStarted = true;
          // _callStartTime è già impostato dalla sincronizzazione sopra
        });
        _startCallTimer();
      } else {
        _showErrorAndExit('Impossibile avviare la chiamata');
      }
    } catch (e) {
      print('❌ Errore avvio chiamata: $e');
      _showErrorAndExit('Errore nell\'avvio della chiamata');
    }
  }

  Future<void> _startIncomingCall() async {
    try {
      print('📞 Avvio chiamata in arrivo già accettata: ${widget.sessionId}');
      
      // CORREZIONE: Sincronizza timer con backend PRIMA di avviare la chiamata
      if (widget.sessionId != null) {
        await _syncCallTimer(widget.sessionId!);
      }
      
      // Avvia la connessione WebRTC
      final success = await _callService.answerCall(widget.sessionId);
      
      if (success) {
        setState(() {
          _isCallStarted = true;
          // _callStartTime è già impostato da _syncCallTimer()
        });
        _startCallTimer();
      } else {
        _showErrorAndExit('Impossibile rispondere alla chiamata');
      }
    } catch (e) {
      print('❌ Errore avvio chiamata in arrivo: $e');
      _showErrorAndExit('Errore nella risposta alla chiamata');
    }
  }

  Future<void> _syncCallTimer(String sessionId) async {
    try {
      print('⏱️ SINCRONIZZAZIONE TIMER: Cercando timestamp per sessione: $sessionId');
      
      // CORREZIONE: Aggiungi autenticazione per API chiamate
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        print('❌ Token non trovato per sincronizzazione timer');
        _callStartTime = DateTime.now();
        return;
      }
      
      // CORREZIONE: Usa endpoint specifico per ottenere il timer della chiamata
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8001/api/webrtc/calls/timer/$sessionId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final startTimeStr = data['start_time'] as String?;
        
        if (startTimeStr != null) {
          // CORREZIONE: Usa SEMPRE il timestamp di creazione della chiamata (dal chiamante)
          final createdAt = DateTime.parse(startTimeStr);
          _callStartTime = createdAt;
          print('✅ TIMER SINCRONIZZATO: Usando timestamp del chiamante: $createdAt');
          print('⏱️ DIFFERENZA: ${DateTime.now().difference(createdAt).inSeconds} secondi fa');
        } else {
          print('⚠️ start_time non trovato nella risposta');
          _callStartTime = DateTime.now();
        }
      } else if (response.statusCode == 404) {
        // Se l'endpoint specifico non esiste, prova con l'endpoint generico
        print('⚠️ Endpoint timer specifico non trovato, usando endpoint generico...');
        await _syncCallTimerFallback(sessionId, token);
      } else {
        print('❌ Errore API timer: ${response.statusCode}');
        _callStartTime = DateTime.now();
      }
    } catch (e) {
      print('❌ Errore sincronizzazione timer: $e');
      // Fallback: prova con endpoint generico
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      if (token != null) {
        await _syncCallTimerFallback(sessionId, token);
      } else {
        _callStartTime = DateTime.now();
      }
    }
  }
  
  /// Fallback per sincronizzazione timer con endpoint generico
  Future<void> _syncCallTimerFallback(String sessionId, String token) async {
    try {
      // Chiama l'API per ottenere i dettagli della chiamata
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8001/api/webrtc/calls/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final calls = data['calls'] as List?;
        
        if (calls != null) {
          // Trova la chiamata corrente
          final currentCall = calls.firstWhere(
            (call) => call['session_id'] == sessionId,
            orElse: () => null,
          );
          
          if (currentCall != null && currentCall['created_at'] != null) {
            // CORREZIONE: Usa il timestamp created_at per sincronizzare con il chiamante
            final createdAt = DateTime.parse(currentCall['created_at']);
            _callStartTime = createdAt;
            print('✅ TIMER SINCRONIZZATO (fallback): Usando timestamp del chiamante: $createdAt');
            print('⏱️ DIFFERENZA (fallback): ${DateTime.now().difference(createdAt).inSeconds} secondi fa');
          } else {
            // Ultimo fallback: usa il tempo corrente
            _callStartTime = DateTime.now();
            print('⚠️ Timer fallback finale: tempo corrente');
          }
        }
      } else {
        // Ultimo fallback: usa il tempo corrente
        _callStartTime = DateTime.now();
        print('⚠️ Timer fallback finale: errore API');
      }
    } catch (e) {
      print('❌ Errore sincronizzazione timer fallback: $e');
      _callStartTime = DateTime.now();
    }
  }

  Future<void> _answerCall() async {
    try {
      // CORREZIONE: Passa il sessionId per chiamate in arrivo
      final success = await _callService.answerCall(widget.sessionId);
      
      if (success) {
        setState(() {
          _isCallStarted = true;
          _callStartTime = DateTime.now();
        });
        _startCallTimer();
      } else {
        _showErrorAndExit('Impossibile rispondere alla chiamata');
      }
    } catch (e) {
      print('❌ Errore risposta chiamata: $e');
      _showErrorAndExit('Errore nella risposta alla chiamata');
    }
  }

  void _startCallTimer() {
    // Timer per aggiornare la durata della chiamata
    Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted && _isCallStarted) {
        setState(() {
          _callDuration = DateTime.now().difference(_callStartTime);
        });
      }
    });
  }

  Future<void> _endCall() async {
    try {
      print('🔚 CallScreen._endCall - Terminando chiamata...');
      
      // Mostra feedback immediato
      _showCallEndingFeedback();
      
      // 1. Termina la chiamata nel servizio nativo
      await _callService.endCall();
      
      // 2. Reset del servizio per evitare problemi di dispose
      _callService.reset();
      
      // 3. Pulisci lo stato delle chiamate
      final callStateManager = CallStateManager();
      callStateManager.endCall();
      
      // 3. Forza cleanup delle chiamate sul backend
      await _forceCleanupBackendCalls();
      
      // Chiamata terminata con successo
      print('✅ CallScreen._endCall - Chiamata terminata con successo');
      
      // 4. CORREZIONE: Forza aggiornamento storico chiamate
      await _refreshCallHistory();
      
      // 5. Naviga indietro alla chat detail in modo sicuro
      await _navigateBackToChat();
      
    } catch (e) {
      print('❌ CallScreen._endCall - Errore terminazione chiamata: $e');
      
      // Anche in caso di errore, torna indietro
      await _navigateBackToChat();
    }
  }

  /// Forza cleanup delle chiamate sul backend
  Future<void> _forceCleanupBackendCalls() async {
    try {
      print('🧹 CallScreen._forceCleanupBackendCalls - Pulizia backend...');
      
      // Chiama endpoint di cleanup
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8001/api/webrtc/calls/cleanup-all-calls/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'reason': 'call_terminated_by_user',
          'cleanup_type': 'terminate_button'
        }),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        print('✅ CallScreen - Backend cleanup completato');
      } else {
        print('⚠️ CallScreen - Errore backend cleanup: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ CallScreen._forceCleanupBackendCalls - Errore: $e');
    }
  }
  

  void _showCallEndingFeedback() {
    if (!mounted) return;
    
    // Mostra feedback che la chiamata sta terminando (senza ScaffoldMessenger)
    print('🔚 Terminando chiamata... (feedback rimosso per compatibilità Material)');
  }
  
  /// Forza refresh dello storico chiamate
  Future<void> _refreshCallHistory() async {
    try {
      print('📞 Aggiornando storico chiamate...');
      
      // Usa Provider per ottenere CallHistoryService
      final callHistoryService = Provider.of<CallHistoryService>(context, listen: false);
      
      // CORREZIONE: Pulisce la cache e forza il refresh immediato
      callHistoryService.clearCache();
      await callHistoryService.loadCallHistory(forceRefresh: true);
      
      print('✅ Storico chiamate aggiornato');
      
    } catch (e) {
      print('❌ Errore aggiornamento storico chiamate: $e');
    }
  }

  Future<void> _navigateBackToChat() async {
    if (!mounted) return;
    
    try {
      // CORREZIONE: Cerca la chat esistente nella cache o naviga alla home
      final otherUserId = widget.calleeId;
      print('📞 Cercando chat con utente: $otherUserId');
      
      // Ottieni tutte le chat dalla cache
      final chats = RealChatService.cachedChats;
      
      // Trova la chat che contiene l'altro utente
      ChatModel? targetChat;
      for (final chat in chats) {
        if (chat.participants.contains(otherUserId) || chat.userId == otherUserId) {
          targetChat = chat;
          break;
        }
      }
      
      if (targetChat != null) {
        print('📞 Navigando alla chat detail reale: ${targetChat.id}');
        context.go('/chat-detail/${targetChat.id}');
        print('✅ Chiamata terminata - navigazione alla chat detail completata');
      } else {
        print('⚠️ Chat non trovata nella cache, navigando alla home');
        context.go('/home');
      }
      
    } catch (e) {
      print('❌ Errore navigazione: $e');
      
      // Fallback: usa GoRouter per andare alla home
      try {
        context.go('/home');
        print('✅ CallScreen - Fallback navigazione home con GoRouter');
      } catch (fallbackError) {
        print('❌ Errore fallback navigazione: $fallbackError');
      }
    }
  }

  void _showErrorAndExit(String message) {
    print('❌ CallScreen._showErrorAndExit - Errore: $message');
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Forza l'utente a premere OK
      builder: (context) => AlertDialog(
        title: const Text(
          'Errore Chiamata',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                // Chiudi dialog
                Navigator.of(context).pop();
                
                // Cleanup forzato del servizio chiamate
                try {
                  await _callService.endCall();
                  _callService.reset();
                } catch (e) {
                  print('Cleanup error: $e');
                  // Forza reset anche in caso di errore
                  _callService.reset();
                }
                
                // Usa la nuova navigazione
                await _navigateBackToChat();
                
              } catch (e) {
                print('❌ Errore durante chiusura dialog: $e');
                
                // Fallback: torna alla home con GoRouter
                if (mounted) {
                  context.go('/home');
                }
              }
            },
            child: const Text(
              'OK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes);
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Gestisce il pulsante back del sistema
        print('🔙 CallScreen - Pulsante back premuto');
        await _endCall();
        return false; // Previene il pop automatico, lo gestiamo noi
      },
      child: Material(
        color: Colors.black, // CORREZIONE: Usa Material invece di Scaffold per evitare footer
        child: SafeArea(
          child: Column(
            children: [
              // Header con info chiamata e pulsante emergenza
              _buildCallHeader(),
              
              // Video area
              Expanded(
                child: _buildVideoArea(_callService),
              ),
              
              // Controls
              _buildCallControls(_callService),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Pulsante emergenza per tornare alla home
          GestureDetector(
            onTap: () async {
              print('🚨 CallScreen - Pulsante emergenza premuto');
              try {
                // Cleanup forzato
                try {
                  await _callService.endCall();
                  _callService.reset();
                } catch (e) {
                  print('Cleanup error: $e');
                  _callService.reset();
                }
                
                // Usa navigazione sicura alla home con GoRouter
                context.go('/home');
              } catch (e) {
                print('❌ Errore pulsante emergenza: $e');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.home,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          
          // Info chiamata (centrata)
          Expanded(
            child: Column(
              children: [
                // Nome contatto
                Text(
                  widget.calleeName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Stato chiamata
                Text(
                  _getCallStatusText(),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
                
                // Durata chiamata (se attiva)
                if (_isCallStarted && _callService.isCallActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Spazio per simmetria
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildVideoArea(NativeAudioCallService callService) {
    if (widget.callType == CallType.audio) {
      // Chiamata audio - mostra avatar
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.3),
                border: Border.all(
                  color: AppTheme.primaryColor,
                  width: 3,
                ),
              ),
              child: const Icon(
                Icons.person,
                size: 80,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            const Icon(
              Icons.phone,
              size: 40,
              color: Colors.white70,
            ),
          ],
        ),
      );
    } else {
      // Chiamata video
      return Stack(
        children: [
          // Audio only - mostra interfaccia audio
            Container(
              color: Colors.grey[900],
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.videocam_off,
                      size: 80,
                      color: Colors.white54,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'In attesa del video...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Local video (picture in picture)
          if (callService.hasLocalVideo)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.mic,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
  }

  Widget _buildCallControls(NativeAudioCallService callService) {
    if (widget.isIncoming && !_isCallStarted) {
      // Controlli per chiamata in arrivo
      return _buildIncomingCallControls();
    } else {
      // Controlli per chiamata attiva
      return _buildActiveCallControls(callService);
    }
  }

  Widget _buildIncomingCallControls() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Rifiuta chiamata
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          
          // Rispondi chiamata
          GestureDetector(
            onTap: _answerCall,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
              ),
              child: const Icon(
                Icons.call,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCallControls(NativeAudioCallService callService) {
    return Container(
      padding: const EdgeInsets.all(30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Toggle microfono
          GestureDetector(
            onTap: callService.toggleMicrophone,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: callService.isMicrophoneEnabled 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.red,
              ),
              child: Icon(
                callService.isMicrophoneEnabled 
                    ? Icons.mic 
                    : Icons.mic_off,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          
          // Termina chiamata
          GestureDetector(
            onTap: _endCall,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          
          // Toggle camera (solo per video)
          if (widget.callType == CallType.video)
            GestureDetector(
              onTap: callService.toggleCamera,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: callService.isCameraEnabled 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.red,
                ),
                child: Icon(
                  callService.isCameraEnabled 
                      ? Icons.videocam 
                      : Icons.videocam_off,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          
          // Switch camera (solo per video)
          if (widget.callType == CallType.video)
            GestureDetector(
              onTap: callService.switchCamera,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.2),
                ),
                child: const Icon(
                  Icons.switch_camera,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getCallStatusText() {
    if (widget.isIncoming && !_isCallStarted) {
        return widget.callType == CallType.video 
            ? 'Videochiamata in arrivo...'
            : 'Chiamata in arrivo...';
    }
    
    switch (_callService.callState) {
      case CallState.idle:
        return 'Preparazione...';
      case CallState.connecting:
        return 'Connessione in corso...';
      case CallState.connected:
        return widget.callType == CallType.video 
            ? 'Videochiamata in corso'
            : 'Chiamata in corso';
      case CallState.disconnected:
        return 'Chiamata terminata';
      case CallState.failed:
        return 'Chiamata fallita';
    }
  }

  @override
  void dispose() {
    // CORREZIONE: Non fare dispose del service singleton qui
    // Il servizio singleton gestisce il proprio lifecycle
    super.dispose();
  }
}
