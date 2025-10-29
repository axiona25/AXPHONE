import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../models/chat_model.dart';
import '../services/chat_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../services/timezone_service.dart';

class RecentChatsWidget extends StatelessWidget {
  const RecentChatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Usa i dati mock dal ChatService
    final recentChats = ChatService.getSortedChats();

    return Column(
      children: recentChats.map((chat) => _buildChatItem(context, chat)).toList(),
    );
  }

  Widget _buildChatItem(BuildContext context, ChatModel chat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Naviga alla chat specifica
            context.go('/chat-detail/${chat.id}');
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.cardColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar - Usa MasterAvatarService CON indicatore di stato
                Builder(
                  builder: (context) {
                    // CORREZIONE CRITICA: Determina l'ID utente corretto
                    String? targetUserId = chat.userId;
                    
                    // Se userId è null, usa i participants per trovare l'altro utente
                    if (targetUserId == null && chat.participants.isNotEmpty) {
                      final currentUserId = '2'; // TODO: Ottieni dall'AuthService
                      targetUserId = chat.participants.firstWhere(
                        (id) => id != currentUserId,
                        orElse: () => chat.participants.first,
                      );
                      print('🎨 RecentChatsWidget - userId era null, usando participant: $targetUserId');
                    }
                    
                    final effectiveUserId = targetUserId ?? chat.id;
                    print('🎨 RecentChatsWidget - Chat: ${chat.name}, effectiveUserId: $effectiveUserId, showOnlineIndicator: true');
                    
                    return MasterAvatarWidget.fromChat(
                      chatId: effectiveUserId, // ✅ USA userId corretto per mappatura
                      chatName: chat.name,
                      size: 48.0,
                      showOnlineIndicator: true, // ✅ ABILITA indicatore di stato
                    );
                  },
                ),
                const SizedBox(width: 12),
                
                // Contenuto chat
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (chat.isGroup)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Gruppo',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.lastMessage,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: chat.unreadCount > 0 ? const Color(0xFF444444) : AppTheme.textSecondary,
                                fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Timestamp e notifiche
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(chat.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    // Nascondi i badge dei messaggi non letti se non servono
                    // if (chat.unreadCount > 0) ...[
                    //   const SizedBox(height: 4),
                    //   Container(
                    //     padding: const EdgeInsets.all(6),
                    //     decoration: const BoxDecoration(
                    //       color: AppTheme.primaryColor,
                    //       shape: BoxShape.circle,
                    //     ),
                    //     child: Text(
                    //       chat.unreadCount.toString(),
                    //       style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    //         color: Colors.black,
                    //         fontWeight: FontWeight.w600,
                    //       ),
                    //     ),
                    //   ),
                    // ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return TimezoneService.formatChatTime(time);
  }
}

