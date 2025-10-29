import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:securevox_app/services/message_service.dart';
import 'package:securevox_app/models/message_model.dart';

/// Test per verificare l'ordinamento corretto dei messaggi
/// I messaggi più recenti devono essere mostrati in basso
void main() {
  group('Message Ordering Tests', () {
    late MessageService messageService;

    setUp(() {
      messageService = MessageService();
    });

    testWidgets('I messaggi devono essere ordinati dal più vecchio al più recente', (WidgetTester tester) async {
      const String chatId = 'test_chat_123';
      
      // Crea messaggi con timestamp diversi
      final message1 = MessageModel(
        id: 'msg_1',
        chatId: chatId,
        senderId: 'user_1',
        isMe: true,
        type: MessageType.text,
        content: 'Primo messaggio (più vecchio)',
        time: '10:00',
        metadata: {},
        isRead: true,
      );
      
      final message2 = MessageModel(
        id: 'msg_2',
        chatId: chatId,
        senderId: 'user_2',
        isMe: false,
        type: MessageType.text,
        content: 'Secondo messaggio (medio)',
        time: '10:05',
        metadata: {},
        isRead: true,
      );
      
      final message3 = MessageModel(
        id: 'msg_3',
        chatId: chatId,
        senderId: 'user_1',
        isMe: true,
        type: MessageType.text,
        content: 'Terzo messaggio (più recente)',
        time: '10:10',
        metadata: {},
        isRead: true,
      );
      
      // Aggiungi i messaggi alla cache in ordine casuale
      messageService.addMessageToCache(chatId, message2); // Secondo
      messageService.addMessageToCache(chatId, message3); // Terzo
      messageService.addMessageToCache(chatId, message1); // Primo
      
      // Recupera i messaggi
      final messages = await messageService.getChatMessages(chatId);
      
      // Verifica che i messaggi siano ordinati correttamente
      expect(messages.length, equals(3));
      
      // Il primo messaggio deve essere il più vecchio
      expect(messages[0].content, equals('Primo messaggio (più vecchio)'));
      expect(messages[0].time, equals('10:00'));
      
      // Il secondo messaggio deve essere quello medio
      expect(messages[1].content, equals('Secondo messaggio (medio)'));
      expect(messages[1].time, equals('10:05'));
      
      // Il terzo messaggio deve essere il più recente
      expect(messages[2].content, equals('Terzo messaggio (più recente)'));
      expect(messages[2].time, equals('10:10'));
      
      print('✅ Test ordinamento messaggi PASSATO');
      print('   📱 Primo messaggio (più vecchio): ${messages[0].content} - ${messages[0].time}');
      print('   📱 Secondo messaggio (medio): ${messages[1].content} - ${messages[1].time}');
      print('   📱 Terzo messaggio (più recente): ${messages[2].content} - ${messages[2].time}');
    });

    testWidgets('I messaggi con timestamp identici devono mantenere l\'ordine di inserimento', (WidgetTester tester) async {
      const String chatId = 'test_chat_456';
      
      // Crea messaggi con timestamp identici
      final message1 = MessageModel(
        id: 'msg_1',
        chatId: chatId,
        senderId: 'user_1',
        isMe: true,
        type: MessageType.text,
        content: 'Primo messaggio',
        time: '10:00',
        metadata: {},
        isRead: true,
      );
      
      final message2 = MessageModel(
        id: 'msg_2',
        chatId: chatId,
        senderId: 'user_2',
        isMe: false,
        type: MessageType.text,
        content: 'Secondo messaggio',
        time: '10:00', // Stesso timestamp
        metadata: {},
        isRead: true,
      );
      
      // Aggiungi i messaggi alla cache
      messageService.addMessageToCache(chatId, message1);
      messageService.addMessageToCache(chatId, message2);
      
      // Recupera i messaggi
      final messages = await messageService.getChatMessages(chatId);
      
      // Verifica che i messaggi mantengano l'ordine di inserimento
      expect(messages.length, equals(2));
      expect(messages[0].content, equals('Primo messaggio'));
      expect(messages[1].content, equals('Secondo messaggio'));
      
      print('✅ Test ordinamento messaggi con timestamp identici PASSATO');
    });
  });
}
