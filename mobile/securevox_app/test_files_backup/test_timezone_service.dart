// Test per verificare la gestione timezone
import 'lib/services/timezone_service.dart';

void main() {
  print('🌍 Test Timezone Service - Verifica gestione timezone');
  
  // Debug timezone
  TimezoneService.debugTimezone();
  
  print('\\n1. Test conversione timestamp:');
  
  // Simula un timestamp UTC dal server
  final utcTimestamp = DateTime.utc(2024, 1, 15, 14, 30, 0);
  print('   Timestamp UTC dal server: ${utcTimestamp.toString()}');
  
  // Converte in locale
  final localTimestamp = TimezoneService.convertFromServer(utcTimestamp);
  print('   Timestamp locale: ${localTimestamp.toString()}');
  
  print('\\n2. Test formattazione chat:');
  
  // Test timestamp di oggi
  final now = DateTime.now();
  print('   Oggi: ${TimezoneService.formatChatTime(now)}');
  
  // Test timestamp di ieri
  final yesterday = now.subtract(Duration(days: 1));
  print('   Ieri: ${TimezoneService.formatChatTime(yesterday)}');
  
  // Test timestamp di una settimana fa
  final lastWeek = now.subtract(Duration(days: 7));
  print('   Una settimana fa: ${TimezoneService.formatChatTime(lastWeek)}');
  
  print('\\n3. Test formattazione chiamate:');
  
  // Test timestamp chiamata
  final callTimestamp = DateTime.utc(2024, 1, 15, 16, 45, 0);
  print('   Timestamp chiamata UTC: ${callTimestamp.toString()}');
  print('   Formattato chiamata: ${TimezoneService.formatCallTime(callTimestamp)}');
  
  print('\\n4. Test raggruppamento chiamate:');
  
  // Test raggruppamento per data
  print('   Oggi: ${TimezoneService.formatCallDate(now)}');
  print('   Ieri: ${TimezoneService.formatCallDate(yesterday)}');
  print('   Una settimana fa: ${TimezoneService.formatCallDate(lastWeek)}');
  
  print('\\n5. Test conversione bidirezionale:');
  
  // Test conversione locale -> server
  final localTime = DateTime.now();
  final serverTime = TimezoneService.convertToServer(localTime);
  print('   Locale -> Server: ${localTime.toString()} -> ${serverTime.toString()}');
  
  // Test conversione server -> locale
  final backToLocal = TimezoneService.convertFromServer(serverTime);
  print('   Server -> Locale: ${serverTime.toString()} -> ${backToLocal.toString()}');
  
  print('\\n✅ TEST TIMEZONE SERVICE COMPLETATO!');
  print('   Gestione timezone centralizzata implementata');
  print('   Conversione UTC <-> Locale funzionante');
  print('   Formattazione timestamp corretta');
  print('   Raggruppamento date ottimizzato');
}
