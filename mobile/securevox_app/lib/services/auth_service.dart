import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/user_model.dart';
import 'user_service.dart';
import 'connection_service.dart';
import 'unified_realtime_service.dart';
import 'unified_avatar_service.dart';
import 'realtime_status_service.dart';
import 'user_status_service.dart';
import 'notification_service.dart';
import 'e2e_manager.dart';

class AuthService extends ChangeNotifier {
  static const String _currentUserKey = 'securevox_current_user';
  static const String _isLoggedInKey = 'securevox_is_logged_in';
  static const String _authTokenKey = 'securevox_auth_token';
  
  // URL del server Secure VOX (da configurare)
  static String get _baseUrl => 'http://127.0.0.1:8001/api'; // Backend locale per iOS Simulator
  
  // Proprietà pubblica per accedere all'utente corrente
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  
  // Costruttore per inizializzare l'utente corrente
  AuthService() {
    _initializeCurrentUser();
  }
  
  /// Metodo per pulire completamente lo stato durante sviluppo
  Future<void> clearAllDataForDevelopment() async {
    try {
      print('🧹 AuthService.clearAllDataForDevelopment - Pulizia completa...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Rimuovi tutti i dati di autenticazione
      await prefs.remove(_currentUserKey);
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_authTokenKey);
      await prefs.remove('device_token');
      
      // Reset proprietà
      _currentUser = null;
      
      // Pulisci cache UserService
      UserService.clearCurrentUserId();
      
      // Notifica listeners
      notifyListeners();
      
      print('✅ AuthService.clearAllDataForDevelopment - Pulizia completata');
      
    } catch (e) {
      print('❌ AuthService.clearAllDataForDevelopment - Errore: $e');
    }
  }
  
  // Inizializza l'utente corrente al momento della creazione
  void _initializeCurrentUser() async {
    await getCurrentUser();
    
    // CORREZIONE: Verifica automaticamente il token all'avvio
    await _verifyAndRefreshTokenOnStartup();
  }

