import 'dart:async';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato
import 'package:flutter/services.dart';

/// Servizio per gestire i suoni delle chiamate
class CallSoundService {
  static final CallSoundService _instance = CallSoundService._internal();
  factory CallSoundService() => _instance;
  CallSoundService._internal();

  // Player per i suoni
  // final AudioPlayer _outgoingPlayer = AudioPlayer(); // Temporaneamente disabilitato
  // final AudioPlayer _incomingPlayer = AudioPlayer(); // Temporaneamente disabilitato
  
  // Stato dei suoni
  bool _isPlayingOutgoing = false;
  bool _isPlayingIncoming = false;
  
  // Timer per loop dei suoni
  Timer? _outgoingTimer;
  Timer? _incomingTimer;

  /// Inizializza il servizio
  Future<void> initialize() async {
    try {
      print('🔊 CallSoundService.initialize - Inizializzazione servizio suoni...');
      
      // Configura i player per loop
      // await _outgoingPlayer.setReleaseMode(ReleaseMode.stop); // Temporaneamente disabilitato
      // await _incomingPlayer.setReleaseMode(ReleaseMode.stop); // Temporaneamente disabilitato
      
      print('✅ CallSoundService inizializzato');
      
    } catch (e) {
      print('❌ Errore inizializzazione CallSoundService: $e');
    }
  }

  /// Avvia il suono di squillo per chi fa la chiamata
  Future<void> startOutgoingCallSound() async {
    try {
      if (_isPlayingOutgoing) {
        print('⚠️ Suono squillo già in riproduzione');
        return;
      }
      
      print('📞 Avvio suono squillo per chiamata in uscita...');
      
      // Vibrazione per feedback tattile
      HapticFeedback.lightImpact();
      
      _isPlayingOutgoing = true;
      
      // Simula suono di squillo classico con timer
      _outgoingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        if (_isPlayingOutgoing) {
          // Suono di squillo simulato (beep corto)
          try {
            // await _outgoingPlayer.play(AssetSource('sounds/outgoing_ring.mp3')); // Temporaneamente disabilitato
          } catch (e) {
            // Fallback: usa vibrazione se il suono non è disponibile
            HapticFeedback.selectionClick();
            print('🔊 Fallback: vibrazione per squillo (file audio non trovato)');
          }
          
          // Vibrazione aggiuntiva ogni 2 secondi
          HapticFeedback.selectionClick();
        } else {
          timer.cancel();
        }
      });
      
