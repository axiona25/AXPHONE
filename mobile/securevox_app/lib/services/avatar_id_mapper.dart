// Servizio per mappare gli ID tra User e Chat per avatar consistenti

class AvatarIdMapper {
  static final Map<String, String> _userToChatIdMap = {};
  static final Map<String, String> _chatToUserIdMap = {};
  
  // Mappa ID utente numerico -> ID chat UUID
  static void mapUserToChat(String userId, String chatId) {
    _userToChatIdMap[userId] = chatId;
    _chatToUserIdMap[chatId] = userId;
  }
  
  // Ottieni ID chat da ID utente
  static String? getChatIdFromUserId(String userId) {
    return _userToChatIdMap[userId];
  }
  
  // Ottieni ID utente da ID chat
  static String? getUserIdFromChatId(String chatId) {
    return _chatToUserIdMap[chatId];
  }
  
  // Ottieni ID unificato per avatar (usa sempre ID utente se mappato)
  static String getUnifiedIdForAvatar(String? userId, String? chatId) {
    // Se abbiamo un ID utente, usalo (più stabile)
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }
    
    // Se abbiamo un ID chat, prova a trovare l'ID utente corrispondente
    if (chatId != null && chatId.isNotEmpty) {
      final mappedUserId = getUserIdFromChatId(chatId);
      if (mappedUserId != null) {
        return mappedUserId; // Usa l'ID utente mappato
      }
      return chatId; // Fallback all'ID chat se non mappato
    }
    
    // Fallback
    return 'unknown';
  }
  
  // Inizializza mappature note
  static void initializeKnownMappings() {
    // Mappature hardcoded per utenti noti
    // Questi dovrebbero essere sincronizzati con il server
    mapUserToChat('1', '1'); // Raffaele Amoroso (ID: 1, r.amoroso80@gmail.com)
    mapUserToChat('2', '2'); // Riccardo Dicamillo (ID: 2, r.dicamillo69@gmail.com)
  }
  
  // Pulisci tutte le mappature
  static void clearMappings() {
    _userToChatIdMap.clear();
    _chatToUserIdMap.clear();
  }
  
  // Debug: stampa tutte le mappature
  static void printMappings() {
    print('🗺️ AvatarIdMapper: Mappature attive:');
    _userToChatIdMap.forEach((userId, chatId) {
      print('  User $userId -> Chat $chatId');
    });
  }
}
