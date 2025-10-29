import '../models/user_model.dart';
import 'real_user_service.dart';
import 'auth_service.dart';

class UserService {
  static List<UserModel> _registeredUsers = [];
  static String? _currentUserId; // Cache per l'ID dell'utente corrente

  // Ottiene gli utenti reali dal database
  static Future<List<UserModel>> getRegisteredUsers() async {
    try {
      return await RealUserService.getRealUsers();
    } catch (e) {
      print('Errore nel recupero utenti reali: $e');
      // Fallback ai dati mock in caso di errore
      if (_registeredUsers.isEmpty) {
        _registeredUsers = _generateMockUsers();
      }
      return List.from(_registeredUsers);
    }
  }

  // Ottiene gli utenti reali dal database ESCLUDENDO l'utente corrente e l'admin
  static Future<List<UserModel>> getRegisteredUsersExcludingCurrent() async {
    try {
      final users = await RealUserService.getRealUsers();
      return _excludeCurrentUser(users);
    } catch (e) {
      print('Errore nel recupero utenti reali: $e');
      // Fallback ai dati mock in caso di errore
      if (_registeredUsers.isEmpty) {
        _registeredUsers = _generateMockUsers();
      }
      return _excludeCurrentUser(List.from(_registeredUsers));
    }
  }

  // Metodo sincrono per compatibilità (usa cache se disponibile)
  static List<UserModel> getRegisteredUsersSync() {
    if (_registeredUsers.isEmpty) {
      _registeredUsers = _generateMockUsers();
    }
    return List.from(_registeredUsers);
  }

  // Metodo sincrono per compatibilità ESCLUDENDO l'utente corrente e l'admin
  static List<UserModel> getRegisteredUsersExcludingCurrentSync() {
    if (_registeredUsers.isEmpty) {
      _registeredUsers = _generateMockUsers();
    }
    return _excludeCurrentUser(List.from(_registeredUsers));
  }

  // Metodo helper per escludere l'utente corrente e l'admin dalla lista
  static List<UserModel> _excludeCurrentUser(List<UserModel> users) {
    try {
      // Ottieni l'utente corrente (versione semplificata)
      final currentUserId = getCurrentUserIdSync();
      
      // Filtra l'utente corrente e l'admin cvox
      final filteredUsers = users.where((user) {
        // Escludi l'utente corrente se disponibile
        if (currentUserId != null && user.id == currentUserId) {
          return false;
        }
        
        // Escludi sempre l'admin cvox (riconoscibile dall'email)
        if (user.email.toLowerCase() == 'admin@securevox.com') {
          return false;
        }
        
        // Escludi anche per username se disponibile
        if (user.email.toLowerCase() == 'admin' || user.name.toLowerCase() == 'admin') {
          return false;
        }
        
        return true;
      }).toList();
      return filteredUsers;
    } catch (e) {
      print('❌ Errore nell\'esclusione utente corrente e admin: $e');
      return users; // Fallback sicuro
    }
  }

  // Metodo helper sincrono per ottenere l'ID dell'utente corrente
  static String? getCurrentUserIdSync() {
    return _currentUserId; // Restituisce l'ID memorizzato in cache
  }

  // Metodo per impostare l'ID dell'utente corrente (chiamato durante il login)
  static void setCurrentUserId(String? userId) {
    _currentUserId = userId;
  }

  // Metodo per pulire l'ID dell'utente corrente (chiamato durante il logout)
  static void clearCurrentUserId() {
    _currentUserId = null;
  }

