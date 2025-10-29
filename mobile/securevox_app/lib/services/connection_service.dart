import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectionService extends ChangeNotifier {
  static final ConnectionService _instance = ConnectionService._internal();
  factory ConnectionService() => _instance;
  ConnectionService._internal();

  bool _isOnline = true; // Default to online for now
  bool _isAppActive = true;

  bool get isOnline => _isOnline;
  bool get isAppActive => _isAppActive;
  bool get isUserOnline => _isOnline && _isAppActive;

  // Colori per gli indicatori
  static const onlineColor = 0xFF26A884; // Verde originale
  static const offlineColor = 0xFF9E9E9E; // Grigio

  Future<void> initialize() async {
    // Controlla la connessione di rete
    _isOnline = await hasNetworkConnection();
    _isAppActive = true;
    debugPrint('ConnectionService inizializzato - stato: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    notifyListeners();
  }

  // Gestisce quando l'app va in background
  void onAppPaused() {
    _isAppActive = false;
    debugPrint('App in background - stato offline');
    // Imposta offline quando l'app va in background
    notifyListeners();
  }

  // Gestisce quando l'app torna attiva
  Future<void> onAppResumed() async {
    _isAppActive = true;
    _isOnline = await hasNetworkConnection();
    debugPrint('App attiva - stato: ${_isOnline ? "ONLINE" : "OFFLINE"}');
    notifyListeners();
  }

  // Gestisce quando l'utente si disconnette
  void onUserLogout() {
    _isOnline = false;
    _isAppActive = false;
    debugPrint('Utente disconnesso - stato offline');
    notifyListeners();
  }

  // Gestisce quando l'app crasha
  void onAppCrashed() {
    _isOnline = false;
    _isAppActive = false;
    debugPrint('App crashato - stato offline');
    notifyListeners();
  }

  // Controlla se c'è connessione di rete
  Future<bool> hasNetworkConnection() async {
    try {
      // Prova a fare una richiesta HTTP per verificare la connessione
      final response = await http.get(Uri.parse('https://www.google.com'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}