import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

/// Widget semplificato per preview documenti Office usando Google Docs Viewer
class OfficePreviewSimple extends StatefulWidget {
  final String fileUrl;
  final String fileType;
  final double? width;
  final double? height;
  final bool isFullscreen;
  final String fileName;

  const OfficePreviewSimple({
    Key? key,
    required this.fileUrl,
    required this.fileType,
    this.width,
    this.height,
    this.isFullscreen = false,
    required this.fileName,
  }) : super(key: key);

  @override
  State<OfficePreviewSimple> createState() => _OfficePreviewSimpleState();
}

class _OfficePreviewSimpleState extends State<OfficePreviewSimple> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      print('📄 OfficePreviewSimple - Inizializzazione per: ${widget.fileName}');
      
      // Usa Google Docs Viewer per tutti i documenti Office
      final encodedUrl = Uri.encodeComponent(widget.fileUrl);
      final viewerUrl = 'https://docs.google.com/viewer?url=$encodedUrl&embedded=true';
      
      print('📄 OfficePreviewSimple - URL viewer: $viewerUrl');
      
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              print('📄 OfficePreviewSimple - Caricamento iniziato: ${widget.fileName}');
            },
            onPageFinished: (String url) {
              print('📄 OfficePreviewSimple - Caricamento completato: ${widget.fileName}');
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              print('❌ OfficePreviewSimple - Errore caricamento: ${error.description}');
              setState(() {
                _error = error.description;
                _isLoading = false;
              });
            },
          ),
        )
        ..loadRequest(Uri.parse(viewerUrl));
        
    } catch (e) {
      print('❌ OfficePreviewSimple - Errore inizializzazione: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_getFileColor()),
              ),
              const SizedBox(height: 8),
              Text(
                'Caricamento ${_getFileTypeName()}...',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _buildFallbackPreview();
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }

  /// Preview di fallback quando Google Docs Viewer non funziona
  Widget _buildFallbackPreview() {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: _getFileColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getFileColor().withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icona del tipo file
          Icon(
            _getFileIcon(),
            size: widget.isFullscreen ? 64 : 32,
            color: _getFileColor(),
          ),
          const SizedBox(height: 8),
          
          // Nome file
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.fileName,
              style: TextStyle(
                fontSize: widget.isFullscreen ? 16 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
              maxLines: widget.isFullscreen ? 3 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Tipo file
          Text(
            _getFileTypeName().toUpperCase(),
            style: TextStyle(
              fontSize: widget.isFullscreen ? 14 : 10,
              fontWeight: FontWeight.w500,
              color: _getFileColor(),
              letterSpacing: 1.2,
            ),
          ),
          
          if (widget.isFullscreen) ...[
            const SizedBox(height: 16),
            Text(
              'Preview non disponibile',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _downloadAndOpen,
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Scarica e Apri'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getFileColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            Text(
              'Tocca per aprire',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Scarica e apre il file con app esterna
  Future<void> _downloadAndOpen() async {
    try {
      final uri = Uri.parse(widget.fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Impossibile aprire ${widget.fileName}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ OfficePreviewSimple - Errore apertura file: $e');
    }
  }

  /// Ottieni colore per tipo file
  Color _getFileColor() {
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

  /// Ottieni icona per tipo file
  IconData _getFileIcon() {
    if (widget.fileType.contains('word') || widget.fileType.contains('document')) {
      return Icons.description; // Word
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet')) {
      return Icons.table_chart; // Excel
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation')) {
      return Icons.slideshow; // PowerPoint
    } else {
      return Icons.insert_drive_file;
    }
  }

  /// Ottieni nome tipo file
  String _getFileTypeName() {
    if (widget.fileType.contains('word') || widget.fileType.contains('document')) {
      return 'Word';
    } else if (widget.fileType.contains('excel') || widget.fileType.contains('spreadsheet')) {
      return 'Excel';
    } else if (widget.fileType.contains('powerpoint') || widget.fileType.contains('presentation')) {
      return 'PowerPoint';
    } else {
      return 'Documento';
    }
  }
}
