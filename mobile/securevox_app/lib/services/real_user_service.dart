import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import 'user_service.dart';

class RealUserService {
  static const String baseUrl = 'http://127.0.0.1:8001'; // Backend URL
  
  // Cache per gli utenti
  static List<UserModel> _cachedUsers = [];
  static DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 5);

  /// Ottiene tutti gli utenti reali dal database
  static Future<List<UserModel>> getRealUsers() async {
    // Controlla se la cache è ancora valida
    if (_cachedUsers.isNotEmpty && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < cacheExpiry) {
      return List.from(_cachedUsers);
    }

    try {
      // Chiamata al backend per ottenere gli utenti
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _cachedUsers = data.map((json) => UserModel.fromJson(json)).toList();
        _lastFetch = DateTime.now();
        
        // Il backend ora esclude già l'utente corrente, quindi non serve più filtrare
        return List.from(_cachedUsers);
      } else {
        print('Errore nel recupero utenti: ${response.statusCode}');
        return _excludeCurrentUser(_getFallbackUsers());
      }
    } catch (e) {
      print('Errore di connessione: $e');
      return _excludeCurrentUser(_getFallbackUsers());
    }
  }

  /// Utenti di fallback in caso di errore di connessione - SENZA URL esterni
  /// Usa gli stessi ID UUID delle chat per sincronizzazione
  static List<UserModel> _getFallbackUsers() {
    return [
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

  /// Cerca utenti per nome o email
  static Future<List<UserModel>> searchUsers(String query) async {
    final users = await getRealUsers();
    if (query.isEmpty) return users;
    
    return users.where((user) {
      return user.name.toLowerCase().contains(query.toLowerCase()) ||
             user.email.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  /// Ottiene un utente specifico per ID (senza escludere l'utente corrente)
  static Future<UserModel?> getUserById(String id) async {
    try {
      // Controlla prima nella cache
      if (_cachedUsers.isNotEmpty && 
          _lastFetch != null && 
          DateTime.now().difference(_lastFetch!) < cacheExpiry) {
        try {
          return _cachedUsers.firstWhere((user) => user.id == id);
        } catch (e) {
          // Se non trovato nella cache, prova a ricaricare
        }
      }

      // Chiamata diretta al backend per ottenere l'utente specifico
      final response = await http.get(
        Uri.parse('$baseUrl/api/users/$id/'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return UserModel.fromJson(data);
      } else {
        print('Errore nel recupero utente $id: ${response.statusCode}');
        // Fallback: cerca nei dati di fallback
        try {
          return _getFallbackUsers().firstWhere((user) => user.id == id);
        } catch (e) {
          return null;
        }
      }
    } catch (e) {
      print('Errore di connessione per utente $id: $e');
      // Fallback: cerca nei dati di fallback
      try {
        return _getFallbackUsers().firstWhere((user) => user.id == id);
      } catch (e) {
        return null;
      }
    }
  }

  /// Pulisce la cache
  static void clearCache() {
    _cachedUsers.clear();
    _lastFetch = null;
  }

  /// Metodo helper per escludere l'utente corrente dalla lista
  static List<UserModel> _excludeCurrentUser(List<UserModel> users) {
    try {
      // Ottieni l'ID dell'utente corrente dal UserService
      final currentUserId = UserService.getCurrentUserIdSync();
      if (currentUserId == null) {
        return users; // Se non riusciamo a ottenere l'ID, restituiamo tutti gli utenti
      }
      
      // Filtra l'utente corrente
      return users.where((user) => user.id != currentUserId).toList();
    } catch (e) {
      print('Errore nell\'esclusione utente corrente: $e');
      return users; // Fallback sicuro
    }
  }
}
