import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../widgets/universal_message_widget.dart';

/// Esempio di come utilizzare il sistema standardizzato di messaggi
class MessageUsageExample extends StatelessWidget {
  const MessageUsageExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Esempi di messaggi creati con il factory
    final messages = [
      // Messaggio di testo
      MessageFactory.createTextMessage(
        id: '1',
        chatId: 'chat1',
        senderId: 'user1',
        isMe: false,
        text: 'Ciao! Come stai?',
        time: '09:25',
      ),

      // Messaggio di testo inviato da me
      MessageFactory.createTextMessage(
        id: '2',
        chatId: 'chat1',
        senderId: 'me',
        isMe: true,
        text: 'Tutto bene, grazie!',
        time: '09:26',
      ),

      // Messaggio audio
      MessageFactory.createVoiceMessage(
        id: '3',
        chatId: 'chat1',
        senderId: 'user1',
        isMe: false,
        duration: '00:16',
        audioUrl: 'https://example.com/audio.mp3',
        time: '09:27',
      ),

      // Messaggio immagine
      MessageFactory.createImageMessage(
        id: '4',
        chatId: 'chat1',
        senderId: 'user1',
        isMe: false,
        imageUrl: 'https://picsum.photos/120/120?random=1',
        caption: 'Guarda questa foto!',
        time: '09:28',
      ),

      // Messaggio video
      MessageFactory.createVideoMessage(
        id: '5',
        chatId: 'chat1',
        senderId: 'me',
        isMe: true,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://picsum.photos/120/120?random=2',
        caption: 'Video interessante',
        time: '09:29',
      ),

      // Messaggio allegato
      MessageFactory.createAttachmentMessage(
        id: '6',
        chatId: 'chat1',
        senderId: 'user1',
        isMe: false,
        fileName: 'Documento.docx',
        fileType: 'docx',
        fileUrl: 'https://example.com/document.docx',
        fileSize: 1024000,
        time: '09:30',
      ),

      // Messaggio posizione
      MessageFactory.createLocationMessage(
        id: '7',
        chatId: 'chat1',
        senderId: 'user1',
        isMe: false,
        latitude: 45.4642,
        longitude: 9.1859,
        address: 'Via Roma, 123',
        city: 'Milano, Italia',
        time: '09:31',
      ),

      // Messaggio contatto
      MessageFactory.createContactMessage(
        id: '8',
        chatId: 'chat1',
        senderId: 'me',
        isMe: true,
        name: 'Marco Rossi',
        phone: '+39 123 456 7890',
        email: 'marco.rossi@example.com',
        organization: 'Azienda SRL',
        time: '09:32',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Esempio Messaggi'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: messages.length,
        itemBuilder: (context, index) {
          final message = messages[index];
          return UniversalMessageWidget(message: message);
        },
      ),
    );
  }
}

/// Utility per creare messaggi di test
class TestMessageCreator {
  static List<MessageModel> createTestMessages() {
    return [
      MessageFactory.createTextMessage(
        id: '1',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        text: 'Buona settimana di lavoro!!',
        time: '09:25',
      ),
      MessageFactory.createTextMessage(
        id: '2',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        text: 'Spero ti piaccia',
        time: '09:25',
      ),
      MessageFactory.createTextMessage(
        id: '3',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        text: 'Guarda il mio lavoro!!',
        time: '09:25',
      ),
      MessageFactory.createTextMessage(
        id: '4',
        chatId: 'test',
        senderId: 'me',
        isMe: true,
        text: 'Hai fatto un ottimo lavoro!',
        time: '09:25',
      ),
      MessageFactory.createVoiceMessage(
        id: '5',
        chatId: 'test',
        senderId: 'me',
        isMe: true,
        duration: '00:16',
        audioUrl: 'https://example.com/audio.mp3',
        time: '09:25',
      ),
      MessageFactory.createTextMessage(
        id: '6',
        chatId: 'test',
        senderId: 'me',
        isMe: true,
        text: 'Ciao! Jhon abraham',
        time: '09:25',
      ),
      MessageFactory.createVideoMessage(
        id: '7',
        chatId: 'test',
        senderId: 'me',
        isMe: true,
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://picsum.photos/120/120?random=2',
        time: '09:25',
      ),
      MessageFactory.createImageMessage(
        id: '8',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        imageUrl: 'https://picsum.photos/120/120?random=1',
        time: '09:25',
      ),
      MessageFactory.createAttachmentMessage(
        id: '9',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        fileName: 'Documento.docx',
        fileType: 'docx',
        fileUrl: 'https://example.com/document.docx',
        fileSize: 1024000,
        time: '09:25',
      ),
      MessageFactory.createAttachmentMessage(
        id: '10',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        fileName: 'Relazione.pdf',
        fileType: 'pdf',
        fileUrl: 'https://example.com/report.pdf',
        fileSize: 2048000,
        time: '09:25',
      ),
      MessageFactory.createLocationMessage(
        id: '11',
        chatId: 'test',
        senderId: 'user1',
        isMe: false,
        latitude: 45.4642,
        longitude: 9.1859,
        address: 'Via Roma, 123',
        city: 'Milano, Italia',
        time: '09:25',
      ),
      MessageFactory.createContactMessage(
        id: '12',
        chatId: 'test',
        senderId: 'me',
        isMe: true,
        name: 'Marco Rossi',
        phone: '+39 123 456 7890',
        email: 'marco.rossi@example.com',
        time: '09:25',
      ),
    ];
  }
}
