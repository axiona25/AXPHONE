import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Menu per la selezione di allegati
class AttachmentMenu extends StatelessWidget {
  final VoidCallback? onGalleryPhoto;
  final VoidCallback? onGalleryVideo;
  final VoidCallback? onDocument;
  final VoidCallback? onContact;
  final VoidCallback? onLocation;
  final VoidCallback? onAudioRecord;

  const AttachmentMenu({
    Key? key,
    this.onGalleryPhoto,
    this.onGalleryVideo,
    this.onDocument,
    this.onContact,
    this.onLocation,
    this.onAudioRecord,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Titolo
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Aggiungi allegato',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Griglia delle opzioni
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Prima riga - Foto, Video, Documento
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library,
                      label: 'Foto',
                      color: Colors.blue,
                      onTap: onGalleryPhoto,
                    ),
                    _buildAttachmentOption(
                      icon: Icons.video_library,
                      label: 'Video',
                      color: Colors.purple,
                      onTap: onGalleryVideo,
                    ),
                    _buildAttachmentOption(
                      icon: Icons.description,
                      label: 'Documento',
                      color: Colors.orange,
                      onTap: onDocument,
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Seconda riga - Contatto, Posizione, Audio
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.person,
                      label: 'Contatto',
                      color: AppTheme.primaryColor,
                      onTap: onContact,
                    ),
                    _buildAttachmentOption(
                      icon: Icons.location_on,
                      label: 'Posizione',
                      color: Colors.indigo,
                      onTap: onLocation,
                    ),
                    _buildAttachmentOption(
                      icon: Icons.mic,
                      label: 'Audio',
                      color: Colors.teal,
                      onTap: onAudioRecord,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Bottone chiudi
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextButton(
              onPressed: () {
                if (context.mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: const Text(
                'Annulla',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget per mostrare il menu allegati
class AttachmentMenuHandler {
  static void showAttachmentMenu(BuildContext context, {
    VoidCallback? onGalleryPhoto,
    VoidCallback? onGalleryVideo,
    VoidCallback? onDocument,
    VoidCallback? onContact,
    VoidCallback? onLocation,
    VoidCallback? onAudioRecord,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachmentMenu(
        onGalleryPhoto: () {
          _safePop(context);
          onGalleryPhoto?.call();
        },
        onGalleryVideo: () {
          _safePop(context);
          onGalleryVideo?.call();
        },
        onDocument: () {
          _safePop(context);
          onDocument?.call();
        },
        onContact: () {
          _safePop(context);
          onContact?.call();
        },
        onLocation: () {
          _safePop(context);
          onLocation?.call();
        },
        onAudioRecord: () {
          _safePop(context);
          onAudioRecord?.call();
        },
      ),
    );
  }

  /// Metodo sicuro per chiudere il modal
  static void _safePop(BuildContext context) {
    if (context.mounted && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }
}
