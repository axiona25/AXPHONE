import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Stati possibili per un utente
enum UserStatus {
  online,     // Utente loggato con connessione
  offline,    // Utente non loggato
  unreachable // Utente loggato ma senza connessione di rete
}

/// Servizio centralizzato per la gestione dello stato degli utenti
class UserStatusService extends ChangeNotifier {
  static UserStatusService? _instance;
  
  static UserStatusService getInstance() {
    _instance ??= UserStatusService._internal();
    return _instance!;
  }
  
  factory UserStatusService() => getInstance();
  
  UserStatusService._internal() {
    print('👥 UserStatusService - NUOVA ISTANZA CREATA (dovrebbe succedere solo una volta)');
    // CORREZIONE: Pre-inizializza stati comuni per evitare flash grigio
    _preInitializeCommonStatuses();
  }

  // Cache degli stati utenti - STATIC per persistenza globale
  static final Map<String, UserStatus> _userStatusCache = {};
  static final Map<String, DateTime> _lastSeenCache = {};
  
  // REAL-TIME: Stream controller per aggiornamenti immediati
  final StreamController<Map<String, UserStatus>> _statusStreamController = 
      StreamController<Map<String, UserStatus>>.broadcast();
  
  // Stream pubblico per ascoltare cambiamenti real-time
  Stream<Map<String, UserStatus>> get statusStream => _statusStreamController.stream;
  
  // Timer per aggiornamenti periodici
  Timer? _statusUpdateTimer;
  
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  static const Duration _updateInterval = Duration(seconds: 15);  // RIDOTTO: 15 secondi per evitare throttling
  static const Duration _offlineThreshold = Duration(minutes: 5);

  /// NUOVO: Pre-inizializza stati comuni per evitare flash grigio
  void _preInitializeCommonStatuses() {
    print('👥 UserStatusService - Pre-inizializzazione stati comuni...');
    final commonUserIds = ['1', '2', '3', '4', '5', '9', '10'];
    
    for (final userId in commonUserIds) {
      if (!_userStatusCache.containsKey(userId)) {
        // Assumi online per default invece di offline per evitare flash grigio
        _userStatusCache[userId] = UserStatus.online;
        _lastSeenCache[userId] = DateTime.now();
        print('👥 UserStatusService - Stato ONLINE pre-assegnato per utente $userId');
      }
    }
    
    print('👥 UserStatusService - ✅ Pre-inizializzazione completata: ${_userStatusCache.length} stati');
  }

  /// Inizializza il servizio
  Future<void> initialize() async {
    print('👥 UserStatusService - Inizializzazione...');
    await _loadCachedStatuses();
    _startPeriodicUpdates();
    print('👥 UserStatusService - ✅ Inizializzato');
  }

  /// Avvia aggiornamenti periodici degli stati
  void _startPeriodicUpdates() {
    _statusUpdateTimer?.cancel();
    _statusUpdateTimer = Timer.periodic(_updateInterval, (_) {
      _updateAllUserStatuses();
    });
  }

  /// Ferma il servizio
  @override
  void dispose() {
    _statusUpdateTimer?.cancel();
    _statusStreamController.close();
    print('👥 UserStatusService - Servizio fermato');
    super.dispose();
  }
  
  /// REAL-TIME: Notifica tutti i listener (ChangeNotifier + Stream)
  void _notifyAllListeners() {
    print('📢 UserStatusService._notifyAllListeners - Notificando TUTTI i listener...');
    print('📢 UserStatusService._notifyAllListeners - ChangeNotifier hasListeners: $hasListeners');
    print('📢 UserStatusService._notifyAllListeners - Stream hasListener: ${_statusStreamController.hasListener}');
    
    // 1. ChangeNotifier (widget tradizionali)
    notifyListeners();
    print('📢 ChangeNotifier notificato');
    
    // 2. Stream (widget real-time)
    if (!_statusStreamController.isClosed) {
      _statusStreamController.add(Map.from(_userStatusCache));
      print('📢 Stream notificato con ${_userStatusCache.length} stati');
    } else {
      print('⚠️ Stream controller è chiuso!');
    }
  }