  // Genera utenti mock per fallback (solo utenti reali dal database)
  static List<UserModel> _generateMockUsers() {
    return [
      // Solo utenti reali dal database come fallback - SENZA URL esterni
      // Usa gli stessi ID UUID delle chat per sincronizzazione
      UserModel(
        id: '3', // ID numerico corretto dal database
        name: 'Riccardo Dicamillo',
        email: 'r.dicamillo69@gmail.com',
        password: 'password123',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        updatedAt: DateTime.now().subtract(const Duration(days: 5)),
        isActive: true,
        profileImage: '', // Nessuna foto - mostrerà iniziali
      ),
      UserModel(
        id: '2', // ID numerico per Raffaele
        name: 'Raffaele Amoroso',
        email: 'r.amoroso80@gmail.com',
        password: 'password123',
        createdAt: DateTime.now().subtract(const Duration(days: 25)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        isActive: true,
        profileImage: '', // Nessuna foto - mostrerà iniziali
      ),
    ];
  }

  // Cerca utenti per nome o email
  static Future<List<UserModel>> searchUsers(String query) async {
    if (query.isEmpty) return await getRegisteredUsers();
    
    final users = await getRegisteredUsers();
    return users.where((user) {
      return user.name.toLowerCase().contains(query.toLowerCase()) ||
             user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Cerca utenti per nome o email ESCLUDENDO l'utente corrente e l'admin
  static Future<List<UserModel>> searchUsersExcludingCurrent(String query) async {
    if (query.isEmpty) return await getRegisteredUsersExcludingCurrent();
    
    final users = await getRegisteredUsersExcludingCurrent();
    return users.where((user) {
      return user.name.toLowerCase().contains(query.toLowerCase()) ||
             user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Metodo sincrono per compatibilità
  static List<UserModel> searchUsersSync(String query) {
    if (query.isEmpty) return getRegisteredUsersSync();
    
    final users = getRegisteredUsersSync();
    return users.where((user) {
      return user.name.toLowerCase().contains(query.toLowerCase()) ||
             user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  // Ottiene gli utenti raggruppati alfabeticamente
  static Future<Map<String, List<UserModel>>> getUsersGroupedByAlphabet() async {
    final users = await getRegisteredUsers();
    final grouped = <String, List<UserModel>>{};
    
    for (final user in users) {
      final firstLetter = user.name.isNotEmpty ? user.name[0].toUpperCase() : '#';
      grouped[firstLetter] ??= [];
      grouped[firstLetter]!.add(user);
    }
    
    // Ordina le chiavi alfabeticamente
    final sortedKeys = grouped.keys.toList()..sort();
    final sortedGrouped = <String, List<UserModel>>{};
    
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  // Ottiene gli utenti raggruppati alfabeticamente ESCLUDENDO l'utente corrente e l'admin
  static Future<Map<String, List<UserModel>>> getUsersGroupedByAlphabetExcludingCurrent() async {
    final users = await getRegisteredUsersExcludingCurrent();
    final grouped = <String, List<UserModel>>{};
    
    for (final user in users) {
      final firstLetter = user.name.isNotEmpty ? user.name[0].toUpperCase() : '#';
      grouped[firstLetter] ??= [];
      grouped[firstLetter]!.add(user);
    }
    
    // Ordina le chiavi alfabeticamente
    final sortedKeys = grouped.keys.toList()..sort();
    final sortedGrouped = <String, List<UserModel>>{};
    
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  // Ottiene gli utenti raggruppati alfabeticamente con ricerca
  static Future<Map<String, List<UserModel>>> getUsersGroupedByAlphabetWithSearch(String query) async {
    final users = await searchUsers(query);
    final grouped = <String, List<UserModel>>{};
    
    for (final user in users) {
      final firstLetter = user.name.isNotEmpty ? user.name[0].toUpperCase() : '#';
      grouped[firstLetter] ??= [];
      grouped[firstLetter]!.add(user);
    }
    
    // Ordina le chiavi alfabeticamente
    final sortedKeys = grouped.keys.toList()..sort();
    final sortedGrouped = <String, List<UserModel>>{};
    
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  // Ottiene gli utenti raggruppati alfabeticamente con ricerca ESCLUDENDO l'utente corrente e l'admin
  static Future<Map<String, List<UserModel>>> getUsersGroupedByAlphabetWithSearchExcludingCurrent(String query) async {
    final users = await searchUsersExcludingCurrent(query);
    final grouped = <String, List<UserModel>>{};
    
    for (final user in users) {
      final firstLetter = user.name.isNotEmpty ? user.name[0].toUpperCase() : '#';
      grouped[firstLetter] ??= [];
      grouped[firstLetter]!.add(user);
    }
    
    // Ordina le chiavi alfabeticamente
    final sortedKeys = grouped.keys.toList()..sort();
    final sortedGrouped = <String, List<UserModel>>{};
    
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  // Ottiene un utente per ID (senza escludere l'utente corrente)
  static Future<UserModel?> getUserById(String id) async {
    try {
      // Prova prima con RealUserService per ottenere l'utente specifico
      final user = await RealUserService.getUserById(id);
      if (user != null) {
        return user;
      }
      
      // Fallback: cerca nei dati mock
      final users = _generateMockUsers();
      return users.firstWhere((user) => user.id == id);
    } catch (e) {
      return null;
    }
  }

  // Metodo sincrono per compatibilità
  static UserModel? getUserByIdSync(String id) {
    try {
      final users = getRegisteredUsersSync();
      return users.firstWhere((user) => user.id == id);
    } catch (e) {
      return null;
    }
  }

  // Ottiene gli utenti online (mock)
  static Future<List<UserModel>> getOnlineUsers() async {
    // Simula alcuni utenti online
    final users = await getRegisteredUsers();
    return users.take(5).toList(); // Primi 5 utenti sono "online"
  }

  // Ottiene gli utenti online ESCLUDENDO l'utente corrente e l'admin (mock)
  static Future<List<UserModel>> getOnlineUsersExcludingCurrent() async {
    // Simula alcuni utenti online
    final users = await getRegisteredUsersExcludingCurrent();
    return users.take(5).toList(); // Primi 5 utenti sono "online"
  }

  // Metodo sincrono per compatibilità
  static List<UserModel> getOnlineUsersSync() {
    // Simula alcuni utenti online
    final users = getRegisteredUsersSync();
    return users.take(5).toList(); // Primi 5 utenti sono "online"
  }

  // Metodo sincrono per compatibilità ESCLUDENDO l'utente corrente e l'admin
  static List<UserModel> getOnlineUsersExcludingCurrentSync() {
    // Simula alcuni utenti online
    final users = getRegisteredUsersExcludingCurrentSync();
    return users.take(5).toList(); // Primi 5 utenti sono "online"
  }

  // Aggiunge un nuovo utente (per registrazioni future)
  static void addUser(UserModel user) {
    _registeredUsers.add(user);
  }

  // Aggiorna un utente esistente
  static void updateUser(UserModel updatedUser) {
    final index = _registeredUsers.indexWhere((user) => user.id == updatedUser.id);
    if (index != -1) {
      _registeredUsers[index] = updatedUser;
    }
  }

  // Ottiene l'utente corrente tramite AuthService
  static Future<UserModel?> getCurrentUser() async {
    try {
      // Usa l'AuthService per ottenere l'utente autenticato
      final authService = AuthService();
      return await authService.getCurrentUser();
    } catch (e) {
      print('Errore nel recupero utente corrente: $e');
      return null;
    }
  }
}
