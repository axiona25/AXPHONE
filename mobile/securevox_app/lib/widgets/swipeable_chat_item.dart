import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_model.dart';
import '../theme/app_theme.dart';
import 'chat_item.dart';

class SwipeableChatItem extends StatefulWidget {
  final ChatModel chat;
  final VoidCallback? onTap;
  final VoidCallback? onMoreAction;
  final VoidCallback? onSwipeStateChanged;
  final bool isSwiped;

  const SwipeableChatItem({
    super.key,
    required this.chat,
    this.onTap,
    this.onMoreAction,
    this.onSwipeStateChanged,
    this.isSwiped = false,
  });

  @override
  State<SwipeableChatItem> createState() => _SwipeableChatItemState();
}

class _SwipeableChatItemState extends State<SwipeableChatItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Sincronizza lo stato iniziale
    if (widget.isSwiped ?? false) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(SwipeableChatItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sincronizza lo stato quando cambia la prop
    final currentIsSwiped = widget.isSwiped ?? false;
    final oldIsSwiped = oldWidget.isSwiped ?? false;
    
    if (currentIsSwiped != oldIsSwiped) {
      if (currentIsSwiped) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleSwipeLeft() {
    if (!(widget.isSwiped ?? false)) {
      // Notifica che il menu deve essere aperto
      if (widget.onSwipeStateChanged != null) {
        widget.onSwipeStateChanged!();
      }
    }
  }

  void _handleSwipeRight() {
    if (widget.isSwiped ?? false) {
      // Notifica che il menu deve essere chiuso
      if (widget.onSwipeStateChanged != null) {
        widget.onSwipeStateChanged!();
      }
    }
  }

  void _handleMoreAction() {
    // Chiudi il menu swipe
    _handleSwipeRight();
    
    // Chiama il callback se fornito
    if (widget.onMoreAction != null) {
      widget.onMoreAction!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        // Reset del pan quando inizia un nuovo gesto
      },
      onPanUpdate: (details) {
        // Swipe verso sinistra per aprire (soglia più alta per evitare attivazioni accidentali)
        if (details.delta.dx < -20 && !(widget.isSwiped ?? false)) {
          _handleSwipeLeft();
        }
        // Swipe verso destra per chiudere
        else if (details.delta.dx > 20 && (widget.isSwiped ?? false)) {
          _handleSwipeRight();
        }
      },
      onTap: () {
        // Se il menu è aperto, chiudilo
        if (widget.isSwiped ?? false) {
          _handleSwipeRight();
        }
        // Altrimenti, esegui l'azione normale
        else if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: Container(
        height: 80, // Altezza fissa per evitare layout issues
        child: Stack(
          clipBehavior: Clip.none, // Permette overflow controllato
          children: [
            // Azioni di swipe (sotto) - sempre presenti ma nascoste
            _buildSwipeActions(),
            // Chat item principale (sopra) - si sposta insieme
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(-80 * _animation.value, 0),
                  child: ChatItem(
                    chat: widget.chat,
                    onTap: () {
                      // Se il menu è aperto, chiudilo invece di navigare
                      if (widget.isSwiped ?? false) {
                        _handleSwipeRight();
                      } else if (widget.onTap != null) {
                        widget.onTap!();
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeActions() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value,
            child: GestureDetector(
              onTap: _handleMoreAction,
              child: Container(
                width: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.9),
                      AppTheme.primaryColor,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icona "Altro"
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_horiz,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Testo "Altro"
                    const Text(
                      'Altro',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
