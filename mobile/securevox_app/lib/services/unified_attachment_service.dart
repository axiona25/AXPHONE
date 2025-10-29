import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../services/user_service.dart';
import '../services/timezone_service.dart';
import '../services/media_service.dart';
import '../services/message_service.dart';

/// Enum per i tipi di allegati supportati
enum AttachmentType {
  image,
  video,
  file,
  contact,
  location,
  audio,
}

/// Modello unificato per allegati
class AttachmentData {
  final AttachmentType type;
  final File? file;
  final String? url;
  final Map<String, dynamic> metadata;
  final String? caption;

  AttachmentData({
    required this.type,
    this.file,
    this.url,
    required this.metadata,
    this.caption,
  });
}

/// Servizio unificato per gestire tutti i tipi di allegati
/// Standardizza il flusso: Preview → Upload → Send → Notify
class UnifiedAttachmentService {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  final MediaService _mediaService = MediaService();

  /// 1. SELEZIONE - Seleziona allegato dal dispositivo
  Future<AttachmentData?> selectAttachment(AttachmentType type) async {
    try {
      print('📎 UnifiedAttachmentService.selectAttachment - Tipo: $type');

      switch (type) {
        case AttachmentType.image:
          final file = await _mediaService.pickImageFromGallery();
          if (file != null) {
            return AttachmentData(
              type: AttachmentType.image,
              file: file,
              metadata: {
                'file_name': file.path.split('/').last,
                'file_size': await file.length(),
                'file_type': 'image/${file.path.split('.').last}',
              },
            );
          }
          break;

        case AttachmentType.video:
          final file = await _mediaService.pickVideoFromGallery();
          if (file != null) {
            return AttachmentData(
              type: AttachmentType.video,
              file: file,
              metadata: {
                'file_name': file.path.split('/').last,
                'file_size': await file.length(),
                'file_type': 'video/${file.path.split('.').last}',
              },
            );
          }
          break;

        case AttachmentType.file:
          final file = await _mediaService.pickDocument();
          if (file != null) {
            return AttachmentData(
              type: AttachmentType.file,
              file: file,
              metadata: {
                'file_name': file.path.split('/').last,
                'file_size': await file.length(),
                'file_type': _getFileType(file.path.split('/').last),
                'file_extension': file.path.split('.').last.toLowerCase(),
              },
            );
          }
          break;

        case AttachmentType.contact:
          final contact = await _mediaService.pickContact();
          if (contact != null) {
            return AttachmentData(
              type: AttachmentType.contact,
              metadata: contact,
            );
          }
          break;

        case AttachmentType.location:
          final position = await _mediaService.getCurrentPosition();
          if (position != null) {
            final address = await _mediaService.getAddressFromCoordinates(
              position.latitude, 
              position.longitude
            );
            return AttachmentData(
              type: AttachmentType.location,
              metadata: {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'address': address,
                'city': 'Roma', // TODO: Estrarre dalla geocoding
                'country': 'Italia',
              },
            );
          }
          break;

        case AttachmentType.audio:
          // TODO: Implementare audio recording
          print('🎤 Audio recording - TODO');
          break;
      }

      return null;
    } catch (e) {
      print('❌ UnifiedAttachmentService.selectAttachment - Errore: $e');
      return null;
    }
  }

  /// 2. UPLOAD - Carica allegato sul server
  Future<Map<String, dynamic>?> uploadAttachment(
    AttachmentData attachment,
    String userId,
    String chatId,
  ) async {
    try {
      print('⬆️ UnifiedAttachmentService.uploadAttachment - Tipo: ${attachment.type}');

      switch (attachment.type) {
        case AttachmentType.image:
          if (attachment.file != null) {
            return await _mediaService.uploadImage(
              userId: userId,
              chatId: chatId,
              image: attachment.file!,
              caption: attachment.caption ?? '',
            );
          }
          break;

        case AttachmentType.video:
          if (attachment.file != null) {
            return await _mediaService.uploadVideo(
              userId: userId,
              chatId: chatId,
              video: attachment.file!,
              caption: attachment.caption ?? '',
            );
          }
          break;

        case AttachmentType.file:
          if (attachment.file != null) {
            return await _mediaService.uploadFile(
              userId: userId,
              chatId: chatId,
              file: attachment.file!,
            );
          }
          break;

        case AttachmentType.contact:
        case AttachmentType.location:
        case AttachmentType.audio:
          // Questi non hanno upload fisico, solo metadata
          return {'success': true, 'data': attachment.metadata};
      }

      return null;
    } catch (e) {
      print('❌ UnifiedAttachmentService.uploadAttachment - Errore: $e');
      return null;
    }
  }

