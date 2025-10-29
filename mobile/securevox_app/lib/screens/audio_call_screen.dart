import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/real_user_service.dart';
import '../services/active_call_service.dart';

class AudioCallScreen extends StatefulWidget {
  final String? userId;
  
  const AudioCallScreen({super.key, this.userId});

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  UserModel? _otherUser;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallActive = true;
  Duration _callDuration = Duration.zero;
  late Timer _callTimer;

  @override
  void initState() {
    super.initState();
    print('🎵 AudioCallScreen.initState - widget.userId: ${widget.userId}');
    print('🎵 AudioCallScreen.initState - ActiveCallService.userId: ${ActiveCallService.userId}');
    print('🔍 AudioCallScreen.initState - SCHERMO INTERO FORZATO');
    
    // CORREZIONE: Nascondi completamente l'UI di sistema per schermo intero
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    
    _loadUser();
    
    // Avvia o aggiorna la chiamata con l'utente corrente
    if (widget.userId != null) {
      print('🎵 AudioCallScreen.initState - Avviando chiamata con userId: ${widget.userId}');
      ActiveCallService.startCall(
        callType: 'audio',
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
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    // CORREZIONE: Ripristina UI di sistema quando si esce
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    
    _pulseController.dispose();
    _callTimer.cancel();
    super.dispose();
  }

  void _loadUser() async {
    // Leggi sempre l'utente dal servizio, non dal widget
    final currentUserId = ActiveCallService.userId;
    print('🎵 AudioCallScreen._loadUser - ActiveCallService.userId: $currentUserId');
    print('🎵 AudioCallScreen._loadUser - widget.userId: ${widget.userId}');
    
    if (currentUserId != null) {
      print('🎵 AudioCallScreen._loadUser - Caricando utente con ID: $currentUserId');
      
      // Prova prima con UserService.getUserById
      final user = await UserService.getUserById(currentUserId);
      print('🎵 AudioCallScreen._loadUser - UserService.getUserById risultato: ${user?.name ?? 'NULL'} (ID: ${user?.id ?? 'NULL'})');
      
      // Se non trova l'utente, prova con RealUserService direttamente
      if (user == null) {
        print('🎵 AudioCallScreen._loadUser - UserService non ha trovato l\'utente, provo RealUserService');
        try {
          final realUser = await RealUserService.getUserById(currentUserId);
          print('🎵 AudioCallScreen._loadUser - RealUserService.getUserById risultato: ${realUser?.name ?? 'NULL'} (ID: ${realUser?.id ?? 'NULL'})');
          if (realUser != null && mounted) {
            setState(() {
              _otherUser = realUser;
            });
            return;
          }
        } catch (e) {
          print('🎵 AudioCallScreen._loadUser - Errore RealUserService: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _otherUser = user;
        });
      }
    } else {
      print('🎵 AudioCallScreen._loadUser - currentUserId è NULL!');
    }
  }

  @override
  void didUpdateWidget(AudioCallScreen oldWidget) {
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
      extendBodyBehindAppBar: true,
      appBar: null, // NESSUNA AppBar
      bottomNavigationBar: null, // NESSUN Footer forzato
      body: Container(
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
        child: SafeArea(
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
        ),
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
              // Torna alla home e mostra picture-in-picture se necessario
              context.go('/home');
            },
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
          ),
          
          // Icone di stato e controlli
          Row(
            children: [
              // Pulsante per tornare al picture-in-picture
              GestureDetector(
                onTap: () {
                  // Torna alla home mantenendo la chiamata in background
                  context.go('/home');
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.picture_in_picture,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Avatar dell'altro utente
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
                  child: _otherUser?.profileImage != null && _otherUser!.profileImage!.isNotEmpty
                      ? Image.network(
                          _otherUser!.profileImage!,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildInitialsAvatar();
                          },
                        )
                      : _buildInitialsAvatar(),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 32),
        
        // Nome dell'altro utente
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
        
        const SizedBox(height: 8),
        
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
    
    print('🎵 AudioCallScreen._buildInitialsAvatar - User: ${_otherUser!.name} (ID: ${_otherUser!.id})');
    return MasterAvatarWidget.fromUser(
      user: _otherUser!,
      size: 200,
    );
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
      child: Column(
        children: [
          // Controlli principali
          Row(
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
              
              // Termina chiamata
              _buildControlButton(
                icon: Icons.call_end,
                isActive: false,
                backgroundColor: Colors.red,
                onTap: _endCall,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Indicatori di stato
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatusIndicator('Microfono', !_isMuted),
              _buildStatusIndicator('Speaker', _isSpeakerOn),
            ],
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
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor ?? (isActive ? AppTheme.primaryColor : Colors.grey[600]),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.green : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
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

  void _endCall() {
    setState(() {
      _isCallActive = false;
    });
    
    // Termina la chiamata e torna alla chat di origine
    ActiveCallService.endCall();
    context.go('/');
  }
}