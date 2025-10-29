import 'dart:async';
import 'package:flutter/foundation.dart';

/// Servizio di emergenza per fermare loop di polling
class EmergencyPollingFix extends ChangeNotifier {
  static final EmergencyPollingFix _instance = EmergencyPollingFix._internal();
  factory EmergencyPollingFix() => _instance;
  EmergencyPollingFix._internal();
  
  bool _emergencyStopActive = false;
  Timer? _emergencyTimer;
  
  /// Attiva stop di emergenza per tutti i servizi di polling
  void activateEmergencyStop() {
    if (_emergencyStopActive) return;
    
    print('🚨 EMERGENZA: Attivando stop polling per loop infinito');
    _emergencyStopActive = true;
    
    // Stop automatico dopo 30 secondi
    _emergencyTimer = Timer(const Duration(seconds: 30), () {
      deactivateEmergencyStop();
    });
    
    notifyListeners();
  }
  
  /// Disattiva stop di emergenza
  void deactivateEmergencyStop() {
    print('✅ EMERGENZA: Disattivando stop polling');
    _emergencyStopActive = false;
    _emergencyTimer?.cancel();
    notifyListeners();
  }

  /// Reset completo (per restart servizi)
  void reset() {
    print('🔄 EMERGENZA: Reset completo');
    deactivateEmergencyStop();
  }
  
  /// Verifica se il polling deve essere fermato
  bool get shouldStopPolling => _emergencyStopActive;
  
  /// Verifica se un errore richiede stop di emergenza
  bool shouldActivateEmergencyStop(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Attiva per errori di autenticazione ripetuti
    if (errorString.contains('401') || 
        errorString.contains('autenticazione') ||
        errorString.contains('unauthorized')) {
      return true;
    }
    
    return false;
  }
}
