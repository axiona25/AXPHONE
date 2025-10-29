import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget per visualizzare immagini con zoom nella chat
class ImageViewerWidget extends StatefulWidget {
  final String imageUrl;
  final String caption;
  final bool isMe;

  const ImageViewerWidget({
    Key? key,
    required this.imageUrl,
    required this.caption,
    required this.isMe,
  }) : super(key: key);

  @override
  State<ImageViewerWidget> createState() => _ImageViewerWidgetState();
}

class _ImageViewerWidgetState extends State<ImageViewerWidget> {
  final TransformationController _transformationController = TransformationController();
  bool _isZoomed = false;
  bool _isRetrying = false;

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
    setState(() {
      _isZoomed = false;
    });
  }

  void _toggleZoom() {
    if (_isZoomed) {
      _resetZoom();
    } else {
      _transformationController.value = Matrix4.identity()..scale(2.0);
      setState(() {
        _isZoomed = true;
      });
    }
  }

  void _retryImage() {
    setState(() {
      _isRetrying = true;
    });
    
    // Simula un retry dopo un breve delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isRetrying = false;
        });
      }
    });
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Immagine',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  _transformationController.value = Matrix4.identity();
                },
                icon: const Icon(
                  Icons.zoom_out,
                  color: Colors.white,
                ),
                tooltip: 'Reset zoom',
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              onInteractionStart: (details) {
                setState(() {
                  _isZoomed = true;
                });
              },
              child: CachedNetworkImage(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 48,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Errore caricamento immagine',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('🖼️ ImageViewerWidget - URL immagine: ${widget.imageUrl}');
    print('🖼️ ImageViewerWidget - Caption: ${widget.caption}');
    print('🖼️ ImageViewerWidget - IsMe: ${widget.isMe}');
    
    // CORREZIONE: Verifica se l'URL è valido
    if (widget.imageUrl.isEmpty) {
      print('❌ ImageViewerWidget - URL vuoto!');
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 48,
                color: Colors.red,
              ),
              SizedBox(height: 8),
              Text(
                'URL immagine non disponibile',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe 
              ? Theme.of(context).primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // Overlay con controlli
            Stack(
              children: [
                // Immagine con zoom
                GestureDetector(
                  onTap: _openFullScreen,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    onInteractionStart: (details) {
                      setState(() {
                        _isZoomed = true;
                      });
                    },
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 200,
                      placeholder: (context, url) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 200,
                        color: Colors.grey[200],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Errore caricamento immagine',
                                style: TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'URL: ${url.length > 50 ? '${url.substring(0, 50)}...' : url}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Errore: ${error.toString().length > 30 ? error.toString().substring(0, 30) + '...' : error.toString()}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: _isRetrying ? null : _retryImage,
                                icon: _isRetrying 
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.refresh, size: 16),
                                label: Text(_isRetrying ? 'Riprova...' : 'Riprova'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Controlli overlay
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: _openFullScreen,
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (_isZoomed)
                          IconButton(
                            onPressed: _resetZoom,
                            icon: const Icon(
                              Icons.zoom_out,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            // Caption se presente
            if (widget.caption.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.isMe 
                      ? Theme.of(context).primaryColor.withOpacity(0.05)
                      : Colors.grey[50],
                ),
                child: Text(
                  widget.caption,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isMe 
                        ? Theme.of(context).primaryColor
                        : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
