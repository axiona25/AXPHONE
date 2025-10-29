import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
// import 'package:flutter_webrtc/flutter_webrtc.dart'; // RIMOSSO: Causa crash su macOS
// NOTA: Questo file è temporaneamente disabilitato perché usa WebRTC
// TODO: Implementare video chiamate con sistema nativo in futuro
import '../theme/app_theme.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/real_user_service.dart';
import '../services/active_call_service.dart';
import '../widgets/custom_snackbar.dart';

class VideoCallScreen extends StatefulWidget {
  final String? userId;
  
  const VideoCallScreen({super.key, this.userId});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  UserModel? _otherUser;
  bool _isMuted = false;
  bool _isVideoOn = true;
  bool _isSpeakerOn = true;
  bool _isCallActive = true;
  Duration _callDuration = Duration.zero;
  late Timer _callTimer;
  
  // WebRTC - DISABILITATO per evitare crash
  // RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  // RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  // MediaStream? _localStream;
  // MediaStream? _remoteStream;

  @override
  void initState() {
    super.initState();
    _loadUser();
    
    // Avvia o aggiorna la chiamata con l'utente corrente
    if (widget.userId != null) {
      ActiveCallService.startCall(
        callType: 'video',
        userId: widget.userId!,
      );
    }
    
    // Inizializza la durata dal servizio
    _callDuration = ActiveCallService.callDuration ?? Duration.zero;
    
    // Avvia il timer per aggiornare l'UI
    _startCallTimer();
    
    // Animazione pulsante per il microfono
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    
    // Inizializza WebRTC in modo asincrono
    _initializeWebRTCAsync();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _callTimer.cancel();
    _disposeWebRTC();
    super.dispose();
  }

  void _loadUser() async {
    // Leggi sempre l'utente dal servizio, non dal widget
    final currentUserId = ActiveCallService.userId;
    print('📹 VideoCallScreen._loadUser - ActiveCallService.userId: $currentUserId');
    print('📹 VideoCallScreen._loadUser - widget.userId: ${widget.userId}');
    
    if (currentUserId != null) {
      print('📹 VideoCallScreen._loadUser - Caricando utente con ID: $currentUserId');
      
      // Prova prima con UserService.getUserById
      final user = await UserService.getUserById(currentUserId);
      print('📹 VideoCallScreen._loadUser - UserService.getUserById risultato: ${user?.name ?? 'NULL'} (ID: ${user?.id ?? 'NULL'})');
      
      if (user == null) {
        print('📹 VideoCallScreen._loadUser - UserService non ha trovato l\'utente, provo RealUserService');
        final realUser = await RealUserService.getUserById(currentUserId);
        print('📹 VideoCallScreen._loadUser - RealUserService.getUserById risultato: ${realUser?.name ?? 'NULL'} (ID: ${realUser?.id ?? 'NULL'})');
        
        if (mounted) {
          setState(() {
            _otherUser = realUser;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _otherUser = user;
          });
        }
      }
    } else {
      print('📹 VideoCallScreen._loadUser - currentUserId è NULL!');
    }
  }

  @override
  void didUpdateWidget(VideoCallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Ricarica sempre l'utente per assicurarsi che sia aggiornato
    _loadUser();
  }

