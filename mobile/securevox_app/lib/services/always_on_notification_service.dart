import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:overlay_support/overlay_support.dart';
// import 'package:flutter_app_badger/flutter_app_badger.dart'; // Temporaneamente disabilitato
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato
import '../theme/app_theme.dart';

/// Tipi di notifiche per gestire suoni e stili specifici
enum NotificationType {
  message,
  audioCall,
  videoCall,
  groupCall,
  missedCall,
  missedVideoCall,
  missedGroupCall,
}

/// Servizio per gestire notifiche sempre visibili su schermo chiuso
class AlwaysOnNotificationService {
  static final AlwaysOnNotificationService _instance = AlwaysOnNotificationService._internal();
  static AlwaysOnNotificationService get instance => _instance;
  AlwaysOnNotificationService._internal();

  bool _isInitialized = false;
  bool _isAlwaysOnActive = false;
  Timer? _badgeUpdateTimer;
  Timer? _screenWakeTimer;
  Timer? _soundRepeatTimer;
  
  // Overlay entry per gestire la visualizzazione
  OverlaySupportEntry? _overlayEntry;
  int _currentBadgeCount = 0;
  String? _lastNotificationTitle;
  String? _lastNotificationBody;
  DateTime? _lastNotificationTime;
  NotificationType _lastNotificationType = NotificationType.message;
  // AudioPlayer? _audioPlayer; // Temporaneamente disabilitato

  // Configurazione
  static const Duration _badgeUpdateInterval = Duration(seconds: 5);
  static const Duration _screenWakeDuration = Duration(minutes: 2);
  static const String _badgeCountKey = 'always_on_badge_count';
  static const String _lastNotificationKey = 'last_notification';

  /// Inizializza il servizio
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔔 AlwaysOnNotificationService - Inizializzazione...');
      
      // Carica stato salvato
      await _loadSavedState();
      
      // Avvia timer per aggiornamento badge
      _startBadgeUpdateTimer();
      