      print('✅ Suono squillo avviato');
      
    } catch (e) {
      print('❌ Errore avvio suono squillo: $e');
    }
  }

  /// Avvia la suoneria per chi riceve la chiamata
  Future<void> startIncomingCallSound() async {
    try {
      if (_isPlayingIncoming) {
        print('⚠️ Suoneria già in riproduzione');
        return;
      }
      
      print('📱 Avvio suoneria per chiamata in arrivo...');
      
      // Vibrazione per feedback tattile
      HapticFeedback.heavyImpact();
      
      _isPlayingIncoming = true;
      
      // Suoneria classica con pattern di vibrazione
      _incomingTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
        if (_isPlayingIncoming) {
          try {
            // Prova a riprodurre suoneria
            // await _incomingPlayer.play(AssetSource('sounds/incoming_ring.mp3')); // Temporaneamente disabilitato
          } catch (e) {
            // Fallback: pattern di vibrazione per suoneria
            _playVibrationPattern();
            print('🔊 Fallback: pattern vibrazione per suoneria (file audio non trovato)');
          }
          
          // Pattern di vibrazione per suoneria
          _playVibrationPattern();
        } else {
          timer.cancel();
        }
      });
      
      print('✅ Suoneria avviata');
      
    } catch (e) {
      print('❌ Errore avvio suoneria: $e');
    }
  }

  /// Pattern di vibrazione per suoneria
  void _playVibrationPattern() {
    // Pattern: vibrazione lunga, pausa, vibrazione corta, pausa, vibrazione corta
    HapticFeedback.heavyImpact();
    
    Timer(const Duration(milliseconds: 200), () {
      HapticFeedback.mediumImpact();
    });
    
    Timer(const Duration(milliseconds: 400), () {
      HapticFeedback.mediumImpact();
    });
  }

  /// Ferma il suono di squillo
  Future<void> stopOutgoingCallSound() async {
    try {
      print('🔇 Fermando suono squillo...');
      
      _isPlayingOutgoing = false;
      _outgoingTimer?.cancel();
      _outgoingTimer = null;
      
      // await _outgoingPlayer.stop(); // Temporaneamente disabilitato
      
      print('✅ Suono squillo fermato');
      
    } catch (e) {
      print('❌ Errore stop suono squillo: $e');
    }
  }

  /// Ferma la suoneria
  Future<void> stopIncomingCallSound() async {
    try {
      print('🔇 Fermando suoneria...');
      
      _isPlayingIncoming = false;
      _incomingTimer?.cancel();
      _incomingTimer = null;
      
      // await _incomingPlayer.stop(); // Temporaneamente disabilitato
      
      print('✅ Suoneria fermata');
      
    } catch (e) {
      print('❌ Errore stop suoneria: $e');
    }
  }

  /// Ferma tutti i suoni
  Future<void> stopAllSounds() async {
    try {
      print('🔇 Fermando tutti i suoni chiamata...');
      
      await stopOutgoingCallSound();
      await stopIncomingCallSound();
      
      print('✅ Tutti i suoni fermati');
      
    } catch (e) {
      print('❌ Errore stop tutti i suoni: $e');
    }
  }

  /// Suono per chiamata accettata
  Future<void> playCallConnectedSound() async {
    try {
      print('✅ Suono chiamata connessa...');
      
      // Ferma tutti gli altri suoni
      await stopAllSounds();
      
      // Feedback tattile per connessione
      HapticFeedback.lightImpact();
      
      try {
        // await _outgoingPlayer.play(AssetSource('sounds/call_connected.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: doppia vibrazione per connessione
        HapticFeedback.lightImpact();
        Timer(const Duration(milliseconds: 100), () {
          HapticFeedback.lightImpact();
        });
        print('🔊 Fallback: vibrazione per connessione (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono connessione: $e');
    }
  }

  /// Suono per chiamata terminata
  Future<void> playCallEndedSound() async {
    try {
      print('🔚 Suono chiamata terminata...');
      
      // Ferma tutti gli altri suoni
      await stopAllSounds();
      
      // Feedback tattile per terminazione
      HapticFeedback.heavyImpact();
      
      try {
        // await _outgoingPlayer.play(AssetSource('sounds/call_ended.mp3')); // Temporaneamente disabilitato
      } catch (e) {
        // Fallback: vibrazione per terminazione
        HapticFeedback.heavyImpact();
        print('🔊 Fallback: vibrazione per terminazione (file audio non trovato)');
      }
      
    } catch (e) {
      print('❌ Errore suono terminazione: $e');
    }
  }

  /// Dispose del servizio
  void dispose() {
    try {
      print('🧹 CallSoundService.dispose - Pulizia risorse audio...');
      
      stopAllSounds();
      
      // _outgoingPlayer.dispose(); // Temporaneamente disabilitato
      // _incomingPlayer.dispose(); // Temporaneamente disabilitato
      
      print('✅ CallSoundService disposed');
      
    } catch (e) {
      print('❌ Errore dispose CallSoundService: $e');
    }
  }

  // Getters per stato
  bool get isPlayingOutgoing => _isPlayingOutgoing;
  bool get isPlayingIncoming => _isPlayingIncoming;
  bool get isPlayingAnySound => _isPlayingOutgoing || _isPlayingIncoming;
}