  void _startCallTimer() {
    // Non creare un timer locale, usa solo quello del servizio
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Leggi sempre la durata dal servizio
          _callDuration = ActiveCallService.callDuration ?? Duration.zero;
        });
        
        // Ricarica l'utente per assicurarsi che sia sempre aggiornato
        _loadUser();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video principale (sfondo)
          _buildMainVideo(),
          
          // Overlay con controlli
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainVideo() {
    // WebRTC disabilitato per evitare crash - mostra sempre l'avatar
    print('📹 VideoCallScreen._buildMainVideo - WebRTC disabilitato, mostrando avatar');
    return _buildFallbackVideo();
  }

  Widget _buildFallbackVideo() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withOpacity(0.8),
            Colors.black,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar grande
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 4,
                      ),
                    ),
                    child: ClipOval(
                      child: _buildInitialsAvatar(),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // Nome utente
            Text(
              _otherUser?.name ?? 'Utente',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Stato della chiamata
            Text(
              _isCallActive ? 'Chiamata in corso' : 'Chiamata terminata',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            // Durata della chiamata
            Text(
              _formatDuration(_callDuration),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    if (_otherUser == null) {
      return Container(
        width: 200,
        height: 200,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 100),
      );
    }
    
    print('📹 VideoCallScreen._buildInitialsAvatar - User: ${_otherUser!.name} (ID: ${_otherUser!.id})');
    return MasterAvatarWidget.fromUser(
      user: _otherUser!,
      size: 200,
    );
  }

  Widget _buildOverlay() {
    return SafeArea(
      child: Column(
        children: [
          // Status bar e navigazione
          _buildTopBar(),
          
          // Spazio per centrare il contenuto
          const Spacer(),
          
          // Contenuto principale
          _buildMainContent(),
          
          // Spazio per centrare il contenuto
          const Spacer(),
          
          // Controlli di chiamata
          _buildCallControls(),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Pulsante indietro
          GestureDetector(
            onTap: () {
              // Torna alla home
              context.go('/home');
            },
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          // Spazio vuoto per bilanciare il layout
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Non mostrare nulla qui, tutto è nel fallback video
    return const SizedBox.shrink();
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Microfono
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            isActive: !_isMuted,
            onTap: _toggleMute,
          ),
          
          // Speaker
          _buildControlButton(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
            isActive: _isSpeakerOn,
            onTap: _toggleSpeaker,
          ),
          
          // Video
          _buildControlButton(
            icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
            isActive: _isVideoOn,
            onTap: _toggleVideo,
          ),
          
          // Termina chiamata
          _buildControlButton(
            icon: Icons.call_end,
            isActive: false,
            backgroundColor: Colors.red,
            onTap: _endCall,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    Color? backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? (isActive ? AppTheme.primaryColor : Colors.grey[600]),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOn = !_isVideoOn;
    });
    
    // Gestisci il video stream
    if (_isVideoOn) {
      _startLocalVideo();
    } else {
      _stopLocalVideo();
    }
  }
  
  // Inizializza WebRTC in modo asincrono (DISABILITATO per evitare crash)
  Future<void> _initializeWebRTCAsync() async {
    try {
      print('📹 VideoCallScreen._initializeWebRTCAsync - WebRTC disabilitato per evitare crash');
      // WebRTC disabilitato temporaneamente per evitare crash
      // await _localRenderer.initialize();
      // await _remoteRenderer.initialize();
      print('📹 VideoCallScreen._initializeWebRTCAsync - WebRTC disabilitato, usando solo avatar');
    } catch (e) {
      print('📹 VideoCallScreen._initializeWebRTCAsync - Errore inizializzazione WebRTC: $e');
      // Continua senza WebRTC se c'è un errore
    }
  }
  
  // Avvia il video locale (DISABILITATO per evitare crash)
  Future<void> _startLocalVideo() async {
    try {
      print('📹 VideoCallScreen._startLocalVideo - Video locale disabilitato per evitare crash');
      // Video locale disabilitato temporaneamente per evitare crash
      // _localStream = await navigator.mediaDevices.getUserMedia({
      //   'video': true,
      //   'audio': true,
      // });
      // _localRenderer.srcObject = _localStream;
      print('📹 VideoCallScreen._startLocalVideo - Video locale disabilitato, usando solo avatar');
    } catch (e) {
      print('📹 VideoCallScreen._startLocalVideo - Errore nell\'avvio del video locale: $e');
    }
  }
  
  // Ferma il video locale (DISABILITATO per evitare crash)
  Future<void> _stopLocalVideo() async {
    try {
      print('📹 VideoCallScreen._stopLocalVideo - Video locale disabilitato per evitare crash');
      // Video locale disabilitato temporaneamente per evitare crash
      // if (_localStream != null) {
      //   await _localStream!.dispose();
      //   _localStream = null;
      // }
      // _localRenderer.srcObject = null;
      print('📹 VideoCallScreen._stopLocalVideo - Video locale disabilitato, usando solo avatar');
    } catch (e) {
      print('📹 VideoCallScreen._stopLocalVideo - Errore nella pulizia del video locale: $e');
    }
  }
  
  // Pulisce WebRTC (DISABILITATO per evitare crash)
  Future<void> _disposeWebRTC() async {
    try {
      print('📹 VideoCallScreen._disposeWebRTC - WebRTC disabilitato per evitare crash');
      // WebRTC disabilitato temporaneamente per evitare crash
      // await _stopLocalVideo();
      // if (_remoteStream != null) {
      //   await _remoteStream!.dispose();
      //   _remoteStream = null;
      // }
      // await _localRenderer.dispose();
      // await _remoteRenderer.dispose();
      print('📹 VideoCallScreen._disposeWebRTC - WebRTC disabilitato, usando solo avatar');
    } catch (e) {
      print('📹 VideoCallScreen._disposeWebRTC - Errore durante la pulizia: $e');
    }
  }

  void _endCall() {
    setState(() {
      _isCallActive = false;
    });
    
    // Termina la chiamata e torna alla chat di origine
    ActiveCallService.endCall();
    context.go('/');
  }
}
