import 'package:flutter/material.dart';
import '../models/message_model.dart';
import 'message_widgets.dart';

/// Widget universale che gestisce tutti i tipi di messaggi
class UniversalMessageWidget extends StatelessWidget {
  final MessageModel message;

  const UniversalMessageWidget({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return TextMessageWidget(
          text: message.content,
          time: message.time,
          isMe: message.isMe,
        );

      case MessageType.voice:
        final voiceData = VoiceMessageData.fromJson(message.metadata ?? {});
        return VoiceMessageWidget(
          duration: voiceData.duration,
          time: message.time,
          isMe: message.isMe,
        );

      case MessageType.image:
        final imageData = ImageMessageData.fromJson(message.metadata ?? {});
        return ImageMessageWidget(
          imageUrl: imageData.imageUrl,
          time: message.time,
          isMe: message.isMe,
        );

      case MessageType.video:
        final videoData = VideoMessageData.fromJson(message.metadata ?? {});
        return VideoMessageWidget(
          thumbnailUrl: videoData.thumbnailUrl,
          time: message.time,
          isMe: message.isMe,
        );

      case MessageType.attachment:
        final attachmentData = AttachmentMessageData.fromJson(message.metadata ?? {});
        return AttachmentMessageWidget(
          fileName: attachmentData.fileName,
          fileType: attachmentData.fileType,
          time: message.time,
          isMe: message.isMe,
        );

      case MessageType.location:
        final locationData = LocationMessageData.fromJson(message.metadata ?? {});
        return LocationMessageWidget(
          address: locationData.address,
          city: locationData.city,
          latitude: locationData.latitude,
          longitude: locationData.longitude,
          time: message.time,
          isMe: message.isMe,
        );

      case MessageType.contact:
        final contactData = ContactMessageData.fromJson(message.metadata ?? {});
        return ContactMessageWidget(
          name: contactData.name,
          phone: contactData.phone,
          email: contactData.email,
          time: message.time,
          isMe: message.isMe,
        );

      default:
        return TextMessageWidget(
          text: message.content,
          time: message.time,
          isMe: message.isMe,
        );
    }
  }
}

/// Factory per creare messaggi di esempio
class MessageFactory {
  static MessageModel createTextMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required String text,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.text,
      content: text,
      time: time,
    );
  }

  static MessageModel createVoiceMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required String duration,
    required String audioUrl,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.voice,
      content: '',
      time: time,
      metadata: VoiceMessageData(
        duration: duration,
        audioUrl: audioUrl,
      ).toJson(),
    );
  }

  static MessageModel createImageMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required String imageUrl,
    String? caption,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.image,
      content: '',
      time: time,
      metadata: ImageMessageData(
        imageUrl: imageUrl,
        caption: caption,
      ).toJson(),
    );
  }

  static MessageModel createVideoMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required String videoUrl,
    required String thumbnailUrl,
    String? caption,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.video,
      content: '',
      time: time,
      metadata: VideoMessageData(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        caption: caption,
      ).toJson(),
    );
  }

  static MessageModel createAttachmentMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required String fileName,
    required String fileType,
    required String fileUrl,
    required int fileSize,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.attachment,
      content: '',
      time: time,
      metadata: AttachmentMessageData(
        fileName: fileName,
        fileType: fileType,
        fileUrl: fileUrl,
        fileSize: fileSize,
      ).toJson(),
    );
  }

  static MessageModel createLocationMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required double latitude,
    required double longitude,
    required String address,
    required String city,
    String? country,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.location,
      content: '',
      time: time,
      metadata: LocationMessageData(
        latitude: latitude,
        longitude: longitude,
        address: address,
        city: city,
        country: country,
      ).toJson(),
    );
  }

  static MessageModel createContactMessage({
    required String id,
    required String chatId,
    required String senderId,
    required bool isMe,
    required String name,
    required String phone,
    String? email,
    String? organization,
    required String time,
  }) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      isMe: isMe,
      type: MessageType.contact,
      content: '',
      time: time,
      metadata: ContactMessageData(
        name: name,
        phone: phone,
        email: email,
        organization: organization,
      ).toJson(),
    );
  }
}