  /// 3. MESSAGE FACTORY - Crea MessageModel unificato
  MessageModel createMessage({
    required String chatId,
    required String senderId,
    required AttachmentType type,
    required String content,
    required Map<String, dynamic> metadata,
    String? caption,
  }) {
    final now = DateTime.now();
    
    // Converti AttachmentType in MessageType
    MessageType messageType;
    switch (type) {
      case AttachmentType.image:
        messageType = MessageType.image;
        break;
      case AttachmentType.video:
        messageType = MessageType.video;
        break;
      case AttachmentType.file:
        messageType = MessageType.file;
        break;
      case AttachmentType.contact:
        messageType = MessageType.contact;
        break;
      case AttachmentType.location:
        messageType = MessageType.location;
        break;
      case AttachmentType.audio:
        messageType = MessageType.voice;
        break;
    }

    return MessageModel(
      id: '${type.name}_${now.millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: senderId,
      isMe: true,
      type: messageType,
      content: caption?.isNotEmpty == true ? caption! : content,
      time: TimezoneService.formatCallTime(now),
      timestamp: now,
      metadata: {
        ...metadata,
        if (caption?.isNotEmpty == true) 'caption': caption,
      },
      isRead: true,
    );
  }

  /// 4. SEND UNIFIED - Invia allegato con flusso unificato
  Future<bool> sendAttachment({
    required String chatId,
    required String recipientId,
    required AttachmentData attachment,
    String? caption,
    required MessageService messageService,
    required Function(String, String) syncCallback,
  }) async {
    try {
      print('📤 UnifiedAttachmentService.sendAttachment - Inizio invio ${attachment.type}');

      // 1. Upload se necessario
      Map<String, dynamic>? uploadResult;
      if (attachment.file != null) {
        final userId = UserService.getCurrentUserIdSync() ?? '1';
        uploadResult = await uploadAttachment(attachment, userId, chatId);
        
        if (uploadResult == null) {
          throw Exception('Upload fallito');
        }
      }

      // 2. Prepara metadata finali
      final finalMetadata = {
        ...attachment.metadata,
        if (uploadResult != null) ...uploadResult,
      };

      // 3. Crea messaggio
      final message = createMessage(
        chatId: chatId,
        senderId: UserService.getCurrentUserIdSync() ?? '1',
        type: attachment.type,
        content: _getContentForType(attachment.type, attachment.metadata),
        metadata: finalMetadata,
        caption: caption,
      );

      // 4. Invia al backend per notifiche real-time
      await _sendMessageToBackend(message, recipientId);

      // 5. Aggiungi alla cache locale
      messageService.addMessageToCache(chatId, message);

      // 6. Sincronizza con RealChatService
      syncCallback(chatId, message.content);

      print('✅ UnifiedAttachmentService.sendAttachment - ${attachment.type} inviato con successo');
      return true;

    } catch (e) {
      print('❌ UnifiedAttachmentService.sendAttachment - Errore: $e');
      return false;
    }
  }

  /// 5. BACKEND SENDER - Invia al backend per notifiche
  Future<void> _sendMessageToBackend(MessageModel message, String recipientId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ Token non disponibile per invio backend');
        return;
      }

      print('📡 Invio messaggio al backend per notifiche real-time...');
      print('📡 Recipient ID: $recipientId');
      print('📡 Message Type: ${message.type}');