  // Nota: addListener, removeListener e notifyListeners sono ereditati da ChangeNotifier

  /// Aggiorna lo stato di un utente (metodo pubblico per RealtimeStatusService)
  void updateUserStatus(String userId, UserStatus status) {
    _userStatusCache[userId] = status;
    _lastSeenCache[userId] = DateTime.now();
  }

  /// Ottiene lo stato di un utente
  UserStatus getUserStatus(String userId) {
    // CORREZIONE: Se non in cache, pre-inizializza come online per evitare flash grigio
    if (!_userStatusCache.containsKey(userId)) {
      print('👥 UserStatusService.getUserStatus - User $userId non in cache, pre-inizializzando come ONLINE');
      _userStatusCache[userId] = UserStatus.online;
      _lastSeenCache[userId] = DateTime.now();
    }
    
    final status = _userStatusCache[userId]!;
    print('👥 UserStatusService.getUserStatus - User $userId: ${getStatusText(status)}');
    return status;
  }

  /// Ottiene il colore per lo stato utente
  /// LOGICA CORRETTA COLORI:
  /// - Utente loggato = online (pallino verde)
  /// - Utente sloggato = offline (pallino grigio)
  /// - Utente che non ha rete = connessione down (pallino giallo)
  Color getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Verde - Utente loggato con connessione
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grigio - Utente sloggato
      case UserStatus.unreachable:
        return const Color(0xFFFFEB3B); // Giallo - Utente loggato senza connessione
    }
  }

  /// Ottiene il testo descrittivo per lo stato
  String getStatusText(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'Online'; // Verde - Loggato con connessione
      case UserStatus.offline:
        return 'Offline'; // Grigio - Sloggato
      case UserStatus.unreachable:
        return 'Connessione instabile'; // Giallo - Loggato senza connessione
    }
  }

  /// Aggiorna lo stato di tutti gli utenti dal server
  Future<void> _updateAllUserStatuses() async {
    try {
      print('👥 UserStatusService - Aggiornamento stati utenti...');
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        print('👥 UserStatusService - Nessun token disponibile');
        return;
      }
      
      print('👥 UserStatusService - Token trovato: ${token.substring(0, 20)}...');

      final response = await http.get(
        Uri.parse('$baseUrl/users/status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> statusData = json.decode(response.body);
        print('👥 UserStatusService - Ricevuti dati dal server: ${statusData.length} utenti');
        bool hasChanges = false;

        for (final userStatus in statusData) {
          final userId = userStatus['id'].toString();
          final userName = userStatus['name'] ?? 'Unknown';
          final isLoggedIn = userStatus['is_logged_in'] ?? false;
          final lastSeen = DateTime.tryParse(userStatus['last_seen'] ?? '');
          final hasConnection = userStatus['has_connection'] ?? false;
          final serverStatus = userStatus['status'] ?? 'unknown';

          print('👥 UserStatusService - Processing User $userId ($userName):');
          print('   Server says: isLoggedIn=$isLoggedIn, hasConnection=$hasConnection, status=$serverStatus');

          final newStatus = _determineUserStatus(isLoggedIn, lastSeen, hasConnection);
          final oldStatus = _userStatusCache[userId];

          print('   Determined status: ${getStatusText(newStatus)} (was: ${getStatusText(oldStatus ?? UserStatus.offline)})');

          if (oldStatus != newStatus) {
            _userStatusCache[userId] = newStatus;
            hasChanges = true;
            print('   ✅ CAMBIO STATO - User $userId ($userName): ${getStatusText(oldStatus ?? UserStatus.offline)} → ${getStatusText(newStatus)}');
          } else {
            print('   ⏸️ NESSUN CAMBIO - User $userId ($userName) rimane: ${getStatusText(oldStatus ?? UserStatus.offline)}');
          }

          if (lastSeen != null) {
            _lastSeenCache[userId] = lastSeen;
          }
        }

        if (hasChanges) {
          await _saveCachedStatuses();
          print('📢 UserStatusService - NOTIFICANDO LISTENER per aggiornamento UI...');
          _notifyAllListeners();
          print('👥 UserStatusService - Stati aggiornati per ${statusData.length} utenti');
        } else {
          print('👥 UserStatusService - Nessun cambio negli stati, ma FORZANDO notifica per real-time...');
        }
        
        // CORREZIONE CRITICA: Notifica SEMPRE i listener, indipendentemente dai cambiamenti
        print('📢 UserStatusService - FORZANDO notifica listener per real-time...');
        _notifyAllListeners();
      } else {
        print('👥 UserStatusService - Errore response: ${response.statusCode}');
      }
    } catch (e) {
      print('👥 UserStatusService - Errore aggiornamento: $e');
    }
  }

  /// Determina lo stato dell'utente basato sui criteri
  /// LOGICA CORRETTA:
  /// - Utente loggato = online (pallino verde)
  /// - Utente sloggato = offline (pallino grigio) 
  /// - Utente che non ha rete = connessione down (pallino giallo)
  UserStatus _determineUserStatus(bool isLoggedIn, DateTime? lastSeen, bool hasConnection) {
    print('🔍 _determineUserStatus: isLoggedIn=$isLoggedIn, hasConnection=$hasConnection');
    
    // LOGICA PRIORITARIA: Se non è loggato, è sempre offline
    if (!isLoggedIn) {
      print('🔍 _determineUserStatus: → OFFLINE (non loggato)');
      return UserStatus.offline;
    }

    // Se è loggato, controlla la connessione
    if (isLoggedIn) {
      if (hasConnection) {
        print('🔍 _determineUserStatus: → ONLINE (loggato + connessione)');
        return UserStatus.online;  // Verde
      } else {
        print('🔍 _determineUserStatus: → UNREACHABLE (loggato + no connessione)');
        return UserStatus.unreachable;  // Giallo
      }
    }

    // Fallback (non dovrebbe mai arrivare qui)
    print('🔍 _determineUserStatus: → OFFLINE (fallback)');
    return UserStatus.offline;
  }

  /// Aggiorna lo stato del proprio utente
  Future<void> updateMyStatus(UserStatus status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      final userId = prefs.getString('securevox_current_user_id');
      
      if (token == null || userId == null) return;

      final response = await http.post(
        Uri.parse('$baseUrl/users/status/update/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'status': status.name,
          'has_connection': status != UserStatus.unreachable,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _userStatusCache[userId] = status;
        _lastSeenCache[userId] = DateTime.now();
        await _saveCachedStatuses();
        notifyListeners();
        print('👥 UserStatusService - Stato aggiornato: ${getStatusText(status)}');
      }
    } catch (e) {
      print('👥 UserStatusService - Errore aggiornamento stato: $e');
    }
  }

  /// Carica gli stati dalla cache locale
  Future<void> _loadCachedStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('user_status_cache');
      
      if (cachedData != null) {
        final Map<String, dynamic> cache = json.decode(cachedData);
        
        for (final entry in cache.entries) {
          final userId = entry.key;
          final statusName = entry.value['status'] as String?;
          final lastSeenStr = entry.value['last_seen'] as String?;
          
          if (statusName != null) {
            _userStatusCache[userId] = UserStatus.values.firstWhere(
              (s) => s.name == statusName,
              orElse: () => UserStatus.offline,
            );
          }
          
          if (lastSeenStr != null) {
            _lastSeenCache[userId] = DateTime.tryParse(lastSeenStr) ?? DateTime.now();
          }
        }
        
        print('👥 UserStatusService - Caricati ${_userStatusCache.length} stati dalla cache');
      }
    } catch (e) {
      print('👥 UserStatusService - Errore caricamento cache: $e');
    }
  }

  /// Salva gli stati nella cache locale
  Future<void> _saveCachedStatuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = <String, Map<String, String>>{};
      
      for (final entry in _userStatusCache.entries) {
        cacheData[entry.key] = {
          'status': entry.value.name,
          'last_seen': (_lastSeenCache[entry.key] ?? DateTime.now()).toIso8601String(),
        };
      }
      
      await prefs.setString('user_status_cache', json.encode(cacheData));
    } catch (e) {
      print('👥 UserStatusService - Errore salvataggio cache: $e');
    }
  }

  /// Forza un aggiornamento immediato SENZA pulire la cache
  Future<void> forceUpdate() async {
    print('🔄 UserStatusService.forceUpdate - FORZANDO aggiornamento stati...');
    
    // CORREZIONE: NON pulire la cache per evitare flash grigio
    // Mantieni gli stati esistenti e aggiorna solo dal server
    print('🔄 UserStatusService.forceUpdate - Aggiornamento senza pulire cache...');
    
    await _updateAllUserStatuses();
    
    // CORREZIONE: Forza sempre notifica listener anche se non ci sono "cambi"
    print('📢 UserStatusService.forceUpdate - FORZANDO notifica listener...');
    _notifyAllListeners();
    
    // CORREZIONE AGGRESSIVA: Forza aggiornamento dopo un breve delay
    await Future.delayed(const Duration(milliseconds: 500));
    print('📢 UserStatusService.forceUpdate - SECONDA notifica listener (delay)...');
    _notifyAllListeners();
  }
  
  /// Debug: Mostra lo stato attuale della cache
  void debugPrintCache() {
    print('🔍 UserStatusService.debugPrintCache:');
    print('   Cache size: ${_userStatusCache.length}');
    for (final entry in _userStatusCache.entries) {
      print('   User ${entry.key}: ${getStatusText(entry.value)}');
    }
  }

  /// METODO DI TEST: Imposta stati manuali per debug
  void setTestStatuses() {
    print('🧪 UserStatusService - Impostazione stati di test...');
    _userStatusCache['2'] = UserStatus.online;   // Raffaele online
    _userStatusCache['3'] = UserStatus.offline;  // Riccardo offline (come da server)
    notifyListeners();
    print('🧪 UserStatusService - Stati di test impostati: Raffaele online, Riccardo offline');
  }

  /// Ottiene tutti gli utenti online
  List<String> getOnlineUsers() {
    return _userStatusCache.entries
        .where((entry) => entry.value == UserStatus.online)
        .map((entry) => entry.key)
        .toList();
  }

  /// Ottiene tutti gli utenti con un determinato stato
  List<String> getUsersByStatus(UserStatus status) {
    return _userStatusCache.entries
        .where((entry) => entry.value == status)
        .map((entry) => entry.key)
        .toList();
  }

  /// Verifica se un utente è online
  bool isUserOnline(String userId) {
    return getUserStatus(userId) == UserStatus.online;
  }

  /// Verifica se un utente è raggiungibile (online o unreachable)
  bool isUserReachable(String userId) {
    final status = getUserStatus(userId);
    return status == UserStatus.online || status == UserStatus.unreachable;
  }

  /// Imposta tutti gli utenti come offline (per token non validi)
  void setAllUsersOffline() {
    print('👥 UserStatusService - Impostazione tutti gli utenti offline...');
    final List<String> userIds = List.from(_userStatusCache.keys);
    
    bool hasUpdates = false;
    for (final userId in userIds) {
      if (_userStatusCache[userId] != UserStatus.offline) {
        _userStatusCache[userId] = UserStatus.offline;
        hasUpdates = true;
        print('👥 UserStatusService - User $userId: → Offline (token non valido)');
      }
    }
    
    if (hasUpdates) {
      notifyListeners();
      print('👥 UserStatusService - Tutti gli utenti impostati offline');
    }
  }

}
