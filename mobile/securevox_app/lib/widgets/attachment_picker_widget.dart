import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/message_service.dart';

class AttachmentPickerWidget extends StatelessWidget {
  final String chatId;
  final String recipientId;
  final Function(bool) onAttachmentSent;

  const AttachmentPickerWidget({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.onAttachmentSent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Allega file',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          
          // Attachment options
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildAttachmentOption(
                    context,
                    icon: Icons.photo,
                    label: 'Foto',
                    color: Colors.blue,
                    onTap: () => _sendImage(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.videocam,
                    label: 'Video',
                    color: Colors.red,
                    onTap: () => _sendVideo(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.mic,
                    label: 'Audio',
                    color: Colors.orange,
                    onTap: () => _sendVoice(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.location_on,
                    label: 'Posizione',
                    color: Colors.green,
                    onTap: () => _sendLocation(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.attach_file,
                    label: 'Documento',
                    color: Colors.purple,
                    onTap: () => _sendDocument(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.contact_phone,
                    label: 'Contatto',
                    color: Colors.teal,
                    onTap: () => _sendContact(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.indigo,
                    onTap: () => _sendCameraImage(context),
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.folder,
                    label: 'File',
                    color: Colors.brown,
                    onTap: () => _sendFile(context),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendImage(BuildContext context) async {
    try {
      final success = await MessageService.sendImageMessage(
        chatId: chatId,
        recipientId: recipientId,
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Immagine inviata');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio dell\'immagine');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendVideo(BuildContext context) async {
    try {
      final success = await MessageService.sendVideoMessage(
        chatId: chatId,
        recipientId: recipientId,
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Video inviato');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio del video');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendVoice(BuildContext context) async {
    try {
      // Simula registrazione audio
      final success = await MessageService.sendVoiceMessage(
        chatId: chatId,
        recipientId: recipientId,
        audioPath: '/path/to/recorded_audio.m4a',
        duration: '0:30',
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Audio inviato');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio dell\'audio');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendLocation(BuildContext context) async {
    try {
      final success = await MessageService.sendLocationMessage(
        chatId: chatId,
        recipientId: recipientId,
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Posizione inviata');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio della posizione');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendDocument(BuildContext context) async {
    try {
      final success = await MessageService.sendDocumentMessage(
        chatId: chatId,
        recipientId: recipientId,
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Documento inviato');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio del documento');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendContact(BuildContext context) async {
    try {
      final success = await MessageService.sendContactMessage(
        chatId: chatId,
        recipientId: recipientId,
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Contatto inviato');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio del contatto');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendCameraImage(BuildContext context) async {
    try {
      // Simula foto dalla camera
      final success = await MessageService.sendImageMessage(
        chatId: chatId,
        recipientId: recipientId,
        caption: 'Foto dalla camera',
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'Foto inviata');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio della foto');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  Future<void> _sendFile(BuildContext context) async {
    try {
      final success = await MessageService.sendDocumentMessage(
        chatId: chatId,
        recipientId: recipientId,
      );
      
      if (success) {
        onAttachmentSent(true);
        Navigator.pop(context);
        _showSuccessSnackBar(context, 'File inviato');
      } else {
        _showErrorSnackBar(context, 'Errore nell\'invio del file');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Errore: $e');
    }
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