      _isInitialized = true;
      print('✅ AlwaysOnNotificationService - Inizializzato');
      
    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore inizializzazione: $e');
    }
  }

  /// Attiva modalità sempre visibile per notifiche importanti
  Future<void> activateAlwaysOn({
    required String title,
    required String body,
    required int badgeCount,
    required NotificationType notificationType,
  }) async {
    try {
      print('🔔 AlwaysOnNotificationService - Attivazione modalità sempre visibile');
      print('   - Titolo: $title');
      print('   - Badge: $badgeCount');
      print('   - Tipo: $notificationType');

      // Salva notifica corrente
      _lastNotificationTitle = title;
      _lastNotificationBody = body;
      _lastNotificationTime = DateTime.now();
      _currentBadgeCount = badgeCount;
      _lastNotificationType = notificationType;

      // Attiva wake lock per mantenere schermo acceso
      await WakelockPlus.enable();
      _isAlwaysOnActive = true;

      // Avvia suono specifico per tipo di notifica
      await _playNotificationSound(notificationType);

      // Mostra overlay di notifica
      await _showAlwaysOnOverlay(
        title: title,
        body: body,
        badgeCount: badgeCount,
        notificationType: notificationType,
      );

      // Avvia timer per spegnere automaticamente
      _startScreenWakeTimer();

      // Salva stato
      await _saveState();

      print('✅ AlwaysOnNotificationService - Modalità sempre visibile attivata');

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore attivazione: $e');
    }
  }

  /// Disattiva modalità sempre visibile
  Future<void> deactivateAlwaysOn() async {
    try {
      print('🔔 AlwaysOnNotificationService - Disattivazione modalità sempre visibile');

      // Ferma suoni
      await _stopNotificationSound();

      // Disattiva wake lock
      await WakelockPlus.disable();
      _isAlwaysOnActive = false;

      // Nascondi overlay
      if (_overlayEntry != null) {
        _overlayEntry!.dismiss();
        _overlayEntry = null;
      }

      // Ferma timer schermo
      _screenWakeTimer?.cancel();

      // Salva stato
      await _saveState();

      print('✅ AlwaysOnNotificationService - Modalità sempre visibile disattivata');

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore disattivazione: $e');
    }
  }

  /// Aggiorna badge count
  Future<void> updateBadgeCount(int count) async {
    try {
      _currentBadgeCount = count;
      
      // Aggiorna badge nativo
      if (count > 0) {
        // await FlutterAppBadger.updateBadgeCount(count); // Temporaneamente disabilitato
      } else {
        // await FlutterAppBadger.removeBadge(); // Temporaneamente disabilitato
      }

      // Se modalità sempre visibile è attiva, aggiorna overlay
      if (_isAlwaysOnActive) {
        await _updateAlwaysOnOverlay();
      }

      // Salva stato
      await _saveState();

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore aggiornamento badge: $e');
    }
  }

  /// Riproduce suono specifico per tipo di notifica
  Future<void> _playNotificationSound(NotificationType type) async {
    try {
      await _stopNotificationSound(); // Ferma suoni precedenti

      String soundFile;
      bool shouldRepeat = false;

      switch (type) {
        case NotificationType.audioCall:
          soundFile = 'audio_call_ring.wav';
          shouldRepeat = true;
          break;
        case NotificationType.videoCall:
          soundFile = 'video_call_ring.wav';
          shouldRepeat = true;
          break;
        case NotificationType.groupCall:
          soundFile = 'group_call_ring.wav';
          shouldRepeat = true;
          break;
        case NotificationType.missedCall:
        case NotificationType.missedVideoCall:
        case NotificationType.missedGroupCall:
          soundFile = 'missed_call.wav';
          shouldRepeat = false;
          break;
        case NotificationType.message:
        default:
          soundFile = 'message_notification.wav';
          shouldRepeat = false;
          break;
      }

      // _audioPlayer = AudioPlayer(); // Temporaneamente disabilitato
      
      // Prova prima con file personalizzato
      try {
        await _audioPlayer!.play(AssetSource('sounds/$soundFile'));
        print('🔊 AlwaysOnNotificationService - Suono personalizzato: $soundFile');
      } catch (e) {
        // Fallback al suono di sistema
        print('⚠️ AlwaysOnNotificationService - Fallback suono sistema per: $soundFile');
        await _audioPlayer!.play(DeviceFileSource('/system/media/audio/notifications/$soundFile'));
      }

      // Se deve ripetere (chiamate in arrivo), avvia timer
      if (shouldRepeat) {
        _startSoundRepeatTimer();
      }

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore riproduzione suono: $e');
    }
  }

  /// Ferma la riproduzione del suono
  Future<void> _stopNotificationSound() async {
    try {
      _soundRepeatTimer?.cancel();
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore stop suono: $e');
    }
  }

  /// Avvia timer per ripetere il suono (chiamate in arrivo)
  void _startSoundRepeatTimer() {
    _soundRepeatTimer?.cancel();
    _soundRepeatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isAlwaysOnActive && _audioPlayer != null) {
        _audioPlayer!.resume();
      } else {
        timer.cancel();
      }
    });
  }

  /// Mostra overlay sempre visibile
  Future<void> _showAlwaysOnOverlay({
    required String title,
    required String body,
    required int badgeCount,
    required NotificationType notificationType,
  }) async {
    try {
      // Crea overlay personalizzato (temporaneamente disabilitato)
      print('🔔 AlwaysOnNotificationService - Overlay disabilitato temporaneamente');

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore overlay: $e');
    }
  }

  /// Aggiorna overlay esistente
  Future<void> _updateAlwaysOnOverlay() async {
    if (_lastNotificationTitle == null) return;

    try {
      // Nascondi overlay precedente
      // Overlay disabilitato temporaneamente
      print('🔔 AlwaysOnNotificationService - Overlay dismiss disabilitato temporaneamente');

      // Mostra nuovo overlay con badge aggiornato
      await _showAlwaysOnOverlay(
        title: _lastNotificationTitle!,
        body: _lastNotificationBody ?? '',
        badgeCount: _currentBadgeCount,
        notificationType: _lastNotificationType,
      );

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore aggiornamento overlay: $e');
    }
  }

  /// Gestisce tap sull'overlay
  void _handleOverlayTap() {
    print('🔔 AlwaysOnNotificationService - Tap su overlay notifica');
    
    // Apri app se non è già aperta
    // TODO: Implementare apertura app
    
    // Disattiva modalità sempre visibile
    deactivateAlwaysOn();
  }

  /// Avvia timer per aggiornamento badge
  void _startBadgeUpdateTimer() {
    _badgeUpdateTimer?.cancel();
    _badgeUpdateTimer = Timer.periodic(_badgeUpdateInterval, (timer) {
      _updateBadgeFromStorage();
    });
  }

  /// Avvia timer per spegnere schermo
  void _startScreenWakeTimer() {
    _screenWakeTimer?.cancel();
    _screenWakeTimer = Timer(_screenWakeDuration, () {
      if (_isAlwaysOnActive) {
        print('🔔 AlwaysOnNotificationService - Timeout schermo, disattivazione automatica');
        deactivateAlwaysOn();
      }
    });
  }

  /// Aggiorna badge da storage
  Future<void> _updateBadgeFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedCount = prefs.getInt(_badgeCountKey) ?? 0;
      
      if (storedCount != _currentBadgeCount) {
        await updateBadgeCount(storedCount);
      }
    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore aggiornamento da storage: $e');
    }
  }

  /// Carica stato salvato
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _currentBadgeCount = prefs.getInt(_badgeCountKey) ?? 0;
      _lastNotificationTitle = prefs.getString('${_lastNotificationKey}_title');
      _lastNotificationBody = prefs.getString('${_lastNotificationKey}_body');
      
      final lastTimeStr = prefs.getString('${_lastNotificationKey}_time');
      if (lastTimeStr != null) {
        _lastNotificationTime = DateTime.parse(lastTimeStr);
      }

      print('🔔 AlwaysOnNotificationService - Stato caricato: badge=$_currentBadgeCount');

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore caricamento stato: $e');
    }
  }

  /// Salva stato corrente
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setInt(_badgeCountKey, _currentBadgeCount);
      
      if (_lastNotificationTitle != null) {
        await prefs.setString('${_lastNotificationKey}_title', _lastNotificationTitle!);
      }
      if (_lastNotificationBody != null) {
        await prefs.setString('${_lastNotificationKey}_body', _lastNotificationBody!);
      }
      if (_lastNotificationTime != null) {
        await prefs.setString('${_lastNotificationKey}_time', _lastNotificationTime!.toIso8601String());
      }

    } catch (e) {
      print('❌ AlwaysOnNotificationService - Errore salvataggio stato: $e');
    }
  }

  /// Pulisce risorse
  void dispose() {
    _badgeUpdateTimer?.cancel();
    _screenWakeTimer?.cancel();
    WakelockPlus.disable();
    _isAlwaysOnActive = false;
    _isInitialized = false;
  }

  // Getters
  bool get isAlwaysOnActive => _isAlwaysOnActive;
  int get currentBadgeCount => _currentBadgeCount;
  String? get lastNotificationTitle => _lastNotificationTitle;
}

