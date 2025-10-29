import '../models/call_model.dart';
import 'package:flutter/material.dart';
import '../services/native_audio_call_service.dart';
import 'package:provider/provider.dart';
// import '../services/webrtc_call_service.dart'; // RIMOSSO: File eliminato
import '../theme/app_theme.dart';
import 'call_screen.dart';

class IncomingCallOverlay extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String callerAvatar;
  final String sessionId;
  final CallType callType;

  const IncomingCallOverlay({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.callerAvatar,
    required this.sessionId,
    required this.callType,
  });

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animazione pulsante per l'avatar
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Animazione slide dall'alto
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Avvia animazioni
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _answerCall() async {
    final callService = Provider.of<NativeAudioCallService>(context, listen: false);
    
    // Ferma animazioni
    _pulseController.stop();
    
    // Naviga alla schermata chiamata
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => CallScreen(
          calleeId: widget.callerId,
          calleeName: widget.callerName,
          callType: widget.callType,
          isIncoming: true,
        ),
      ),
    );
    
    // Rispondi alla chiamata
    await callService.answerCall();
  }

  void _rejectCall() async {
    try {
      print('❌ IncomingCallOverlay._rejectCall - Rifiutando chiamata...');
      
      final callService = Provider.of<NativeAudioCallService>(context, listen: false);
      
      // Animazione slide out (con timeout)
      try {
        await _slideController.reverse().timeout(const Duration(seconds: 1));
      } catch (e) {
        print('⚠️ Timeout animazione slide out: $e');
      }
      
      // Chiudi overlay in modo sicuro
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Rifiuta chiamata (non bloccare se fallisce)
      try {
        await callService.endCall();
      } catch (e) {
        print('⚠️ Errore rifiuto chiamata (non critico): $e');
      }
      
      print('✅ IncomingCallOverlay._rejectCall - Chiamata rifiutata');
      
    } catch (e) {
      print('❌ IncomingCallOverlay._rejectCall - Errore: $e');
      
      // Fallback: chiudi overlay comunque
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
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
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Tipo chiamata
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
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
                      const SizedBox(width: 8),
                      Text(
                        widget.callType == CallType.video
                            ? 'Videochiamata in arrivo'
                            : 'Chiamata in arrivo',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Avatar con animazione pulse
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: widget.callerAvatar.isNotEmpty
                              ? Image.network(
                                  widget.callerAvatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildDefaultAvatar();
                                  },
                                )
                              : _buildDefaultAvatar(),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Nome chiamante
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                // Stato chiamata
                Text(
                  'SecureVox',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
                
                const Spacer(),
                
                // Controlli chiamata
                _buildCallControls(),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.7),
          ],
        ),
      ),
      child: const Icon(
        Icons.person,
        size: 80,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Pulsante rifiuta
          GestureDetector(
            onTap: _rejectCall,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          
          // Pulsante rispondi
          GestureDetector(
            onTap: _answerCall,
            child: Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
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
}
