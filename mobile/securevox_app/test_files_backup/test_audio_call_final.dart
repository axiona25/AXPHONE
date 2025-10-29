import 'lib/services/user_service.dart';
import 'lib/services/active_call_service.dart';
import 'lib/services/centralized_avatar_service.dart';
import 'lib/models/user_model.dart';

void main() async {
  print('🧪 Test Audio Call Final - Verifica dati sincronizzati');
  
  // Inizializza i servizi
  CentralizedAvatarService.initialize();
  
  // Test 1: Verifica che UserService restituisca Riccardo Dicamillo con UUID corretto
  print('\n1. Test UserService.getUserById con UUID:');
  final user = await UserService.getUserById('5008b261-468a-4b04-9ace-3ad48619c20d');
  if (user != null) {
    print('✅ Utente trovato: ${user.name} (ID: ${user.id})');
    assert(user.name == 'Riccardo Dicamillo', 'Nome utente errato');
    assert(user.id == '5008b261-468a-4b04-9ace-3ad48619c20d', 'ID utente errato');
  } else {
    print('❌ Utente NON trovato!');
  }
  
  // Test 2: Verifica che ActiveCallService funzioni con l'UUID
  print('\n2. Test ActiveCallService con UUID:');
  ActiveCallService.startAudioCall('5008b261-468a-4b04-9ace-3ad48619c20d');
  print('✅ ActiveCallService.userId: ${ActiveCallService.userId}');
  assert(ActiveCallService.userId == '5008b261-468a-4b04-9ace-3ad48619c20d', 'ID ActiveCallService errato');
  
  // Test 3: Verifica che CentralizedAvatarService funzioni con l'utente
  print('\n3. Test CentralizedAvatarService con utente:');
  if (user != null) {
    final avatar = CentralizedAvatarService().buildUserAvatar(user: user, size: 200);
    print('✅ Avatar creato per ${user.name}');
    assert(avatar != null, 'Avatar non creato');
  }
  
  // Test 4: Simula il flusso completo della schermata di chiamata audio
  print('\n4. Test flusso completo AudioCallScreen:');
  print('   - ActiveCallService.userId: ${ActiveCallService.userId}');
  if (ActiveCallService.userId != null) {
    final callUser = await UserService.getUserById(ActiveCallService.userId!);
    if (callUser != null) {
      print('   - Utente caricato: ${callUser.name} (ID: ${callUser.id})');
      print('   - Avatar creato: ${CentralizedAvatarService().buildUserAvatar(user: callUser, size: 200) != null}');
      assert(callUser.name == 'Riccardo Dicamillo', 'Nome utente nella chiamata errato');
      assert(callUser.id == '5008b261-468a-4b04-9ace-3ad48619c20d', 'ID utente nella chiamata errato');
    } else {
      print('   ❌ Utente NON caricato nella chiamata!');
    }
  }
  
  print('\n🎉 Test completato! La schermata di chiamata audio dovrebbe ora mostrare:');
  print('   - Nome: "Riccardo Dicamillo"');
  print('   - Avatar: Colore verde pastello con iniziali "RD"');
  print('   - ID: 5008b261-468a-4b04-9ace-3ad48619c20d');
}
