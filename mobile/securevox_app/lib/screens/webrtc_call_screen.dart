import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart'; // Temporaneamente disabilitato
import '../services/securevox_call_service.dart';
import '../services/auth_service.dart';
import '../services/real_chat_service.dart';
import '../services/user_service.dart';
import '../models/chat_model.dart';
import '../models/call_model.dart';
import '../theme/app_theme.dart';

/// Schermata di chiamata WebRTC reale con SecureVOX Call
class WebRTCCallScreen extends StatefulWidget {
  final String calleeId;
  final String calleeName;
  final CallType callType;
  final bool isIncoming;
  final String? sessionId;

  const WebRTCCallScreen({
    super.key,
    required this.calleeId,
    required this.calleeName,
    required this.callType,
    this.isIncoming = false,
    this.sessionId,
  });

  @override
  State<WebRTCCallScreen> createState() => _WebRTCCallScreenState();
}

class _WebRTCCallScreenState extends State<WebRTCCallScreen>
    with TickerProviderStateMixin {
  late SecureVOXCallService _callService;
  late AuthService _authService;
  
  // Renderers video
  // final RTCVideoRenderer _localRenderer = RTCVideoRenderer(); // Temporaneamente disabilitato
  // final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer(); // Temporaneamente disabilitato
  
  // Animazioni
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Timer
  Timer? _connectionTimer;
  bool _isConnected = false;
  
  @override
  void initState() {
    super.initState();
    
    print('🎥 WebRTCCallScreen.initState - ${widget.calleeName}');
    print('🎥 CallType: ${widget.callType}, IsIncoming: ${widget.isIncoming}');
    print('🎥 SessionId: ${widget.sessionId}');
    
    // Forza schermo intero
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    // Inizializza servizi
    _callService = Provider.of<SecureVOXCallService>(context, listen: false);
    _authService = Provider.of<AuthService>(context, listen: false);
    
    // Inizializza renderers
    _initializeRenderers();
    
    // Setup animazioni
    _setupAnimations();
    
    // Avvia chiamata
    _initializeCall();
  }
  
  Future<void> _initializeRenderers() async {
    // try {
    //   await _localRenderer.initialize();
    //   await _remoteRenderer.initialize();
    //   print('✅ Video renderers inizializzati');
    // } catch (e) {
    //   print('❌ Errore inizializzazione renderers: $e');
    // } // Temporaneamente disabilitato
    print('⚠️ WebRTCCallScreen - Renderers temporaneamente disabilitati');
  }
  
  void _setupAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }
  
  Future<void> _initializeCall() async {
    try {
      // Inizializza servizio se necessario
      if (!_callService.isInitialized) {
        await _callService.initialize();
      }
      
      // Autentica utente
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('Utente non autenticato');
      }
      
      await _callService.authenticate(currentUser.id);
      
      // Setup listeners
      _callService.addListener(_onCallServiceUpdate);
      
      // Avvia o rispondi alla chiamata
      if (widget.isIncoming && widget.sessionId != null) {
        // Risposta chiamata
        await _callService.answerCall(widget.sessionId!);
      } else {
        // Nuova chiamata
        final sessionId = widget.sessionId ?? 
            'call_${currentUser.id}_${widget.calleeId}_${DateTime.now().millisecondsSinceEpoch}';
        
        await _callService.startCall(
          widget.calleeId,
          sessionId,
          isVideoCall: widget.callType == CallType.video,
        );
      }
      
      // Timer di connessione
      _startConnectionTimer();
      
    } catch (e) {
      print('❌ Errore inizializzazione chiamata: $e');
      _showErrorAndExit('Errore durante l\'avvio della chiamata: $e');
    }
  }
  
  void _onCallServiceUpdate() {
    if (!mounted) return;
    
    setState(() {
      // Aggiorna stream video
      // if (_callService.localStream != null) {
      //   _localRenderer.srcObject = _callService.localStream;
      // }
      
      // if (_callService.remoteStream != null) {
      //   _remoteRenderer.srcObject = _callService.remoteStream;
      //   _isConnected = true;
      //   _connectionTimer?.cancel();
      // } // Temporaneamente disabilitato
    });
  }
  
  void _startConnectionTimer() {
    _connectionTimer = Timer(const Duration(seconds: 30), () {
      if (!_isConnected && mounted) {
        _showErrorAndExit('Timeout connessione - chiamata non riuscita');
      }
    });
  }
  
  Future<void> _endCall() async {
    try {
      print('📞 WebRTCCallScreen - Terminando chiamata...');
      
      await _callService.endCall();
      
      // Naviga alla chat detail reale
      await _navigateBackToChat();
      
    } catch (e) {
      print('❌ Errore terminazione chiamata: $e');
      _navigateToHome();
    }
  }
  
  Future<void> _navigateBackToChat() async {
    if (!mounted) return;
    
    try {
      final otherUserId = widget.calleeId;
      print('📞 Cercando chat con utente: $otherUserId');
      
      final chats = RealChatService.cachedChats;
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
      } else {
        print('⚠️ Chat non trovata, navigando alla home');
        context.go('/home');
      }
      
    } catch (e) {
      print('❌ Errore navigazione: $e');
      _navigateToHome();
    }
  }
  
  void _navigateToHome() {
    try {
      context.go('/home');
    } catch (e) {
      print('❌ Errore navigazione home: $e');
    }
  }
  
  void _showErrorAndExit(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Errore Chiamata'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToHome();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _endCall();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: null,
        bottomNavigationBar: null,
        body: Consumer<SecureVOXCallService>(
          builder: (context, callService, child) {
            return Stack(
              children: [
                // Background video o avatar
                _buildVideoBackground(),
                
                // Overlay informazioni chiamata
                _buildCallOverlay(callService),
                
                // Controlli chiamata
                _buildCallControls(callService),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildVideoBackground() {
    // if (widget.callType == CallType.video && _callService.remoteStream != null) { // Temporaneamente disabilitato per problemi iOS
    if (widget.callType == CallType.video) {
      // Video remoto a schermo intero
      return Positioned.fill(
        child: Container(
          color: Colors.black,
          child: Center(
            child: Text(
              'Video Remoto\n(Temporaneamente disabilitato)',
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    } else {
      // Avatar di sfondo per chiamate audio
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor.withOpacity(0.8),
              Colors.black.withOpacity(0.9),
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: AppTheme.primaryColor,
                  child: Text(
                    widget.calleeName.isNotEmpty 
                        ? widget.calleeName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }
  
  Widget _buildCallOverlay(SecureVOXCallService callService) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: Column(
        children: [
          // Nome chiamante/ricevente
          Text(
            widget.calleeName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 4,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Stato chiamata e timer
          Text(
            _isConnected 
                ? _formatDuration(callService.callDuration)
                : (widget.isIncoming ? 'Chiamata in arrivo...' : 'Connessione...'),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Indicatore tipo chiamata
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.callType == CallType.video 
                      ? Icons.videocam 
                      : Icons.phone,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  widget.callType == CallType.video 
                      ? 'Video chiamata' 
                      : 'Chiamata audio',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCallControls(SecureVOXCallService callService) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Video locale (se video call)
          // if (widget.callType == CallType.video && callService.localStream != null) // Temporaneamente disabilitato per problemi iOS
          if (widget.callType == CallType.video)
            Container(
              margin: const EdgeInsets.only(bottom: 20, right: 20),
              alignment: Alignment.bottomRight,
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.grey[800],
                    child: Center(
                      child: Text(
                        'Video Locale\n(Temporaneamente disabilitato)',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          
          // Controlli principali
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute audio
              _buildControlButton(
                icon: callService.isAudioMuted ? Icons.mic_off : Icons.mic,
                color: callService.isAudioMuted ? Colors.red : Colors.white,
                backgroundColor: callService.isAudioMuted 
                    ? Colors.red.withOpacity(0.2) 
                    : Colors.black26,
                onPressed: () => callService.toggleAudio(),
              ),
              
              // Speaker
              _buildControlButton(
                icon: callService.isSpeakerEnabled 
                    ? Icons.volume_up 
                    : Icons.volume_down,
                color: Colors.white,
                backgroundColor: Colors.black26,
                onPressed: () => callService.toggleSpeaker(),
              ),
              
              // Termina chiamata
              _buildControlButton(
                icon: Icons.call_end,
                color: Colors.white,
                backgroundColor: Colors.red,
                size: 64,
                onPressed: _endCall,
              ),
              
              // Video toggle (se video call)
              if (widget.callType == CallType.video)
                _buildControlButton(
                  icon: callService.isVideoMuted 
                      ? Icons.videocam_off 
                      : Icons.videocam,
                  color: callService.isVideoMuted ? Colors.red : Colors.white,
                  backgroundColor: callService.isVideoMuted 
                      ? Colors.red.withOpacity(0.2) 
                      : Colors.black26,
                  onPressed: () => callService.toggleVideo(),
                ),
              
              // Switch camera (se video call)
              if (widget.callType == CallType.video)
                _buildControlButton(
                  icon: Icons.switch_camera,
                  color: Colors.white,
                  backgroundColor: Colors.black26,
                  onPressed: () {
                    // TODO: Implementare switch camera
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onPressed,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.4,
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    print('🧹 WebRTCCallScreen.dispose');
    
    // Cleanup
    _connectionTimer?.cancel();
    _pulseController.dispose();
    _callService.removeListener(_onCallServiceUpdate);
    
    // Cleanup renderers
    // _localRenderer.dispose(); // Temporaneamente disabilitato
    // _remoteRenderer.dispose(); // Temporaneamente disabilitato
    
    // Ripristina system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    
    super.dispose();
  }
}