  /// Verifica e aggiorna il token all'avvio dell'app
  Future<void> _verifyAndRefreshTokenOnStartup() async {
    try {
      print('🔐 AuthService._verifyAndRefreshTokenOnStartup - Verifica token...');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('⚠️ AuthService - Nessun token salvato, utente non loggato');
        return;
      }
      
      print('🔐 AuthService - Token trovato: ${token.substring(0, 10)}...');
      
      // Verifica token con il server
      final isValid = await verifyToken();
      
      if (isValid) {
        print('✅ AuthService - Token valido, utente autenticato');
        
        // Aggiorna stato online
        await _updateUserOnlineStatus();
        
        // 🔐 NUOVO: Inizializza E2EE se l'utente è già loggato
        await _initializeE2EE();
        
        // Riavvia servizi che dipendono dall'autenticazione
        await _restartAuthenticatedServices();
        
      } else {
        print('❌ AuthService - Token scaduto o non valido, forzando logout');
        
        // Token non valido, forza logout
        await forceLogout('Token scaduto');
      }
      
    } catch (e) {
      print('❌ AuthService._verifyAndRefreshTokenOnStartup - Errore: $e');
      
      // In caso di errore, assume token non valido
      await forceLogout('Errore verifica token');
    }
  }

  /// Aggiorna stato online dell'utente
  Future<void> _updateUserOnlineStatus() async {
    try {
      // Aggiorna stato nel UserStatusService
      await UserStatusService().forceUpdate();
      
      // Notifica il server che l'utente è online
      await _updateServerOnlineStatus();
      
    } catch (e) {
      print('⚠️ AuthService._updateUserOnlineStatus - Errore: $e');
    }
  }

  /// Notifica il server dello stato online
  Future<void> _updateServerOnlineStatus() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/users/update-status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token ${await _getAuthToken()}',
        },
        body: jsonEncode({
          'has_connection': true,
          'status': 'online'
        }),
      );
      
      if (response.statusCode == 200) {
        print('✅ AuthService - Stato online aggiornato sul server');
      } else {
        print('⚠️ AuthService - Errore aggiornamento stato: ${response.statusCode}');
      }
      
    } catch (e) {
      print('⚠️ AuthService._updateServerOnlineStatus - Errore: $e');
    }
  }

  /// Riavvia servizi che dipendono dall'autenticazione
  Future<void> _restartAuthenticatedServices() async {
    try {
      // Riavvia il servizio di stato utenti
      await UserStatusService().forceUpdate();
      
      // Il CallNotificationService verrà riavviato automaticamente
      // dal CallNotificationHandler quando rileva il nuovo token valido
      
      print('✅ AuthService - Servizi autenticati riavviati');
      
    } catch (e) {
      print('⚠️ AuthService._restartAuthenticatedServices - Errore: $e');
    }
  }

  /// Forza logout con messaggio
  Future<void> forceLogout(String reason) async {
    try {
      print('🔐 AuthService.forceLogout - Motivo: $reason');
      
      // 1. Cleanup chiamate attive prima del logout
      await _cleanupActiveCallsOnLogout();
      
      // 2. Pulisci dati locali
      await clearAllAppCache();
      
      // 3. Reset proprietà
      _currentUser = null;
      
      // 4. Notifica listeners
      notifyListeners();
      
      print('✅ AuthService.forceLogout - Logout forzato completato');
      
    } catch (e) {
      print('❌ AuthService.forceLogout - Errore: $e');
    }
  }

  /// Cleanup chiamate attive quando l'utente fa logout
  Future<void> _cleanupActiveCallsOnLogout() async {
    try {
      print('🧹 AuthService._cleanupActiveCallsOnLogout - Pulizia chiamate...');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('⚠️ Nessun token per cleanup chiamate');
        return;
      }
      
      // Chiama endpoint per terminare tutte le chiamate dell'utente
      final response = await http.post(
        Uri.parse('$_baseUrl/webrtc/calls/cleanup-user-calls/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'reason': 'user_logout',
          'cleanup_type': 'all_user_calls'
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        print('✅ AuthService - Chiamate utente pulite dal backend');
      } else {
        print('⚠️ AuthService - Errore cleanup chiamate: ${response.statusCode}');
      }
      
    } catch (e) {
      print('❌ AuthService._cleanupActiveCallsOnLogout - Errore: $e');
    }
  }
  
  
  // Registra un nuovo utente tramite server
  Future<Map<String, dynamic>> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // CORREZIONE: Registrazione con retry automatico
      http.Response? response;
      int maxRetries = 3;
      int currentRetry = 0;
      
      while (currentRetry < maxRetries) {
        try {
          print('🔐 AuthService.registerUser - Tentativo ${currentRetry + 1}/$maxRetries');
          
          response = await http.post(
            Uri.parse('$_baseUrl/auth/register/'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'name': name,
              'email': email.toLowerCase().trim(),
              'password': password,
            }),
          ).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout connessione server');
            },
          );
          
          // Se arriviamo qui, la richiesta è riuscita
          break;
          
        } catch (e) {
          currentRetry++;
          print('❌ AuthService.registerUser - Tentativo $currentRetry fallito: $e');
          
          if (currentRetry < maxRetries) {
            print('🔄 AuthService.registerUser - Retry in 2 secondi...');
            await Future.delayed(const Duration(seconds: 2));
          } else {
            rethrow;
          }
        }
      }
      
      if (response == null) {
        throw Exception('Impossibile connettersi al server dopo $maxRetries tentativi');
      }

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data['user']);
        
        // Salva i dati dell'utente e il token localmente
        await _setCurrentUser(user);
        await _setAuthToken(data['token']);
        await _setLoggedInStatus(true);
        
        // Imposta l'ID dell'utente corrente nel UserService
        UserService.setCurrentUserId(user.id);
        
        // Imposta lo stato online nel ConnectionService
        final connectionService = ConnectionService();
        await connectionService.initialize();
        
        // CORREZIONE: Registra automaticamente il dispositivo nel sistema di notifiche
        print('🔐 AuthService.registerUser - Registrazione dispositivo nel sistema notifiche...');
        await _registerDeviceForNotifications(user.id);
        
        // Notifica i listener del cambiamento di stato
        notifyListeners();
        
        // 🎯 CORREZIONE CRITICA: Forza aggiornamento stati dopo registrazione
        print('🎯 AuthService.registerUser - Forzando aggiornamento stati dopo registrazione...');
        await UserStatusService().forceUpdate();
        
        return {
          'success': true,
          'user': user,
          'token': data['token'],
          'message': data['message'] ?? 'Registrazione completata con successo',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante la registrazione',
        };
      }
    } catch (e) {
      print('Errore durante la registrazione: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Login utente tramite server
  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      // Pulisci completamente tutta la cache prima del login
      await clearAllAppCache();
      
      print('🔐 AuthService.loginUser - Tentativo login per: ${email.toLowerCase().trim()}');
      
      // CORREZIONE: Verifica veloce del server (1 solo tentativo)
      print('🔐 AuthService.loginUser - Verifica rapida disponibilità server...');
      bool serverReady = await _checkServerHealth();
      
      if (!serverReady) {
        print('⚠️ AuthService.loginUser - Health check fallito, ma procediamo comunque con login diretto');
        // Non blocchiamo il login se l'health check fallisce
      } else {
        print('✅ AuthService.loginUser - Server pronto');
      }
      
      // CORREZIONE: Login con retry automatico per gestire hot reload
      http.Response? response;
      int maxRetries = 2; // Ridotto a 2 tentativi per velocità
      int currentRetry = 0;
      
      while (currentRetry < maxRetries) {
        try {
          print('🔐 AuthService.loginUser - Tentativo ${currentRetry + 1}/$maxRetries');
          print('🔐 AuthService.loginUser - URL: $_baseUrl/auth/login/');
          print('🔐 AuthService.loginUser - Email: ${email.toLowerCase().trim()}');
          
          final requestBody = {
            'email': email.toLowerCase().trim(),
            'password': password,
          };
          print('🔐 AuthService.loginUser - Request body: ${jsonEncode(requestBody)}');
          
          response = await http.post(
            Uri.parse('$_baseUrl/auth/login/'),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          ).timeout(
            const Duration(seconds: 8), // Timeout ottimizzato a 8 secondi
            onTimeout: () {
              throw Exception('Timeout: Il server non risponde entro 8 secondi');
            },
          );
          
          print('🔐 AuthService.loginUser - Risposta ricevuta: ${response.statusCode}');
          print('🔐 AuthService.loginUser - Response headers: ${response.headers}');
          print('🔐 AuthService.loginUser - Response body: ${response.body}');
          
          // Se arriviamo qui, la richiesta è riuscita
          break;
          
        } catch (e) {
          currentRetry++;
          print('❌ AuthService.loginUser - Tentativo $currentRetry fallito: $e');
          print('❌ AuthService.loginUser - Tipo errore: ${e.runtimeType}');
          
          // Log specifico per hot reload
          if (e.toString().contains('timeout') || e.toString().contains('connection')) {
            print('🔄 AuthService.loginUser - Errore di connessione dopo hot reload');
          }
          
          if (currentRetry < maxRetries) {
            // Delay ridotto per velocità
            final delaySeconds = 1; // Solo 1 secondo di delay
            print('🔄 AuthService.loginUser - Retry in $delaySeconds secondi...');
            await Future.delayed(Duration(seconds: delaySeconds));
          } else {
            // Ultimo tentativo fallito, rilancia l'errore
            rethrow;
          }
        }
      }
      
      if (response == null) {
        throw Exception('Impossibile connettersi al server dopo $maxRetries tentativi');
      }
      
      print('🔐 AuthService.loginUser - Risposta server: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔐 AuthService.loginUser - Dati ricevuti: ${data.keys}');
        
        final user = UserModel.fromJson(data['user']);
        final token = data['token'];
        
        print('🔐 AuthService.loginUser - User ID: ${user.id}, Token: ${token != null ? token.substring(0, 10) : 'NULL'}...');
        
        // NUOVO: Verifica se l'utente è bloccato (is_active = false)
        final bool isActive = data['user']['is_active'] ?? true;
        if (!isActive) {
          print('🚫 AuthService.loginUser - Utente bloccato dall\'amministratore');
          return {
            'success': false,
            'message': 'Utente momentaneamente sospeso',
            'blocked': true,
          };
        }
        
        // Verifica che il token non sia null
        if (token == null) {
          print('❌ AuthService.loginUser - Token nullo ricevuto dal server');
          return {
            'success': false,
            'message': 'Token di autenticazione non ricevuto dal server',
          };
        }
        
        // Salva l'utente e il token localmente
        await _setCurrentUser(user);
        await _setAuthToken(token);
        await _setLoggedInStatus(true);
        
        // Imposta l'ID dell'utente corrente nel UserService
        UserService.setCurrentUserId(user.id);
        
        // NUOVO: Inizializza il colore avatar per l'utente al login
        final userColor = UnifiedAvatarService.getUserColor(user.id);
        print('🎨 AuthService.loginUser - Colore avatar per ${user.name}: $userColor');
        
        // Imposta lo stato online nel ConnectionService
        final connectionService = ConnectionService();
        await connectionService.initialize();
        
        // CORREZIONE: Pre-carica gli avatar di tutti gli utenti per cache immediata
        print('🔐 AuthService.loginUser - Pre-caricamento avatar utenti...');
        UnifiedAvatarService.preloadAllUserAvatars(); // Non await per non bloccare il login
        
        // NUOVO: Inizializza RealtimeStatusService dopo il login
        print('🔐 AuthService.loginUser - Inizializzazione RealtimeStatusService...');
        await RealtimeStatusService().initialize();
        
        // NUOVO: Imposta immediatamente l'utente corrente come online
        print('🔐 AuthService.loginUser - Impostazione stato online per user ${user.id}...');
        UserStatusService().updateUserStatus(user.id, UserStatus.online);
        
        // NUOVO: Forza aggiornamento immediato degli stati di tutti
        print('🔐 AuthService.loginUser - Aggiornamento stati utenti...');
        await UserStatusService().forceUpdate();
        
        // CORREZIONE: Registra automaticamente il dispositivo nel sistema di notifiche
        print('🔐 AuthService.loginUser - Registrazione dispositivo nel sistema notifiche...');
        await _registerDeviceForNotifications(user.id);
        
        // NUOVO: Inizializza NotificationService (SecureVox Notify)
        print('🔐 AuthService.loginUser - Inizializzazione SecureVox Notify...');
        await _initializeNotificationService(user.id);
        
        // NUOVO: Inizializza CallNotificationService per chiamate in arrivo
        print('📞 AuthService.loginUser - Inizializzazione CallNotificationService...');
        await _initializeCallNotificationService();
        
        // 🔐 NUOVO: Inizializza automaticamente E2EE al login
        print('🔐 AuthService.loginUser - Inizializzazione automatica E2EE...');
        await _initializeE2EE();
        
        // Notifica i listener del cambiamento di stato
        notifyListeners();
        
        // 🎯 CORREZIONE CRITICA: Forza aggiornamento stati dopo login
        print('🎯 AuthService.loginUser - Forzando aggiornamento stati dopo login...');
        await UserStatusService().forceUpdate();
        
        return {
          'success': true,
          'user': user,
          'token': token,
          'message': data['message'] ?? 'Login effettuato con successo',
        };
      } else {
        final error = jsonDecode(response.body);
        print('❌ AuthService.loginUser - Errore ${response.statusCode}: ${error}');
        return {
          'success': false,
          'message': error['message'] ?? 'Credenziali non valide',
        };
      }
    } catch (e) {
      print('❌ AuthService.loginUser - Errore durante il login: $e');
      print('❌ AuthService.loginUser - Tipo errore: ${e.runtimeType}');
      
      String errorMessage;
      if (e.toString().contains('Timeout')) {
        errorMessage = 'Il server non risponde. Verifica la connessione e riprova.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('connection')) {
        errorMessage = 'Problema di connessione. Verifica la rete e riprova.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Risposta del server non valida. Contatta il supporto.';
      } else {
        errorMessage = 'Errore imprevisto: ${e.toString()}';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Richiedi reset password
  Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/request-reset/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Istruzioni inviate via email',
          'debug_token': data['debug_token'], // Solo per debug
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante la richiesta di reset',
        };
      }
    } catch (e) {
      print('Errore durante la richiesta di reset: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }


  // Pulisce completamente la cache di autenticazione
  Future<void> clearAuthCache() async {
    try {
      print('🧹 AuthService.clearAuthCache - Pulizia cache autenticazione...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Rimuovi tutti i dati di autenticazione
      await prefs.remove(_currentUserKey);
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_authTokenKey);
      
      // Reset delle variabili locali
      _currentUser = null;
      
      // Reset UserService
      UserService.setCurrentUserId(null);
      
      print('✅ AuthService.clearAuthCache - Cache pulita con successo');
      
      // Notifica i listener
      notifyListeners();
    } catch (e) {
      print('❌ AuthService.clearAuthCache - Errore: $e');
    }
  }

  // Pulisce completamente tutta la cache dell'app
  Future<void> clearAllAppCache() async {
    try {
      print('🧹 AuthService.clearAllAppCache - Pulizia completa cache app...');
      
      final prefs = await SharedPreferences.getInstance();
      
      // Ottieni tutte le chiavi
      final keys = prefs.getKeys();
      
      // Rimuovi tutte le chiavi relative all'app
      for (String key in keys) {
        if (key.startsWith('securevox_') || 
            key.startsWith('message_') || 
            key.startsWith('chat_') ||
            key.startsWith('user_')) {
          await prefs.remove(key);
          print('🗑️ Rimosso: $key');
        }
      }
      
      // Reset delle variabili locali
      _currentUser = null;
      
      // Reset UserService
      UserService.setCurrentUserId(null);
      
      print('✅ AuthService.clearAllAppCache - Cache completa pulita');
      
      // Notifica i listener
      notifyListeners();
    } catch (e) {
      print('❌ AuthService.clearAllAppCache - Errore: $e');
    }
  }


  // Logout utente
  Future<void> logout() async {
    try {
      print('🔐 AuthService.logout - Avvio logout...');
      
      final token = await _getAuthToken();
      if (token != null) {
        print('🔐 AuthService.logout - Notifica server del logout...');
        // Notifica il server del logout (usa enhanced logout)
        try {
          final response = await http.post(
            Uri.parse('$_baseUrl/auth/logout/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            print('🔐 AuthService.logout - Server notificato con successo - Stato impostato OFFLINE');
          } else {
            print('⚠️ AuthService.logout - Errore notifica server: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ AuthService.logout - Errore connessione server: $e');
        }
      }
      
      // NUOVO: Ferma servizi real-time e notifiche prima della pulizia
      try {
        final realtimeService = RealtimeStatusService();
        realtimeService.dispose();
        NotificationService.instance.dispose();
        print('🔐 AuthService.logout - Servizi real-time e notifiche fermati');
      } catch (e) {
        print('⚠️ AuthService.logout - Errore fermata servizi: $e');
      }
      
      // NUOVO: Imposta utente corrente come offline
      final currentUser = await getCurrentUser();
      if (currentUser != null) {
        print('🔐 AuthService.logout - Impostazione stato offline per user ${currentUser.id}...');
        UserStatusService().updateUserStatus(currentUser.id, UserStatus.offline);
      }
      
      // NUOVO: Imposta tutti gli utenti offline nella cache locale (token scaduto)
      print('🔐 AuthService.logout - Impostazione tutti utenti offline...');
      UserStatusService().setAllUsersOffline();
      
      // Pulisci i dati locali
      await _setCurrentUser(null);
      await _setAuthToken(null);
      await _setLoggedInStatus(false);
      
      // Pulisci l'ID dell'utente corrente nel UserService
      UserService.clearCurrentUserId();
      
      // Imposta lo stato offline nel ConnectionService
      final connectionService = ConnectionService();
      connectionService.onUserLogout();
      
      // Notifica i listener del cambiamento di stato
      notifyListeners();
      
      print('🔐 AuthService.logout - ✅ Logout completato - App in stato offline');
      
    } catch (e) {
      print('❌ AuthService.logout - Errore durante il logout: $e');
      // Pulisci comunque i dati locali anche se il server non risponde
      await _setCurrentUser(null);
      await _setAuthToken(null);
      await _setLoggedInStatus(false);
      
      // Pulisci l'ID dell'utente corrente nel UserService
      UserService.clearCurrentUserId();
      
      // Ferma servizi e imposta offline
      try {
        final realtimeService = RealtimeStatusService();
        realtimeService.dispose();
        UserStatusService().setAllUsersOffline();
      } catch (e2) {
        print('⚠️ AuthService.logout - Errore pulizia servizi: $e2');
      }
      
      // Imposta lo stato offline nel ConnectionService
      final connectionService = ConnectionService();
      connectionService.onUserLogout();
    }
  }

  // Verifica se l'utente è loggato
  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;
      final token = prefs.getString(_authTokenKey);
      
      // Verifica che ci sia un token valido
      return isLoggedIn && token != null;
    } catch (e) {
      print('Errore durante la verifica del login: $e');
      return false;
    }
  }

  // Carica l'avatar sul server
  Future<Map<String, dynamic>> uploadAvatar(File avatarFile) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Utente non autenticato',
        };
      }

      // Crea la richiesta multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/users/avatar/'),
      );

      // Aggiungi l'header di autorizzazione
      request.headers['Authorization'] = 'Token $token';

      // Aggiungi il file avatar
      request.files.add(
        await http.MultipartFile.fromPath(
          'avatar',
          avatarFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Invia la richiesta
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data['user']);
        
        // Aggiorna l'utente corrente con i nuovi dati
        await _setCurrentUser(user);
        
        // CORREZIONE: Aggiorna la cache URL avatar e pulisci la cache widget
        await UnifiedAvatarService.updateUserAvatarUrl(user.id, user.profileImage);
        UnifiedAvatarService.clearUserCache(user.id);
        
        // Notifica i listener del cambiamento di stato
        notifyListeners();
        
        return {
          'success': true,
          'user': user,
          'message': data['message'] ?? 'Avatar aggiornato con successo',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante il caricamento dell\'avatar',
        };
      }
    } catch (e) {
      print('Errore durante il caricamento dell\'avatar: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Auto-logout per hot reload e ricompilazione
  Future<void> autoLogout() async {
    try {
      print('🔄 AuthService.autoLogout - Avvio auto-logout per hot reload...');
      
      final token = await _getAuthToken();
      if (token != null) {
        print('🔄 AuthService.autoLogout - Notifica server auto-logout...');
        try {
          final response = await http.post(
            Uri.parse('$_baseUrl/auth/auto-logout/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $token',
            },
          ).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            print('🔄 AuthService.autoLogout - Server notificato con successo');
          } else {
            print('⚠️ AuthService.autoLogout - Errore notifica server: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ AuthService.autoLogout - Errore connessione server: $e');
        }
      }
      
      // Pulisci i dati locali
      await _setCurrentUser(null);
      await _setAuthToken(null);
      await _setLoggedInStatus(false);
      
      // Pulisci l'ID dell'utente corrente nel UserService
      UserService.clearCurrentUserId();
      
      // Ferma servizi real-time e notifiche
      try {
        final realtimeService = RealtimeStatusService();
        realtimeService.dispose();
        UserStatusService().setAllUsersOffline();
        NotificationService.instance.dispose();
      } catch (e) {
        print('⚠️ AuthService.autoLogout - Errore fermata servizi: $e');
      }
      
      // Imposta lo stato offline nel ConnectionService
      final connectionService = ConnectionService();
      connectionService.onUserLogout();
      
      // Notifica i listener del cambiamento di stato
      notifyListeners();
      
      print('🔄 AuthService.autoLogout - ✅ Auto-logout completato');
      
    } catch (e) {
      print('❌ AuthService.autoLogout - Errore durante auto-logout: $e');
      // Pulisci comunque i dati locali
      await _setCurrentUser(null);
      await _setAuthToken(null);
      await _setLoggedInStatus(false);
      UserService.clearCurrentUserId();
      
      try {
        final realtimeService = RealtimeStatusService();
        realtimeService.dispose();
        UserStatusService().setAllUsersOffline();
        NotificationService.instance.dispose();
      } catch (e2) {
        print('⚠️ AuthService.autoLogout - Errore pulizia servizi: $e2');
      }
      
      final connectionService = ConnectionService();
      connectionService.onUserLogout();
    }
  }

  // Verifica se l'email esiste nel database
  Future<Map<String, dynamic>> verifyEmailExists(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/verify-email/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email.toLowerCase().trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'exists': data['exists'],
          'user_id': data['user_id'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'exists': false,
          'message': data['message'] ?? 'Email non trovata',
        };
      }
    } catch (e) {
      print('Errore durante la verifica email: $e');
      return {
        'success': false,
        'exists': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Reset password con nuova password
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    String? userId,
    required String newPassword,
    String? resetToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/reset-password/'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'user_id': userId,
          'new_password': newPassword,
          'reset_token': resetToken,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password cambiata con successo',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Errore durante il cambio password',
        };
      }
    } catch (e) {
      print('Errore durante il reset password: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Elimina l'avatar dal server (torna alle iniziali)
  Future<Map<String, dynamic>> deleteAvatar() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Utente non autenticato',
        };
      }

      // Invia richiesta DELETE per eliminare l'avatar
      final response = await http.delete(
        Uri.parse('$_baseUrl/users/avatar/delete/'),
        headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data['user']);
        
        // Aggiorna l'utente corrente con i nuovi dati (senza avatar)
        await _setCurrentUser(user);
        
        // CORREZIONE: Pulisci la cache avatar e forza il ritorno alle iniziali
        await UnifiedAvatarService.updateUserAvatarUrl(user.id, null);
        UnifiedAvatarService.clearUserCache(user.id);
        
        // Notifica i listener del cambiamento di stato
        notifyListeners();
        
        return {
          'success': true,
          'user': user,
          'message': data['message'] ?? 'Avatar eliminato con successo',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante l\'eliminazione dell\'avatar',
        };
      }
    } catch (e) {
      print('Errore durante l\'eliminazione dell\'avatar: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Ottieni l'utente corrente
  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_currentUserKey);
      
      if (userJson != null) {
        final userData = jsonDecode(userJson);
        final user = UserModel.fromJson(userData);
        
        // Aggiorna la proprietà _currentUser
        _currentUser = user;
        
        // Imposta l'ID dell'utente corrente nel UserService
        UserService.setCurrentUserId(user.id);
        
        // Notifica i listener del cambiamento
        notifyListeners();
        
        return user;
      }
      
      // Se non c'è utente salvato, pulisci la proprietà
      _currentUser = null;
      notifyListeners();
      return null;
    } catch (e) {
      print('Errore durante il recupero dell\'utente corrente: $e');
      _currentUser = null;
      notifyListeners();
      return null;
    }
  }

  // Verifica il token con il server
  Future<bool> verifyToken() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.get(
        Uri.parse('$_baseUrl/auth/verify/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Errore durante la verifica del token: $e');
      return false;
    }
  }

  // Aggiorna profilo utente
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? name,
    String? bio,
    String? phone,
    String? location,
    DateTime? dateOfBirth,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Token di autenticazione non trovato',
        };
      }

      final response = await http.put(
        Uri.parse('$_baseUrl/users/$userId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          if (name != null) 'name': name,
          if (bio != null) 'bio': bio,
          if (phone != null) 'phone': phone,
          if (location != null) 'location': location,
          if (dateOfBirth != null) 'date_of_birth': dateOfBirth.toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromJson(data['user']);
        
        // Aggiorna l'utente corrente
        await _setCurrentUser(user);
        
        // Aggiorna l'ID dell'utente corrente nel UserService
        UserService.setCurrentUserId(user.id);
        
        return {
          'success': true,
          'user': user,
          'message': data['message'] ?? 'Profilo aggiornato con successo',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante l\'aggiornamento del profilo',
        };
      }
    } catch (e) {
      print('Errore durante l\'aggiornamento del profilo: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Cambia password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        return {
          'success': false,
          'message': 'Token di autenticazione non trovato',
        };
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/change-password/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Password cambiata con successo',
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante il cambio password',
        };
      }
    } catch (e) {
      print('Errore durante il cambio password: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  // Metodo pubblico per impostare l'utente corrente (usato per autenticazione social)
  Future<void> setCurrentUser(UserModel? user) async {
    await _setCurrentUser(user);
  }

  // Metodo pubblico per impostare il token (usato per autenticazione social)
  Future<void> setAuthToken(String? token) async {
    await _setAuthToken(token);
  }

  // Metodo pubblico per impostare lo stato di login (usato per autenticazione social)
  Future<void> setLoggedInStatus(bool isLoggedIn) async {
    await _setLoggedInStatus(isLoggedIn);
    notifyListeners();
  }

  // Metodi privati per la gestione locale
  Future<void> _setCurrentUser(UserModel? user) async {
    try {
      // Aggiorna la proprietà _currentUser
      _currentUser = user;
      
      final prefs = await SharedPreferences.getInstance();
      if (user != null) {
        await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
        
        // CORREZIONE: Aggiorna immediatamente la cache avatar per l'utente corrente
        if (user.profileImage != null && user.profileImage!.isNotEmpty) {
          await UnifiedAvatarService.updateUserAvatarUrl(user.id, user.profileImage);
        }
        UnifiedAvatarService.clearUserCache(user.id);
      } else {
        await prefs.remove(_currentUserKey);
      }
      
      // Notifica i listener del cambiamento
      notifyListeners();
    } catch (e) {
      print('Errore durante l\'impostazione dell\'utente corrente: $e');
    }
  }

  Future<void> _setAuthToken(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token != null) {
        await prefs.setString(_authTokenKey, token);
      } else {
        await prefs.remove(_authTokenKey);
      }
    } catch (e) {
      print('Errore durante l\'impostazione del token: $e');
    }
  }

  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_authTokenKey);
    } catch (e) {
      print('Errore durante il recupero del token: $e');
      return null;
    }
  }

  // Metodo pubblico per ottenere il token
  Future<String?> getToken() async {
    final token = await _getAuthToken();
    // CORREZIONE: Non pulire i token personalizzati cifrati che iniziano con 'Z0FBQUFBQm'
    // Questi sono token validi del sistema di autenticazione personalizzato
    return token;
  }

  // Metodo per pulire completamente i token vecchi
  Future<void> clearOldTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.setBool(_isLoggedInKey, false);
      print('Token vecchi puliti');
    } catch (e) {
      print('Errore durante la pulizia dei token vecchi: $e');
    }
  }

  Future<void> _setLoggedInStatus(bool isLoggedIn) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, isLoggedIn);
    } catch (e) {
      print('Errore durante l\'impostazione dello stato di login: $e');
    }
  }

  /// CORREZIONE: Registra automaticamente il dispositivo nel sistema di notifiche
  Future<void> _registerDeviceForNotifications(String userId) async {
    try {
      print('🔔 AuthService._registerDeviceForNotifications - Inizio registrazione per user: $userId');
      
      // Inizializza e registra il dispositivo nel UnifiedRealtimeService
      final unifiedRealtime = UnifiedRealtimeService();
      
      // Imposta manualmente l'userId prima dell'inizializzazione
      await _setUserIdForNotifications(userId);
      
      // Inizializza il servizio (che include la registrazione del dispositivo)
      await unifiedRealtime.initialize();
      
      print('✅ AuthService._registerDeviceForNotifications - Dispositivo registrato con successo per user: $userId');
    } catch (e) {
      print('❌ AuthService._registerDeviceForNotifications - Errore registrazione dispositivo per user $userId: $e');
      // Non bloccare il login se la registrazione notifiche fallisce
    }
  }

  /// Inizializza NotificationService (SecureVox Notify)
  Future<void> _initializeNotificationService(String userId) async {
    try {
      print('🔔 AuthService._initializeNotificationService - Inizio inizializzazione per user: $userId');
      
      // Inizializza il NotificationService
      await NotificationService.instance.initialize(userId: userId);
      
      // Configura callback per gestire notifiche
      NotificationService.instance.onNotificationTap = (data) {
        print('📱 Notifica tappata: ${data['type']}');
        // Qui puoi navigare alla schermata appropriata
        _handleNotificationTap(data);
      };
      
      NotificationService.instance.onCallNotification = (data) {
        print('📞 Chiamata in arrivo: ${data['call_type']}');
        // Qui puoi mostrare la schermata di chiamata in arrivo
        _handleIncomingCall(data);
      };
      
      NotificationService.instance.onMessageReceived = (data) {
        print('💬 Messaggio ricevuto: ${data['title']}');
        // Qui puoi aggiornare la UI con il nuovo messaggio
        _handleMessageReceived(data);
      };
      
      print('✅ AuthService._initializeNotificationService - NotificationService inizializzato per user: $userId');
    } catch (e) {
      print('❌ AuthService._initializeNotificationService - Errore inizializzazione per user $userId: $e');
      // Non bloccare il login se le notifiche falliscono
    }
  }

  /// Inizializza il servizio notifiche chiamate
  Future<void> _initializeCallNotificationService() async {
    try {
      print('📞 AuthService._initializeCallNotificationService - Inizializzazione...');
      
      // Il servizio sarà inizializzato automaticamente dal CallNotificationHandler
      // Qui possiamo fare configurazioni aggiuntive se necessario
      
      print('✅ AuthService._initializeCallNotificationService - Configurazione completata');
      
    } catch (e) {
      print('❌ AuthService._initializeCallNotificationService - Errore: $e');
      // Non bloccare il login se le notifiche chiamate falliscono
    }
  }
  
  /// Inizializza automaticamente E2EE al login
  Future<void> _initializeE2EE() async {
    try {
      print('');
      print('=' * 70);
      print('🔐 INIZIALIZZAZIONE E2EE AUTOMATICA AL LOGIN');
      print('=' * 70);
      
      // 🧹 CORREZIONE CRITICA: Pulisce la cache delle chiavi pubbliche PRIMA dell'inizializzazione
      // Questo forza il download delle chiavi aggiornate dal server
      print('🧹 Step 1: Pulizia cache chiavi pubbliche obsolete...');
      await E2EManager.clearPublicKeysCache();
      print('✅ Step 1: Cache chiavi pulita');
      
      // Inizializza il sistema E2EE
      print('🔐 Step 2: Inizializzazione sistema E2EE...');
      await E2EManager.initialize();
      print('✅ Step 2: Sistema E2EE inizializzato');
      
      // Verifica se E2EE è già abilitato
      if (E2EManager.isEnabled) {
        print('✅ E2EE già abilitato precedentemente');
        
        // Sincronizza comunque la chiave pubblica con il backend
        print('🔐 Step 3: Sincronizzazione chiave pubblica con backend...');
        await E2EManager.syncPublicKeyWithBackend();
        print('✅ Step 3: Chiave sincronizzata');
        
      } else {
        // E2EE non ancora abilitato, abilitalo automaticamente
        print('⚠️  E2EE NON abilitato, procedura di abilitazione automatica...');
        
        print('🔐 Step 3: Generazione chiavi E2EE...');
        await E2EManager.enable();
        
        print('✅ E2EE ABILITATO CON SUCCESSO!');
        print('✅ Chiave pubblica inviata al server');
      }
      
      print('=' * 70);
      print('✅ INIZIALIZZAZIONE E2EE COMPLETATA');
      print('=' * 70);
      print('');
      
    } catch (e, stackTrace) {
      print('');
      print('❌❌❌ ERRORE INIZIALIZZAZIONE E2EE ❌❌❌');
      print('Errore: $e');
      print('Stack trace:');
      print(stackTrace);
      print('❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌❌');
      print('');
      // Non bloccare il login se E2EE fallisce
      // L'utente potrà abilitarlo manualmente dalle impostazioni
    }
  }
  
  /// Gestisce il tap su una notifica
  void _handleNotificationTap(Map<String, dynamic> data) {
    try {
      final type = data['type'];
      switch (type) {
        case 'message':
          // Naviga alla chat
          final chatId = data['chat_id'];
          if (chatId != null) {
            // TODO: Implementa navigazione alla chat
            print('📱 Navigazione alla chat: $chatId');
          }
          break;
        case 'call':
          // Gestisci risposta/rifiuto chiamata
          final callId = data['call_id'];
          if (callId != null) {
            print('📞 Gestisci chiamata: $callId');
          }
          break;
        case 'chat_deleted':
          // Gestisci eliminazione chat
          final chatId = data['chat_id'];
          print('🗑️ Chat eliminata: $chatId');
          break;
      }
    } catch (e) {
      print('❌ Errore gestione tap notifica: $e');
    }
  }
  
  /// Gestisce chiamate in arrivo
  void _handleIncomingCall(Map<String, dynamic> data) {
    try {
      final callId = data['call_id'];
      final callType = data['call_type'];
      final senderId = data['sender_id'];
      final isGroup = data['is_group'] ?? false;
      
      print('📞 Chiamata in arrivo:');
      print('  - ID: $callId');
      print('  - Tipo: $callType');
      print('  - Da: $senderId');
      print('  - Gruppo: $isGroup');
      
      // TODO: Mostra schermata di chiamata in arrivo
      // Puoi usare un overlay, dialog o navigare a una nuova schermata
      
    } catch (e) {
      print('❌ Errore gestione chiamata in arrivo: $e');
    }
  }
  
  /// Gestisce messaggi ricevuti
  void _handleMessageReceived(Map<String, dynamic> data) {
    try {
      final title = data['title'];
      final body = data['body'];
      final messageData = data['data'] ?? {};
      
      print('💬 Messaggio ricevuto:');
      print('  - Titolo: $title');
      print('  - Contenuto: $body');
      
      // TODO: Aggiorna la UI, incrementa contatori, ecc.
      // Potresti notificare altri servizi o widget
      
    } catch (e) {
      print('❌ Errore gestione messaggio ricevuto: $e');
    }
  }

  /// Verifica se il server è raggiungibile
  Future<bool> _checkServerHealth() async {
    try {
      print('🏥 AuthService._checkServerHealth - Verificando server $_baseUrl...');
      print('🏥 AuthService._checkServerHealth - URL completo: $_baseUrl/health/');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/health/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 3)); // Timeout ridotto a 3 secondi
      
      print('🏥 AuthService._checkServerHealth - Risposta ricevuta: ${response.statusCode}');
      print('🏥 AuthService._checkServerHealth - Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 404) {
        print('✅ AuthService._checkServerHealth - Server raggiungibile (${response.statusCode})');
        return true;
      } else {
        print('⚠️ AuthService._checkServerHealth - Server risponde con ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ AuthService._checkServerHealth - Errore dettagliato: $e');
      print('❌ AuthService._checkServerHealth - Tipo errore: ${e.runtimeType}');
      return false;
    }
  }

  /// Helper per impostare l'userId nelle SharedPreferences per le notifiche
  Future<void> _setUserIdForNotifications(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('securevox_current_user_id', userId);
      print('🔔 AuthService._setUserIdForNotifications - User ID impostato per notifiche: $userId');
    } catch (e) {
      print('❌ AuthService._setUserIdForNotifications - Errore: $e');
    }
  }

  /// Verifica che il dispositivo sia registrato nel server delle notifiche
  Future<void> _verifyNotificationRegistration(String userId) async {
    try {
      print('🔍 AuthService._verifyNotificationRegistration - Verifica registrazione per user: $userId');
      
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8002/devices'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devices = data['devices'] as List;
        
        bool found = false;
        for (var device in devices) {
          if (device['user_id'] == userId) {
            found = true;
            print('✅ AuthService._verifyNotificationRegistration - Dispositivo trovato per user $userId:');
            print('   - Device Token: ${device['device_token']}');
            print('   - Platform: ${device['platform']}');
            print('   - Last Seen: ${device['last_seen']}');
            print('   - Is Online: ${device['is_online']}');
            break;
          }
        }
        
        if (!found) {
          print('❌ AuthService._verifyNotificationRegistration - Dispositivo NON trovato per user $userId');
          print('📋 AuthService._verifyNotificationRegistration - Dispositivi disponibili:');
          for (var device in devices) {
            print('   - User ${device['user_id']}: ${device['device_token']}');
          }
        }
      } else {
        print('❌ AuthService._verifyNotificationRegistration - Errore verifica: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ AuthService._verifyNotificationRegistration - Errore: $e');
    }
  }
}