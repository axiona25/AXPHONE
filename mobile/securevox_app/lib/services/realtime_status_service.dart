import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'user_status_service.dart';

/// Servizio per aggiornamenti real-time degli stati utenti
class RealtimeStatusService {
  static final RealtimeStatusService _instance = RealtimeStatusService._internal();
  factory RealtimeStatusService() => _instance;
  RealtimeStatusService._internal();

  Timer? _pollingTimer;
  Timer? _heartbeatTimer;
  bool _isActive = false;
  
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  static const Duration _pollingInterval = Duration(seconds: 10); // RIDOTTO: 10 secondi per evitare throttling
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  /// Inizializza il servizio real-time
  Future<void> initialize() async {
    if (_isActive) return;
    
    print('📡 RealtimeStatusService - Inizializzazione...');
    _isActive = true;
    
    // Avvia polling frequente per stati
    _startStatusPolling();
    
    // Avvia heartbeat per mantenere il proprio stato
    _startHeartbeat();
    
    print('📡 RealtimeStatusService - ✅ Inizializzato');
  }

  /// Ferma il servizio
  void dispose() {
    print('📡 RealtimeStatusService - Stopping...');
    _isActive = false;
    _pollingTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  /// Avvia polling frequente degli stati
  void _startStatusPolling() {
    print('📡 RealtimeStatusService - Avvio polling stati ogni ${_pollingInterval.inSeconds}s...');
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) async {
      if (!_isActive) return;
      print('📡 RealtimeStatusService - Timer polling scattato');
      await _pollUserStatuses();
    });
    
