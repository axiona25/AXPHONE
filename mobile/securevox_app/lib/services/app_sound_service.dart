import 'dart:async';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato
import 'package:flutter/services.dart';

/// Servizio per gestire tutti i suoni dell'app (messaggi, notifiche, toast)
class AppSoundService {
  static final AppSoundService _instance = AppSoundService._internal();
  factory AppSoundService() => _instance;
  AppSoundService._internal();

  // Player per i diversi tipi di suoni
  // final AudioPlayer _messagePlayer = AudioPlayer(); // Temporaneamente disabilitato
  // final AudioPlayer _notificationPlayer = AudioPlayer(); // Temporaneamente disabilitato
  // final AudioPlayer _toastPlayer = AudioPlayer(); // Temporaneamente disabilitato
  
  bool _isInitialized = false;

  /// Inizializza il servizio
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🔊 AppSoundService.initialize - Inizializzazione servizio suoni app...');
      
      // Configura i player
      // await _messagePlayer.setReleaseMode(ReleaseMode.stop); // Temporaneamente disabilitato
      // await _notificationPlayer.setReleaseMode(ReleaseMode.stop); // Temporaneamente disabilitato
      // await _toastPlayer.setReleaseMode(ReleaseMode.stop); // Temporaneamente disabilitato
      
      _isInitialized = true;
      print('✅ AppSoundService inizializzato');
      
    } catch (e) {
      print('❌ Errore inizializzazione AppSoundService: $e');
    }
  }

  /// Suono per nuovo messaggio in arrivo
  Future<void> playNewMessageSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('💬 Riproduzione suono nuovo messaggio...');
      
      // Vibrazione leggera per messaggio
      HapticFeedback.selectionClick();
      
      try {
        // await _messagePlayer.play(AssetSource('sounds/message_received.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione doppia per messaggio
        HapticFeedback.selectionClick();
        Timer(const Duration(milliseconds: 100), () {
          HapticFeedback.selectionClick();
        });
        print('🔊 Fallback: vibrazione per nuovo messaggio (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono nuovo messaggio: $e');
    }
  }

  /// Suono per messaggio inviato
  Future<void> playMessageSentSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('📤 Riproduzione suono messaggio inviato...');
      
      // Vibrazione molto leggera per conferma invio
      HapticFeedback.lightImpact();
      
      try {
        // await _messagePlayer.play(AssetSource('sounds/message_sent.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione singola per invio
        HapticFeedback.lightImpact();
        print('🔊 Fallback: vibrazione per messaggio inviato (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono messaggio inviato: $e');
    }
  }

  /// Suono per notifica generica
  Future<void> playNotificationSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('🔔 Riproduzione suono notifica...');
      
      // Vibrazione media per notifica
      HapticFeedback.mediumImpact();
      
      try {
        // await _notificationPlayer.play(AssetSource('sounds/notification.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione per notifica
        HapticFeedback.mediumImpact();
        print('🔊 Fallback: vibrazione per notifica (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono notifica: $e');
    }
  }

  /// Suono per toast di successo
  Future<void> playSuccessSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('✅ Riproduzione suono successo...');
      
      // Vibrazione leggera per successo
      HapticFeedback.lightImpact();
      
      try {
        // await _toastPlayer.play(AssetSource('sounds/success.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione doppia per successo
        HapticFeedback.lightImpact();
        Timer(const Duration(milliseconds: 150), () {
          HapticFeedback.lightImpact();
        });
        print('🔊 Fallback: vibrazione per successo (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono successo: $e');
    }
  }

  /// Suono per toast di errore
  Future<void> playErrorSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('❌ Riproduzione suono errore...');
      
      // Vibrazione pesante per errore
      HapticFeedback.heavyImpact();
      
      try {
        // await _toastPlayer.play(AssetSource('sounds/error.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione tripla per errore
        HapticFeedback.heavyImpact();
        Timer(const Duration(milliseconds: 100), () {
          HapticFeedback.mediumImpact();
        });
        Timer(const Duration(milliseconds: 200), () {
          HapticFeedback.mediumImpact();
        });
        print('🔊 Fallback: vibrazione per errore (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono errore: $e');
    }
  }

  /// Suono per toast di avviso
  Future<void> playWarningSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('⚠️ Riproduzione suono avviso...');
      
      // Vibrazione media per avviso
      HapticFeedback.mediumImpact();
      
      try {
        // await _toastPlayer.play(AssetSource('sounds/warning.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione lunga per avviso
        HapticFeedback.mediumImpact();
        Timer(const Duration(milliseconds: 200), () {
          HapticFeedback.lightImpact();
        });
        print('🔊 Fallback: vibrazione per avviso (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono avviso: $e');
    }
  }

  /// Suono per toast informativo
  Future<void> playInfoSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('ℹ️ Riproduzione suono info...');
      
      // Vibrazione leggera per info
      HapticFeedback.selectionClick();
      
      try {
        // await _toastPlayer.play(AssetSource('sounds/info.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione singola per info
        HapticFeedback.selectionClick();
        print('🔊 Fallback: vibrazione per info (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono info: $e');
    }
  }

  /// Suono per azione completata (upload, download, ecc.)
  Future<void> playActionCompletedSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      print('🎯 Riproduzione suono azione completata...');
      
      // Vibrazione di conferma
      HapticFeedback.lightImpact();
      
      try {
        // await _toastPlayer.play(AssetSource('sounds/action_completed.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: pattern di vibrazione per completamento
        HapticFeedback.lightImpact();
        Timer(const Duration(milliseconds: 100), () {
          HapticFeedback.selectionClick();
        });
        print('🔊 Fallback: vibrazione per azione completata (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono azione completata: $e');
    }
  }

  /// Suono per typing indicator (quando qualcuno sta scrivendo)
  Future<void> playTypingSound() async {
    try {
      if (!_isInitialized) await initialize();
      
      // Vibrazione molto leggera per typing
      HapticFeedback.selectionClick();
      
    } catch (e) {
      print('❌ Errore suono typing: $e');
    }
  }

  /// Ferma tutti i suoni
  Future<void> stopAllSounds() async {
    try {
      // await _messagePlayer.stop(); // Temporaneamente disabilitato
      // await _notificationPlayer.stop(); // Temporaneamente disabilitato
      // await _toastPlayer.stop(); // Temporaneamente disabilitato
      
      print('🔇 AppSoundService - Tutti i suoni fermati');
      
    } catch (e) {
      print('❌ Errore stop tutti i suoni: $e');
    }
  }

  /// Dispose del servizio
  void dispose() {
    try {
      print('🧹 AppSoundService.dispose - Pulizia risorse audio...');
      
      stopAllSounds();
      
      // _messagePlayer.dispose(); // Temporaneamente disabilitato
      // _notificationPlayer.dispose(); // Temporaneamente disabilitato
      // _toastPlayer.dispose(); // Temporaneamente disabilitato
      
      _isInitialized = false;
      print('✅ AppSoundService disposed');
      
    } catch (e) {
      print('❌ Errore dispose AppSoundService: $e');
    }
  }
}
