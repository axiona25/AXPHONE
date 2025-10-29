import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato

/// Configurazione per prevenire crash di memoria e threading
class CrashPreventionConfig {
  static final CrashPreventionConfig _instance = CrashPreventionConfig._internal();
  static CrashPreventionConfig get instance => _instance;
  CrashPreventionConfig._internal();

  // Timer per cleanup automatico
  Timer? _cleanupTimer;
  
  // Lista di risorse da pulire
  final List<StreamSubscription> _subscriptions = [];
  final List<Timer> _timers = [];
  // final List<AudioPlayer> _audioPlayers = []; // Temporaneamente disabilitato

  /// Inizializza la prevenzione crash
  Future<void> initialize() async {
    try {
      print('🛡️ CrashPreventionConfig - Inizializzazione...');

      // Configura gestione errori
      FlutterError.onError = (FlutterErrorDetails details) {
        print('🚨 FlutterError: ${details.exception}');
        print('📍 Stack: ${details.stack}');
        // Non re-lanciare l'errore per evitare crash
      };

      // Configura gestione errori asincroni
      PlatformDispatcher.instance.onError = (error, stack) {
        print('🚨 PlatformDispatcher Error: $error');
        print('📍 Stack: $stack');
        return true; // Gestisce l'errore
      };

      // Avvia timer di cleanup
      _startCleanupTimer();

      print('✅ CrashPreventionConfig - Inizializzato');

    } catch (e) {
      print('❌ CrashPreventionConfig - Errore inizializzazione: $e');
    }
  }

  /// Registra una risorsa per cleanup automatico
  void registerResource(dynamic resource) {
    if (resource is StreamSubscription) {
      _subscriptions.add(resource);
    } else if (resource is Timer) {
      _timers.add(resource);
    // } else if (resource is AudioPlayer) {
    //   _audioPlayers.add(resource); // Temporaneamente disabilitato
    }
  }

  /// Avvia timer di cleanup automatico
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _performCleanup();
    });
  }

  /// Esegue cleanup delle risorse
  void _performCleanup() {
    try {
      print('🧹 CrashPreventionConfig - Cleanup risorse...');

      // Pulisce subscription scadute
      _subscriptions.removeWhere((sub) {
        try {
          if (sub.isPaused) {
            sub.cancel();
            return true;
          }
          return false;
        } catch (e) {
          return true; // Rimuove se errore
        }
      });

      // Pulisce timer scaduti
      _timers.removeWhere((timer) {
        try {
          if (!timer.isActive) {
            return true;
          }
          return false;
        } catch (e) {
          return true; // Rimuove se errore
        }
      });

      // Pulisce audio player non utilizzati
      // _audioPlayers.removeWhere((player) {
      //   try {
      //     // Non dispose automaticamente, solo rimuove dalla lista
      //     return false;
      //   } catch (e) {
      //     return true; // Rimuove se errore
      //   }
      // }); // Temporaneamente disabilitato

      print('✅ CrashPreventionConfig - Cleanup completato');

    } catch (e) {
      print('❌ CrashPreventionConfig - Errore cleanup: $e');
    }
  }

  /// Pulisce tutte le risorse registrate
  void dispose() {
    try {
      print('🧹 CrashPreventionConfig - Disposizione risorse...');

      // Ferma timer di cleanup
      _cleanupTimer?.cancel();

      // Pulisce tutte le subscription
      for (final sub in _subscriptions) {
        try {
          sub.cancel();
        } catch (e) {
          print('⚠️ CrashPreventionConfig - Errore cancellazione subscription: $e');
        }
      }
      _subscriptions.clear();

      // Pulisce tutti i timer
      for (final timer in _timers) {
        try {
          timer.cancel();
        } catch (e) {
          print('⚠️ CrashPreventionConfig - Errore cancellazione timer: $e');
        }
      }
      _timers.clear();

      // Pulisce tutti gli audio player
      // for (final player in _audioPlayers) {
      //   try {
      //     player.dispose();
      //   } catch (e) {
      //     print('⚠️ CrashPreventionConfig - Errore disposizione audio player: $e');
      //   }
      // }
      // _audioPlayers.clear(); // Temporaneamente disabilitato

      print('✅ CrashPreventionConfig - Disposizione completata');

    } catch (e) {
      print('❌ CrashPreventionConfig - Errore disposizione: $e');
    }
  }

  /// Configurazioni per prevenire crash di memoria
  static const Map<String, dynamic> memoryConfig = {
    // 'maxAudioPlayers': 3, // Temporaneamente disabilitato
    'maxTimers': 10,
    'maxSubscriptions': 20,
    'cleanupInterval': Duration(minutes: 5),
    'maxMemoryUsage': 100 * 1024 * 1024, // 100MB
  };

  /// Configurazioni per prevenire crash di threading
  static const Map<String, dynamic> threadingConfig = {
    'maxConcurrentOperations': 5,
    'operationTimeout': Duration(seconds: 30),
    'retryAttempts': 3,
    'retryDelay': Duration(seconds: 1),
  };
}
