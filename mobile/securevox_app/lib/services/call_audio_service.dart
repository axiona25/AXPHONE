import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato
import 'package:flutter/services.dart';

/// Servizio per gestire suoni di sistema durante le chiamate
class CallAudioService {
  static final CallAudioService _instance = CallAudioService._internal();
  static CallAudioService get instance => _instance;
  CallAudioService._internal();

  // Player per suoni di chiamata
  // AudioPlayer? _callPlayer; // Temporaneamente disabilitato
  // AudioPlayer? _ringtonePlayer; // Temporaneamente disabilitato
  // AudioPlayer? _busyPlayer; // Temporaneamente disabilitato
  
  // Timer per gestire durata suoni
  Timer? _callSoundTimer;
  Timer? _ringtoneTimer;
  Timer? _busyTimer;
  
  // Stato chiamata corrente
  String? _currentCallId;
  String? _currentCallType;
  bool _isInCall = false;
  bool _isRinging = false;
  bool _isBusy = false;
  
  // Configurazione suoni
  static const Duration _callSoundInterval = Duration(seconds: 2);
  static const Duration _ringtoneInterval = Duration(seconds: 3);
  static const Duration _busySoundDuration = Duration(seconds: 1);
  static const int _maxCallSoundRepeats = 30; // 1 minuto
  static const int _maxRingtoneRepeats = 20; // 1 minuto

  /// Inizializza il servizio
  Future<void> initialize() async {
    try {
      print('🔊 CallAudioService - Inizializzazione...');
      
      // Inizializza player
      // _callPlayer = AudioPlayer(); // Temporaneamente disabilitato
      // _ringtonePlayer = AudioPlayer(); // Temporaneamente disabilitato
      // _busyPlayer = AudioPlayer(); // Temporaneamente disabilitato
      
      // Configura player per chiamate
      // await _callPlayer!.setPlayerMode(PlayerMode.lowLatency); // Temporaneamente disabilitato
      // await _ringtonePlayer!.setPlayerMode(PlayerMode.lowLatency); // Temporaneamente disabilitato
      // await _busyPlayer!.setPlayerMode(PlayerMode.lowLatency); // Temporaneamente disabilitato
      
      print('✅ CallAudioService - Inizializzato');
      
    } catch (e) {
      print('❌ CallAudioService - Errore inizializzazione: $e');
    }
  }

  /// Avvia suono di chiamata in corso
  Future<void> startCallInProgressSound({
    required String callId,
    required String callType,
  }) async {
    try {
      print('🔊 CallAudioService - Avvio suono chiamata in corso');
      print('   - Call ID: $callId');
      print('   - Tipo: $callType');

      // Ferma suoni precedenti
      await stopAllSounds();

      // Imposta stato
      _currentCallId = callId;
      _currentCallType = callType;
      _isInCall = true;

      // Determina file audio
      String soundFile = _getCallInProgressSound(callType);
      
      // Riproduce suono di chiamata in corso
      await _playCallInProgressSound(soundFile);

      print('✅ CallAudioService - Suono chiamata in corso avviato');

    } catch (e) {
      print('❌ CallAudioService - Errore avvio suono chiamata: $e');
    }
  }

  /// Avvia suono di squillo per chiamata in arrivo
  Future<void> startIncomingCallRingtone({
    required String callId,
    required String callType,
  }) async {
    try {
      print('🔊 CallAudioService - Avvio suono chiamata in arrivo');
      print('   - Call ID: $callId');
      print('   - Tipo: $callType');

      // Ferma suoni precedenti
      await stopAllSounds();

      // Imposta stato
      _currentCallId = callId;
      _currentCallType = callType;
      _isRinging = true;

      // Determina file audio
      String soundFile = _getIncomingCallSound(callType);
      
      // Riproduce suono di squillo
      await _playIncomingCallRingtone(soundFile);

      print('✅ CallAudioService - Suono chiamata in arrivo avviato');

    } catch (e) {
      print('❌ CallAudioService - Errore avvio suono in arrivo: $e');
    }
  }

