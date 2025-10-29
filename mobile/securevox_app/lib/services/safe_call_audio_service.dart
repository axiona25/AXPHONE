import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato
import 'package:flutter/services.dart';

/// Servizio sicuro per gestire suoni di chiamate
/// Versione semplificata per evitare crash di threading
class SafeCallAudioService {
  static final SafeCallAudioService _instance = SafeCallAudioService._internal();
  static SafeCallAudioService get instance => _instance;
  SafeCallAudioService._internal();

  // Player per suoni di chiamata (singolo per evitare conflitti)
  // AudioPlayer? _audioPlayer; // Temporaneamente disabilitato
  
  // Timer per gestire durata suoni
  Timer? _soundTimer;
  
  // Stato chiamata corrente
  String? _currentCallId;
  bool _isPlaying = false;
  
  // Configurazione suoni
  static const Duration _soundInterval = Duration(seconds: 3);
  static const int _maxSoundRepeats = 10; // Ridotto per evitare problemi

  /// Inizializza il servizio
  Future<void> initialize() async {
    try {
      print('🔊 SafeCallAudioService - Inizializzazione...');
      
      // Inizializza player singolo
      // _audioPlayer = AudioPlayer();
      // await _audioPlayer!.setPlayerMode(PlayerMode.lowLatency); // Temporaneamente disabilitato
      
      print('✅ SafeCallAudioService - Inizializzato');
      
    } catch (e) {
      print('❌ SafeCallAudioService - Errore inizializzazione: $e');
    }
  }

  /// Avvia suono di chiamata in corso (versione sicura)
  Future<void> startCallInProgressSound({
    required String callId,
    required String callType,
  }) async {
    try {
      print('🔊 SafeCallAudioService - Avvio suono chiamata in corso');
      print('   - Call ID: $callId');
      print('   - Tipo: $callType');

      // Ferma suoni precedenti
      await stopAllSounds();

      // Imposta stato
      _currentCallId = callId;
      _isPlaying = true;

      // Riproduce suono di chiamata in corso (versione semplificata)
      await _playCallSound(callType);

      print('✅ SafeCallAudioService - Suono chiamata in corso avviato');

    } catch (e) {
      print('❌ SafeCallAudioService - Errore avvio suono chiamata: $e');
    }
  }

  /// Avvia suono di squillo per chiamata in arrivo (versione sicura)
  Future<void> startIncomingCallRingtone({
    required String callId,
    required String callType,
  }) async {
    try {
      print('🔊 SafeCallAudioService - Avvio suono chiamata in arrivo');
      print('   - Call ID: $callId');
      print('   - Tipo: $callType');

      // Ferma suoni precedenti
      await stopAllSounds();

      // Imposta stato
      _currentCallId = callId;
      _isPlaying = true;

      // Riproduce suono di chiamata in arrivo (versione semplificata)
      await _playIncomingSound(callType);

      print('✅ SafeCallAudioService - Suono chiamata in arrivo avviato');

    } catch (e) {
      print('❌ SafeCallAudioService - Errore avvio suono in arrivo: $e');
    }
  }

  /// Avvia suono di occupato (versione sicura)
  Future<void> startBusySound({
    required String reason,
  }) async {
    try {
      print('🔊 SafeCallAudioService - Avvio suono occupato');
      print('   - Motivo: $reason');

      // Ferma suoni precedenti
      await stopAllSounds();

      // Riproduce suono di occupato (versione semplificata)
      await _playBusySound();

      print('✅ SafeCallAudioService - Suono occupato avviato');

    } catch (e) {
      print('❌ SafeCallAudioService - Errore avvio suono occupato: $e');
    }
  }

  /// Ferma tutti i suoni
  Future<void> stopAllSounds() async {
    try {
      print('🔊 SafeCallAudioService - Fermata tutti i suoni');

      // Ferma timer
      _soundTimer?.cancel();
      _soundTimer = null;

      // Ferma player
      // if (_audioPlayer != null) {
      //   await _audioPlayer!.stop();
      // } // Temporaneamente disabilitato

      // Reset stato
      _currentCallId = null;
      _isPlaying = false;

      print('✅ SafeCallAudioService - Tutti i suoni fermati');

    } catch (e) {
      print('❌ SafeCallAudioService - Errore fermata suoni: $e');
    }
  }

  /// Ferma suono specifico per chiamata
  Future<void> stopCallSound(String callId) async {
    if (_currentCallId == callId) {
      await stopAllSounds();
    }
  }

  /// Riproduce suono di chiamata (versione semplificata)
  Future<void> _playCallSound(String callType) async {
    try {
      // Riproduce suono una volta senza timer per evitare problemi
      await _playSoundFile('audio_call_ring.wav');
      
    } catch (e) {
      print('❌ SafeCallAudioService - Errore riproduzione suono chiamata: $e');
    }
  }

  /// Riproduce suono di chiamata in arrivo (versione semplificata)
  Future<void> _playIncomingSound(String callType) async {
    try {
      // Riproduce suono una volta senza timer per evitare problemi
      await _playSoundFile('audio_call_ring.wav');
      
    } catch (e) {
      print('❌ SafeCallAudioService - Errore riproduzione suono in arrivo: $e');
    }
  }

  /// Riproduce suono di occupato (versione semplificata)
  Future<void> _playBusySound() async {
    try {
      // Riproduce suono una volta senza timer per evitare problemi
      await _playSoundFile('busy_tone.wav');
      
    } catch (e) {
      print('❌ SafeCallAudioService - Errore riproduzione suono occupato: $e');
    }
  }

  /// Riproduce file audio (versione sicura)
  Future<void> _playSoundFile(String fileName) async {
    try {
      // if (_audioPlayer == null) return; // Temporaneamente disabilitato
      print('🔊 SafeCallAudioService - Audio temporaneamente disabilitato');
      return;

      // // Prova prima con file personalizzato
      // try {
      //   await _audioPlayer!.play(AssetSource('sounds/$fileName'));
      //   print('🔊 SafeCallAudioService - Suono personalizzato: $fileName');
      //   return;
      // } catch (e) {
      //   print('⚠️ SafeCallAudioService - File personalizzato non trovato: $fileName');
      // }

      // // Fallback al suono di sistema
      // try {
      //   await _audioPlayer!.play(DeviceFileSource('/system/media/audio/notifications/$fileName'));
      //   print('🔊 SafeCallAudioService - Suono sistema: $fileName');
      //   return;
      // } catch (e) {
      //   print('⚠️ SafeCallAudioService - Suono sistema non trovato: $fileName');
      // }

      // // Fallback al suono di default
      // try {
      //   await _audioPlayer!.play(DeviceFileSource('/system/media/audio/notifications/Default.wav'));
      //   print('🔊 SafeCallAudioService - Suono default');
      // } catch (e) {
      //   print('❌ SafeCallAudioService - Impossibile riprodurre suono di fallback');
      // }

    } catch (e) {
      print('❌ SafeCallAudioService - Errore riproduzione file: $e');
    }
  }

  /// Verifica se l'utente è occupato
  bool get isUserBusy => _isPlaying;

  /// Verifica se è in chiamata
  bool get isInCall => _isPlaying;

  /// Ottiene ID chiamata corrente
  String? get currentCallId => _currentCallId;

  /// Pulisce risorse
  void dispose() {
    _soundTimer?.cancel();
    // _audioPlayer?.dispose(); // Temporaneamente disabilitato
    _isPlaying = false;
    _currentCallId = null;
  }
}
