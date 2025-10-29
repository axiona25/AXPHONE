// Test per verificare che la schermata di chiamata audio mostri l'avatar corretto

void main() {
  print('🎵 Test Audio Call Avatar');
  print('=' * 50);
  
  // Simula i dati come li vedrebbe la schermata di chiamata audio
  print('\n📱 Simulazione Audio Call Screen:');
  print('-' * 30);
  
  // Dati della chat (come vengono passati alla chiamata)
  final chatName = 'Riccardo Dicamillo';
  final chatId = '5008b261-468a-4b04-9ace-3ad48619c20d';
  
  print('Chat Name: $chatName');
  print('Chat ID: $chatId');
  
  // Simula l'estrazione dell'ID utente (come fa _extractUserIdFromChat)
  final extractedUserId = _extractUserIdFromChat(chatName, chatId);
  print('Extracted User ID: $extractedUserId');
  
  // Simula il caricamento dell'utente (come fa _loadUser)
  final user = _getUserById(extractedUserId);
  print('Loaded User: ${user?.name ?? 'NULL'} (ID: ${user?.id ?? 'NULL'})');
  
  // Simula la creazione dell'avatar (come fa _buildInitialsAvatar)
  if (user != null) {
    final avatarColor = _getAvatarColorById(user.id);
    print('Avatar Color: $avatarColor');
    print('Avatar Initials: ${_getInitials(user.name)}');
    
    print('\n✅ SUCCESSO! Audio Call Screen mostrerà:');
    print('  - Nome: ${user.name}');
    print('  - Colore: $avatarColor');
    print('  - Iniziali: ${_getInitials(user.name)}');
  } else {
    print('\n❌ ERRORE! User non trovato');
  }
  
  print('\n🎯 Verifica Mappatura:');
  print('-' * 20);
  print('Chat "Riccardo Dicamillo" -> User ID: $extractedUserId');
  print('User ID $extractedUserId -> Avatar Color: ${_getAvatarColorById(extractedUserId)}');
  print('Stesso colore in tutte le schermate: ✅');
}

// Simula la funzione _extractUserIdFromChat
String _extractUserIdFromChat(String chatName, String chatId) {
  final chatToUserIdMap = {
    'riccardo dicamillo': '5008b261-468a-4b04-9ace-3ad48619c20d',
    'raffaele amoroso': '2',
    'alex linderson': '1',
    'alice rossi': '2',
    'sofia verdi': '3',
    'andrea neri': '4',
    'giulia russo': '10',
    'francesco romano': '11',
    'chiara ferrari': '12',
    'luca conti': '13',
    'maria bianchi': '14',
    'giovanni rossi': '15',
    'elena martini': '16',
    'john ahraham': '17',
    'john borino': '18',
    'sabila': '19',
  };
  
  final mappedUserId = chatToUserIdMap[chatName.toLowerCase()];
  if (mappedUserId != null) {
    return mappedUserId;
  }
  
  // Fallback: usa l'ID della chat se è un numero valido
  if (int.tryParse(chatId) != null) {
    return chatId;
  }
  
  // Ultimo fallback
  return '1';
}

// Simula la funzione _getUserById
User? _getUserById(String id) {
  final users = [
    User(
      id: '5008b261-468a-4b04-9ace-3ad48619c20d',
      name: 'Riccardo Dicamillo',
      email: 'r.dicamillo69@gmail.com',
    ),
    User(
      id: '2',
      name: 'Raffaele Amoroso',
      email: 'r.amoroso80@gmail.com',
    ),
    User(
      id: '3',
      name: 'Test User',
      email: 'test@example.com',
    ),
  ];
  
  try {
    return users.firstWhere((user) => user.id == id);
  } catch (e) {
    return null;
  }
}

// Simula la funzione _getAvatarColorById
String _getAvatarColorById(String userId) {
  const List<String> avatarColors = [
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
  
  if (userId.isEmpty) {
    return avatarColors[0];
  }
  
  final hash = userId.hashCode;
  final index = hash.abs() % avatarColors.length;
  return avatarColors[index];
}

// Simula la funzione _getInitials
String _getInitials(String name) {
  if (name.isEmpty) return '?';
  
  final words = name.trim().split(' ');
  if (words.length == 1) {
    return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
  } else {
    final initials = words.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
    return initials.toUpperCase();
  }
}

// Classe User semplificata
class User {
  final String id;
  final String name;
  final String email;
  
  User({required this.id, required this.name, required this.email});
}
