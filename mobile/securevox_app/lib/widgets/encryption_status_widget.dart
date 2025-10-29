import 'package:flutter/material.dart';

/// Widget per mostrare lo stato di crittografia della chat
/// Con elegante animazione di luccichio dorato
class EncryptionStatusWidget extends StatefulWidget {
  final bool isEncrypted;
  final String encryptionType;
  final String tooltipText;
  final double size;
  final Color? iconColor;

  const EncryptionStatusWidget({
    super.key,
    this.isEncrypted = true,
    this.encryptionType = 'Chat Cifrata',
    this.tooltipText = 'Crittografia AES256 attiva\nChat sicura e protetta',
    this.size = 16.0,
    this.iconColor,
  });

  @override
  State<EncryptionStatusWidget> createState() => _EncryptionStatusWidgetState();
}

class _EncryptionStatusWidgetState extends State<EncryptionStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _reflectionController;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _reflectionAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controller per l'animazione di luccichio principale
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Controller per il riflesso
    _reflectionController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Animazione di luccichio (gradiente che si muove)
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Animazione del riflesso (opacità)
    _reflectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _reflectionController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
    ));

    // Avvia le animazioni con pause tra i cicli
    _startAnimationCycle();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _startReflectionCycle();
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  /// Avvia il ciclo di animazione shimmer con pause
  void _startAnimationCycle() async {
    if (!mounted) return;
    
    // Esegui l'animazione
    await _shimmerController.forward();
    await _shimmerController.reverse();
    
    // Pausa di 3 secondi
    if (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      _startAnimationCycle(); // Ricomincia il ciclo
    }
  }

  /// Avvia il ciclo di animazione riflesso con pause
  void _startReflectionCycle() async {
    if (!mounted) return;
    
    // Esegui l'animazione
    await _reflectionController.forward();
    await _reflectionController.reverse();
    
    // Pausa di 3 secondi
    if (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      _startReflectionCycle(); // Ricomincia il ciclo
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEncrypted) {
      return const SizedBox.shrink();
    }

    final baseColor = widget.iconColor ?? Colors.white;

    return Tooltip(
      message: widget.tooltipText,
      preferBelow: false,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: 'Poppins',
        height: 1.4,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_shimmerAnimation, _reflectionAnimation]),
        builder: (context, child) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icona lucchetto con effetto luccichio e riflesso
              Stack(
                children: [
                  // Icona principale con gradiente animato
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _getShimmerColor(baseColor, _shimmerAnimation.value - 0.3),
                          _getShimmerColor(baseColor, _shimmerAnimation.value),
                          _getShimmerColor(baseColor, _shimmerAnimation.value + 0.3),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    },
                    child: Icon(
                      Icons.lock,
                      size: widget.size,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Riflesso in basso a sinistra
                  Positioned(
                    left: widget.size * 0.1,
                    bottom: widget.size * 0.1,
                    child: Opacity(
                      opacity: _reflectionAnimation.value * 0.6,
                      child: Container(
                        width: widget.size * 0.3,
                        height: widget.size * 0.15,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.8),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(widget.size * 0.1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(width: 4),
              
              // Testo AES256 con effetto luccichio
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getShimmerColor(baseColor, _shimmerAnimation.value - 0.2),
                      _getShimmerColor(baseColor, _shimmerAnimation.value + 0.1),
                      _getShimmerColor(baseColor, _shimmerAnimation.value + 0.4),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: Text(
                  widget.encryptionType,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: widget.size - 2,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Calcola il colore del luccichio basato sulla posizione dell'animazione
  Color _getShimmerColor(Color baseColor, double position) {
    // Normalizza la posizione tra 0 e 1
    final normalizedPosition = ((position + 1.0) / 3.0).clamp(0.0, 1.0);
    
    // Crea un'onda sinusoidale per l'effetto luccichio
    final shimmerIntensity = (1.0 + (normalizedPosition * 2.0 - 1.0).abs()) / 2.0;
    
    // Colori oro per il luccichio
    const goldColor = Color(0xFFFFD700); // Oro
    const lightGoldColor = Color(0xFFFFF8DC); // Oro chiaro
    
    if (shimmerIntensity > 0.7) {
      // Fase oro intenso
      return Color.lerp(goldColor, lightGoldColor, (shimmerIntensity - 0.7) / 0.3) ?? baseColor;
    } else if (shimmerIntensity > 0.4) {
      // Fase transizione oro
      return Color.lerp(baseColor, goldColor, (shimmerIntensity - 0.4) / 0.3) ?? baseColor;
    } else {
      // Fase colore base
      return baseColor;
    }
  }
}

/// Widget semplificato per solo l'icona con animazione di luccichio dorato
class EncryptionIconWidget extends StatefulWidget {
  final bool isEncrypted;
  final double size;
  final Color? iconColor;

  const EncryptionIconWidget({
    super.key,
    this.isEncrypted = true,
    this.size = 16.0,
    this.iconColor,
  });

  @override
  State<EncryptionIconWidget> createState() => _EncryptionIconWidgetState();
}

class _EncryptionIconWidgetState extends State<EncryptionIconWidget>
    with TickerProviderStateMixin {
  late AnimationController _shimmerController;
  late AnimationController _reflectionController;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _reflectionAnimation;

  @override
  void initState() {
    super.initState();
    
    // Controller per l'animazione di luccichio
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    // Controller per il riflesso
    _reflectionController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Animazione di luccichio
    _shimmerAnimation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Animazione del riflesso
    _reflectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _reflectionController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
    ));

    // Avvia le animazioni con pause tra i cicli
    _startAnimationCycle();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _startReflectionCycle();
      }
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  /// Avvia il ciclo di animazione shimmer con pause
  void _startAnimationCycle() async {
    if (!mounted) return;
    
    // Esegui l'animazione
    await _shimmerController.forward();
    await _shimmerController.reverse();
    
    // Pausa di 3 secondi
    if (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      _startAnimationCycle(); // Ricomincia il ciclo
    }
  }

  /// Avvia il ciclo di animazione riflesso con pause
  void _startReflectionCycle() async {
    if (!mounted) return;
    
    // Esegui l'animazione
    await _reflectionController.forward();
    await _reflectionController.reverse();
    
    // Pausa di 3 secondi
    if (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      _startReflectionCycle(); // Ricomincia il ciclo
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEncrypted) {
      return const SizedBox.shrink();
    }

    final baseColor = widget.iconColor ?? Colors.white;

    return Tooltip(
      message: 'Crittografia AES256 attiva\nChat sicura e protetta',
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: 'Poppins',
        height: 1.4,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_shimmerAnimation, _reflectionAnimation]),
        builder: (context, child) {
          return Stack(
            children: [
              // Icona principale con gradiente animato
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getShimmerColor(baseColor, _shimmerAnimation.value - 0.3),
                      _getShimmerColor(baseColor, _shimmerAnimation.value),
                      _getShimmerColor(baseColor, _shimmerAnimation.value + 0.3),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: Icon(
                  Icons.lock,
                  size: widget.size,
                  color: Colors.white,
                ),
              ),
              
              // Riflesso in basso a sinistra
              Positioned(
                left: widget.size * 0.1,
                bottom: widget.size * 0.1,
                child: Opacity(
                  opacity: _reflectionAnimation.value * 0.6,
                  child: Container(
                    width: widget.size * 0.3,
                    height: widget.size * 0.15,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.8),
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.size * 0.1),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Calcola il colore del luccichio basato sulla posizione dell'animazione
  Color _getShimmerColor(Color baseColor, double position) {
    // Normalizza la posizione tra 0 e 1
    final normalizedPosition = ((position + 1.0) / 3.0).clamp(0.0, 1.0);
    
    // Crea un'onda sinusoidale per l'effetto luccichio
    final shimmerIntensity = (1.0 + (normalizedPosition * 2.0 - 1.0).abs()) / 2.0;
    
    // Colori oro per il luccichio
    const goldColor = Color(0xFFFFD700); // Oro
    const lightGoldColor = Color(0xFFFFF8DC); // Oro chiaro
    
    if (shimmerIntensity > 0.7) {
      // Fase oro intenso
      return Color.lerp(goldColor, lightGoldColor, (shimmerIntensity - 0.7) / 0.3) ?? baseColor;
    } else if (shimmerIntensity > 0.4) {
      // Fase transizione oro
      return Color.lerp(baseColor, goldColor, (shimmerIntensity - 0.4) / 0.3) ?? baseColor;
    } else {
      // Fase colore base
      return baseColor;
    }
  }
}
