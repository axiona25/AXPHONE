// Test per verificare la mappatura ID tra User e Chat

import 'lib/services/avatar_id_mapper.dart';

void main() {
  print('🧪 Test Mappatura ID Avatar');
  print('=' * 50);
  
  // Inizializza le mappature
  AvatarIdMapper.initializeKnownMappings();
  
  // Test mappature
  print('\n📋 Test Mappature:');
  print('-' * 30);
  
  // Test Riccardo Dicamillo
  final riccardoUserId = '2';
  final riccardoChatId = '5008b261-468a-4b04-9ace-3ad48619c20d';
  
  print('Riccardo Dicamillo:');
  print('  User ID: $riccardoUserId');
  print('  Chat ID: $riccardoChatId');
  
  final riccardoUnifiedId = AvatarIdMapper.getUnifiedIdForAvatar(riccardoUserId, null);
  final riccardoUnifiedIdFromChat = AvatarIdMapper.getUnifiedIdForAvatar(null, riccardoChatId);
  
  print('  Unified ID (da User): $riccardoUnifiedId');
  print('  Unified ID (da Chat): $riccardoUnifiedIdFromChat');
  print('  ID identici: ${riccardoUnifiedId == riccardoUnifiedIdFromChat ? '✅' : '❌'}');
  
  // Test Raffaele Amoroso
  final raffaeleUserId = '1';
  final raffaeleChatId = '00000000-0000-0000-0000-000000000001';
  
  print('\nRaffaele Amoroso:');
  print('  User ID: $raffaeleUserId');
  print('  Chat ID: $raffaeleChatId');
  
  final raffaeleUnifiedId = AvatarIdMapper.getUnifiedIdForAvatar(raffaeleUserId, null);
  final raffaeleUnifiedIdFromChat = AvatarIdMapper.getUnifiedIdForAvatar(null, raffaeleChatId);
  
  print('  Unified ID (da User): $raffaeleUnifiedId');
  print('  Unified ID (da Chat): $raffaeleUnifiedIdFromChat');
  print('  ID identici: ${raffaeleUnifiedId == raffaeleUnifiedIdFromChat ? '✅' : '❌'}');
  
  // Test mappature inverse
  print('\n🔄 Test Mappature Inverse:');
  print('-' * 30);
  
  final riccardoChatFromUser = AvatarIdMapper.getChatIdFromUserId(riccardoUserId);
  final riccardoUserFromChat = AvatarIdMapper.getUserIdFromChatId(riccardoChatId);
  
  print('Riccardo:');
  print('  User $riccardoUserId -> Chat: $riccardoChatFromUser');
  print('  Chat $riccardoChatId -> User: $riccardoUserFromChat');
  print('  Mappature corrette: ${riccardoChatFromUser == riccardoChatId && riccardoUserFromChat == riccardoUserId ? '✅' : '❌'}');
  
  // Stampa tutte le mappature
  print('\n📊 Tutte le Mappature:');
  print('-' * 30);
  AvatarIdMapper.printMappings();
  
  print('\n📝 Risultato:');
  print('=' * 50);
  if (riccardoUnifiedId == riccardoUnifiedIdFromChat && 
      raffaeleUnifiedId == raffaeleUnifiedIdFromChat &&
      riccardoChatFromUser == riccardoChatId && 
      riccardoUserFromChat == riccardoUserId) {
    print('✅ Mappatura ID funziona correttamente!');
    print('✅ Stesso utente = Stesso ID unificato = Stesso colore avatar');
    print('✅ Il problema degli avatar diversi è risolto!');
  } else {
    print('❌ Mappatura ID non funziona correttamente');
  }
}
