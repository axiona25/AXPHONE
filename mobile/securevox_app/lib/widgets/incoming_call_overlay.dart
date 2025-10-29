import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class IncomingCallOverlay extends StatefulWidget {
  final Map<String, dynamic> callData;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDismiss; // Per compatibilità con codice esistente

  const IncomingCallOverlay({
    Key? key,
    required this.callData,
    this.onAccept,
    this.onReject,
    this.onDismiss,
  }) : super(key: key);

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
    
    // Animazione pulsante
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
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
      curve: Curves.easeOutBack,
    ));

    _slideController.forward();

    // Vibrazione
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callerName = widget.callData['caller_name'] ?? 'Sconosciuto';
    final callType = widget.callData['call_type'] ?? 'audio';
    final isVideoCall = callType == 'video';

    return Material(
      color: Colors.transparent,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.9),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                
                // Titolo chiamata
                Text(
                  isVideoCall ? 'Videochiamata in arrivo' : 'Chiamata in arrivo',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Avatar del chiamante
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[800],
                          child: Text(
                            callerName.isNotEmpty 
                                ? callerName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Nome chiamante
                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 10),
                
                // Tipo chiamata
                Text(
                  isVideoCall ? 'Videochiamata' : 'Chiamata vocale',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                
                const Spacer(),
                
                // Pulsanti azione
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Pulsante rifiuta (rosso)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (widget.onReject != null) {
                            widget.onReject!();
                          } else if (widget.onDismiss != null) {
                            widget.onDismiss!();
                          }
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      
                      // Pulsante accetta (verde)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (widget.onAccept != null) {
                            widget.onAccept!();
                          } else if (widget.onDismiss != null) {
                            widget.onDismiss!();
                          }
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideoCall ? Icons.videocam : Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }
}