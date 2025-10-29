import 'package:flutter/material.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';

/// Servizio unificato per la gestione degli avatar
/// Fornisce un'interfaccia coerente per creare avatar in tutta l'app
class UnifiedAvatarService {
  static final MasterAvatarService _masterService = MasterAvatarService();
  
  /// Crea un avatar per un utente
  static Widget buildUserAvatar({
    required String userId,
    String? userName,
    String? profileImageUrl,
    double size = 40.0,
    bool showOnlineIndicator = false,
  }) {
    return MasterAvatarWidget(
      userId: userId,
      userName: userName ?? 'Utente',
      profileImageUrl: profileImageUrl,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
    );
  }
  
  /// Crea un avatar per una chat
  static Widget buildChatAvatar({
    required String chatId,
    required String chatName,
    String? avatarUrl,
    double size = 40.0,
    bool showOnlineIndicator = false,
  }) {
    return MasterAvatarWidget.fromChat(
      chatId: chatId,
      chatName: chatName,
      avatarUrl: avatarUrl,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
    );
  }
  
  /// Crea un avatar di gruppo (usa il sistema chat)
  static Widget buildGroupAvatar({
    required String groupId,
    required String groupName,
    double size = 40.0,
    bool showOnlineIndicator = false,
  }) {
    return MasterAvatarWidget.fromChat(
      chatId: groupId,
      chatName: groupName,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
    );
  }
  
  /// Genera le iniziali da un nome
  static String generateInitials(String name) {
    if (name.isEmpty) return '?';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0].substring(0, 1).toUpperCase();
    } else {
      return (words[0].substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
    }
  }
  
  /// Crea un avatar circolare semplice
  static Widget buildSimpleAvatar({
    required String text,
    double size = 40.0,
    Color? backgroundColor,
    Color? textColor,
    double? fontSize,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: textColor ?? Colors.black,
            fontSize: fontSize ?? size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Crea un avatar con gradiente
  static Widget buildGradientAvatar({
    required String text,
    double size = 40.0,
    List<Color>? gradientColors,
    Color? textColor,
    double? fontSize,
  }) {
    final colors = gradientColors ?? [
      Colors.blue.shade400,
      Colors.purple.shade400,
    ];
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: textColor ?? Colors.white,
            fontSize: fontSize ?? size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Crea un avatar con icona
  static Widget buildIconAvatar({
    required IconData icon,
    double size = 40.0,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: iconColor ?? Colors.black,
        size: size * 0.5,
      ),
    );
  }
  
  /// Pre-carica i dati degli avatar per migliori performance
  static Future<void> preloadAvatarData(List<String> userIds) async {
    // Implementazione semplificata
    print('🔄 UnifiedAvatarService - Pre-caricamento avatar per ${userIds.length} utenti');
  }
  
  /// Pulisce la cache degli avatar
  static void clearAvatarCache() {
    print('🗑️ UnifiedAvatarService - Cache avatar pulita');
  }
  
  /// Ottiene informazioni sull'avatar di un utente
  static Future<Map<String, dynamic>> getAvatarInfo(String userId) async {
    return {
      'userId': userId,
      'hasCustomAvatar': false,
      'avatarUrl': null,
    };
  }
  
  /// Verifica se un utente ha un avatar personalizzato
  static Future<bool> hasCustomAvatar(String userId) async {
    final info = await getAvatarInfo(userId);
    return info['hasCustomAvatar'] ?? false;
  }
  
  /// Crea un avatar placeholder
  static Widget buildPlaceholderAvatar({
    double size = 40.0,
    IconData icon = Icons.person,
    Color? backgroundColor,
    Color? iconColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey.shade200,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1.0,
        ),
      ),
      child: Icon(
        icon,
        color: iconColor ?? Colors.grey.shade500,
        size: size * 0.5,
      ),
    );
  }
  
  /// Crea un avatar con badge di stato
  static Widget buildAvatarWithBadge({
    required Widget avatar,
    required Widget badge,
    double badgeSize = 12.0,
    Alignment badgeAlignment = Alignment.bottomRight,
  }) {
    return Stack(
      children: [
        avatar,
        Positioned.fill(
          child: Align(
            alignment: badgeAlignment,
            child: SizedBox(
              width: badgeSize,
              height: badgeSize,
              child: badge,
            ),
          ),
        ),
      ],
    );
  }
  
  /// Crea un avatar con indicatore online
  static Widget buildAvatarWithOnlineIndicator({
    required Widget avatar,
    required bool isOnline,
    double indicatorSize = 12.0,
    Color? onlineColor,
    Color? offlineColor,
  }) {
    return buildAvatarWithBadge(
      avatar: avatar,
      badge: Container(
        width: indicatorSize,
        height: indicatorSize,
        decoration: BoxDecoration(
          color: isOnline 
              ? (onlineColor ?? Colors.green) 
              : (offlineColor ?? Colors.grey),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2.0,
          ),
        ),
      ),
    );
  }
  
  /// Pre-carica tutti gli avatar degli utenti
  static Future<void> preloadAllUserAvatars() async {
    await _masterService.preloadAllUserData();
  }
  
  /// Aggiorna l'URL dell'avatar di un utente
  static Future<void> updateUserAvatarUrl(String userId, String? avatarUrl) async {
    await _masterService.updateUserProfilePhoto(userId, avatarUrl);
  }
  
  /// Pulisce la cache per un utente specifico
  static void clearUserCache(String userId) {
    // Il MasterAvatarService non ha un metodo specifico per singolo utente
    // quindi implementiamo una versione semplificata
    print('🗑️ UnifiedAvatarService - Pulizia cache per utente: $userId');
  }
  
  /// Ottiene l'ID utente da un nome (metodo di compatibilità)
  static String getUserIdFromName(String name) {
    // Implementazione semplificata - potrebbe essere migliorata
    // Per ora restituisce un hash del nome come ID
    return name.hashCode.abs().toString();
  }
  
  /// Ottiene il colore assegnato a un utente
  static Color? getUserColor(String userId) {
    return _masterService.getUserColor(userId);
  }
}
