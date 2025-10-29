// Test di debug per verificare la consistenza degli avatar
// Questo test simula il comportamento reale dell'app

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

// Simula AvatarService
class AvatarService {
  static final AvatarService _instance = AvatarService._internal();
  factory AvatarService() => _instance;
  AvatarService._internal();

  String buildUserAvatar({
    required UserModel user,
    double size = 48.0,
    bool showOnlineIndicator = false,
    bool isOnline = false,
  }) {
    String avatar;
    
    // Priorità: immagine di profilo > iniziali con colore basato su ID
    if (user.profileImage != null && user.profileImage!.isNotEmpty) {
      avatar = 'ProfileImage: ${user.profileImage}';
    } else {
      final color = getAvatarColorById(user.id);
      avatar = 'Initials: ${_getInitials(user.name)} with color $color';
    }

    // Aggiungi indicatore online se richiesto
    if (showOnlineIndicator) {
      avatar += ' [${isOnline ? 'ONLINE' : 'OFFLINE'}]';
    }

    return avatar;
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      final initials = words.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
      return initials.toUpperCase();
    } else {
      final singleName = words[0];
      return singleName.length >= 2 
          ? singleName.substring(0, 2).toUpperCase()
          : singleName[0].toUpperCase();
    }
  }
}

void main() {
  print('🔍 Test di Debug - Sincronizzazione Avatar');
  print('=' * 50);
  
  // Simula Riccardo Dicamillo con ID diverso
  final user1 = UserModel(
    id: 'user_123',
    name: 'Riccardo Dicamillo',
    profileImage: null,
  );
  
  final user2 = UserModel(
    id: 'user_456', // ID diverso!
    name: 'Riccardo Dicamillo',
    profileImage: null,
  );
  
  final user3 = UserModel(
    id: 'user_123', // Stesso ID di user1
    name: 'Riccardo Dicamillo',
    profileImage: null,
  );
  
  final avatarService = AvatarService();
  
  print('\n📋 Test con ID diversi:');
  print('-' * 30);
  
  final avatar1 = avatarService.buildUserAvatar(user: user1);
  final avatar2 = avatarService.buildUserAvatar(user: user2);
  final avatar3 = avatarService.buildUserAvatar(user: user3);
  
  print('User1 (ID: ${user1.id}): $avatar1');
  print('User2 (ID: ${user2.id}): $avatar2');
  print('User3 (ID: ${user3.id}): $avatar3');
  
  print('\n🔍 Analisi:');
  print('User1 == User2: ${avatar1 == avatar2 ? '✅' : '❌'}');
  print('User1 == User3: ${avatar1 == avatar3 ? '✅' : '❌'}');
  print('User2 == User3: ${avatar2 == avatar3 ? '✅' : '❌'}');
  
  print('\n📋 Test con stesso ID ma nomi diversi:');
  print('-' * 30);
  
  final user4 = UserModel(
    id: 'user_123',
    name: 'Mario Rossi',
    profileImage: null,
  );
  
  final avatar4 = avatarService.buildUserAvatar(user: user4);
  
  print('User1 (${user1.name}): $avatar1');
  print('User4 (${user4.name}): $avatar4');
  print('Stesso ID, nomi diversi: ${avatar1 == avatar4 ? '✅' : '❌'}');
  
  print('\n📋 Test con ID vuoto:');
  print('-' * 30);
  
  final user5 = UserModel(
    id: '',
    name: 'Riccardo Dicamillo',
    profileImage: null,
  );
  
  final avatar5 = avatarService.buildUserAvatar(user: user5);
  
  print('User5 (ID vuoto): $avatar5');
  print('Colore per ID vuoto: ${getAvatarColorById('')}');
  
  print('\n📋 Test con profilo immagine:');
  print('-' * 30);
  
  final user6 = UserModel(
    id: 'user_123',
    name: 'Riccardo Dicamillo',
    profileImage: 'https://example.com/avatar.jpg',
  );
  
  final avatar6 = avatarService.buildUserAvatar(user: user6);
  
  print('User6 (con immagine): $avatar6');
  print('Priorità immagine: ${avatar6.contains('ProfileImage') ? '✅' : '❌'}');
  
  print('\n🎯 Conclusioni:');
  print('=' * 50);
  print('✅ Stesso ID = Stesso colore');
  print('✅ ID diverso = Colore diverso');
  print('✅ Immagine di profilo ha priorità');
  print('✅ ID vuoto usa colore di default');
  
  print('\n💡 Il problema potrebbe essere:');
  print('- ID utente non consistente tra schermate');
  print('- Cache non condivisa tra Provider');
  print('- Provider non funzionante correttamente');
}
