/// Modello standardizzato per tutti i tipi di messaggi
class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final bool isMe;
  final MessageType type;
  final String content;
  final String time;
  final DateTime timestamp; // Aggiunto timestamp completo
  final Map<String, dynamic>? metadata;
  bool isRead; // Rimosso final per permettere la modifica

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.isMe,
    required this.type,
    required this.content,
    required this.time,
    required this.timestamp,
    this.metadata,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      isMe: json['isMe'],
      type: MessageType.fromString(json['type']),
      content: json['content'],
      time: json['time'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      metadata: json['metadata'],
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'isMe': isMe,
      'type': type.toString(),
      'content': content,
      'time': time,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'isRead': isRead,
    };
  }
}

/// Enum per i tipi di messaggi
enum MessageType {
  text,
  voice,
  image,
  video,
  file,
  attachment,
  location,
  contact;

  static MessageType fromString(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return MessageType.text;
      case 'voice':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'file':
        return MessageType.file;
      case 'attachment':
        return MessageType.attachment;
      case 'location':
        return MessageType.location;
      case 'contact':
        return MessageType.contact;
      default:
        return MessageType.text;
    }
  }

  @override
  String toString() {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.voice:
        return 'voice';
      case MessageType.image:
        return 'image';
      case MessageType.video:
        return 'video';
      case MessageType.file:
        return 'file';
      case MessageType.attachment:
        return 'attachment';
      case MessageType.location:
        return 'location';
      case MessageType.contact:
        return 'contact';
    }
  }
}

/// Modelli specifici per ogni tipo di messaggio

/// Modello per messaggi di testo
class TextMessageData {
  final String text;

  TextMessageData({required this.text});

  factory TextMessageData.fromJson(Map<String, dynamic> json) {
    return TextMessageData(text: json['text']);
  }

  Map<String, dynamic> toJson() {
    return {'text': text};
  }
}

/// Modello per messaggi audio
class VoiceMessageData {
  final String duration;
  final String audioUrl;

  VoiceMessageData({required this.duration, required this.audioUrl});

  factory VoiceMessageData.fromJson(Map<String, dynamic> json) {
    return VoiceMessageData(
      duration: json['duration'],
      audioUrl: json['audioUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'audioUrl': audioUrl,
    };
  }
}

/// Modello per messaggi di immagini
class ImageMessageData {
  final String imageUrl;
  final String? caption;

  ImageMessageData({required this.imageUrl, this.caption});

  factory ImageMessageData.fromJson(Map<String, dynamic> json) {
    // CORREZIONE: Debug del parsing dei metadati immagine
    print('🖼️ ImageMessageData.fromJson - DEBUG:');
    print('🖼️   json keys: ${json.keys}');
    print('🖼️   json values: $json');
    print('🖼️   json[imageUrl]: ${json['imageUrl']}');
    print('🖼️   json[image_url]: ${json['image_url']}');
    
    // CORREZIONE: Prova multipli campi per l'URL
    final imageUrl = json['imageUrl'] ?? json['image_url'] ?? '';
    print('🖼️   URL finale estratto: $imageUrl');
    
    return ImageMessageData(
      imageUrl: imageUrl,
      caption: json['caption'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'caption': caption,
    };
  }
}

/// Modello per messaggi video
class VideoMessageData {
  final String videoUrl;
  final String thumbnailUrl;
  final String? caption;

  VideoMessageData({
    required this.videoUrl,
    required this.thumbnailUrl,
    this.caption,
  });

  factory VideoMessageData.fromJson(Map<String, dynamic> json) {
    return VideoMessageData(
      videoUrl: json['videoUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      caption: json['caption'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
    };
  }
}

/// Modello per messaggi di allegati
class AttachmentMessageData {
  final String fileName;
  final String fileType;
  final String fileUrl;
  final int fileSize;

  AttachmentMessageData({
    required this.fileName,
    required this.fileType,
    required this.fileUrl,
    required this.fileSize,
  });

  factory AttachmentMessageData.fromJson(Map<String, dynamic> json) {
    return AttachmentMessageData(
      fileName: json['fileName']?.toString() ?? '',
      fileType: json['fileType']?.toString() ?? '',
      fileUrl: json['fileUrl']?.toString() ?? '',
      fileSize: int.tryParse(json['fileSize']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'fileType': fileType,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
    };
  }
}

/// Modello per messaggi di posizione geografica
class LocationMessageData {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String? country;

  LocationMessageData({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    this.country,
  });

  factory LocationMessageData.fromJson(Map<String, dynamic> json) {
    return LocationMessageData(
      latitude: json['latitude'],
      longitude: json['longitude'],
      address: json['address'],
      city: json['city'],
      country: json['country'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'city': city,
      'country': country,
    };
  }
}

/// Modello per messaggi di contatto
class ContactMessageData {
  final String name;
  final String phone;
  final String? email;
  final String? organization;

  ContactMessageData({
    required this.name,
    required this.phone,
    this.email,
    this.organization,
  });

  factory ContactMessageData.fromJson(Map<String, dynamic> json) {
    return ContactMessageData(
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      organization: json['organization'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'email': email,
      'organization': organization,
    };
  }
}
