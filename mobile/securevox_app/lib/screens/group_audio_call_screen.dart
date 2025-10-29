import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/unified_avatar_service.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/active_call_service.dart';

class GroupAudioCallScreen extends StatefulWidget {
  final List<String>? userIds;
  
  const GroupAudioCallScreen({super.key, this.userIds});

  @override
  State<GroupAudioCallScreen> createState() => _GroupAudioCallScreenState();
}

class _GroupAudioCallScreenState extends State<GroupAudioCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  List<UserModel> _participants = [];
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCallActive = true;
  Duration _callDuration = Duration.zero;
  late Timer _callTimer;
  int _currentMainParticipant = 0;

  @override
  void initState() {
    super.initState();
    _loadParticipants();
    
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
    _pulseController.dispose();
    _callTimer.cancel();
    super.dispose();
  }

  void _loadParticipants() {
    // Leggi sempre i partecipanti dal servizio, non dal widget
    final currentUserIds = ActiveCallService.userIds;
    if (currentUserIds != null) {
      final participants = currentUserIds
          .map((id) => UserService.getUserById(id))
          .where((user) => user != null)
          .cast<UserModel>()
          .toList();
      
      setState(() {
        _participants = participants;
      });
    }
  }

  void _startCallTimer() {
    // Non creare un timer locale, usa solo quello del servizio
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Leggi sempre la durata dal servizio
          _callDuration = ActiveCallService.callDuration ?? Duration.zero;
        });
        
        // Ricarica i partecipanti per assicurarsi che siano sempre aggiornati
        _loadParticipants();
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
            onTap: () => context.pop(),
            child: const Icon(
              Icons.arrow_back_ios,
              color: Colors.white,
              size: 20,
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Avatar del partecipante principale
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
                  child: _participants.isNotEmpty
                      ? _buildInitialsAvatar(_participants[_currentMainParticipant])
                      : _buildEmptyAvatar(),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 32),
        
        // Nome del partecipante principale
        Text(
          _participants.isNotEmpty ? _participants[_currentMainParticipant].name : 'Utente',
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
          _isCallActive ? 'Chiamata di gruppo in corso' : 'Chiamata terminata',
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

  Widget _buildInitialsAvatar(UserModel participant) {
    print('🎵 GroupAudioCallScreen._buildInitialsAvatar - User: ${participant.name} (ID: ${participant.id})');
    return UnifiedAvatarService.buildUserAvatar(
      userId: participant.id,
      userName: participant.name,
      profileImageUrl: participant.profileImage,
      size: 200,
    );
  }

  Widget _buildEmptyAvatar() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[600],
      ),
      child: const Center(
        child: Icon(
          Icons.group,
          color: Colors.white,
          size: 60,
        ),
      ),
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
          
          // Lista partecipanti
          _buildParticipantsList(),
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

  Widget _buildParticipantsList() {
    if (_participants.isEmpty) return const SizedBox.shrink();
    
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _participants.length,
        itemBuilder: (context, index) {
          final participant = _participants[index];
          final isMain = index == _currentMainParticipant;
          
          return GestureDetector(
            onTap: () => _switchMainParticipant(index),
            child: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isMain ? AppTheme.primaryColor : Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: _buildSmallInitialsAvatar(participant),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSmallInitialsAvatar(UserModel participant) {
    return UnifiedAvatarService.buildUserAvatar(
      userId: participant.id,
      userName: participant.name,
      profileImageUrl: participant.profileImage,
      size: 50,
    );
  }


  void _switchMainParticipant(int index) {
    setState(() {
      _currentMainParticipant = index;
    });
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
    
    // Torna indietro dopo un breve delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        context.pop();
      }
    });
  }
}
