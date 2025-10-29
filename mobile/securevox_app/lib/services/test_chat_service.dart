import '../models/chat_model.dart';
import 'date_formatter_service.dart';

class TestChatService {
  static List<ChatModel> _emptyChats = [];
  static List<ChatModel> _mockChats = [
    ChatModel(
      id: '1',
      name: 'Raffaele Amoroso', // Nome completo - mostrerà "Raffaele Amoroso"
      lastMessage: 'Ciao! Come stai?',
      timestamp: DateFormatterService.generateTestTimestamp(30), // 30 minuti fa
      avatarUrl: '', // Nessuna foto profilo - mostrerà le iniziali "RA"
      isOnline: true,
      unreadCount: 2,
      isGroup: false,
      userId: '5', // Corrisponde all'utente Raffaele Amoroso
    ),
    ChatModel(
      id: '2',
      name: 'Alex Linderson', // Nome completo - mostrerà "Alex Linderson"
      lastMessage: 'How are you today?',
      timestamp: DateFormatterService.generateTestTimestamp(2), // 2 ore fa
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 3,
      isGroup: false,
      userId: '1', // Corrisponde all'utente Alex Linderson
    ),
    ChatModel(
      id: '3',
      name: 'Team Sviluppo',
      lastMessage: 'Meeting alle 15:00 oggi',
      timestamp: DateFormatterService.generateTestTimestampForDay(1), // Ieri
      avatarUrl: '',
      isOnline: false,
      unreadCount: 4,
      isGroup: true,
      groupMembers: ['Alex Linderson', 'Sarah Johnson', 'Mike Wilson', 'Emma Davis'],
    ),
    ChatModel(
      id: '10',
      name: 'Famiglia',
      lastMessage: 'A che ora arrivate per pranzo?',
      timestamp: DateFormatterService.generateTestTimestamp(45), // 45 minuti fa
      avatarUrl: '',
      isOnline: false,
      unreadCount: 2,
      isGroup: true,
      groupMembers: ['Mamma', 'Papà', 'Marco'],
    ),
    ChatModel(
      id: '11',
      name: 'Amici Università',
      lastMessage: 'Chi viene alla festa di stasera?',
      timestamp: DateFormatterService.generateTestTimestampForDay(1), // Ieri
      avatarUrl: '',
      isOnline: false,
      unreadCount: 7,
      isGroup: true,
      groupMembers: ['Luca', 'Giulia', 'Andrea', 'Chiara', 'Francesco'],
    ),
    ChatModel(
      id: '12',
      name: 'Colleghi Marketing',
      lastMessage: 'Il nuovo progetto è pronto per il lancio',
      timestamp: DateFormatterService.generateTestTimestampForDay(3), // 3 giorni fa
      avatarUrl: '',
      isOnline: false,
      unreadCount: 0,
      isGroup: true,
      groupMembers: ['Elena', 'Roberto'],
    ),
    ChatModel(
      id: '4',
      name: 'John Ahraham', // Nome completo - mostrerà "John Ahraham"
      lastMessage: 'Hey! Can you join the meeting?',
      timestamp: DateFormatterService.generateTestTimestampForDay(2), // L'altro ieri
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: false,
      unreadCount: 0,
      isGroup: false,
      userId: '17', // Corrisponde all'utente John Ahraham
    ),
    ChatModel(
      id: '5',
      name: 'Sabila', // Solo nome - mostrerà "Sabila"
      lastMessage: 'How are you today?',
      timestamp: DateFormatterService.generateTestTimestampForDay(3), // 3 giorni fa (mercoledì)
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: false,
      unreadCount: 0,
      isGroup: false,
      userId: '19', // Corrisponde all'utente Sabila
    ),
    ChatModel(
      id: '6',
      name: 'John Borino', // Nome completo - mostrerà "John Borino"
      lastMessage: 'Have a good day 🌸',
      timestamp: DateFormatterService.generateTestTimestampForDay(5), // 5 giorni fa (lunedì)
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
      userId: '18', // Corrisponde all'utente John Borino
    ),
    ChatModel(
      id: '7',
      name: 'Sarah Johnson',
      lastMessage: 'Have a good day 🌸',
      timestamp: DateFormatterService.generateTestTimestampForDay(8), // 8 giorni fa (data completa)
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
    ),
    ChatModel(
      id: '8',
      name: 'Emma Wilson',
      lastMessage: 'Have a good day 🌸',
      timestamp: DateFormatterService.generateTestTimestampForDay(15), // 15 giorni fa (data completa)
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: true,
      unreadCount: 0,
      isGroup: false,
    ),
    ChatModel(
      id: '9',
      name: 'Angel Dayna',
      lastMessage: 'How are you today?',
      timestamp: DateFormatterService.generateTestTimestampForDay(30), // 30 giorni fa (data completa)
      avatarUrl: '', // Nessuna foto - mostrerà iniziali
      isOnline: false,
      unreadCount: 0,
      isGroup: false,
    ),
  ];

  static List<ChatModel> getAllChats() {
    return List.from(_mockChats);
  }

  static List<ChatModel> getEmptyChats() {
    return List.from(_emptyChats);
  }

  static void setEmptyMode(bool isEmpty) {
    // Questo metodo può essere usato per testare il placeholder
    // In un'app reale, questo sarebbe gestito dal backend
  }

  static List<ChatModel> searchChats(String query) {
    if (query.isEmpty) return getAllChats();
    
    return _mockChats.where((chat) {
      return chat.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
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

  static ChatModel? getChatById(String id) {
    try {
      return _mockChats.firstWhere((chat) => chat.id == id);
    } catch (e) {
      return null;
    }
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
}
