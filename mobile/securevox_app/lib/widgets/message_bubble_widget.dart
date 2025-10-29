import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/message_model.dart';
import '../services/location_service.dart';
import '../services/contact_service.dart';
import 'audio_player_widget.dart';
import 'video_player_widget.dart';
import 'image_viewer_widget.dart';
import 'location_preview_widget.dart';

class MessageBubbleWidget extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(String, String, String)? onFileOpen;

  const MessageBubbleWidget({
    super.key,
    required this.message,
    this.onTap,
    this.onLongPress,
    this.onFileOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment: message.isMe 
              ? MainAxisAlignment.end 
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Bubble del messaggio (senza avatar)
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // NUOVO: Sfondo trasparente per TUTTI i messaggi media (inviati e ricevuti)
                  color: _isMediaMessage()
                      ? Colors.transparent    // TRASPARENTE per tutti i messaggi media
                      : message.isMe 
                          ? AppTheme.primaryColor  // VERDE per messaggi testo inviati
                          : Colors.grey[300],      // GRIGIO per messaggi testo ricevuti
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomLeft: message.isMe 
                        ? const Radius.circular(18) 
                        : const Radius.circular(4),
                    bottomRight: message.isMe 
                        ? const Radius.circular(4) 
                        : const Radius.circular(18),
                  ),
                  boxShadow: _isMediaMessage()
                      ? [] // Nessuna ombra per TUTTI i messaggi media trasparenti
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contenuto del messaggio
                    _buildMessageContent(context),
                    
                    // Timestamp
                    const SizedBox(height: 4),
                    Text(
                      message.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: _isMediaMessage()
                            ? Colors.grey[600]  // GRIGIO per TUTTI i messaggi media senza sfondo
                            : message.isMe 
                                ? Colors.white70 
                                : Colors.grey[600], // Grigio più scuro per messaggi in entrata
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return _buildTextContent();
      case MessageType.image:
        return _buildImageContent();
      case MessageType.video:
        return _buildVideoContent();
      case MessageType.voice:
        return _buildVoiceContent();
      case MessageType.file:
        return _buildFileContent();
      case MessageType.location:
        return _buildLocationContent();
      case MessageType.attachment:
        return _buildAttachmentContent();
      case MessageType.contact:
        return _buildContactContent();
    }
  }

  Widget _buildTextContent() {
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 16,
        color: message.isMe ? Colors.white : Colors.black, // Nero per messaggi in entrata
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildImageContent() {
    final imageData = ImageMessageData.fromJson(message.metadata!);
    
    // CORREZIONE: Debug dei metadati dell'immagine nel MessageBubbleWidget
    print('🖼️ MessageBubbleWidget._buildImageContent - DEBUG:');
    print('🖼️   message.metadata: ${message.metadata}');
    print('🖼️   imageData.imageUrl: ${imageData.imageUrl}');
    print('🖼️   imageData.caption: ${imageData.caption}');
    
    return ImageViewerWidget(
      imageUrl: imageData.imageUrl,
      caption: imageData.caption ?? '',
      isMe: message.isMe,
    );
  }

  Widget _buildVideoContent() {
    final videoData = VideoMessageData.fromJson(message.metadata!);
    
    return VideoPlayerWidget(
      videoUrl: videoData.videoUrl,
      thumbnailUrl: videoData.thumbnailUrl,
    );
  }

  Widget _buildVoiceContent() {
    final voiceData = VoiceMessageData.fromJson(message.metadata!);
    
    // return AudioPlayerWidget(
    //   audioUrl: voiceData.audioUrl,
    //   duration: voiceData.duration,
    //   isMe: message.isMe,
    // ); // Temporaneamente disabilitato
    
    // Widget temporaneo per messaggi audio
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: message.isMe ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.audiotrack, color: message.isMe ? Colors.white : Colors.black),
          SizedBox(width: 8),
          Text(
            'Audio temporaneamente non disponibile',
            style: TextStyle(
              color: message.isMe ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationContent() {
    try {
      // Prova prima a usare il nuovo formato LocationData
      final locationData = LocationData.fromJson(message.metadata!);
      
      return LocationPreviewWidget(
        location: locationData,
        onTap: () => LocationService.openLocationInMaps(locationData),
        width: 260,
        height: 160,
        showDetails: true,
      );
    } catch (e) {
      // Fallback al vecchio formato se esiste
      try {
        final oldLocationData = LocationMessageData.fromJson(message.metadata!);
        final locationData = LocationData(
          latitude: oldLocationData.latitude,
          longitude: oldLocationData.longitude,
          accuracy: 0.0,
          timestamp: message.timestamp,
        );
        
        return LocationPreviewWidget(
          location: locationData,
          onTap: () => LocationService.openLocationInMaps(locationData),
          width: 260,
          height: 160,
          showDetails: true,
        );
      } catch (e2) {
        // Fallback generico se i metadati non sono validi
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: message.isMe ? Colors.white : AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Posizione',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: message.isMe ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: message.isMe ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        );
      }
    }
  }

  Widget _buildAttachmentContent() {
    // Usa la stessa logica semplificata di _buildFileContent
    return _buildFileContent();
  }

  Widget _buildContactContent() {
    // Prova prima a usare il nuovo formato ContactData
    try {
      final contactData = ContactData.fromJson(message.metadata!);
      return _buildContactContentWithData(contactData);
    } catch (e) {
      // Fallback al vecchio formato
      final contactData = ContactMessageData.fromJson(message.metadata!);
      
      return Builder(
        builder: (context) => GestureDetector(
          onTap: () => _showContactDetailsModalLegacy(context, contactData),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 280,
            minHeight: 60,
          ),
          decoration: BoxDecoration(
            color: message.isMe ? Colors.white : Colors.grey[50], // Stesso stile dei file
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[300]!, // Bordo grigio come i file
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icona contatto
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                
                // Info contatto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        contactData.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: message.isMe ? Colors.grey[800] : Colors.black, // Stesso colore dei file
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Contact',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600], // Stesso colore dei file
                            ),
                          ),
                          if (contactData.phone.isNotEmpty) ...[
                            Text(
                              ' • ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                            Flexible(
                              child: Text(
                                contactData.phone,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                  // Icona visualizza
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildFileContent() {
    final metadata = message.metadata;
    if (metadata == null) {
      return Text(
        message.content,
        style: TextStyle(
          fontSize: 16,
          color: message.isMe ? Colors.white : Colors.black,
        ),
      );
    }

    final fileName = metadata['fileName'] ?? metadata['file_name'] ?? message.content;
    final fileSize = metadata['fileSize'] ?? metadata['file_size'] ?? 0;
    final fileType = metadata['fileType'] ?? metadata['file_type'] ?? metadata['mime_type'] ?? '';
    final fileExtension = metadata['fileExtension'] ?? metadata['file_extension'] ?? '';
    final fileUrl = metadata['fileUrl'] ?? metadata['file_url'] ?? '';
    
    // DEBUG: Verifica estrazione metadati
    print('🔍 FILE DEBUG - Message ID: ${message.id}');
    print('🔍 FILE DEBUG - Metadata raw: $metadata');
    print('🔍 FILE DEBUG - fileName: $fileName');
    print('🔍 FILE DEBUG - fileSize: $fileSize (${fileSize.runtimeType})');
    print('🔍 FILE DEBUG - fileType: $fileType');
    print('🔍 FILE DEBUG - fileUrl: $fileUrl');
    
    // Formatta la dimensione del file
    String formatFileSize(dynamic bytes) {
      int size = 0;
      if (bytes is int) {
        size = bytes;
      } else if (bytes is String) {
        size = int.tryParse(bytes) ?? 0;
      }
      
      if (size == 0) return 'Dimensione sconosciuta';
      if (size < 1024) return '$size B';
      if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    
    // SOLUZIONE STABILE: Solo icona e info nella chat bubble
    // La preview PDF sarà disponibile solo in fullscreen (FileViewerScreen)
    // Questo evita errori di rendering con PDF viewer embedded
    return GestureDetector(
      onTap: () {
        if (onFileOpen != null) {
          onFileOpen!(fileUrl, fileName, fileType);
        }
      },
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          minHeight: 60, // Ridotto da 80 a 60 per essere più compatto
        ),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.white : Colors.grey[50], // Sfondo bianco per messaggi inviati
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!, // NUOVO: Bordo grigio per tutti i documenti
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12), // Ridotto da 16 a 12
          child: Row(
            children: [
              // Icona file più piccola
              Container(
                width: 40, // Ridotto da 48 a 40
                height: 40, // Ridotto da 48 a 40
                decoration: BoxDecoration(
                  color: _getFileColor(fileType),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getFileIcon(fileType),
                  size: 24, // Ridotto da 28 a 24
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10), // Ridotto da 12 a 10
              // Info file
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName,
                      style: TextStyle(
                        fontSize: 13, // Ridotto da 14 a 13
                        fontWeight: FontWeight.w600,
                        color: message.isMe ? Colors.grey[800] : Colors.black, // NUOVO: Grigio scuro per messaggi inviati
                      ),
                      maxLines: 1, // Ridotto da 2 a 1 per essere più compatto
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // Ridotto da 4 a 2
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            fileExtension.isNotEmpty ? fileExtension.toUpperCase() : _getFileTypeName(fileType),
                            style: TextStyle(
                              fontSize: 10, // Ridotto da 11 a 10
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600], // NUOVO: Grigio per tutti i messaggi
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 10, // Ridotto da 11 a 10
                            color: Colors.grey[600], // NUOVO: Grigio per tutti i messaggi
                          ),
                        ),
                        const SizedBox(width: 6), // Ridotto da 8 a 6
                        Flexible(
                          child: Text(
                            formatFileSize(fileSize),
                            style: TextStyle(
                              fontSize: 10, // Ridotto da 11 a 10
                              color: Colors.grey[600], // NUOVO: Grigio per tutti i messaggi
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Icona per aprire fullscreen più piccola
              Icon(
                Icons.open_in_full,
                size: 16, // Ridotto da 18 a 16
                color: Colors.grey[600], // NUOVO: Grigio per tutti i messaggi (inviati e ricevuti)
              ),
            ],
          ),
        ),
      ),
    );
  }


  Color _getFileColor(String fileType) {
    if (fileType.contains('pdf')) {
      return Colors.red[600]!;
    } else if (fileType.contains('word') || fileType.contains('document') || fileType.contains('docx')) {
      return Colors.blue[600]!;
    } else if (fileType.contains('excel') || fileType.contains('spreadsheet') || fileType.contains('xlsx')) {
      return Colors.green[600]!;
    } else if (fileType.contains('powerpoint') || fileType.contains('presentation') || fileType.contains('pptx')) {
      return Colors.orange[600]!;
    } else if (fileType.contains('zip') || fileType.contains('rar')) {
      return Colors.purple[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  IconData _getFileIcon(String fileType) {
    if (fileType.startsWith('image/')) {
      return Icons.image;
    } else if (fileType.startsWith('video/')) {
      return Icons.video_file;
    } else if (fileType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (fileType == 'application/pdf' || fileType.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (fileType.contains('word') || fileType.contains('document') || fileType.contains('docx')) {
      return Icons.description;
    } else if (fileType.contains('excel') || fileType.contains('spreadsheet') || fileType.contains('xlsx')) {
      return Icons.table_chart;
    } else if (fileType.contains('powerpoint') || fileType.contains('presentation') || fileType.contains('pptx')) {
      return Icons.slideshow;
    } else if (fileType.contains('zip') || fileType.contains('rar')) {
      return Icons.archive;
    } else {
      return Icons.attach_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Ottieni nome del tipo file
  String _getFileTypeName(String fileType) {
    if (fileType.contains('word') || fileType.contains('document')) {
      return 'Word';
    } else if (fileType.contains('excel') || fileType.contains('spreadsheet')) {
      return 'Excel';
    } else if (fileType.contains('powerpoint') || fileType.contains('presentation')) {
      return 'PowerPoint';
    } else if (fileType.contains('pdf')) {
      return 'PDF';
    } else {
      return 'File';
    }
  }

  String _getOfficeTypeName(String fileType) {
    if (fileType.contains('word') || fileType.contains('docx')) {
      return 'Word Document';
    } else if (fileType.contains('excel') || fileType.contains('xlsx')) {
      return 'Excel Spreadsheet';
    } else if (fileType.contains('powerpoint') || fileType.contains('pptx')) {
      return 'PowerPoint Presentation';
    } else {
      return 'Office Document';
    }
  }

  /// Determina se il messaggio è di tipo media (immagine, video, file, contatto, posizione)
  bool _isMediaMessage() {
    return message.type == MessageType.image ||
           message.type == MessageType.video ||
           message.type == MessageType.file ||
           message.type == MessageType.attachment ||
           message.type == MessageType.contact ||
           message.type == MessageType.location;
  }

  Widget _buildContactContentWithData(ContactData contactData) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => _showContactDetailsModal(context, contactData),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 280,
          minHeight: 60,
        ),
        decoration: BoxDecoration(
          color: message.isMe ? Colors.white : Colors.grey[50], // Stesso stile dei file
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!, // Bordo grigio come i file
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icona contatto (stesso stile dell'icona file)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor, // Colore blu come i documenti
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person,
                  size: 24,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              
              // Info contatto (stesso layout dei file)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      contactData.name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: message.isMe ? Colors.grey[800] : Colors.black, // Stesso colore dei file
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Contact', // Tipo file come nei documenti
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600], // Stesso colore dei file
                          ),
                        ),
                        if (contactData.phoneNumbers.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          Flexible(
                            child: Text(
                              contactData.phoneNumbers.first,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
                // Icona visualizza
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Salva il contatto nella rubrica del telefono (nuovo formato)
  void _saveContactToPhone(ContactData contactData) async {
    try {
      print('📞 MessageBubbleWidget._saveContactToPhone - Salvando: ${contactData.name}');
      
      // Usa ContactService per salvare il contatto
      await ContactService.saveContactToPhone(contactData);
      
      print('✅ Contatto salvato con successo nella rubrica');
    } catch (e) {
      print('❌ Errore salvando contatto: $e');
    }
  }

  /// Salva il contatto nella rubrica del telefono (formato legacy)
  void _saveContactToPhoneFallback(ContactMessageData contactData) async {
    try {
      print('📞 MessageBubbleWidget._saveContactToPhoneFallback - Salvando: ${contactData.name}');
      
      // Converte al nuovo formato e salva
      final newContactData = ContactData(
        name: contactData.name,
        phoneNumbers: contactData.phone.isNotEmpty ? [contactData.phone] : [],
        emails: contactData.email?.isNotEmpty == true ? [contactData.email!] : [],
      );
      
      await ContactService.saveContactToPhone(newContactData);
      
      print('✅ Contatto legacy salvato con successo nella rubrica');
    } catch (e) {
      print('❌ Errore salvando contatto legacy: $e');
    }
  }

  /// Mostra modale con dettagli contatto (nuovo formato)
  void _showContactDetailsModal(BuildContext context, ContactData contactData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Indicatore drag
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Avatar grande
            CircleAvatar(
              radius: 50,
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(
                Icons.person,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            
            // Nome
            Text(
              contactData.name,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Numeri di telefono sotto il nome
            if (contactData.phoneNumbers.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...contactData.phoneNumbers.map((phone) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Text(
                      phone,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )),
            ],
            
            const SizedBox(height: 24),
            
            // Email (se presente)
            if (contactData.emails.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.email, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Email',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...contactData.emails.map((email) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            const SizedBox(height: 24),
            
            // Pulsante Salva in rubrica
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _saveContactToPhone(contactData);
                  
                  // Mostra conferma
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Contatto salvato nella rubrica'),
                      backgroundColor: Color(0xFF0D7C66),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.person_add),
                label: const Text(
                  'Salva in rubrica',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Pulsante Chiudi
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Chiudi',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mostra modale con dettagli contatto (formato legacy)
  void _showContactDetailsModalLegacy(BuildContext context, ContactMessageData contactData) {
    // Converte al nuovo formato e mostra la modale
    final newContactData = ContactData(
      name: contactData.name,
      phoneNumbers: contactData.phone.isNotEmpty ? [contactData.phone] : [],
      emails: contactData.email?.isNotEmpty == true ? [contactData.email!] : [],
    );
    _showContactDetailsModal(context, newContactData);
  }
}
