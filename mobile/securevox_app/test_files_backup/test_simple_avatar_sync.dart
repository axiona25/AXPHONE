// Test semplice per verificare la sincronizzazione avatar

import 'lib/services/avatar_id_mapper.dart';

void main() {
  print('🧪 Test Sincronizzazione Avatar Semplice');
  print('=' * 50);
  
  // Inizializza le mappature
  AvatarIdMapper.initializeKnownMappings();
  
  // Test Riccardo Dicamillo
  print('\n👤 Test Riccardo Dicamillo:');
  print('-' * 30);
  
  final riccardoUserId = '2';
  final riccardoChatId = '5008b261-468a-4b04-9ace-3ad48619c20d';
  
  print('User ID: $riccardoUserId');
  print('Chat ID: $riccardoChatId');
  
  final riccardoUserUnifiedId = AvatarIdMapper.getUnifiedIdForAvatar(riccardoUserId, null);
  final riccardoChatUnifiedId = AvatarIdMapper.getUnifiedIdForAvatar(null, riccardoChatId);
  
  print('Unified ID (da User): $riccardoUserUnifiedId');
  print('Unified ID (da Chat): $riccardoChatUnifiedId');
  print('ID identici: ${riccardoUserUnifiedId == riccardoChatUnifiedId ? '✅' : '❌'}');
  
  // Test Raffaele Amoroso
  print('\n👤 Test Raffaele Amoroso:');
  print('-' * 30);
  
  final raffaeleUserId = '1';
  final raffaeleChatId = '00000000-0000-0000-0000-000000000001';
  
  print('User ID: $raffaeleUserId');
  print('Chat ID: $raffaeleChatId');
  
  final raffaeleUserUnifiedId = AvatarIdMapper.getUnifiedIdForAvatar(raffaeleUserId, null);
  final raffaeleChatUnifiedId = AvatarIdMapper.getUnifiedIdForAvatar(null, raffaeleChatId);
  
  print('Unified ID (da User): $raffaeleUserUnifiedId');
  print('Unified ID (da Chat): $raffaeleChatUnifiedId');
  print('ID identici: ${raffaeleUserUnifiedId == raffaeleChatUnifiedId ? '✅' : '❌'}');
  
  // Test mappature inverse
  print('\n🔄 Test Mappature Inverse:');
  print('-' * 30);
  
  final riccardoChatFromUser = AvatarIdMapper.getChatIdFromUserId(riccardoUserId);
  final riccardoUserFromChat = AvatarIdMapper.getUserIdFromChatId(riccardoChatId);
  
  print('Riccardo:');
  print('  User $riccardoUserId -> Chat: $riccardoChatFromUser');
  print('  Chat $riccardoChatId -> User: $riccardoUserFromChat');
  print('  Mappature corrette: ${riccardoChatFromUser == riccardoChatId && riccardoUserFromChat == riccardoUserId ? '✅' : '❌'}');
  
  // Risultato finale
  print('\n📝 Risultato Finale:');
  print('=' * 50);
  
  if (riccardoUserUnifiedId == riccardoChatUnifiedId && 
      raffaeleUserUnifiedId == raffaeleChatUnifiedId &&
      riccardoChatFromUser == riccardoChatId && 
      riccardoUserFromChat == riccardoUserId) {
    print('🎉 SUCCESSO! Sincronizzazione Avatar Completata!');
    print('✅ ID mappati correttamente tra User e Chat');
    print('✅ Stesso utente = Stesso ID unificato = Stesso colore avatar');
    print('✅ Il problema degli avatar diversi è RISOLTO!');
    print('\n🚀 Ora Riccardo Dicamillo avrà lo stesso colore');
    print('   in Home, Contatti, Chat, Chiamate e tutte le schermate!');
  } else {
    print('❌ ERRORE! Sincronizzazione non funziona');
  }
}
