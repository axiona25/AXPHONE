import '../models/chat_model.dart';
import 'date_formatter_service.dart';
import 'user_service.dart';
import 'auth_service.dart';
import 'real_chat_service.dart';

class ChatService {
  static final List<ChatModel> _mockChats = [
    ChatModel(
      id: '1',
      name: 'Raffaele Amoroso', // Nome reale
      lastMessage: 'Ti piace ?',
      timestamp: DateFormatterService.generateTestTimestamp(2), // 2 ore fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
      userId: '2', // ✅ ID REALE di Raffaele dal server
    ),
    ChatModel(
      id: '2',
      name: 'Riccardo Dicamillo', // Nome reale
      lastMessage: 'Ti piace ?',
      timestamp: DateFormatterService.generateTestTimestampForDay(1), // Ieri
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
      userId: '3', // ✅ ID REALE di Riccardo dal server
    ),
    ChatModel(
      id: '3',
      name: 'Admin SecureVox', // Nome reale admin
      lastMessage: 'Sistema aggiornato',
      timestamp: DateFormatterService.generateTestTimestampForDay(2), // L'altro ieri
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: false,
      unreadCount: 0,
      isGroup: false,
      userId: '9', // ✅ ID REALE di Admin dal server (offline)
    ),
    ChatModel(
      id: '4',
      name: 'Security Test', // Nome security
      lastMessage: 'Controlli di sicurezza',
      timestamp: DateFormatterService.generateTestTimestampForDay(3), // 3 giorni fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: false,
      unreadCount: 0,
      isGroup: false,
      userId: '10', // ✅ ID REALE di Security dal server (unreachable - giallo)
    ),
    ChatModel(
      id: '5',
      name: 'John Borino',
      lastMessage: 'Have a good day 🌸',
      timestamp: DateFormatterService.generateTestTimestampForDay(5), // 5 giorni fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
    ),
    ChatModel(
      id: '6',
      name: 'Sarah Johnson',
      lastMessage: 'Have a good day 🌸',
      timestamp: DateFormatterService.generateTestTimestampForDay(8), // 8 giorni fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
    ),
    ChatModel(
      id: '7',
      name: 'Emma Wilson',
      lastMessage: 'Have a good day 🌸',
      timestamp: DateFormatterService.generateTestTimestampForDay(15), // 15 giorni fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
    ),
    ChatModel(
      id: '8',
      name: 'Angel Dayna',
      lastMessage: 'How are you today?',
      timestamp: DateFormatterService.generateTestTimestampForDay(30), // 30 giorni fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: false,
      unreadCount: 0,
      isGroup: false,
    ),
  ];

  static List<ChatModel> getAllChats() {
    return List.from(_mockChats);
  }

  static ChatModel getChatById(String id) {
    try {
      // Prima prova a cercare nelle chat reali (sincrono)
      final realChats = getRealUserChatsSync();
      final realChat = realChats.firstWhere((chat) => chat.id == id);
      return realChat;
    } catch (e) {
      // Se non trova nelle chat reali, cerca nelle chat mock
      print('Chat $id not found in real chats, trying mock chats');
      return _mockChats.firstWhere((chat) => chat.id == id);
    }
  }

  static List<ChatModel> getOnlineChats() {
    return _mockChats.where((chat) => chat.isOnline).toList();
  }

  static List<ChatModel> getUnreadChats() {
    return _mockChats.where((chat) => chat.unreadCount > 0).toList();
  }

  static List<ChatModel> getGroupChats() {
    return _mockChats.where((chat) => chat.isGroup).toList();
  }

  static List<ChatModel> getIndividualChats() {
    return _mockChats.where((chat) => !chat.isGroup).toList();
  }


  static void markAsRead(String chatId) {
    final index = _mockChats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      _mockChats[index] = _mockChats[index].copyWith(unreadCount: 0);
    }
  }

  static void updateLastMessage(String chatId, String message) {
    final index = _mockChats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      _mockChats[index] = _mockChats[index].copyWith(
        lastMessage: message,
        timestamp: DateTime.now(),
      );
    }
  }

  static Future<ChatModel?> createNewChat({
    required String participantId,
    required String name,
    String? avatarUrl,
    bool isGroup = false,
    List<String>? groupMembers,
  }) async {
    try {
      // Crea la chat nel database tramite il servizio reale
      final newChat = await RealChatService.createChat(
        participantId: participantId,
        isGroup: isGroup,
        groupName: isGroup ? name : null,
      );
      
      if (newChat != null) {
        // Aggiungi anche alla lista mock per compatibilità
        _mockChats.insert(0, newChat);
        return newChat;
      }
      
      return null;
    } catch (e) {
      print('Errore nella creazione chat: $e');
      return null;
    }
  }

  static List<ChatModel> getSortedChats() {
    // Ordina le chat per timestamp (dalle più recenti alle più vecchie)
    final sortedChats = List<ChatModel>.from(_mockChats);
    sortedChats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sortedChats;
  }

  // Genera chat basate sugli utenti reali dal database
  // REGOLA FONDAMENTALE: Non creare chat automatiche per utenti registrati
  // Le chat devono essere create esplicitamente tramite "crea nuova chat"
  static Future<List<ChatModel>> getRealUserChats() async {
    try {
      // Utilizza il servizio reale per ottenere le chat dal database
      return await RealChatService.getRealChats();
    } catch (e) {
      print('Errore nel recupero chat reali: $e');
      // Se c'è un errore, pulisci i token vecchi
      final authService = AuthService();
      await authService.clearOldTokens();
      return <ChatModel>[]; // Restituisce lista vuota anche in caso di errore
    }
  }

  // Metodo sincrono per compatibilità
  // REGOLA FONDAMENTALE: Non creare chat automatiche per utenti registrati
  static List<ChatModel> getRealUserChatsSync() {
    try {
      // Restituisce le chat dalla cache se disponibili
      return RealChatService.cachedChats.isNotEmpty 
          ? List.from(RealChatService.cachedChats)
          : <ChatModel>[];
    } catch (e) {
      print('Errore nel recupero chat reali: $e');
      return <ChatModel>[]; // Restituisce lista vuota anche in caso di errore
    }
  }

}
