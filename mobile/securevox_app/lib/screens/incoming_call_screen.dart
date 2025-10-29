import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../services/call_sound_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../models/user_model.dart';
import '../widgets/custom_snackbar.dart';

class IncomingCallScreen extends StatefulWidget {
  final UserModel caller;
  final bool isVideoCall;
  
  const IncomingCallScreen({
    super.key,
    required this.caller,
    this.isVideoCall = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _slideAnimation;
  
  final CallSoundService _soundService = CallSoundService();

  @override
  void initState() {
    super.initState();
    
    // SUONO: Inizializza e avvia suoneria per chiamata in arrivo
    _initializeAndStartRingtone();
    
    // Animazione pulsante per il pulsante di risposta
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    // Avvia le animazioni
    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  /// Inizializza e avvia la suoneria
  void _initializeAndStartRingtone() async {
    try {
      await _soundService.initialize();
      await _soundService.startIncomingCallSound();
      print('🔊 IncomingCallScreen - Suoneria avviata');
    } catch (e) {
      print('❌ IncomingCallScreen - Errore suoneria: $e');
    }
  }

  @override
  void dispose() {
    // SUONO: Ferma suoneria quando si esce dalla schermata
    _soundService.stopIncomingCallSound();
    
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.black, // CORREZIONE: Usa Material invece di Scaffold per consistenza UI
        child: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(
              widget.caller.profileImage ?? '',
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.3),
              BlendMode.darken,
            ),
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
              
              const SizedBox(height: 40),
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
          // Ora
          Text(
            _getCurrentTime(),
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Avatar del chiamante
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 3,
            ),
          ),
          child: ClipOval(
            child: widget.caller.profileImage != null && widget.caller.profileImage!.isNotEmpty
                ? Image.network(
                    widget.caller.profileImage!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildInitialsAvatar();
                    },
                  )
                : _buildInitialsAvatar(),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Nome del chiamante
        Text(
          widget.caller.name,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Tipo di chiamata
        Text(
          widget.isVideoCall ? 'Chiamata video in arrivo' : 'Chiamata audio in arrivo',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInitialsAvatar() {
    print('📞 IncomingCallScreen._buildInitialsAvatar - User: ${widget.caller.name} (ID: ${widget.caller.id})');
    return MasterAvatarWidget.fromUser(
      user: widget.caller,
      size: 120,
    );
  }

  Widget _buildCallControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Opzioni Remind me e Message
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlOption(
                icon: Icons.alarm,
                label: 'Ricordami',
                onTap: _onRemindMe,
              ),
              _buildControlOption(
                icon: Icons.message,
                label: 'Messaggio',
                onTap: _onSendMessage,
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Pulsante di risposta con animazione
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: GestureDetector(
                  onTap: _onAnswerCall,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Testo "scorri per rispondere"
          Text(
            'Tocca per rispondere',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Pulsante rifiuta
          GestureDetector(
            onTap: _onDeclineCall,
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _onAnswerCall() {
    // SUONO: Ferma suoneria prima di navigare
    _soundService.stopIncomingCallSound();
    print('🔊 IncomingCallScreen - Suoneria fermata, chiamata accettata');
    
    // Naviga alla schermata di chiamata attiva
    if (widget.isVideoCall) {
      print('📞 IncomingCallScreen - Navigando a video call: /video-call/${widget.caller.id}');
      context.go('/video-call/${widget.caller.id}');
    } else {
      print('📞 IncomingCallScreen - Navigando a audio call: /audio-call/${widget.caller.id}');
      context.go('/audio-call/${widget.caller.id}');
    }
  }

  void _onDeclineCall() {
    // SUONO: Ferma suoneria prima di uscire
    _soundService.stopIncomingCallSound();
    print('🔊 IncomingCallScreen - Suoneria fermata, chiamata rifiutata');
    
    // Torna indietro
    context.pop();
  }

  void _onRemindMe() {
    // TODO: Implementare promemoria
    CustomSnackBar.showSuccess(
      context,
      'Promemoria impostato',
    );
  }

  void _onSendMessage() {
    // TODO: Implementare invio messaggio
    CustomSnackBar.showPrimary(
      context,
      'Apertura messaggi...',
    );
  }
}