/// Widget overlay per notifiche sempre visibili
class AlwaysOnNotificationOverlay extends StatefulWidget {
  final String title;
  final String body;
  final int badgeCount;
  final NotificationType notificationType;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const AlwaysOnNotificationOverlay({
    Key? key,
    required this.title,
    required this.body,
    required this.badgeCount,
    required this.notificationType,
    required this.onTap,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<AlwaysOnNotificationOverlay> createState() => _AlwaysOnNotificationOverlayState();
}

class _AlwaysOnNotificationOverlayState extends State<AlwaysOnNotificationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animazione pulsante per badge
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animazione slide in
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

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

  @override
  Widget build(BuildContext context) {
    // Determina colori e icone basati sul tipo di notifica
    final notificationConfig = _getNotificationConfig(widget.notificationType);
    
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.9),
              AppTheme.backgroundColor.withOpacity(0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: notificationConfig.gradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: 8,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header con logo SecureVOX
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.security,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'SecureVOX',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Icona principale e badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            notificationConfig.icon,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                        if (widget.badgeCount > 0) ...[
                          const SizedBox(width: 16),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryColor.withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    widget.badgeCount.toString(),
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Titolo
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Corpo
                    Text(
                      widget.body,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Pulsanti azione in stile SecureVOX
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Pulsante principale
                        ElevatedButton.icon(
                          onPressed: widget.onTap,
                          icon: Icon(notificationConfig.actionIcon),
                          label: Text(notificationConfig.actionText),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primaryColor,
                            elevation: 8,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        
                        // Pulsante secondario
                        TextButton.icon(
                          onPressed: widget.onDismiss,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Chiudi'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white.withOpacity(0.8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Indicatore di sicurezza
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Comunicazione sicura E2EE',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Configurazione per ogni tipo di notifica
  NotificationConfig _getNotificationConfig(NotificationType type) {
    switch (type) {
      case NotificationType.audioCall:
        return NotificationConfig(
          icon: Icons.phone,
          actionIcon: Icons.phone,
          actionText: 'Rispondi',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        );
      case NotificationType.videoCall:
        return NotificationConfig(
          icon: Icons.videocam,
          actionIcon: Icons.videocam,
          actionText: 'Rispondi Video',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          ),
        );
      case NotificationType.groupCall:
        return NotificationConfig(
          icon: Icons.group,
          actionIcon: Icons.group,
          actionText: 'Partecipa',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
          ),
        );
      case NotificationType.missedCall:
        return NotificationConfig(
          icon: Icons.phone_missed,
          actionIcon: Icons.call_made,
          actionText: 'Richiama',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          ),
        );
      case NotificationType.missedVideoCall:
        return NotificationConfig(
          icon: Icons.videocam_off,
          actionIcon: Icons.videocam,
          actionText: 'Richiama Video',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          ),
        );
      case NotificationType.missedGroupCall:
        return NotificationConfig(
          icon: Icons.group_off,
          actionIcon: Icons.group,
          actionText: 'Richiama Gruppo',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFF5722), Color(0xFFE64A19)],
          ),
        );
      case NotificationType.message:
      default:
        return NotificationConfig(
          icon: Icons.message,
          actionIcon: Icons.open_in_new,
          actionText: 'Apri',
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
          ),
        );
    }
  }
}

/// Configurazione per ogni tipo di notifica
class NotificationConfig {
  final IconData icon;
  final IconData actionIcon;
  final String actionText;
  final LinearGradient gradient;

  const NotificationConfig({
    required this.icon,
    required this.actionIcon,
    required this.actionText,
    required this.gradient,
  });
}
