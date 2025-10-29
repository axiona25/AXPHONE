import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../theme/app_theme.dart';
import '../services/user_service.dart';
import '../services/real_user_service.dart';
import '../services/active_call_service.dart';
import '../models/user_model.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';

class CallPipWidget extends StatefulWidget {
  final String callType;
  final String? userId;
  final List<String>? userIds;
  final VoidCallback onExpand;
  final VoidCallback onEnd;

  const CallPipWidget({
    super.key,
    required this.callType,
    this.userId,
    this.userIds,
    required this.onExpand,
    required this.onEnd,
  });

  @override
  State<CallPipWidget> createState() => _CallPipWidgetState();
}

class _CallPipWidgetState extends State<CallPipWidget> {
  UserModel? _user;
  String _displayName = 'Chiamata';
  String _displayTime = '00:00';
  Timer? _uiUpdateTimer;
  
  // Posizione del widget PIP
  Offset _position = const Offset(0, 0);
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadCallInfo();
    _startUiUpdateTimer();
    
    // Inizializza la posizione di default (sotto l'header a destra)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenSize = MediaQuery.of(context).size;
        final statusBarHeight = MediaQuery.of(context).padding.top;
        setState(() {
          _position = Offset(
            screenSize.width - 180, // 160 (larghezza widget) + 20 (margine)
            statusBarHeight + 80, // Sotto l'header
          );
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant CallPipWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId || 
        widget.userIds != oldWidget.userIds || 
        widget.callType != oldWidget.callType) {
      _loadCallInfo();
    }
  }

  void _loadCallInfo() async {
    if (widget.userId != null) {
      print('📱 CallPipWidget._loadCallInfo - Caricando utente con ID: ${widget.userId}');
      
      // Prova prima con UserService.getUserById
      final user = await UserService.getUserById(widget.userId!);
      print('📱 CallPipWidget._loadCallInfo - UserService.getUserById risultato: ${user?.name ?? 'NULL'} (ID: ${user?.id ?? 'NULL'})');
      
      // Se non trova l'utente, prova con RealUserService direttamente
      if (user == null) {
        print('📱 CallPipWidget._loadCallInfo - UserService non ha trovato l\'utente, provo RealUserService');
        try {
          final realUser = await RealUserService.getUserById(widget.userId!);
          print('📱 CallPipWidget._loadCallInfo - RealUserService.getUserById risultato: ${realUser?.name ?? 'NULL'} (ID: ${realUser?.id ?? 'NULL'})');
          if (mounted) {
            setState(() {
              _user = realUser;
              _displayName = realUser?.name ?? 'Utente Sconosciuto';
            });
            return;
          }
        } catch (e) {
          print('📱 CallPipWidget._loadCallInfo - Errore RealUserService: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _user = user;
          _displayName = user?.name ?? 'Utente Sconosciuto';
        });
      }
    } else if (widget.userIds != null && widget.userIds!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _displayName = 'Gruppo (${widget.userIds!.length})';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _displayName = 'Chiamata';
        });
      }
    }
  }

  void _startUiUpdateTimer() {
    _uiUpdateTimer?.cancel();
    _uiUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _displayTime = _formatDuration(ActiveCallService.callDuration ?? Duration.zero);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  void dispose() {
    _uiUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position.dx + details.delta.dx,
              _position.dy + details.delta.dy,
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
            // Mantieni il widget all'interno dello schermo
            final screenSize = MediaQuery.of(context).size;
            final statusBarHeight = MediaQuery.of(context).padding.top;
            final widgetWidth = 160;
            final widgetHeight = 80;
            
            _position = Offset(
              _position.dx.clamp(0, screenSize.width - widgetWidth),
              _position.dy.clamp(statusBarHeight, screenSize.height - widgetHeight - MediaQuery.of(context).padding.bottom),
            );
          });
        },
        child: AnimatedScale(
          scale: _isDragging ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 160,
            height: 80,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  // Contenuto
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        // Avatar
                        Stack(
                          children: [
                            _buildAvatar(),
                            if (widget.callType == 'video' || widget.callType == 'group_video')
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Icon(
                                    Icons.videocam,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        
                        // Info chiamata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _displayName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _displayTime,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Pulsanti
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Pulsante espandi
                            GestureDetector(
                              onTap: widget.onExpand,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.fullscreen,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                            
                            // Pulsante fine chiamata
                            GestureDetector(
                              onTap: () {
                                ActiveCallService.endCallAndReturnToChat(context);
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.call_end,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_user != null) {
      print('📱 CallPipWidget._buildAvatar - User: ${_user!.name} (ID: ${_user!.id})');
      return MasterAvatarWidget.fromUser(
        user: _user!,
        size: 40,
      );
    } else if (widget.callType.contains('group')) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor,
        ),
        child: const Icon(
          Icons.people,
          color: Colors.white,
          size: 20,
        ),
      );
    } else {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }
  }


  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      // Se ci sono più nomi, prendi la prima lettera di ognuno (max 2)
      final initials = words.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
      return initials.toUpperCase();
    } else {
      // Se c'è solo un nome, prendi le prime due lettere
      final singleName = words[0];
      return singleName.length >= 2 
          ? singleName.substring(0, 2).toUpperCase()
          : singleName[0].toUpperCase();
    }
  }
}