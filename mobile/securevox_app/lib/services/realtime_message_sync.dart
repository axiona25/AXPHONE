import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message_model.dart';

/// Servizio per la sincronizzazione real-time dei messaggi tra dispositivi
/// Simula l'arrivo dei messaggi in tempo reale
class RealtimeMessageSync {
  static final RealtimeMessageSync _instance = RealtimeMessageSync._internal();
  factory RealtimeMessageSync() => _instance;
  RealtimeMessageSync._internal();

  static const String _baseUrl = 'http://127.0.0.1:8001/api';
  Timer? _syncTimer;
  final Map<String, StreamController<MessageModel>> _messageStreams = {};
  final Map<String, List<MessageModel>> _pendingMessages = {};

  /// Inizializza il servizio di sincronizzazione real-time
  Future<void> initialize() async {
    print('🔄 RealtimeMessageSync.initialize - Inizializzazione servizio real-time');
    
    // Avvia il timer di sincronizzazione ogni 2 secondi
    _syncTimer = Timer.periodic(Duration(seconds: 2), (timer) {
      _syncMessages();
    });
    
    print('✅ RealtimeMessageSync.initialize - Servizio inizializzato');
  }

  /// Ferma il servizio di sincronizzazione
  void dispose() {
    _syncTimer?.cancel();
    _messageStreams.values.forEach((controller) => controller.close());
    _messageStreams.clear();
    _pendingMessages.clear();
    print('🔄 RealtimeMessageSync.dispose - Servizio fermato');
  }

  /// Invia un messaggio e simula l'arrivo per l'altro utente
  Future<void> sendMessageAndSync({
    required String chatId,
    required String senderId,
    required String recipientId,
    required String content,
    required String messageId,
  }) async {
    try {
      print('📤 RealtimeMessageSync.sendMessageAndSync - Invio messaggio: $messageId');
      
      // Simula l'invio al backend
      await _sendToBackend(chatId, senderId, content, messageId);
      
      // Simula l'arrivo del messaggio per l'altro utente dopo 1 secondo
      Timer(Duration(seconds: 1), () {
        _simulateMessageArrival(chatId, senderId, content, messageId);
      });
      
      print('✅ RealtimeMessageSync.sendMessageAndSync - Messaggio inviato e sincronizzato');
    } catch (e) {
      print('❌ RealtimeMessageSync.sendMessageAndSync - Errore: $e');
    }
  }

  /// Simula l'arrivo di un messaggio per l'altro utente
  void _simulateMessageArrival(String chatId, String senderId, String content, String messageId) {
    try {
      print('📨 RealtimeMessageSync._simulateMessageArrival - Simulazione arrivo messaggio');
      
      final now = DateTime.now();
      final incomingMessage = MessageModel(
        id: 'arrival_$messageId',
        chatId: chatId,
        senderId: senderId,
        content: content,
        time: now.toIso8601String(),
        timestamp: now,
        isMe: false,
        isRead: false,
        type: MessageType.text,
      );
      
      // Aggiungi alla lista dei messaggi in arrivo
      if (!_pendingMessages.containsKey(chatId)) {
        _pendingMessages[chatId] = [];
      }
      _pendingMessages[chatId]!.add(incomingMessage);
      
      // Notifica l'arrivo del messaggio
      _notifyMessageArrival(chatId, incomingMessage);
      
      print('✅ RealtimeMessageSync._simulateMessageArrival - Messaggio simulato: $content');
    } catch (e) {
      print('❌ RealtimeMessageSync._simulateMessageArrival - Errore: $e');
    }
  }

  /// Notifica l'arrivo di un messaggio
  void _notifyMessageArrival(String chatId, MessageModel message) {
    if (_messageStreams.containsKey(chatId)) {
      _messageStreams[chatId]!.add(message);
    }
  }

  /// Sincronizza i messaggi in arrivo
  Future<void> _syncMessages() async {
    try {
      for (final chatId in _pendingMessages.keys) {
        final messages = _pendingMessages[chatId]!;
        if (messages.isNotEmpty) {
          print('🔄 RealtimeMessageSync._syncMessages - Sincronizzazione chat: $chatId (${messages.length} messaggi)');
          
          // Simula l'arrivo dei messaggi
          for (final message in messages) {
            _notifyMessageArrival(chatId, message);
          }
          
          // Pulisci i messaggi sincronizzati
          _pendingMessages[chatId]!.clear();
        }
      }
    } catch (e) {
      print('❌ RealtimeMessageSync._syncMessages - Errore: $e');
    }
  }

  /// Invia messaggio al backend
  Future<void> _sendToBackend(String chatId, String senderId, String content, String messageId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'sender_id': senderId,
          'content': content,
          'message_id': messageId,
          'message_type': 'text',
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ RealtimeMessageSync._sendToBackend - Messaggio inviato al backend');
      } else {
        print('❌ RealtimeMessageSync._sendToBackend - Errore backend: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ RealtimeMessageSync._sendToBackend - Errore: $e');
    }
  }

  /// Ottiene lo stream dei messaggi per una chat
  Stream<MessageModel> getMessageStream(String chatId) {
    if (!_messageStreams.containsKey(chatId)) {
      _messageStreams[chatId] = StreamController<MessageModel>.broadcast();
    }
    return _messageStreams[chatId]!.stream;
  }

  /// Simula l'arrivo di un messaggio per un altro utente
  void simulateIncomingMessageForOtherUser(String chatId, String content, String senderId) {
    final messageId = 'sim_${DateTime.now().millisecondsSinceEpoch}';
    _simulateMessageArrival(chatId, senderId, content, messageId);
  }
}
