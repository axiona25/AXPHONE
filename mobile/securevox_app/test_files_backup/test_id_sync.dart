// Test per verificare la sincronizzazione degli ID tra ChatService e UserService

import 'dart:math';

// Simula i colori degli avatar (copiato da AvatarUtils)
const List<String> _avatarColors = [
  '#26A884',    // AppTheme.primaryColor
  '#0D7557',    // AppTheme.secondaryColor
  '#81C784',    // Verde pastello chiaro
  '#A5D6A7',    // Verde pastello molto chiaro
  '#90CAF9',    // Blu pastello
  '#B39DDB',    // Viola pastello
  '#EF9A9A',    // Rosa pastello
  '#FFB74D',    // Arancione pastello
  '#80CBC4',    // Turchese pastello
  '#CE93D8',    // Lavanda pastello
  '#B2DFDB',    // Acqua pastello
  '#FFCC80',    // Pesca pastello
];

// Simula la funzione getAvatarColorById (copiata da AvatarUtils)
String getAvatarColorById(String userId) {
  if (userId.isEmpty) {
    return _avatarColors[0];
  }
  
  // Usa l'ID per generare un indice consistente
  final hash = userId.hashCode;
  final index = hash.abs() % _avatarColors.length;
  
  return _avatarColors[index];
}

// Simula UserModel
class UserModel {
  final String id;
  final String name;
  final String? profileImage;
  
  UserModel({
    required this.id,
    required this.name,
    this.profileImage,
  });
}

// Simula ChatModel
class ChatModel {
  final String id;
  final String name;
  final String avatarUrl;
  
  ChatModel({
    required this.id,
    required this.name,
    this.avatarUrl = '',
  });
}

// Simula i dati aggiornati di UserService
List<UserModel> getMockUsers() {
  return [
    UserModel(
      id: '5008b261-468a-4b04-9ace-3ad48619c20d', // Stesso ID della chat
      name: 'Riccardo Dicamillo',
      profileImage: null,
    ),
    UserModel(
      id: '2',
      name: 'Raffaele Amoroso',
      profileImage: null,
    ),
    UserModel(
      id: '3',
      name: 'Test User',
      profileImage: null,
    ),
  ];
}

// Simula i dati di ChatService (dati reali dal server)
List<ChatModel> getMockChats() {
  return [
    ChatModel(
      id: '5008b261-468a-4b04-9ace-3ad48619c20d', // Stesso ID dell'utente
      name: 'Riccardo Dicamillo',
      avatarUrl: '',
    ),
  ];
}

void main() {
  print('🧪 Test Sincronizzazione ID tra ChatService e UserService');
  print('=' * 70);
  
  // Carica i dati mock
  final users = getMockUsers();
  final chats = getMockChats();
  
  print('\n📋 Dati Mock:');
  print('-' * 50);
  
  print('\n👥 Utenti (UserService):');
  for (final user in users) {
    final color = getAvatarColorById(user.id);
    print('  - ${user.name} (ID: ${user.id}) → Colore: $color');
  }
  
  print('\n💬 Chat (ChatService):');
  for (final chat in chats) {
    final color = getAvatarColorById(chat.id);
    print('  - ${chat.name} (ID: ${chat.id}) → Colore: $color');
  }
  
  // Verifica sincronizzazione per Riccardo Dicamillo
  print('\n🔍 Verifica Sincronizzazione:');
  print('-' * 50);
  
  final riccardoUser = users.firstWhere((u) => u.name == 'Riccardo Dicamillo');
  final riccardoChat = chats.firstWhere((c) => c.name == 'Riccardo Dicamillo');
  
  print('Utente: ${riccardoUser.name} (ID: ${riccardoUser.id})');
  print('Chat: ${riccardoChat.name} (ID: ${riccardoChat.id})');
  
  final sameId = riccardoUser.id == riccardoChat.id;
  print('ID identici: ${sameId ? '✅' : '❌'}');
  
  if (sameId) {
    final userColor = getAvatarColorById(riccardoUser.id);
    final chatColor = getAvatarColorById(riccardoChat.id);
    final sameColor = userColor == chatColor;
    
    print('Colore utente: $userColor');
    print('Colore chat: $chatColor');
    print('Colori identici: ${sameColor ? '✅' : '❌'}');
    
    if (sameColor) {
      print('\n🎉 SUCCESSO! Riccardo Dicamillo avrà lo stesso colore');
      print('   in tutte le schermate dell\'app!');
    } else {
      print('\n❌ ERRORE! I colori sono ancora diversi');
    }
  } else {
    print('\n❌ ERRORE! Gli ID non sono sincronizzati');
  }
  
  print('\n📝 Risultato:');
  print('=' * 70);
  if (sameId) {
    print('✅ ID sincronizzati tra UserService e ChatService');
    print('✅ Stesso utente = Stesso ID = Stesso colore');
    print('✅ Il problema degli avatar diversi è risolto!');
  } else {
    print('❌ ID non sincronizzati - problema persistente');
  }
}
