import 'package:intl/intl.dart';
import 'timezone_service.dart';

class DateFormatterService {
  static String formatChatTimestamp(DateTime timestamp) {
    return TimezoneService.formatChatTime(timestamp);
  }
  
  static String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Lunedì';
      case 2:
        return 'Martedì';
      case 3:
        return 'Mercoledì';
      case 4:
        return 'Giovedì';
      case 5:
        return 'Venerdì';
      case 6:
        return 'Sabato';
      case 7:
        return 'Domenica';
      default:
        return '';
    }
  }
  
  // Metodo per test - genera timestamp casuali per i test
  static DateTime generateTestTimestamp(int hoursAgo) {
    return DateTime.now().subtract(Duration(hours: hoursAgo));
  }
  
  // Metodo per test - genera timestamp per giorni specifici
  static DateTime generateTestTimestampForDay(int daysAgo) {
    return DateTime.now().subtract(Duration(days: daysAgo));
  }
}