    // Esegui subito il primo poll
    print('📡 RealtimeStatusService - Avvio polling immediato...');
    _pollUserStatuses();
  }

  /// Avvia heartbeat per mantenere il proprio stato online
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) async {
      if (!_isActive) return;
      await _sendHeartbeat();
    });
  }

  /// Polling degli stati utenti
  Future<void> _pollUserStatuses() async {
    try {
      print('📡 RealtimeStatusService - Avvio polling stati utenti...');
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        print('📡 RealtimeStatusService - Nessun token disponibile per polling');
        // Debug: controlla tutte le chiavi disponibili
        final keys = prefs.getKeys();
        print('📡 RealtimeStatusService - Chiavi disponibili: $keys');
        return;
      }
      
      print('📡 RealtimeStatusService - Token trovato: ${token.substring(0, 10)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/users/status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> statusData = json.decode(response.body);
        print('📡 RealtimeStatusService - Ricevuti stati per ${statusData.length} utenti');
        
        // Aggiorna UserStatusService con i nuovi dati
        bool hasUpdates = false;
        
        for (final userStatus in statusData) {
          final userId = userStatus['id'].toString();
          final isLoggedIn = userStatus['is_logged_in'] ?? false;
          final lastSeen = DateTime.tryParse(userStatus['last_seen'] ?? '');
          final hasConnection = userStatus['has_connection'] ?? false;
          
          // DEBUG: Log dettagliato per ogni utente
          print('📡 DEBUG - User $userId:');
          print('  - is_logged_in: $isLoggedIn');
          print('  - has_connection: $hasConnection');
          print('  - last_seen: ${userStatus['last_seen']}');
          
          final oldStatus = UserStatusService().getUserStatus(userId);
          final newStatus = _determineUserStatus(isLoggedIn, lastSeen, hasConnection);
          
          print('  - oldStatus: ${UserStatusService().getStatusText(oldStatus)}');
          print('  - newStatus: ${UserStatusService().getStatusText(newStatus)}');
          
          if (oldStatus != newStatus) {
            UserStatusService().updateUserStatus(userId, newStatus);
            hasUpdates = true;
            print('📡 CAMBIO STATO - User $userId: ${UserStatusService().getStatusText(oldStatus)} → ${UserStatusService().getStatusText(newStatus)}');
          } else {
            print('📡 NESSUN CAMBIO - User $userId rimane: ${UserStatusService().getStatusText(oldStatus)}');
          }
        }
        
        if (hasUpdates) {
          // Notifica i listener per aggiornamento UI
          UserStatusService().notifyListeners();
          print('📡 RealtimeStatusService - Stati aggiornati in real-time');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        print('📡 RealtimeStatusService - Token non valido (${response.statusCode}), fermo il servizio');
        // Token non valido, ferma il servizio per evitare spam
        dispose();
        
        // Imposta tutti gli utenti come offline se il token non è valido
        UserStatusService().setAllUsersOffline();
      } else {
        print('📡 RealtimeStatusService - Errore HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('📡 RealtimeStatusService - Errore polling: $e');
    }
  }

  /// Invia heartbeat per mantenere stato online
  Future<void> _sendHeartbeat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) return;

      // Determina il proprio stato basato sulla connettività
      final hasConnection = await _checkConnectivity();
      final status = hasConnection ? 'online' : 'unreachable';

      final response = await http.post(
        Uri.parse('$baseUrl/users/status/update/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'status': status,
          'has_connection': hasConnection,
          'last_seen': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('📡 RealtimeStatusService - Heartbeat sent: $status');
      }
    } catch (e) {
      print('📡 RealtimeStatusService - Errore heartbeat: $e');
      // In caso di errore di rete, aggiorna il proprio stato come unreachable
      await UserStatusService().updateMyStatus(UserStatus.unreachable);
    }
  }

  /// Verifica connettività di rete
  Future<bool> _checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health/'),
      ).timeout(const Duration(seconds: 3));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Determina lo stato dell'utente basato sui criteri
  /// LOGICA CORRETTA:
  /// - Utente loggato = online (pallino verde)
  /// - Utente sloggato = offline (pallino grigio) 
  /// - Utente che non ha rete = connessione down (pallino giallo)
  UserStatus _determineUserStatus(bool isLoggedIn, DateTime? lastSeen, bool hasConnection) {
    print('📡 _determineUserStatus: isLoggedIn=$isLoggedIn, hasConnection=$hasConnection');
    
    // LOGICA PRIORITARIA: Se non è loggato, è sempre offline
    if (!isLoggedIn) {
      print('📡 _determineUserStatus: → OFFLINE (non loggato)');
      return UserStatus.offline;
    }

    // Se è loggato, controlla la connessione
    if (isLoggedIn) {
      if (hasConnection) {
        print('📡 _determineUserStatus: → ONLINE (loggato + connessione)');
        return UserStatus.online;  // Verde
      } else {
        print('📡 _determineUserStatus: → UNREACHABLE (loggato + no connessione)');
        return UserStatus.unreachable;  // Giallo
      }
    }

    // Fallback (non dovrebbe mai arrivare qui)
    print('📡 _determineUserStatus: → OFFLINE (fallback)');
    return UserStatus.offline;
  }

  /// Notifica cambio di stato per un utente specifico
  Future<void> notifyStatusChange(String userId, UserStatus newStatus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) return;

      // In un'implementazione completa, questo invierebbe una notifica push
      // o userebbe WebSocket per notificare altri client
      print('📡 RealtimeStatusService - Notificando cambio stato per $userId: ${UserStatusService().getStatusText(newStatus)}');
      
    } catch (e) {
      print('📡 RealtimeStatusService - Errore notifica: $e');
    }
  }

  /// Forza aggiornamento immediato
  Future<void> forceUpdate() async {
    if (!_isActive) return;
    await _pollUserStatuses();
  }

  /// Imposta stato offline quando l'app va in background
  Future<void> setOfflineOnBackground() async {
    await UserStatusService().updateMyStatus(UserStatus.offline);
    print('📡 RealtimeStatusService - Stato impostato offline (background)');
  }

  /// Riprende stato online quando l'app torna attiva
  Future<void> setOnlineOnForeground() async {
    final hasConnection = await _checkConnectivity();
    final status = hasConnection ? UserStatus.online : UserStatus.unreachable;
    await UserStatusService().updateMyStatus(status);
    
    // Forza aggiornamento immediato
    await forceUpdate();
    
    print('📡 RealtimeStatusService - Stato ripristinato (foreground): ${UserStatusService().getStatusText(status)}');
  }
}