      final response = await http.post(
        Uri.parse('$baseUrl/chats/${message.chatId}/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'recipient_id': recipientId,
          'message_type': message.type.toString().split('.').last, // file invece di MessageType.file
          'content': message.content,
          'metadata': message.metadata,
          'timestamp': message.timestamp.toIso8601String(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Messaggio inviato al backend con successo');
      } else {
        print('❌ Errore invio backend: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Errore invio messaggio al backend: $e');
    }
  }

  /// Helper: Ottieni contenuto per tipo
  String _getContentForType(AttachmentType type, Map<String, dynamic> metadata) {
    switch (type) {
      case AttachmentType.image:
        return '📷 Immagine';
      case AttachmentType.video:
        return '🎥 Video';
      case AttachmentType.file:
        return '📎 ${metadata['file_name'] ?? 'Documento'}';
      case AttachmentType.contact:
        return '👤 ${metadata['name'] ?? 'Contatto'}';
      case AttachmentType.location:
        return '📍 Posizione';
      case AttachmentType.audio:
        return '🎤 Audio';
    }
  }

  /// Helper: Ottieni tipo MIME del file
  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  /// Helper: Ottieni token di autenticazione (COPIATO DA MessageService)
  Future<String?> _getAuthToken() async {
    try {
      print('🔑 UnifiedAttachmentService._getAuthToken - INIZIO recupero token');
      final prefs = await SharedPreferences.getInstance();
      
      // Debug: mostra tutte le chiavi salvate
      final allKeys = prefs.getKeys();
      print('🔑 UnifiedAttachmentService._getAuthToken - Chiavi disponibili: ${allKeys.where((k) => k.startsWith('securevox_')).toList()}');
      
      final token = prefs.getString('securevox_auth_token');
      final isLoggedIn = prefs.getBool('securevox_is_logged_in') ?? false;
      
      print('🔑 UnifiedAttachmentService._getAuthToken - Token presente: ${token != null}');
      print('🔑 UnifiedAttachmentService._getAuthToken - Token length: ${token?.length ?? 0}');
      print('🔑 UnifiedAttachmentService._getAuthToken - Is logged in: $isLoggedIn');
      if (token != null) {
        print('🔑 UnifiedAttachmentService._getAuthToken - Token preview: ${token.substring(0, math.min(20, token.length))}...');
      }
      
      // Se il token è null o vuoto, pulisci lo stato di login
      if (token == null || token.isEmpty) {
        print('🔑 UnifiedAttachmentService._getAuthToken - Token non disponibile, pulizia stato login');
        await prefs.setBool('securevox_is_logged_in', false);
        return null;
      }
      
      print('🔑 UnifiedAttachmentService._getAuthToken - Token recuperato con successo');
      return token;
    } catch (e) {
      print('❌ UnifiedAttachmentService._getAuthToken - Errore: $e');
      return null;
    }
  }
}

/// Widget unificato per preview allegati nel campo input
class UnifiedAttachmentPreview extends StatelessWidget {
  final AttachmentData attachment;
  final VoidCallback onRemove;
  final String? caption;

  const UnifiedAttachmentPreview({
    Key? key,
    required this.attachment,
    required this.onRemove,
    this.caption,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Preview specifica per tipo
        _buildPreviewWidget(),
        const SizedBox(width: 12),
        
        // Campo caption
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: _getHintForType(),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        
        // Pulsante rimuovi
        GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewWidget() {
      switch (attachment.type) {
        case AttachmentType.image:
          return _buildImagePreview();
        case AttachmentType.video:
          return _buildVideoPreview();
        case AttachmentType.file:
          return _buildFilePreview();
        case AttachmentType.contact:
          return _buildContactPreview();
        case AttachmentType.location:
          return _buildLocationPreview();
        case AttachmentType.audio:
          return _buildAudioPreview();
      }
  }

  Widget _buildImagePreview() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: attachment.file != null
            ? Image.file(attachment.file!, fit: BoxFit.cover)
            : const Icon(Icons.image, size: 40),
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.black,
      ),
      child: const Icon(
        Icons.play_circle_outline,
        color: Colors.white,
        size: 30,
      ),
    );
  }

  Widget _buildFilePreview() {
    final fileName = attachment.metadata['file_name'] ?? 'File';
    final fileExtension = attachment.metadata['file_extension'] ?? '';
    
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getFileIcon(attachment.metadata['file_type'] ?? ''),
            size: 24,
            color: Colors.blue[600],
          ),
          const SizedBox(height: 2),
          Text(
            fileExtension.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPreview() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.blue[50],
      ),
      child: const Icon(
        Icons.person,
        size: 30,
        color: Colors.blue,
      ),
    );
  }

  Widget _buildLocationPreview() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.green[50],
      ),
      child: const Icon(
        Icons.location_on,
        size: 30,
        color: Colors.green,
      ),
    );
  }

  Widget _buildAudioPreview() {
    return Container(
      width: 80,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.orange[50],
      ),
      child: const Icon(
        Icons.mic,
        size: 30,
        color: Colors.orange,
      ),
    );
  }

  String _getHintForType() {
    switch (attachment.type) {
      case AttachmentType.image:
        return 'Aggiungi una didascalia...';
      case AttachmentType.video:
        return 'Aggiungi una caption...';
      case AttachmentType.file:
        return 'Aggiungi una didascalia...';
      case AttachmentType.contact:
        return 'Aggiungi un messaggio...';
      case AttachmentType.location:
        return 'Aggiungi un messaggio...';
      case AttachmentType.audio:
        return 'Messaggio vocale';
    }
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.startsWith('image/')) {
      return Icons.image;
    } else if (fileType.startsWith('video/')) {
      return Icons.video_file;
    } else if (fileType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (fileType == 'application/pdf') {
      return Icons.picture_as_pdf;
    } else if (fileType.contains('word') || fileType.contains('document')) {
      return Icons.description;
    } else if (fileType.contains('excel') || fileType.contains('spreadsheet')) {
      return Icons.table_chart;
    } else if (fileType.contains('powerpoint') || fileType.contains('presentation')) {
      return Icons.slideshow;
    } else {
      return Icons.attach_file;
    }
  }
}
