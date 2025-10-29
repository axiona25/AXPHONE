import '../models/call_model.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';
import 'real_call_service.dart';
import 'timezone_service.dart';
import 'auth_service.dart';

class CallService extends ChangeNotifier {
  AuthService? _authService;
  
  // Setter per iniettare il servizio di autenticazione
  void setAuthService(AuthService authService) {
    _authService = authService;
  }
  
  // Ottiene l'ID dell'utente corrente
  String? get _currentUserId => _authService?.currentUser?.id;
  
  static List<CallModel> _mockCalls = [
    // Chiamate di oggi - Esempi con Raffaele e Riccardo
    // Chiamata persa: Riccardo chiama Raffaele ma Raffaele non risponde
    CallModel(
      id: '1',
      contactName: 'Riccardo Dicamillo',
      contactAvatar: '',
      contactId: '5008b261-468a-4b04-9ace-3ad48619c20d', // ID Riccardo
      callerId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo chiama
      calleeId: '2', // Raffaele riceve
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      type: CallType.audio,
      direction: CallDirection.missed,
      status: CallStatus.missed,
      duration: const Duration(seconds: 0),
      phoneNumber: '+39 123 456 7890',
    ),
    // Chiamata in uscita: Raffaele chiama Riccardo
    CallModel(
      id: '2',
      contactName: 'Riccardo Dicamillo',
      contactAvatar: '',
      contactId: '5008b261-468a-4b04-9ace-3ad48619c20d', // ID Riccardo
      callerId: '2', // Raffaele chiama
      calleeId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo riceve
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: CallType.video,
      direction: CallDirection.outgoing,
      status: CallStatus.completed,
      duration: const Duration(minutes: 15, seconds: 30),
      phoneNumber: '+39 234 567 8901',
    ),
    // Chiamata in entrata: Riccardo chiama Raffaele
    CallModel(
      id: '3',
      contactName: 'Riccardo Dicamillo',
      contactAvatar: '',
      contactId: '5008b261-468a-4b04-9ace-3ad48619c20d', // ID Riccardo
      callerId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo chiama
      calleeId: '2', // Raffaele riceve
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      type: CallType.audio,
      direction: CallDirection.incoming,
      status: CallStatus.completed,
      duration: const Duration(minutes: 8, seconds: 45),
      phoneNumber: '+39 345 678 9012',
    ),
    
    // Chiamate di ieri - Esempi con Raffaele e Riccardo
    // Chiamata persa: Raffaele chiama Riccardo ma Riccardo non risponde
    CallModel(
      id: '4',
      contactName: 'Raffaele Amoroso',
      contactAvatar: '',
      contactId: '2', // ID Raffaele
      callerId: '2', // Raffaele chiama
      calleeId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo riceve
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      type: CallType.video,
      direction: CallDirection.missed,
      status: CallStatus.missed,
      duration: const Duration(seconds: 0),
      phoneNumber: '+39 456 789 0123',
    ),
    // Chiamata in uscita: Riccardo chiama Raffaele
    CallModel(
      id: '5',
      contactName: 'Raffaele Amoroso',
      contactAvatar: '',
      contactId: '2', // ID Raffaele
      callerId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo chiama
      calleeId: '2', // Raffaele riceve
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      type: CallType.audio,
      direction: CallDirection.outgoing,
      status: CallStatus.completed,
      duration: const Duration(minutes: 45, seconds: 12),
      phoneNumber: '+39 567 890 1234',
    ),
    // Chiamata in entrata: Raffaele chiama Riccardo
    CallModel(
      id: '6',
      contactName: 'Raffaele Amoroso',
      contactAvatar: '',
      contactId: '2', // ID Raffaele
      callerId: '2', // Raffaele chiama
      calleeId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo riceve
      timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      type: CallType.video,
      direction: CallDirection.incoming,
      status: CallStatus.completed,
      duration: const Duration(minutes: 22, seconds: 8),
      phoneNumber: '+39 678 901 2345',
    ),
    
    // Chiamate della settimana scorsa - Esempi con Raffaele e Riccardo
    // Chiamata persa: Riccardo chiama Raffaele ma Raffaele non risponde
    CallModel(
      id: '7',
      contactName: 'Riccardo Dicamillo',
      contactAvatar: '',
      contactId: '5008b261-468a-4b04-9ace-3ad48619c20d', // ID Riccardo
      callerId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo chiama
      calleeId: '2', // Raffaele riceve
      timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 1)),
      type: CallType.audio,
      direction: CallDirection.missed,
      status: CallStatus.missed,
      duration: const Duration(seconds: 0),
      phoneNumber: '+39 789 012 3456',
    ),
    // Chiamata in uscita: Raffaele chiama Riccardo
    CallModel(
      id: '8',
      contactName: 'Riccardo Dicamillo',
      contactAvatar: '',
      contactId: '5008b261-468a-4b04-9ace-3ad48619c20d', // ID Riccardo
      callerId: '2', // Raffaele chiama
      calleeId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo riceve
      timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 3)),
      type: CallType.video,
      direction: CallDirection.outgoing,
      status: CallStatus.completed,
      duration: const Duration(minutes: 12, seconds: 33),
      phoneNumber: '+39 890 123 4567',
    ),
    // Chiamata in entrata: Riccardo chiama Raffaele
    CallModel(
      id: '9',
      contactName: 'Riccardo Dicamillo',
      contactAvatar: '',
      contactId: '5008b261-468a-4b04-9ace-3ad48619c20d', // ID Riccardo
      callerId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo chiama
      calleeId: '2', // Raffaele riceve
      timestamp: DateTime.now().subtract(const Duration(days: 4, hours: 2)),
      type: CallType.audio,
      direction: CallDirection.incoming,
      status: CallStatus.completed,
      duration: const Duration(minutes: 6, seconds: 55),
      phoneNumber: '+39 901 234 5678',
    ),
    // Chiamata persa: Raffaele chiama Riccardo ma Riccardo non risponde
    CallModel(
      id: '10',
      contactName: 'Raffaele Amoroso',
      contactAvatar: '',
      contactId: '2', // ID Raffaele
      callerId: '2', // Raffaele chiama
      calleeId: '5008b261-468a-4b04-9ace-3ad48619c20d', // Riccardo riceve
      timestamp: DateTime.now().subtract(const Duration(days: 5, hours: 4)),
      type: CallType.video,
      direction: CallDirection.missed,
      status: CallStatus.missed,
      duration: const Duration(seconds: 0),
      phoneNumber: '+39 012 345 6789',
    ),
  ];

  List<CallModel> _filteredCalls = [];
  String _searchQuery = '';
  bool _isLoading = false;

  CallService() {
    _filteredCalls = [];
    // Non caricare immediatamente per evitare loop
    // _loadCallsFromBackend();
  }

  List<CallModel> getAllCalls() {
    return List.from(_filteredCalls);
  }

  /// Carica le chiamate dal backend
  Future<void> _loadCallsFromBackend() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      print('📞 CallService._loadCallsFromBackend - Caricando chiamate dal backend...');
      final calls = await RealCallService.getCalls();
      _filteredCalls = _filterCallsForCurrentUser(calls);
      _sortCallsByDate();
      print('📞 CallService._loadCallsFromBackend - Caricate ${_filteredCalls.length} chiamate per utente corrente');
    } catch (e) {
      print('📞 CallService._loadCallsFromBackend - Errore: $e');
      // Fallback ai dati mock se il backend non è disponibile
      _filteredCalls = _filterCallsForCurrentUser(_mockCalls);
      _sortCallsByDate();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ricarica le chiamate dal backend
  Future<void> refreshCalls() async {
    print('📞 CallService.refreshCalls - Ricaricando chiamate...');
    RealCallService.invalidateCache();
    await _loadCallsFromBackend();
  }

  /// Verifica se sta caricando
  bool get isLoading => _isLoading;

  /// Filtra le chiamate in base all'utente corrente
  List<CallModel> _filterCallsForCurrentUser(List<CallModel> calls) {
    if (_currentUserId == null) {
      print('📞 CallService._filterCallsForCurrentUser - Nessun utente corrente, mostrando tutte le chiamate');
      return calls;
    }

    print('📞 CallService._filterCallsForCurrentUser - Filtrando chiamate per utente: $_currentUserId');
    
    final filteredCalls = calls.where((call) {
      // Una chiamata è rilevante per l'utente corrente se:
      // 1. L'utente corrente è il chiamante (callerId = currentUserId)
      // 2. L'utente corrente è il ricevente (calleeId = currentUserId)
      
      final isCaller = call.callerId == _currentUserId;
      final isCallee = call.calleeId == _currentUserId;
      
      if (isCaller || isCallee) {
        print('📞 CallService._filterCallsForCurrentUser - Chiamata ${call.id} rilevante: isCaller=$isCaller, isCallee=$isCallee');
        return true;
      }
      
      return false;
    }).toList();

    print('📞 CallService._filterCallsForCurrentUser - Filtrate ${filteredCalls.length} chiamate da ${calls.length} totali');
    return filteredCalls;
  }

  /// Inizializza le chiamate se non sono ancora state caricate
  Future<void> initializeCalls() async {
    if (_filteredCalls.isEmpty && !_isLoading) {
      await _loadCallsFromBackend();
    }
  }

  List<CallModel> searchCalls(String query) {
    _searchQuery = query.toLowerCase();
    
    // Prima filtra per utente corrente, poi per query di ricerca
    List<CallModel> userFilteredCalls = _filterCallsForCurrentUser(_mockCalls);
    
    if (_searchQuery.isEmpty) {
      // Se non c'è query, mostra tutte le chiamate dell'utente corrente
      _filteredCalls = List.from(userFilteredCalls);
    } else {
      // Filtra le chiamate dell'utente corrente per query di ricerca
      _filteredCalls = userFilteredCalls.where((call) {
        return call.contactName.toLowerCase().contains(_searchQuery);
      }).toList();
    }
    _sortCallsByDate();
    notifyListeners();
    return _filteredCalls;
  }

  Map<String, List<CallModel>> getGroupedCalls() {
    final Map<String, List<CallModel>> grouped = {};
    
    for (final call in _filteredCalls) {
      final date = call.timestamp;
      String groupKey;
      
      if (_isToday(date)) {
        groupKey = 'Oggi';
      } else if (_isYesterday(date)) {
        groupKey = 'Ieri';
      } else if (_isThisWeek(date)) {
        groupKey = 'Questa settimana';
      } else {
        groupKey = _formatDate(date);
      }
      
      if (!grouped.containsKey(groupKey)) {
        grouped[groupKey] = [];
      }
      grouped[groupKey]!.add(call);
    }
    
    return grouped;
  }

  void _sortCallsByDate() {
    _filteredCalls.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  bool _isToday(DateTime date) {
    final localDate = TimezoneService.convertFromServer(date);
    final now = DateTime.now();
    return localDate.year == now.year &&
           localDate.month == now.month &&
           localDate.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final localDate = TimezoneService.convertFromServer(date);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return localDate.year == yesterday.year &&
           localDate.month == yesterday.month &&
           localDate.day == yesterday.day;
  }

  bool _isThisWeek(DateTime date) {
    final localDate = TimezoneService.convertFromServer(date);
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return localDate.isAfter(startOfWeek.subtract(const Duration(days: 1)));
  }

  String _formatDate(DateTime date) {
    final localDate = TimezoneService.convertFromServer(date);
    final months = [
      'Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
      'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'
    ];
    return '${localDate.day} ${months[localDate.month - 1]} ${localDate.year}';
  }

  String formatDuration(Duration duration) {
    if (duration.inSeconds == 0) {
      return '';
    }
    
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String formatTime(DateTime timestamp) {
    return TimezoneService.formatCallTime(timestamp);
  }

  // Avvia una chiamata usando il backend
  Future<void> startCall(CallModel call) async {
    try {
      print('📞 CallService.startCall - Avvio chiamata con ${call.contactName}');
      
      // Estrai l'ID del contatto dal nome (per ora usiamo un mapping semplice)
      String calleeId = _extractUserIdFromName(call.contactName);
      
      final success = await RealCallService.createCall(
        calleeId: calleeId,
        callType: call.type,
        phoneNumber: call.phoneNumber,
      );
      
      if (success) {
        print('📞 CallService.startCall - Chiamata creata con successo');
        // Ricarica le chiamate per aggiornare la lista
        await refreshCalls();
      } else {
        print('📞 CallService.startCall - Errore nella creazione della chiamata');
      }
    } catch (e) {
      print('📞 CallService.startCall - Errore: $e');
    }
  }

  /// Estrae l'ID utente dal nome del contatto (mapping semplice)
  String _extractUserIdFromName(String contactName) {
    // Mapping semplice per i nomi noti
    switch (contactName.toLowerCase()) {
      case 'riccardo dicamillo':
        return '5008b261-468a-4b04-9ace-3ad48619c20d';
      case 'raffaele amoroso':
        return '2';
      case 'test user':
        return '3';
      default:
        // Per nomi sconosciuti, usa un ID generico
        return 'unknown';
    }
  }

  /// Determina il nome del contatto da mostrare in base alla prospettiva dell'utente corrente
  String getContactNameForCurrentUser(CallModel call) {
    if (_currentUserId == null) {
      return call.contactName;
    }

    // Se l'utente corrente è il chiamante, mostra il nome del ricevente
    if (call.callerId == _currentUserId) {
      return call.contactName; // Il contactName è già il nome del ricevente
    }
    
    // Se l'utente corrente è il ricevente, mostra il nome del chiamante
    if (call.calleeId == _currentUserId) {
      return call.contactName; // Il contactName è già il nome del chiamante
    }

    return call.contactName;
  }

  /// Determina la direzione della chiamata in base alla prospettiva dell'utente corrente
  CallDirection getCallDirectionForCurrentUser(CallModel call) {
    if (_currentUserId == null) {
      return call.direction;
    }

    // Se l'utente corrente è il chiamante, la chiamata è in uscita
    if (call.callerId == _currentUserId) {
      return CallDirection.outgoing;
    }
    
    // Se l'utente corrente è il ricevente, la chiamata è in entrata
    if (call.calleeId == _currentUserId) {
      return call.direction; // Mantieni la direzione originale (incoming/missed)
    }

    return call.direction;
  }
}
