import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/pdf_preview_widget.dart';
import '../widgets/office_preview_widget.dart';

/// Schermo per visualizzare file a tutto schermo
class FileViewerScreen extends StatefulWidget {
  final String fileUrl;
  final String fileName;
  final String fileType;
  final Map<String, dynamic>? metadata;
  final int fileSize;

  const FileViewerScreen({
    Key? key,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    this.metadata,
    this.fileSize = 0,
  }) : super(key: key);

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Nascondi la status bar per esperienza fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    // Ripristina la status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Contenuto principale
          Center(
            child: _buildFileContent(),
          ),
          
          // Header con pulsante indietro
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Pulsante indietro
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                
                // CORREZIONE: Nascondi il nome del file per PDF e documenti Office in fullscreen
                if (_shouldShowFileName()) ...[
                  const SizedBox(width: 16),
                  
                  // Nome file (solo per file non-PDF/Office)
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else ...[
                  // Spacer per centrare i pulsanti quando non c'è titolo
                  const Spacer(),
                ],
                
                // Pulsante condividi
                GestureDetector(
                  onTap: _shareFile,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileContent() {
    
    if (widget.fileType.startsWith('image/')) {
      // Mostra immagine
      return InteractiveViewer(
        child: Image.network(
          widget.fileUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const CircularProgressIndicator(color: Colors.white);
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorWidget();
          },
        ),
      );
    } else if (widget.fileType.contains('pdf')) {
      // Preview PDF REALE fullscreen
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black, // Background nero per fullscreen
        child: PdfPreviewWidget(
          pdfUrl: widget.fileUrl,
          isFullScreen: true,
          fileName: widget.fileName,
        ),
      );
    } else if (widget.fileType.contains('word') || widget.fileType.contains('document') ||
               widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet') ||
               widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation') ||
               widget.fileType.contains('xlsx') || widget.fileType.contains('docx') || 
               widget.fileType.contains('pptx') || widget.fileType == 'xlsx' || 
               widget.fileType == 'docx' || widget.fileType == 'pptx' ||
               widget.fileName.toLowerCase().endsWith('.docx') ||
               widget.fileName.toLowerCase().endsWith('.xlsx') ||
               widget.fileName.toLowerCase().endsWith('.pptx')) {
      // NUOVO: Fullscreen Office usando PDF convertito se disponibile
      final pdfPreviewUrl = widget.metadata?['pdfPreviewUrl'] ?? 
                            widget.metadata?['pdf_preview_url'] ??
                            widget.metadata?['pdfPreview'] ??
                            widget.metadata?['pdf_preview'];
      
      print('🏢 FileViewerScreen - Office file detected: ${widget.fileName}');
      print('🏢 FileViewerScreen - pdfPreviewUrl from metadata: $pdfPreviewUrl');
      print('🏢 FileViewerScreen - All metadata: ${widget.metadata}');
      
      if (pdfPreviewUrl != null && pdfPreviewUrl.toString().isNotEmpty) {
        print('✅ FileViewerScreen - Using PDF preview for Office file');
        
        // SOLUZIONE MIGLIORATA: Usa sempre OfficePreviewWidget per Office files con PDF convertito
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black, // Background nero per fullscreen
          child: OfficePreviewWidget(
            pdfUrl: pdfPreviewUrl.toString(),
            width: double.infinity,
            height: double.infinity,
            isFullscreen: true,
            fileName: widget.fileName,
          ),
        );
      } else {
        print('⚠️ FileViewerScreen - No PDF preview available, showing info widget');
        return _buildOfficeInfoWidget();
      }
    } else {
      // Per altri file, mostra icona e info
      return _buildFileInfoWidget();
    }
  }

  Widget _buildOfficeInfoWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _getOfficeColor().withValues(alpha: 0.1),
            _getOfficeColor().withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icona grande
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getOfficeColor().withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getOfficeIcon(),
                size: 120,
                color: _getOfficeColor(),
              ),
            ),
            const SizedBox(height: 32),
            
            // Nome file
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.fileName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            
            // Tipo file
            Text(
              _getOfficeTypeName().toUpperCase(),
              style: TextStyle(
                color: _getOfficeColor(),
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            
            // Dimensione file
            Text(
              _formatFileSize(widget.fileSize),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 40),
            
            // Pulsanti azione
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsante condividi
                    ElevatedButton.icon(
                      onPressed: _shareFile,
                      icon: const Icon(Icons.share),
                      label: const Text('Condividi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getOfficeColor(),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Pulsante download (simulato)
                    ElevatedButton.icon(
                      onPressed: () {
                        // Simula download
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Download di ${widget.fileName} avviato'),
                            backgroundColor: _getOfficeColor(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // NUOVO: Pulsante per tentare visualizzazione diretta del file originale
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton.icon(
                    onPressed: () => _tryDirectFileView(),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Prova visualizzazione diretta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Info aggiuntiva
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Preview PDF non disponibile per questo file ${_getOfficeTypeName().toLowerCase()}.',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Puoi provare la visualizzazione diretta o scaricare il file per aprirlo con un\'applicazione compatibile.',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInfoWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icona file grande
          Icon(
            _getFileIcon(widget.fileType),
            size: 80,
            color: Colors.white,
          ),
          
          const SizedBox(height: 24),
          
          // Nome file
          Text(
            widget.fileName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Tipo file
          Text(
            widget.fileType,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Pulsante condividi file
          ElevatedButton.icon(
            onPressed: _shareFile,
            icon: const Icon(Icons.share, color: Colors.white),
            label: const Text(
              'Condividi file',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Errore nel caricamento del file',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.fileName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
    } else if (fileType.contains('zip') || fileType.contains('rar')) {
      return Icons.archive;
    } else {
      return Icons.attach_file;
    }
  }

  void _shareFile() {
    // TODO: Implementare condivisione file
    print('📤 Condivisione file: ${widget.fileName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Condivisione di ${widget.fileName}'),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Tenta di visualizzare il file Office direttamente senza PDF preview
  void _tryDirectFileView() {
    print('🔍 FileViewer - Tentativo visualizzazione diretta file: ${widget.fileName}');
    print('🔍 FileViewer - URL originale: ${widget.fileUrl}');
    
    // Mostra messaggio informativo
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Apertura diretta di ${widget.fileName}...'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // TODO: Implementare apertura con app esterna se necessario
    // Per ora mostra solo il messaggio
  }

  /// Helper per documenti Office
  Color _getOfficeColor() {
    if (widget.fileType.contains('word') || widget.fileType.contains('document')) {
      return Colors.blue[600]!;
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet')) {
      return Colors.green[600]!;
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation')) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  IconData _getOfficeIcon() {
    if (widget.fileType.contains('word') || widget.fileType.contains('document')) {
      return Icons.description;
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet')) {
      return Icons.table_chart;
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation')) {
      return Icons.slideshow;
    } else {
      return Icons.insert_drive_file;
    }
  }

  String _getOfficeTypeName() {
    if (widget.fileType.contains('word') || widget.fileType.contains('document')) {
      return 'Word Document';
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet')) {
      return 'Excel Spreadsheet';
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation')) {
      return 'PowerPoint Presentation';
    } else {
      return 'Office Document';
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

  /// Determina se mostrare il nome del file nell'header
  /// Nasconde il nome per PDF e documenti Office in fullscreen per un'esperienza più pulita
  bool _shouldShowFileName() {
    // Nascondi il nome per PDF
    if (widget.fileType.contains('pdf') || widget.fileName.toLowerCase().endsWith('.pdf')) {
      return false;
    }
    
    // Nascondi il nome per documenti Office
    if (widget.fileType.contains('word') || widget.fileType.contains('document') ||
        widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet') ||
        widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation') ||
        widget.fileType.contains('xlsx') || widget.fileType.contains('docx') || 
        widget.fileType.contains('pptx') || widget.fileType == 'xlsx' || 
        widget.fileType == 'docx' || widget.fileType == 'pptx' ||
        widget.fileName.toLowerCase().endsWith('.docx') ||
        widget.fileName.toLowerCase().endsWith('.xlsx') ||
        widget.fileName.toLowerCase().endsWith('.pptx')) {
      return false;
    }
    
    // Mostra il nome per altri tipi di file (immagini, video, ecc.)
    return true;
  }
}