  /// Avvia suono di occupato
  Future<void> startBusySound({
    required String reason,
  }) async {
    try {
      print('🔊 CallAudioService - Avvio suono occupato');
      print('   - Motivo: $reason');

      // Ferma suoni precedenti
      await stopAllSounds();

      // Imposta stato
      _isBusy = true;

      // Riproduce suono di occupato
      await _playBusySound();

      print('✅ CallAudioService - Suono occupato avviato');

    } catch (e) {
      print('❌ CallAudioService - Errore avvio suono occupato: $e');
    }
  }

  /// Ferma tutti i suoni
  Future<void> stopAllSounds() async {
    try {
      print('🔊 CallAudioService - Fermata tutti i suoni');

      // Ferma timer
      _callSoundTimer?.cancel();
      _ringtoneTimer?.cancel();
      _busyTimer?.cancel();

      // Ferma player
      // await _callPlayer?.stop(); // Temporaneamente disabilitato
      // await _ringtonePlayer?.stop(); // Temporaneamente disabilitato
      // await _busyPlayer?.stop(); // Temporaneamente disabilitato

      // Reset stato
      _currentCallId = null;
      _currentCallType = null;
      _isInCall = false;
      _isRinging = false;
      _isBusy = false;

      print('✅ CallAudioService - Tutti i suoni fermati');

    } catch (e) {
      print('❌ CallAudioService - Errore fermata suoni: $e');
    }
  }

  /// Ferma suono specifico per chiamata
  Future<void> stopCallSound(String callId) async {
    if (_currentCallId == callId) {
      await stopAllSounds();
    }
  }

  /// Riproduce suono di chiamata in corso
  Future<void> _playCallInProgressSound(String soundFile) async {
    try {
      int repeatCount = 0;
      
      _callSoundTimer = Timer.periodic(_callSoundInterval, (timer) async {
        if (repeatCount >= _maxCallSoundRepeats || !_isInCall) {
          timer.cancel();
          return;
        }

        try {
          // Prova prima con file personalizzato
          // await _callPlayer!.play(AssetSource('sounds/$soundFile')); // Temporaneamente disabilitato
          print('🔊 CallAudioService - Suono chiamata in corso: $soundFile');
        } catch (e) {
          // Fallback al suono di sistema
          try {
            // await _callPlayer!.play(DeviceFileSource('/system/media/audio/notifications/$soundFile')); // Temporaneamente disabilitato
            print('🔊 CallAudioService - Suono sistema chiamata: $soundFile');
          } catch (e2) {
            // Suono di fallback
            await _playFallbackCallSound();
          }
        }

        repeatCount++;
      });

    } catch (e) {
      print('❌ CallAudioService - Errore riproduzione suono chiamata: $e');
    }
  }

  /// Riproduce suono di chiamata in arrivo
  Future<void> _playIncomingCallRingtone(String soundFile) async {
    try {
      int repeatCount = 0;
      
      _ringtoneTimer = Timer.periodic(_ringtoneInterval, (timer) async {
        if (repeatCount >= _maxRingtoneRepeats || !_isRinging) {
          timer.cancel();
          return;
        }

        try {
          // Prova prima con file personalizzato
          // await _ringtonePlayer!.play(AssetSource('sounds/$soundFile')); // Temporaneamente disabilitato
          print('🔊 CallAudioService - Suono chiamata in arrivo: $soundFile');
        } catch (e) {
          // Fallback al suono di sistema
          try {
            // await _ringtonePlayer!.play(DeviceFileSource('/system/media/audio/notifications/$soundFile')); // Temporaneamente disabilitato
            print('🔊 CallAudioService - Suono sistema in arrivo: $soundFile');
          } catch (e2) {
            // Suono di fallback
            await _playFallbackRingtone();
          }
        }

        repeatCount++;
      });

    } catch (e) {
      print('❌ CallAudioService - Errore riproduzione suono in arrivo: $e');
    }
  }

