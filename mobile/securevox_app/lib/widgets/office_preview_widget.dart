import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Widget per preview Office files (DOCX, XLSX, PPTX) usando WebView
class OfficePreviewWidget extends StatefulWidget {
  final String pdfUrl; // URL del PDF generato dal backend
  final double? width;
  final double? height;
  final bool isFullscreen;
  final String fileName;

  const OfficePreviewWidget({
    Key? key,
    required this.pdfUrl,
    this.width,
    this.height,
    this.isFullscreen = false,
    required this.fileName,
  }) : super(key: key);

  @override
  State<OfficePreviewWidget> createState() => _OfficePreviewWidgetState();
}

class _OfficePreviewWidgetState extends State<OfficePreviewWidget> {
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  WebViewController? _webController;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('🏢 OfficePreviewWidget - Caricamento iniziato: $url');
          },
          onPageFinished: (url) {
            print('🏢 OfficePreviewWidget - Caricamento completato: $url');
          },
          onWebResourceError: (error) {
            print('❌ OfficePreviewWidget - Errore WebView: $error');
            setState(() {
              _error = error.description;
            });
          },
        ),
      );
    _downloadAndCachePdf();
  }

  /// Scarica e salva il PDF generato dal backend localmente per la visualizzazione
  Future<void> _downloadAndCachePdf() async {
    try {
      print('🏢 OfficePreviewWidget - Inizio download PDF convertito: ${widget.pdfUrl}');
      print('🏢 OfficePreviewWidget - Nome file originale: ${widget.fileName}');
      
      // Verifica URL valido
      if (widget.pdfUrl.isEmpty) {
        throw Exception('URL PDF vuoto');
      }
      
      // Scarica il PDF convertito dal backend
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Errore download PDF: ${response.statusCode}');
      }
      
      // Salva il PDF localmente
      final tempDir = await getTemporaryDirectory();
      _localPath = '${tempDir.path}/office_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(_localPath!);
      await file.writeAsBytes(response.bodyBytes);
      
      print('🏢 OfficePreviewWidget - PDF convertito salvato: $_localPath');
      
      // Carica il PDF nel WebView
      await _webController!.loadRequest(Uri.file(_localPath!));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ OfficePreviewWidget - Errore: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              SizedBox(height: 8),
              Text(
                'Errore caricamento documento',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              Text(
                _error!,
                style: TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Caricamento documento...'),
            ],
          ),
        ),
      );
    }

    if (_localPath == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('Documento non disponibile'),
        ),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: WebViewWidget(
          controller: _webController!,
        ),
      ),
    );
  }
}