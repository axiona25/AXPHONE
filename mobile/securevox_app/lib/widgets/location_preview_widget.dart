import 'package:flutter/material.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

/// Widget per mostrare la preview di una posizione geografica
class LocationPreviewWidget extends StatelessWidget {
  final LocationData location;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final bool showDetails;

  const LocationPreviewWidget({
    super.key,
    required this.location,
    this.onTap,
    this.width,
    this.height,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => LocationService.openLocationInMaps(location),
      child: Container(
        width: width ?? 280,
        height: height ?? 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Mappa statica di background
              _buildMapImage(),
              
              // Overlay con icona posizione e dettagli
              _buildOverlay(context),
              
              // Indicatore di tap
              _buildTapIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  /// Costruisce il placeholder della mappa (versione semplificata)
  Widget _buildMapImage() {
    print('🗺️ LocationPreviewWidget - Creando placeholder per coordinate: ${location.latitude}, ${location.longitude}');
    
    // Placeholder semplice e carino - al click si apre il navigatore
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0D7C66).withOpacity(0.1),
              const Color(0xFF0D7C66).withOpacity(0.2),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Pattern di griglia per simulare mappa
            CustomPaint(
              size: Size.infinite,
              painter: _MapGridPainter(),
            ),
            // Contenuto centrale
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icona mappa grande
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.map,
                      size: 48,
                      color: const Color(0xFF0D7C66),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Pin rosso sovrapposto
                  Icon(
                    Icons.location_on,
                    size: 32,
                    color: Colors.red.shade600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Costruisce l'overlay con dettagli
  Widget _buildOverlay(BuildContext context) {
    if (!showDetails) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Posizione condivisa',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            if (location.accuracy > 0) ...[
              const SizedBox(height: 2),
              Text(
                'Precisione: ${location.accuracy.toStringAsFixed(0)}m',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Costruisce l'indicatore di tap
  Widget _buildTapIndicator() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.navigation,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            const Text(
              'Naviga',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget compatto per la preview della posizione nei messaggi
class CompactLocationPreview extends StatelessWidget {
  final LocationData location;
  final VoidCallback? onTap;

  const CompactLocationPreview({
    super.key,
    required this.location,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => LocationService.openLocationInMaps(location),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppTheme.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_on,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Posizione condivisa',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: AppTheme.primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter per disegnare una griglia che simula una mappa
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Linee verticali
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Linee orizzontali
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