  /// Riproduce suono di occupato
  Future<void> _playBusySound() async {
    try {
      // Riproduce suono di occupato una volta
      try {
        // await _busyPlayer!.play(AssetSource('sounds/busy_tone.wav')); // Temporaneamente disabilitato
        print('🔊 CallAudioService - Suono occupato personalizzato');
      } catch (e) {
        // Fallback al suono di sistema
        try {
          // await _busyPlayer!.play(DeviceFileSource('/system/media/audio/notifications/busy_tone.wav')); // Temporaneamente disabilitato
          print('🔊 CallAudioService - Suono occupato sistema');
        } catch (e2) {
          // Suono di fallback
          await _playFallbackBusySound();
        }
      }

      // Timer per fermare dopo la durata
      _busyTimer = Timer(_busySoundDuration, () {
        _isBusy = false;
      });

    } catch (e) {
      print('❌ CallAudioService - Errore riproduzione suono occupato: $e');
    }
  }

  /// Suono di fallback per chiamata in corso
  Future<void> _playFallbackCallSound() async {
    try {
      // Usa suono di sistema predefinito
      // await _callPlayer!.play(DeviceFileSource('/system/media/audio/notifications/Default.wav')); // Temporaneamente disabilitato
    } catch (e) {
      print('❌ CallAudioService - Impossibile riprodurre suono di fallback');
    }
  }

  /// Suono di fallback per chiamata in arrivo
  Future<void> _playFallbackRingtone() async {
    try {
      // Usa suono di sistema predefinito
      // await _ringtonePlayer!.play(DeviceFileSource('/system/media/audio/notifications/Default.wav')); // Temporaneamente disabilitato
    } catch (e) {
      print('❌ CallAudioService - Impossibile riprodurre suono di fallback');
    }
  }

  /// Suono di fallback per occupato
  Future<void> _playFallbackBusySound() async {
    try {
      // Usa suono di sistema predefinito
      // await _busyPlayer!.play(DeviceFileSource('/system/media/audio/notifications/Default.wav')); // Temporaneamente disabilitato
    } catch (e) {
      print('❌ CallAudioService - Impossibile riprodurre suono di fallback');
    }
  }

  /// Determina file audio per chiamata in corso
  String _getCallInProgressSound(String callType) {
    switch (callType.toLowerCase()) {
      case 'video':
        return 'video_call_in_progress.wav';
      case 'audio':
      default:
        return 'audio_call_in_progress.wav';
    }
  }

  /// Determina file audio per chiamata in arrivo
  String _getIncomingCallSound(String callType) {
    switch (callType.toLowerCase()) {
      case 'video':
        return 'video_call_ring.wav';
      case 'audio':
      default:
        return 'audio_call_ring.wav';
    }
  }

  /// Verifica se l'utente è occupato
  bool get isUserBusy => _isInCall || _isRinging;

  /// Verifica se è in chiamata
  bool get isInCall => _isInCall;

  /// Verifica se sta squillando
  bool get isRinging => _isRinging;

  /// Verifica se è occupato
  bool get isBusy => _isBusy;

  /// Ottiene ID chiamata corrente
  String? get currentCallId => _currentCallId;

  /// Ottiene tipo chiamata corrente
  String? get currentCallType => _currentCallType;

  /// Pulisce risorse
  void dispose() {
    _callSoundTimer?.cancel();
    _ringtoneTimer?.cancel();
    _busyTimer?.cancel();
    // _callPlayer?.dispose(); // Temporaneamente disabilitato
    // _ringtonePlayer?.dispose(); // Temporaneamente disabilitato
    // _busyPlayer?.dispose(); // Temporaneamente disabilitato
    _isInCall = false;
    _isRinging = false;
    _isBusy = false;
  }
}
