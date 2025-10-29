import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Widget per preview PDF in miniatura e fullscreen
class PdfPreviewWidget extends StatefulWidget {
  final String pdfUrl;
  final String fileName;
  final bool isFullScreen;

  const PdfPreviewWidget({
    Key? key,
    required this.pdfUrl,
    required this.fileName,
    this.isFullScreen = false,
  }) : super(key: key);

  @override
  State<PdfPreviewWidget> createState() => _PdfPreviewWidgetState();
}

class _PdfPreviewWidgetState extends State<PdfPreviewWidget> {
  WebViewController? _webController;
  bool _isLoading = true;
  String? _error;
  File? _localFile;

  @override
  void initState() {
    super.initState();
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('📄 PdfPreviewWidget - Caricamento iniziato: $url');
          },
          onPageFinished: (url) {
            print('📄 PdfPreviewWidget - Caricamento completato: $url');
          },
          onWebResourceError: (error) {
            print('❌ PdfPreviewWidget - Errore WebView: $error');
            setState(() {
              _error = error.description;
            });
          },
        ),
      );
    _loadPdf();
  }

  /// Scarica e salva il PDF localmente per la visualizzazione
  Future<void> _loadPdf() async {
    try {
      print('📄 PdfPreviewWidget - Inizio download PDF: ${widget.pdfUrl}');
      print('📄 PdfPreviewWidget - Nome file: ${widget.fileName}');
      
      // Verifica URL valido
      if (widget.pdfUrl.isEmpty) {
        throw Exception('URL PDF vuoto');
      }
      
      // Scarica il PDF
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode != 200) {
        throw Exception('Errore download PDF: ${response.statusCode}');
      }
      
      // Salva localmente
      final tempDir = await getTemporaryDirectory();
      _localFile = File('${tempDir.path}/pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await _localFile!.writeAsBytes(response.bodyBytes);
      
      print('📄 PdfPreviewWidget - PDF salvato: ${_localFile!.path}');
      
      // Carica il PDF nel WebView
      await _webController!.loadRequest(Uri.file(_localFile!.path));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ PdfPreviewWidget - Errore: $e');
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
        height: widget.isFullScreen ? null : 200,
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
                'Errore caricamento PDF',
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
        height: widget.isFullScreen ? null : 200,
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
              Text('Caricamento PDF...'),
            ],
          ),
        ),
      );
    }

    if (_localFile == null) {
      return Container(
        height: widget.isFullScreen ? null : 200,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text('PDF non disponibile'),
        ),
      );
    }

    return Container(
      height: widget.isFullScreen ? null : 200,
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