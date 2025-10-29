import 'package:intl/intl.dart';

class TimezoneService {
  // Timezone del server (configurato in Django)
  static const String serverTimezone = 'Europe/Rome';
  
  // Timezone locale del dispositivo
  static String get localTimezone {
    return DateTime.now().timeZoneName;
  }
  
  /// Converte un timestamp UTC dal server in DateTime locale
  static DateTime convertFromServer(DateTime utcTimestamp) {
    // Se il timestamp è già in UTC, lo convertiamo in locale
    if (utcTimestamp.isUtc) {
      return utcTimestamp.toLocal();
    }
    
    // Se il timestamp è in timezone del server, lo trattiamo come UTC e convertiamo
    // Questo è un workaround per timestamp che arrivano dal server
    return utcTimestamp.toLocal();
  }
  
  /// Converte un timestamp locale in UTC per inviare al server
  static DateTime convertToServer(DateTime localTimestamp) {
    return localTimestamp.toUtc();
  }
  
  /// Formatta un timestamp per la visualizzazione nelle chat
  static String formatChatTime(DateTime timestamp) {
    // Assicuriamoci che il timestamp sia in locale
    final localTime = convertFromServer(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final timestampDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    // 1. Giorno in corso - mostra ora precisa (13:15)
    if (timestampDate == today) {
      return DateFormat('HH:mm').format(localTime);
    }
    
    // 2. Ieri - mostra "Ieri" + ora
    if (timestampDate == yesterday) {
      return 'Ieri ${DateFormat('HH:mm').format(localTime)}';
    }
    
    // 3. Dopo ieri - mostra data completa (14/09/25)
    return DateFormat('dd/MM/yy').format(localTime);
  }
  
  /// Formatta un timestamp per la visualizzazione nelle chiamate
  static String formatCallTime(DateTime timestamp) {
    final localTime = convertFromServer(timestamp);
    return DateFormat('HH:mm').format(localTime);
  }
  
  /// Formatta una data per il raggruppamento delle chiamate
  static String formatCallDate(DateTime timestamp) {
    final localTime = convertFromServer(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final timestampDate = DateTime(localTime.year, localTime.month, localTime.day);
    
    if (timestampDate == today) {
      return 'Oggi';
    } else if (timestampDate == yesterday) {
      return 'Ieri';
    } else if (_isThisWeek(localTime)) {
      return 'Questa settimana';
    } else {
      return _formatDate(localTime);
    }
  }
  
  /// Verifica se una data è di questa settimana
  static bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return date.isAfter(startOfWeek.subtract(const Duration(days: 1)));
  }
  
  /// Formatta una data completa
  static String _formatDate(DateTime date) {
    final months = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  /// Debug: mostra informazioni timezone
  static void debugTimezone() {
    final now = DateTime.now();
    print('🌍 Timezone Debug:');
    print('   Server timezone: $serverTimezone');
    print('   Local timezone: ${now.timeZoneName}');
    print('   Local time: ${now.toString()}');
    print('   UTC time: ${now.toUtc().toString()}');
    print('   Timezone offset: ${now.timeZoneOffset}');
  }
}
