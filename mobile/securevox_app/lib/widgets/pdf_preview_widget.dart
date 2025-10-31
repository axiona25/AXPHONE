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
      print('');
      print('📄📄📄 ===== PdfPreviewWidget._loadPdf =====');
      print('📄 pdfUrl ricevuto: ${widget.pdfUrl}');
      print('📄 pdfUrl type: ${widget.pdfUrl.runtimeType}');
      print('📄 pdfUrl length: ${widget.pdfUrl.length}');
      print('📄 Nome file: ${widget.fileName}');
      
      // Verifica URL valido
      if (widget.pdfUrl.isEmpty) {
        throw Exception('URL PDF vuoto');
      }
      
      // 🔐 CORREZIONE: Verifica se è un percorso locale o un URL remoto
      final hasFileProtocol = widget.pdfUrl.startsWith('file://');
      final hasAbsolutePath = widget.pdfUrl.startsWith('/');
      final hasHttp = widget.pdfUrl.startsWith('http://') || widget.pdfUrl.startsWith('https://');
      
      print('📄 Analisi percorso:');
      print('   • hasFileProtocol: $hasFileProtocol');
      print('   • hasAbsolutePath: $hasAbsolutePath');
      print('   • hasHttp: $hasHttp');
      
      final isLocalPath = hasFileProtocol || hasAbsolutePath || !hasHttp;
      print('📄 isLocalPath risultato: $isLocalPath');
      
      if (isLocalPath) {
        // È un percorso locale: usa direttamente
        print('📄 ✅ PERCORSO LOCALE RILEVATO');
        
        String localPath = widget.pdfUrl;
        print('📄 Percorso originale: $localPath');
        
        // Rimuovi prefisso file:// se presente
        if (localPath.startsWith('file://')) {
          localPath = localPath.substring(7);
          print('📄 Rimosso prefisso file://: $localPath');
        }
        
        // 🔐 CORREZIONE: Decodifica caratteri URL-encoded (es: %20 -> spazio)
        // Decodifica iterativamente per gestire percorsi parzialmente codificati
        String previousPath = localPath;
        int decodeIterations = 0;
        while (localPath.contains('%') && decodeIterations < 10) {
          previousPath = localPath;
          try {
            localPath = Uri.decodeComponent(localPath);
            decodeIterations++;
            if (localPath == previousPath) break; // Nessun cambio, esci dal loop
          } catch (e) {
            print('⚠️ PdfPreviewWidget - Errore decodifica URL iterazione $decodeIterations: $e');
            break;
          }
        }
        
        print('📄 Decodifica completata in $decodeIterations iterazioni');
        print('📄 Percorso decodificato finale: $localPath');
        
        // 🔐 CORREZIONE: Usa Uri.file() per creare un File dal percorso
        final uri = Uri.file(localPath);
        _localFile = File(uri.path);
        
        print('📄 File path costruito: ${_localFile?.path}');
        print('📄 Verifica esistenza file...');
        
        final file = _localFile;
        if (file == null || !await file.exists()) {
          print('❌ File NON trovato: ${file?.path}');
          throw Exception('File locale non trovato: ${file?.path}');
        }
        
        print('✅ File locale trovato: ${_localFile!.path}');
        print('📄 File size: ${await _localFile!.length()} bytes');
      } else {
        // È un URL remoto: scarica prima
        print('📄 ✅ URL REMOTO RILEVATO');
        print('📄 Download in corso...');
        
        // Scarica il PDF
        final response = await http.get(Uri.parse(widget.pdfUrl));
        if (response.statusCode != 200) {
          throw Exception('Errore download PDF: ${response.statusCode}');
        }
        
        // Salva localmente
        final tempDir = await getTemporaryDirectory();
        _localFile = File('${tempDir.path}/pdf_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await _localFile!.writeAsBytes(response.bodyBytes);
        
        print('✅ PDF scaricato e salvato: ${_localFile!.path}');
      }
      
      // Carica il PDF nel WebView usando Uri.file() per percorsi locali
      print('📄 Caricamento PDF nel WebView...');
      print('📄 File path per WebView: ${_localFile!.path}');
      await _webController!.loadRequest(Uri.file(_localFile!.path));
      
      print('✅ PDF caricato nel WebView con successo');
      print('📄📄📄 =================================');
      print('');
      
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ===== PdfPreviewWidget._loadPdf ERROR =====');
      print('❌ Errore: $e');
      print('❌ Stack trace: $stackTrace');
      print('❌ pdfUrl che ha causato l\'errore: ${widget.pdfUrl}');
      print('❌❌❌ ===========================================');
      print('');
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