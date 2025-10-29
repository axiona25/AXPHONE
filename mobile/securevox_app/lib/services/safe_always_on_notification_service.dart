import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';
// import 'package:flutter_app_badger/flutter_app_badger.dart'; // Temporaneamente disabilitato
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Servizio sicuro per gestire notifiche sempre visibili
/// Versione semplificata per evitare crash di threading
class SafeAlwaysOnNotificationService {
  static final SafeAlwaysOnNotificationService _instance = SafeAlwaysOnNotificationService._internal();
  static SafeAlwaysOnNotificationService get instance => _instance;
  SafeAlwaysOnNotificationService._internal();

  bool _isInitialized = false;
  bool _isAlwaysOnActive = false;
  Timer? _badgeUpdateTimer;
  Timer? _screenWakeTimer;
  
  int _currentBadgeCount = 0;
  String? _lastNotificationTitle;
  String? _lastNotificationBody;
  DateTime? _lastNotificationTime;

  // Configurazione
  static const Duration _badgeUpdateInterval = Duration(seconds: 10);
  static const Duration _screenWakeDuration = Duration(minutes: 1);
  static const String _badgeCountKey = 'safe_always_on_badge_count';
  static const String _lastNotificationKey = 'safe_last_notification';

  /// Inizializza il servizio
  Future<void> initialize() async {
    if (_isInitialized) {
      print('ℹ️ SafeAlwaysOnNotificationService già inizializzato');
      return;
    }

    try {
      print('🔔 SafeAlwaysOnNotificationService - Inizializzazione...');

      // Carica stato salvato
      await _loadSavedState();

      // Avvia timer di aggiornamento badge
      _startBadgeUpdateTimer();

      _isInitialized = true;
      print('✅ SafeAlwaysOnNotificationService - Inizializzato');

    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore inizializzazione: $e');
    }
  }

  /// Attiva notifica sempre visibile (versione semplificata)
  Future<void> activateAlwaysOn({
    required String title,
    required String body,
    required int badgeCount,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      print('🔔 SafeAlwaysOnNotificationService - Attivazione notifica');
      print('   - Titolo: $title');
      print('   - Badge: $badgeCount');

      // Salva stato
      _lastNotificationTitle = title;
      _lastNotificationBody = body;
      _lastNotificationTime = DateTime.now();
      _currentBadgeCount = badgeCount;

      // Attiva wake lock (solo se non già attivo)
      if (!_isAlwaysOnActive) {
        await ScreenBrightness().setScreenBrightness(1.0);
        _isAlwaysOnActive = true;
        print('🔔 Wake lock attivato');
      }

      // Aggiorna badge
      await _updateBadge(badgeCount);

      // Avvia timer per spegnere automaticamente
      _startScreenWakeTimer();

      // Salva stato
      await _saveState();

      print('✅ SafeAlwaysOnNotificationService - Notifica attivata');

    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore attivazione: $e');
    }
  }

  /// Disattiva notifica sempre visibile
  Future<void> deactivateAlwaysOn() async {
    try {
      print('🔔 SafeAlwaysOnNotificationService - Disattivazione notifica');

      // Disattiva wake lock
      if (_isAlwaysOnActive) {
        await ScreenBrightness().resetScreenBrightness();
        _isAlwaysOnActive = false;
        print('🔔 Wake lock disattivato');
      }

      // Ferma timer schermo
      _screenWakeTimer?.cancel();
      _screenWakeTimer = null;

      // Reset stato
      _lastNotificationTitle = null;
      _lastNotificationBody = null;
      _lastNotificationTime = null;
      _currentBadgeCount = 0;

      // Salva stato
      await _saveState();

      print('✅ SafeAlwaysOnNotificationService - Notifica disattivata');

    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore disattivazione: $e');
    }
  }

  /// Aggiorna badge count
  Future<void> updateBadgeCount(int badgeCount) async {
    try {
      _currentBadgeCount = badgeCount;
      await _updateBadge(badgeCount);
      await _saveState();
    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore aggiornamento badge: $e');
    }
  }

  /// Avvia timer di aggiornamento badge
  void _startBadgeUpdateTimer() {
    _badgeUpdateTimer?.cancel();
    _badgeUpdateTimer = Timer.periodic(_badgeUpdateInterval, (timer) {
      if (_isAlwaysOnActive && _currentBadgeCount > 0) {
        _updateBadge(_currentBadgeCount);
      }
    });
  }

  /// Avvia timer per spegnere schermo automaticamente
  void _startScreenWakeTimer() {
    _screenWakeTimer?.cancel();
    _screenWakeTimer = Timer(_screenWakeDuration, () {
      if (_isAlwaysOnActive) {
        deactivateAlwaysOn();
      }
    });
  }

  /// Aggiorna badge dell'app
  Future<void> _updateBadge(int badgeCount) async {
    try {
      if (Platform.isIOS) {
        // await FlutterAppBadger.updateBadgeCount(badgeCount); // Temporaneamente disabilitato
      }
    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore aggiornamento badge: $e');
    }
  }

  /// Carica stato salvato
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _currentBadgeCount = prefs.getInt(_badgeCountKey) ?? 0;
      _lastNotificationTitle = prefs.getString('${_lastNotificationKey}_title');
      _lastNotificationBody = prefs.getString('${_lastNotificationKey}_body');
      
      final lastTime = prefs.getInt('${_lastNotificationKey}_time');
      if (lastTime != null) {
        _lastNotificationTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
      }

    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore caricamento stato: $e');
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
        await prefs.setInt('${_lastNotificationKey}_time', _lastNotificationTime!.millisecondsSinceEpoch);
      }

    } catch (e) {
      print('❌ SafeAlwaysOnNotificationService - Errore salvataggio stato: $e');
    }
  }

  /// Pulisce risorse
  void dispose() {
    _badgeUpdateTimer?.cancel();
    _screenWakeTimer?.cancel();
    _isAlwaysOnActive = false;
    _currentBadgeCount = 0;
    _lastNotificationTitle = null;
    _lastNotificationBody = null;
    _lastNotificationTime = null;
  }

  /// Getters
  bool get isInitialized => _isInitialized;
  bool get isAlwaysOnActive => _isAlwaysOnActive;
  int get currentBadgeCount => _currentBadgeCount;
  String? get lastNotificationTitle => _lastNotificationTitle;
  String? get lastNotificationBody => _lastNotificationBody;
  DateTime? get lastNotificationTime => _lastNotificationTime;
}
