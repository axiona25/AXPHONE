import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/pdf_preview_widget.dart';
import '../widgets/office_preview_widget.dart';
import 'package:open_file/open_file.dart';  // 🆕 Per aprire file con app esterne
import 'package:share_plus/share_plus.dart';  // 🆕 Per condividere file
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';

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
  final MediaService _mediaService = MediaService();  // 🆕 Per decifrare file
  
  // 🆕 Stati per conversione Office → PDF
  bool _isConverting = false;
  String? _convertedPdfUrl;  // URL del PDF convertito
  String? _conversionError;

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
    // 🔐 CORREZIONE: Rileva il tipo dal nome del file se fileType è generico ('bin', 'octet-stream')
    final isGenericType = widget.fileType == 'bin' || 
                          widget.fileType.contains('octet-stream') ||
                          widget.fileType.isEmpty;
    final fileNameLower = widget.fileName.toLowerCase();
    
    print('🔍 FileViewerScreen._buildFileContent:');
    print('   fileName: ${widget.fileName}');
    print('   fileType: ${widget.fileType}');
    print('   isGenericType: $isGenericType');
    
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
    } else if (widget.fileType.contains('pdf') || (isGenericType && fileNameLower.endsWith('.pdf'))) {
      // 🔐 CORREZIONE: Rileva PDF anche dal nome del file
      print('✅ FileViewerScreen: PDF rilevato (type: ${widget.fileType}, file: ${widget.fileName})');

      // 🔐 CORREZIONE: Controlla se abbiamo già un PDF decifrato salvato localmente
      final pdfPreviewUrl = _convertedPdfUrl;
      
      if (pdfPreviewUrl != null && pdfPreviewUrl.isNotEmpty) {
        print('✅ PDF decifrato già disponibile: $pdfPreviewUrl');
        // PDF già decifrato: usa quello
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: PdfPreviewWidget(
            pdfUrl: pdfPreviewUrl,
            isFullScreen: true,
            fileName: widget.fileName,
          ),
        );
      }

      // 🔐 CORREZIONE: Verifica se il PDF è cifrato e usiamo _convertEncryptedOfficeToPdf
      final isEncrypted = MediaService.isAttachmentEncrypted(widget.metadata);
      print('🔐 PDF cifrato: $isEncrypted');
      
      if (isEncrypted) {
        print('🔐 PDF cifrato rilevato, avvio decifratura e gestione...');
        // Usa lo stesso codice per Office che gestisce la decifratura
        // Mostra loading durante la conversione
        if (_isConverting) {
          return _buildConversionLoadingWidget();
        }
        // Avvia decifratura dopo il build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _convertEncryptedOfficeToPdf();
        });
        // Mostra loading mentre aspettiamo
        return _buildConversionLoadingWidget();
      }

      // Preview PDF REALE fullscreen (non cifrato)
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
               fileNameLower.endsWith('.docx') ||
               fileNameLower.endsWith('.xlsx') ||
               fileNameLower.endsWith('.pptx') ||
               fileNameLower.endsWith('.doc') ||
               fileNameLower.endsWith('.xls') ||
               fileNameLower.endsWith('.ppt')) {
      // 🔐 CORREZIONE: Rileva Office anche dal nome del file
      print('✅ FileViewerScreen: Office file rilevato (type: ${widget.fileType}, file: ${widget.fileName})');

      // NUOVO: Fullscreen Office usando PDF convertito se disponibile
      final pdfPreviewUrl = _convertedPdfUrl ??  // 🔐 Prima controlla se abbiamo un PDF convertito localmente
                            widget.metadata?['pdfPreviewUrl'] ?? 
                            widget.metadata?['pdf_preview_url'] ??
                            widget.metadata?['pdfPreview'] ??
                            widget.metadata?['pdf_preview'];
      
      print('🏢 FileViewerScreen - Office file detected: ${widget.fileName}');
      print('🏢 FileViewerScreen - pdfPreviewUrl from metadata: ${widget.metadata?['pdfPreviewUrl']}');
      print('🏢 FileViewerScreen - convertedPdfUrl: $_convertedPdfUrl');
      print('🏢 FileViewerScreen - All metadata: ${widget.metadata}');
      
      if (pdfPreviewUrl != null && pdfPreviewUrl.toString().isNotEmpty) {
        print('✅ FileViewerScreen - Using PDF preview for Office file');
        print('✅ pdfPreviewUrl: $pdfPreviewUrl');
        
        // CORREZIONE: Usa PdfPreviewWidget per Office files (come prima)
        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black, // Background nero per fullscreen
          child: PdfPreviewWidget(
            pdfUrl: pdfPreviewUrl.toString(),
            fileName: widget.fileName,
            isFullScreen: true,
          ),
        );
      } else {
        print('⚠️ FileViewerScreen - No PDF preview available');
        
        // Mostra errore di conversione se presente
        if (_conversionError != null) {
          return _buildConversionErrorWidget();
        }
        
        // Mostra loading durante la conversione
        if (_isConverting) {
          return _buildConversionLoadingWidget();
        }
        
        // 🔐 CORREZIONE: Se il file è cifrato, decifralo e convertilo in PDF
        print('');
        print('🔐🔐🔐 ===== VERIFICA CIFRATURA FILE OFFICE =====');
        print('🔐 Metadata completi: ${widget.metadata}');
        print('🔐 Metadata keys: ${widget.metadata?.keys.toList()}');
        
        final isEncrypted = MediaService.isAttachmentEncrypted(widget.metadata);
        print('🔐 isEncrypted risultato: $isEncrypted');
        
        // 🔐 DEBUG: Verifica manuale se ci sono metadata di cifratura
        final hasEncryptedField = widget.metadata?['encrypted'] == true;
        final hasIv = widget.metadata?['iv'] != null;
        final hasMac = widget.metadata?['mac'] != null;
        print('🔐 Verifica manuale:');
        print('   • encrypted field: $hasEncryptedField');
        print('   • iv presente: $hasIv');
        print('   • mac presente: $hasMac');
        print('🔐 ========================================');
        print('');
        
        if (isEncrypted && !_isConverting && _convertedPdfUrl == null) {
          print('🔐 File Office cifrato senza PDF preview, avvio decifratura e conversione...');
          // Avvia conversione dopo il build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _convertEncryptedOfficeToPdf();
          });
          // Mostra loading mentre aspettiamo
          return _buildConversionLoadingWidget();
        }
        
        // 🔐 CORREZIONE: Anche per file non cifrati senza pdfPreviewUrl, prova a convertire in PDF
        if (!isEncrypted && !_isConverting && _convertedPdfUrl == null) {
          print('📄 File Office NON cifrato senza PDF preview, avvio conversione diretta...');
          // Avvia conversione dopo il build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _convertNonEncryptedOfficeToPdf();
          });
          // Mostra loading mentre aspettiamo
          return _buildConversionLoadingWidget();
        }
        
        // Altrimenti mostra info widget con bottone per aprire con app esterna
        print('ℹ️ File Office senza PDF preview e conversione non disponibile');
        print('ℹ️ Stato: isEncrypted=$isEncrypted, isConverting=$_isConverting, convertedPdfUrl=$_convertedPdfUrl');
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
                // 🆕 Bottone grande principale "Apri con..."
                ElevatedButton.icon(
                  onPressed: _shareFile,
                  icon: const Icon(Icons.open_in_new, size: 24),
                  label: Text(_getOpenWithAppName()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getOfficeColor(),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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

  /// 🆕 Widget per mostrare il loading durante la conversione
  Widget _buildConversionLoadingWidget() {
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
            // Icona Office animata
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _getOfficeColor().withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getOfficeIcon(),
                size: 80,
                color: _getOfficeColor(),
              ),
            ),
            const SizedBox(height: 32),
            
            // Progress indicator
            SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(_getOfficeColor()),
              ),
            ),
            const SizedBox(height: 24),
            
            // Messaggio
            const Text(
              'Preparazione anteprima...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Decifratura e conversione di\n${widget.fileName}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '🔐 File cifrato end-to-end',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 🆕 Widget per mostrare errori di conversione
  Widget _buildConversionErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red.withValues(alpha: 0.1),
            Colors.red.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icona errore
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 80,
                color: Colors.red,
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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            
            // Messaggio errore
            const Text(
              'Errore conversione PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _conversionError ?? 'Errore sconosciuto',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 32),
            
            // Bottone per aprire con app esterna
            ElevatedButton.icon(
              onPressed: _shareFile,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Apri con app esterna'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
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

  /// Apre il file con app esterna (scarica, decifra se necessario, e apre)
  Future<void> _shareFile() async {
    print('');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ 📤 FileViewerScreen._shareFile - Apertura con app esterna ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    print('📄 File: ${widget.fileName}');
    print('📄 URL: ${widget.fileUrl}');
    print('📄 Type: ${widget.fileType}');
    print('📄 Metadata: ${widget.metadata}');
    
    // Mostra dialogo di caricamento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Preparazione file...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // 🔐 Verifica se il file è cifrato
      final isEncrypted = MediaService.isAttachmentEncrypted(widget.metadata);
      print('🔐 File cifrato: $isEncrypted');
      
      File? localFile;
      
      if (isEncrypted) {
        // File cifrato: scarica e decifra
        print('🔐 File cifrato rilevato, avvio download e decifratura...');
        
        final encryptionMeta = MediaService.getEncryptionMetadata(widget.metadata!);
        if (encryptionMeta == null) {
          throw Exception('Metadata di cifratura non disponibili');
        }
        
        // Estrai senderId dai metadata
        final senderId = widget.metadata?['sender_id']?.toString() ?? 
                        widget.metadata?['senderId']?.toString() ?? 
                        widget.metadata?['recipient_id']?.toString();
        
        if (senderId == null) {
          throw Exception('sender_id non disponibile nei metadata');
        }
        
        print('🔐 Sender ID: $senderId');
        print('🔐 IV presente: ${encryptionMeta['iv'] != null}');
        print('🔐 MAC presente: ${encryptionMeta['mac'] != null}');
        
        // Scarica e decifra
        final decryptedBytes = await _mediaService.downloadAndDecryptFile(
          url: widget.fileUrl,
          senderId: senderId,
          encryptionMetadata: encryptionMeta,
        );
        
        if (decryptedBytes == null) {
          throw Exception('Decifratura fallita');
        }
        
        print('✅ File decifrato: ${decryptedBytes.length} bytes');
        
        // Salva temporaneamente
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/${widget.fileName}';
        localFile = File(tempFilePath);
        await localFile.writeAsBytes(decryptedBytes);
        
        print('✅ File salvato temporaneamente: $tempFilePath');
        
      } else {
        // File non cifrato: scarica normalmente via HTTP
        print('📥 File non cifrato, scarico direttamente...');
        
        final response = await http.get(Uri.parse(widget.fileUrl));
        
        if (response.statusCode != 200) {
          throw Exception('Errore download file: ${response.statusCode}');
        }
        
        print('✅ File scaricato: ${response.bodyBytes.length} bytes');
        
        // Salva temporaneamente
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = '${tempDir.path}/${widget.fileName}';
        localFile = File(tempFilePath);
        await localFile.writeAsBytes(response.bodyBytes);
        
        print('✅ File salvato temporaneamente: $tempFilePath');
      }
      
      // Chiudi dialogo
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Apri con app esterna
      print('📱 Apertura file con app esterna: ${localFile.path}');
      final result = await OpenFile.open(localFile.path);
      
      print('✅ Risultato apertura: ${result.type} - ${result.message}');
      
      if (result.type != ResultType.done) {
        throw Exception('Impossibile aprire il file: ${result.message}');
      }
      
      print('═══════════════════════════════════════════════════════════');
      
    } catch (e, stackTrace) {
      print('❌ Errore apertura file: $e');
      print('❌ Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      
      // Chiudi dialogo se aperto
      if (mounted) {
        Navigator.of(context).pop();
        
        // Mostra errore
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// 🆕 Converte un file Office cifrato in PDF per la preview
  Future<void> _convertEncryptedOfficeToPdf() async {
    if (_isConverting) {
      print('⚠️ Conversione già in corso, salto...');
      return;
    }
    
    print('');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ 🔄 _convertEncryptedOfficeToPdf - Conversione in corso   ║');
    print('╚═══════════════════════════════════════════════════════════╝');
    
    setState(() {
      _isConverting = true;
      _conversionError = null;
    });
    
    try {
      // 🔐 CORREZIONE MITTENTE: Se esiste local_file_name, usalo direttamente
      // Il mittente ha già il file originale in chiaro salvato localmente
      final localFileName = widget.metadata?['local_file_name']?.toString();
      Uint8List decryptedBytes;
      
      // 🔐 CORREZIONE BUG: Inizializza decryptedBytes qui per evitare errore "potentially unassigned"
      decryptedBytes = Uint8List(0);
      
      // Flag per sapere se abbiamo caricato il file locale
      bool fileLoadedFromLocal = false;
      
      if (localFileName != null && localFileName.isNotEmpty) {
        print('🔐 MITTENTE: Trovato local_file_name, carico file locale: $localFileName');
        
        // Carica il file locale
        final appDir = await getApplicationDocumentsDirectory();
        final localFilePath = '${appDir.path}/image_cache/$localFileName';
        final localFile = File(localFilePath);
        
        if (await localFile.exists()) {
          print('✅ File locale trovato: $localFilePath');
          decryptedBytes = await localFile.readAsBytes();
          print('✅ File locale caricato: ${decryptedBytes.length} bytes');
          fileLoadedFromLocal = true;
        } else {
          print('⚠️ File locale non trovato, procedo con decifratura dal server...');
        }
      }
      
      // 🔐 DESTINATARIO o FALLBACK: Decifra il file dal server
      if (!fileLoadedFromLocal) {
        print('🔐 DESTINATARIO: Decifro file dal server...');
        
        // 1️⃣ Verifica metadata di cifratura
        final encryptionMeta = MediaService.getEncryptionMetadata(widget.metadata!);
        if (encryptionMeta == null) {
          throw Exception('Metadata di cifratura non disponibili');
        }
        
        // 🔐 CORREZIONE: Estrai senderId correttamente
        final senderId = widget.metadata?['sender_id']?.toString() ?? 
                        widget.metadata?['senderId']?.toString();
        
        if (senderId == null) {
          print('❌ sender_id non trovato nei metadata');
          throw Exception('sender_id non disponibile nei metadata');
        }
        
        print('🔐 IV presente: ${encryptionMeta['iv'] != null}');
        print('🔐 MAC presente: ${encryptionMeta['mac'] != null}');
        
        // Log IV e MAC (primi 30 caratteri)
        final ivStr = encryptionMeta['iv']?.toString() ?? '';
        final macStr = encryptionMeta['mac']?.toString() ?? '';
        print('🔐 IV value (first 30): ${ivStr.length > 30 ? ivStr.substring(0, 30) + "..." : ivStr}');
        print('🔐 MAC value (first 30): ${macStr.length > 30 ? macStr.substring(0, 30) + "..." : macStr}');
        
        // 2️⃣ Scarica e decifra il file Office
        print('⬇️ Download e decifratura file Office...');
        final downloadedBytes = await _mediaService.downloadAndDecryptFile(
          url: widget.fileUrl,
          senderId: senderId,
          encryptionMetadata: encryptionMeta,
        );
        
        if (downloadedBytes == null) {
          throw Exception('Decifratura fallita');
        }
        
        decryptedBytes = downloadedBytes;
        print('✅ File decifrato: ${decryptedBytes.length} bytes');
      }
      
      // 3️⃣ Verifica se è già un PDF o serve conversione
      final fileNameLower = widget.fileName.toLowerCase();
      final isPdfFile = fileNameLower.endsWith('.pdf') || widget.fileType.contains('pdf');
      
      if (isPdfFile) {
        // È già un PDF: salva direttamente senza conversione
        print('📄 File è già un PDF, salvo direttamente senza conversione...');
        
        final tempDir = await getTemporaryDirectory();
        final fileNameSafe = widget.fileName.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w.-]'), '_');
        final pdfPath = '${tempDir.path}/${fileNameSafe}_decrypted.pdf';
        final pdfFile = File(pdfPath);
        await pdfFile.writeAsBytes(decryptedBytes);
        
        print('✅ PDF decifrato salvato: $pdfPath');
        
        // Aggiorna lo stato con il path del PDF
        if (mounted) {
          setState(() {
            _convertedPdfUrl = 'file://${pdfFile.absolute.path}';
            _isConverting = false;
          });
        }
        
        print('✅ Decifratura PDF completata con successo!');
        print('═══════════════════════════════════════════════════════════');
        return;
      }
      
      // Non è un PDF: invia al backend per conversione PDF
      print('📤 Invio file decifrato al backend per conversione PDF...');
      
      final url = Uri.parse('${ApiConfig.backendUrl}/api/media/convert/office-to-pdf/');
      final request = http.MultipartRequest('POST', url);
      
      // Aggiungi il file decifrato
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        decryptedBytes,
        filename: widget.fileName,
      ));
      
      // Aggiungi il token di autenticazione
      final token = await AuthService().getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      print('📤 Richiesta POST a: $url');
      print('📤 File: ${widget.fileName} (${decryptedBytes.length} bytes)');
      
      final response = await request.send();
      
      print('📥 Risposta ricevuta: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // 4️⃣ Salva il PDF convertito temporaneamente
        final pdfBytes = await response.stream.toBytes();
        print('✅ PDF ricevuto: ${pdfBytes.length} bytes');
        
        final tempDir = await getTemporaryDirectory();
        // 🔐 CORREZIONE: Usa il nome base del file senza spazi per evitare problemi con URI
        final fileNameSafe = widget.fileName.replaceAll(' ', '_').replaceAll(RegExp(r'[^\w.-]'), '_');
        final pdfPath = '${tempDir.path}/${fileNameSafe}_converted.pdf';
        final pdfFile = File(pdfPath);
        await pdfFile.writeAsBytes(pdfBytes);
        
        print('✅ PDF salvato: $pdfPath');
        
        // 5️⃣ Aggiorna lo stato con il path del PDF (usa percorso assoluto con file://)
        if (mounted) {
          setState(() {
            // 🔐 CORREZIONE: Usa file:// URI per percorsi locali per compatibilità
            _convertedPdfUrl = 'file://${pdfFile.absolute.path}';
            _isConverting = false;
          });
        }
        
        print('✅ Conversione completata con successo!');
        print('═══════════════════════════════════════════════════════════');
        
      } else {
        // Errore dal backend
        final responseBody = await response.stream.bytesToString();
        print('❌ Errore conversione: ${response.statusCode}');
        print('❌ Risposta: $responseBody');
        
        final Map<String, dynamic> errorData = json.decode(responseBody);
        final errorMsg = errorData['error'] ?? 'Errore sconosciuto';
        final errorDetails = errorData['details'] ?? '';
        
        throw Exception('$errorMsg: $errorDetails');
      }
      
    } catch (e, stackTrace) {
      print('❌ Errore conversione Office → PDF: $e');
      print('❌ Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      
      if (mounted) {
        setState(() {
          _conversionError = e.toString();
          _isConverting = false;
        });
      }
    }
  }

  /// 🆕 Converte un file Office NON cifrato in PDF per la preview
  Future<void> _convertNonEncryptedOfficeToPdf() async {
    if (_isConverting) {
      print('⚠️ Conversione già in corso, salto...');
      return;
    }
    
    print('');
    print('╔═══════════════════════════════════════════════════════════╗');
    print('║ 🔄 _convertNonEncryptedOfficeToPdf - Conversione in corso║');
    print('╚═══════════════════════════════════════════════════════════╝');
    
    setState(() {
      _isConverting = true;
      _conversionError = null;
    });
    
    try {
      // 1️⃣ Scarica il file Office non cifrato
      print('⬇️ Download file Office non cifrato...');
      final response = await http.get(Uri.parse(widget.fileUrl));
      
      if (response.statusCode != 200) {
        throw Exception('Errore download file: ${response.statusCode}');
      }
      
      final fileBytes = response.bodyBytes;
      print('✅ File scaricato: ${fileBytes.length} bytes');
      
      // 2️⃣ Invia al backend per conversione PDF
      print('📤 Invio file al backend per conversione PDF...');
      
      final url = Uri.parse('${ApiConfig.backendUrl}/api/media/convert/office-to-pdf/');
      final request = http.MultipartRequest('POST', url);
      
      // Aggiungi il file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: widget.fileName,
      ));
      
      // Aggiungi il token di autenticazione
      final token = await AuthService().getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      print('📤 Richiesta POST a: $url');
      print('📤 File: ${widget.fileName} (${fileBytes.length} bytes)');
      
      final responseStream = await request.send();
      
      print('📥 Risposta ricevuta: ${responseStream.statusCode}');
      
      if (responseStream.statusCode == 200) {
        // 3️⃣ Salva il PDF convertito temporaneamente
        final pdfBytes = await responseStream.stream.toBytes();
        print('✅ PDF ricevuto: ${pdfBytes.length} bytes');
        
        final tempDir = await getTemporaryDirectory();
        final pdfPath = '${tempDir.path}/${widget.fileName}_converted.pdf';
        final pdfFile = File(pdfPath);
        await pdfFile.writeAsBytes(pdfBytes);
        
        print('✅ PDF salvato: $pdfPath');
        
        // 4️⃣ Aggiorna lo stato con il path del PDF
        if (mounted) {
          setState(() {
            _convertedPdfUrl = 'file://${pdfFile.absolute.path}';
            _isConverting = false;
          });
        }
        
        print('✅ Conversione completata con successo!');
        print('═══════════════════════════════════════════════════════════');
        
      } else {
        // Errore dal backend
        final responseBody = await responseStream.stream.bytesToString();
        print('❌ Errore conversione: ${responseStream.statusCode}');
        print('❌ Risposta: $responseBody');
        
        final Map<String, dynamic> errorData = json.decode(responseBody);
        final errorMsg = errorData['error'] ?? 'Errore sconosciuto';
        final errorDetails = errorData['details'] ?? '';
        
        throw Exception('$errorMsg: $errorDetails');
      }
      
    } catch (e, stackTrace) {
      print('❌ Errore conversione Office → PDF (non cifrato): $e');
      print('❌ Stack trace: $stackTrace');
      print('═══════════════════════════════════════════════════════════');
      
      if (mounted) {
        setState(() {
          _conversionError = e.toString();
          _isConverting = false;
        });
      }
    }
  }

  /// Tenta di visualizzare il file Office direttamente con conversione PDF
  Future<void> _tryDirectFileView() async {
    print('🔍 FileViewer - Tentativo visualizzazione diretta file: ${widget.fileName}');
    print('🔍 FileViewer - URL originale: ${widget.fileUrl}');
    
    // Verifica se il file è cifrato
    final isEncrypted = MediaService.isAttachmentEncrypted(widget.metadata);
    
    if (isEncrypted) {
      print('🔐 File cifrato rilevato, avvio conversione PDF per preview...');
      
      // Mostra messaggio informativo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏳ Preparazione anteprima PDF...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
      
      // Avvia la conversione Office → PDF
      await _convertEncryptedOfficeToPdf();
      
    } else {
      print('ℹ️ File non cifrato, apertura con app esterna...');
      
      // Per file non cifrati, apri con app esterna
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Apertura di ${widget.fileName}...'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
      
      // Chiama _shareFile per aprire con app esterna
      await _shareFile();
    }
  }

  /// Helper per documenti Office
  Color _getOfficeColor() {
    if (widget.fileType.contains('word') || widget.fileType.contains('document') ||
        widget.fileName.toLowerCase().endsWith('.docx') || widget.fileName.toLowerCase().endsWith('.doc')) {
      return Colors.blue[600]!;
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet') ||
               widget.fileName.toLowerCase().endsWith('.xlsx') || widget.fileName.toLowerCase().endsWith('.xls')) {
      return Colors.green[600]!;
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation') ||
               widget.fileName.toLowerCase().endsWith('.pptx') || widget.fileName.toLowerCase().endsWith('.ppt')) {
      return Colors.orange[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }
  
  /// Restituisce il nome dell'app suggerita per aprire il file
  String _getOpenWithAppName() {
    final fileNameLower = widget.fileName.toLowerCase();
    
    if (widget.fileType.contains('word') || widget.fileType.contains('document') ||
        fileNameLower.endsWith('.docx') || fileNameLower.endsWith('.doc')) {
      return 'Apri con Word/Pages';
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet') ||
               fileNameLower.endsWith('.xlsx') || fileNameLower.endsWith('.xls')) {
      return 'Apri con Excel/Numbers';
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation') ||
               fileNameLower.endsWith('.pptx') || fileNameLower.endsWith('.ppt')) {
      return 'Apri con PowerPoint/Keynote';
    } else {
      return 'Apri con app esterna';
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
    final fileNameLower = widget.fileName.toLowerCase();
    
    // Nascondi il nome per PDF
    if (widget.fileType.contains('pdf') || fileNameLower.endsWith('.pdf')) {
      return false;
    }
    
    // Nascondi il nome per documenti Office
    if (widget.fileType.contains('word') || widget.fileType.contains('document') ||
        widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet') ||
        widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation') ||
        widget.fileType.contains('xlsx') || widget.fileType.contains('docx') || 
        widget.fileType.contains('pptx') || widget.fileType == 'xlsx' || 
        widget.fileType == 'docx' || widget.fileType == 'pptx' ||
        fileNameLower.endsWith('.docx') ||
        fileNameLower.endsWith('.xlsx') ||
        fileNameLower.endsWith('.pptx') ||
        fileNameLower.endsWith('.doc') ||
        fileNameLower.endsWith('.xls') ||
        fileNameLower.endsWith('.ppt')) {
      return false;
    }
    
    // Mostra il nome per altri tipi di file (immagini, video, ecc.)
    return true;
  }
}
