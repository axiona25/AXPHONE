import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_model.dart';
import '../theme/app_theme.dart';
import '../services/date_formatter_service.dart';
import '../services/message_service.dart';
import '../screens/chat_detail_screen.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../services/real_chat_service.dart';
import '../services/user_status_service.dart';
import 'group_avatar_widget.dart';

class ChatItem extends StatefulWidget {
  final ChatModel chat;
  final VoidCallback? onTap;

  const ChatItem({
    super.key,
    required this.chat,
    this.onTap,
  });

  @override
  State<ChatItem> createState() => _ChatItemState();
}

class _ChatItemState extends State<ChatItem> 
    with SingleTickerProviderStateMixin {
  
  // CACHE STATICA per le icone timer - persiste tra navigazioni
  static final Map<String, bool> _gestationCache = {};
  
  // Metodo per aggiornare la cache quando una chat va in gestazione
  static void updateGestationCache(String chatId, bool isInGestation) {
    _gestationCache[chatId] = isInGestation;
    print('📝 Cache timer forzato per $chatId: $isInGestation');
  }
  
  // Metodo per pulire la cache (se necessario)
  static void clearGestationCache() {
    _gestationCache.clear();
    print('🧹 Cache timer pulita');
  }
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Registra il callback per aggiornare la cache timer
    RealChatService.setTimerCacheCallback(updateGestationCache);
    
    // Animazione di pulsazione solo per chat in gestazione
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Avvia animazione se chat in gestazione
    if (widget.chat.isInGestation) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MessageService>(
      builder: (context, messageService, child) {
        return InkWell(
          onTap: () {
            // 🔧 FIX: NON marcare come letto qui - verrà fatto quando ChatDetail si carica
            // messageService.markChatAsRead(widget.chat.id); // ❌ RIMOSSO
            
            // Debug: stampa la navigazione
            print('Navigating to: /chat-detail/${widget.chat.id}');
            
            // Naviga alla schermata di dettaglio chat usando GoRouter
            context.go('/chat-detail/${widget.chat.id}');
          },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar con indicatore online/offline
            _buildAvatar(),
            const SizedBox(width: 12),
            
            // Contenuto chat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome e timestamp
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.chat.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Flexible(
                        child: Text(
                          DateFormatterService.formatChatTimestamp(widget.chat.timestamp),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Ultimo messaggio e badge non letti
                  Row(
                    children: [
                      Expanded(
                        child: Consumer<MessageService>(
                          builder: (context, messageService, child) {
                            // Ottieni il conteggio dei messaggi non letti dal MessageService
                            final unreadCount = messageService.getUnreadCount(widget.chat.id);
                            final hasUnreadMessages = unreadCount > 0;
                            
                            return Text(
                              widget.chat.lastMessage.isEmpty ? 'Nessun messaggio' : widget.chat.lastMessage,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: hasUnreadMessages ? FontWeight.w600 : FontWeight.w400,
                                color: hasUnreadMessages ? Colors.black : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            );
                          },
                        ),
                      ),
                      // NUOVO: Mostra icona countdown per chat in gestazione, altrimenti badge non letti
                      Consumer<MessageService>(
                        builder: (context, messageService, child) {
                          // SOLUZIONE DEFINITIVA: Accedi direttamente alla cache raw per bypassare il bug
                          final cachedChats = RealChatService.cachedChats;
                          final directCachedChat = cachedChats.firstWhere(
                            (chat) => chat.id == widget.chat.id,
                            orElse: () => widget.chat,
                          );
                          
                          // CONTROLLO GESTAZIONE: Con cache per evitare ricaricamenti
                          final chatId = widget.chat.id;
                          
                          // Se non è in cache, calcola e salva
                          if (!_gestationCache.containsKey(chatId)) {
                            _gestationCache[chatId] = widget.chat.isInGestation;
                            print('🔄 Cache timer aggiornata per: ${widget.chat.name} = ${widget.chat.isInGestation}');
                          }
                          
                          // Usa sempre la cache
                          final isInGestation = _gestationCache[chatId] ?? false;
                          
                          // Timer icon per chat in gestazione
                          
                          if (isInGestation) {
                            return Row(
                              children: [
                                const SizedBox(width: 8),
                                _buildCountdownIcon(),
                              ],
                            );
                          }
                          
                          // Altrimenti mostra il badge dei messaggi non letti normale
                          final unreadCount = messageService.getUnreadCount(widget.chat.id);
                          if (unreadCount > 0) {
                            return Row(
                              children: [
                                const SizedBox(width: 8),
                                _buildUnreadBadge(unreadCount),
                              ],
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
        );
      },
    );
  }

  Widget _buildAvatar() {
    print('🎨 ChatItem._buildAvatar - CHIAMATO per chat: ${widget.chat.name} (isGroup: ${widget.chat.isGroup})');
    
    if (widget.chat.isGroup) {
      // Per i gruppi, mostra solo l'avatar senza indicatore
      return _buildGroupAvatar();
    }
    
    // CORREZIONE CRITICA: Usa la logica corretta per chat private
    return _buildUserAvatar();
  }

  Widget _buildUserAvatar() {
    print('🎨 ChatItem._buildUserAvatar - CHIAMATO per chat: ${widget.chat.name} (isGroup: ${widget.chat.isGroup})');
    
    // CORREZIONE CRITICA: Determina l'ID utente corretto
    String? targetUserId = widget.chat.userId;
    
    // Se userId è null, usa i participants per trovare l'altro utente
    if (targetUserId == null && widget.chat.participants.isNotEmpty) {
      // Trova l'utente che NON è l'utente corrente
      final currentUserId = '2'; // TODO: Ottieni dall'AuthService
      targetUserId = widget.chat.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => widget.chat.participants.first,
      );
      print('🎨 ChatItem._buildUserAvatar - userId era null, usando participant: $targetUserId');
    }
    
    final effectiveUserId = targetUserId ?? widget.chat.id;
    print('🎨 ChatItem._buildUserAvatar - Chat: ${widget.chat.name}, effectiveUserId: $effectiveUserId, showOnlineIndicator: true');
    
    // NUOVO: Usa il servizio master per avatar consistenti CON indicatore di stato
    return MasterAvatarWidget.fromChat(
      chatId: effectiveUserId, // ✅ USA userId corretto per mappatura
      chatName: widget.chat.name,
      avatarUrl: widget.chat.avatarUrl.isNotEmpty ? widget.chat.avatarUrl : null,
      size: 50,
      showOnlineIndicator: true, // ✅ ABILITA indicatore di stato
    );
  }

  Widget _buildGroupAvatar() {
    // Se non ci sono membri del gruppo, usa l'avatar mock
    if (widget.chat.groupMembers == null || widget.chat.groupMembers!.isEmpty) {
      return const MockGroupAvatarWidget(
        size: 50,
        showBorder: false,
      );
    }

    // Prepara i dati per il widget multi-immagini
    final memberAvatars = <String>[];
    final memberNames = <String>[];

    for (final member in widget.chat.groupMembers!.take(4)) {
      if (member.length >= 2) {
        memberNames.add(member);
        // Per ora usiamo URL mock, in futuro si può aggiungere un campo avatarUrl ai membri
        memberAvatars.add('');
      }
    }

    return GroupAvatarWidget(
      memberAvatars: memberAvatars,
      memberNames: memberNames,
      size: 50,
      showBorder: false,
    );
  }

  Widget _buildUnreadBadge(int unreadCount) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor, // Verde del progetto (#26A884)
      ),
      child: Center(
        child: Text(
          unreadCount.toString(),
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// NUOVO: Widget per l'icona countdown delle chat in gestazione
  Widget _buildCountdownIcon() {
    return Tooltip(
      message: 'Chat in gestazione - eliminazione programmata',
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              Colors.red.shade400,
              Colors.orange.shade500,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade200.withOpacity(0.5),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Icona principale: orologio timer
            Icon(
              Icons.schedule,
              size: 14,
              color: Colors.white,
            ),
            // Piccolo indicatore di timer in basso a destra
            Positioned(
              right: 2,
              bottom: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.yellow.shade300,
                  border: Border.all(
                    color: Colors.white,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  Icons.access_time,
                  size: 5,
                  color: Colors.red.shade700,
                ),
              ),
            ),
          ],
        ),
        ),
        ),
      ),
    );
  }


}

