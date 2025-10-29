import '../models/call_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/call_model.dart';

class RealCallService {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  static List<CallModel> _cachedCalls = [];
  static DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 10); // Aumenta cache a 10 minuti

  /// Ottiene il token di autenticazione da SharedPreferences
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      print('📞 RealCallService._getAuthToken - Errore nel recupero del token: $e');
      return null;
    }
  }

  /// Recupera le chiamate dal backend
  static Future<List<CallModel>> getCalls() async {
    try {
      // Controlla se abbiamo dati in cache validi
      if (_cachedCalls.isNotEmpty && 
          _lastFetch != null && 
          DateTime.now().difference(_lastFetch!) < cacheExpiry) {
        print('📞 RealCallService.getCalls - Usando cache (${_cachedCalls.length} chiamate)');
        return _cachedCalls;
      }

      print('📞 RealCallService.getCalls - Recuperando chiamate dal backend...');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📞 RealCallService.getCalls - Token non disponibile');
        return _getFallbackCalls();
      }

      final response = await http.get(
        Uri.parse('$baseUrl/webrtc/calls/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> callsData = data['calls'] ?? [];
        
        _cachedCalls = callsData.map((callData) => CallModel.fromJson(callData)).toList();
        _lastFetch = DateTime.now();
        
        print('📞 RealCallService.getCalls - Recuperate ${_cachedCalls.length} chiamate dal backend');
        return _cachedCalls;
      } else {
        print('📞 RealCallService.getCalls - Errore ${response.statusCode}: ${response.body}');
        return _getFallbackCalls();
      }
    } catch (e) {
      print('📞 RealCallService.getCalls - Errore di connessione: $e');
      return _getFallbackCalls();
    }
  }

  /// Dati di fallback se il backend non è disponibile
  static List<CallModel> _getFallbackCalls() {
    print('📞 RealCallService._getFallbackCalls - Usando dati di fallback');
    return [
      // Chiamate di oggi
      CallModel(
        id: 'fallback-1',
        contactName: 'Riccardo Dicamillo',
        contactAvatar: '',
        contactId: '2', // ID utente Riccardo Dicamillo
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        type: CallType.audio,
        direction: CallDirection.missed,
        status: CallStatus.missed,
        duration: const Duration(seconds: 0),
        phoneNumber: '+39 123 456 7890',
      ),
      CallModel(
        id: 'fallback-2',
        contactName: 'Raffaele Amoroso',
        contactAvatar: '',
        contactId: '1', // ID utente Raffaele Amoroso
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: CallType.video,
        direction: CallDirection.outgoing,
        status: CallStatus.completed,
        duration: const Duration(minutes: 15, seconds: 30),
        phoneNumber: '+39 234 567 8901',
      ),
    ];
  }

  /// Crea una nuova chiamata nel backend
  static Future<bool> createCall({
    required String calleeId,
    required CallType callType,
    String? phoneNumber,
  }) async {
    try {
      print('📞 RealCallService.createCall - Creando chiamata per $calleeId');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📞 RealCallService.createCall - Token non disponibile');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/webrtc/calls/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'callee_id': calleeId,
          'call_type': callType.name,
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('📞 RealCallService.createCall - Chiamata creata con successo');
        // Invalida la cache per forzare il refresh
        _cachedCalls.clear();
        _lastFetch = null;
        return true;
      } else {
        print('📞 RealCallService.createCall - Errore ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('📞 RealCallService.createCall - Errore di connessione: $e');
      return false;
    }
  }

  /// Termina una chiamata nel backend
  static Future<bool> endCall(String sessionId) async {
    try {
      print('📞 RealCallService.endCall - Terminando chiamata $sessionId');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📞 RealCallService.endCall - Token non disponibile');
        return false;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/webrtc/calls/end/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'session_id': sessionId,
        }),
      );

      if (response.statusCode == 200) {
        print('📞 RealCallService.endCall - Chiamata terminata con successo');
        // Invalida la cache per forzare il refresh
        _cachedCalls.clear();
        _lastFetch = null;
        return true;
      } else {
        print('📞 RealCallService.endCall - Errore ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      print('📞 RealCallService.endCall - Errore di connessione: $e');
      return false;
    }
  }

  /// Invalida la cache per forzare il refresh
  static void invalidateCache() {
    print('📞 RealCallService.invalidateCache - Cache invalidata');
    _cachedCalls.clear();
    _lastFetch = null;
  }
}
