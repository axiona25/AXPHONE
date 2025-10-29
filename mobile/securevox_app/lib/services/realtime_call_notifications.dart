import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../widgets/incoming_call_overlay.dart';

class RealtimeCallNotifications {
  static final RealtimeCallNotifications _instance = RealtimeCallNotifications._internal();
  factory RealtimeCallNotifications() => _instance;
  RealtimeCallNotifications._internal();

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  BuildContext? _context;
  OverlayEntry? _currentOverlay;
  
  // Callbacks
  Function(Map<String, dynamic>)? onIncomingCall;
  Function(String)? onCallEnded;

  void setContext(BuildContext context) {
    _context = context;
  }

  /// Inizializza connessione WebSocket per notifiche real-time
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        print('⚠️ RealtimeCallNotifications - Nessun token disponibile');
        return;
      }

      print('🔌 RealtimeCallNotifications - Connessione WebSocket...');
      
      // Connetti al WebSocket del backend Django
      final wsUrl = 'ws://127.0.0.1:8001/ws/notifications/';
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['Bearer', token], // Passa token nell'header
      );

      // Ascolta messaggi
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );

      _isConnected = true;
      print('✅ RealtimeCallNotifications - WebSocket connesso');

    } catch (e) {
      print('❌ RealtimeCallNotifications - Errore connessione: $e');
      _scheduleReconnect();
    }
  }

  /// Gestisce messaggi WebSocket
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      
      print('📨 RealtimeCallNotifications - Messaggio ricevuto: $type');
      
      switch (type) {
        case 'incoming_call':
          _handleIncomingCall(data['data']);
          break;
          
        case 'call_ended':
          _handleCallEnded(data['data']);
          break;
          
        case 'call_cancelled':
          _handleCallCancelled(data['data']);
          break;
          
        default:
          print('⚠️ Tipo messaggio sconosciuto: $type');
      }
      
    } catch (e) {
      print('❌ Errore parsing messaggio WebSocket: $e');
    }
  }

  /// Gestisce chiamata in arrivo
  void _handleIncomingCall(Map<String, dynamic> callData) {
    print('📞 RealtimeCallNotifications - Chiamata in arrivo!');
    print('📞 Dati: ${jsonEncode(callData)}');
    
    // Mostra overlay
    _showIncomingCallOverlay(callData);
    
    // Notifica callback
    if (onIncomingCall != null) {
      onIncomingCall!(callData);
    }
  }

  /// Gestisce chiamata terminata
  void _handleCallEnded(Map<String, dynamic> data) {
    final sessionId = data['session_id'];
    print('📞 RealtimeCallNotifications - Chiamata terminata: $sessionId');
    
    // Rimuovi overlay se presente
    _removeCurrentOverlay();
    
    // Notifica callback
    if (onCallEnded != null) {
      onCallEnded!(sessionId);
    }
  }

  /// Gestisce chiamata cancellata
  void _handleCallCancelled(Map<String, dynamic> data) {
    final sessionId = data['session_id'];
    print('📞 RealtimeCallNotifications - Chiamata cancellata: $sessionId');
    
    // Rimuovi overlay se presente
    _removeCurrentOverlay();
  }

  /// Mostra overlay chiamata in arrivo
  void _showIncomingCallOverlay(Map<String, dynamic> callData) {
    if (_context == null) {
      print('⚠️ Context non disponibile per overlay chiamata');
      return;
    }

    // Rimuovi overlay precedente
    _removeCurrentOverlay();

    try {
      _currentOverlay = OverlayEntry(
        builder: (context) => IncomingCallOverlay(
          callData: callData,
          onDismiss: _removeCurrentOverlay,
        ),
      );

      Overlay.of(_context!).insert(_currentOverlay!);
      print('✅ Overlay chiamata in arrivo mostrato');

    } catch (e) {
      print('❌ Errore mostrando overlay: $e');
    }
  }

  /// Rimuove overlay corrente
  void _removeCurrentOverlay() {
    if (_currentOverlay != null) {
      try {
        _currentOverlay!.remove();
        _currentOverlay = null;
        print('✅ Overlay chiamata rimosso');
      } catch (e) {
        print('❌ Errore rimozione overlay: $e');
      }
    }
  }

  /// Gestisce errori WebSocket
  void _handleError(error) {
    print('❌ RealtimeCallNotifications - Errore WebSocket: $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Gestisce disconnessione WebSocket
  void _handleDisconnection() {
    print('🔌 RealtimeCallNotifications - WebSocket disconnesso');
    _isConnected = false;
    _scheduleReconnect();
  }

  /// Programma riconnessione automatica
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      print('🔄 RealtimeCallNotifications - Tentativo riconnessione...');
      initialize();
    });
  }

  /// Chiude connessione
  void dispose() {
    print('🔌 RealtimeCallNotifications - Chiusura connessione...');
    _reconnectTimer?.cancel();
    _removeCurrentOverlay();
    _channel?.sink.close();
    _isConnected = false;
  }

  /// Stato connessione
  bool get isConnected => _isConnected;
}
