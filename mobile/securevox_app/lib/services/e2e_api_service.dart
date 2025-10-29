import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servizio API per lo scambio chiavi E2EE con il backend
class E2EApiService {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  
  /// Ottiene il token di autenticazione
  static Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // CORREZIONE: Usa la stessa chiave di AuthService
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      print('❌ E2EApiService._getAuthToken - Errore: $e');
      return null;
    }
  }
  
  /// Upload della chiave pubblica al backend
  static Future<bool> uploadPublicKey(String publicKey) async {
    try {
      print('🔐 E2EApiService.uploadPublicKey - Upload chiave pubblica al backend');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ E2EApiService.uploadPublicKey - Token non disponibile');
        return false;
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/e2e/upload-key/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'public_key': publicKey,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ E2EApiService.uploadPublicKey - Chiave caricata con successo');
        print('   User ID: ${data['user_id']}');
        print('   Key length: ${data['key_length']}');
        return true;
      } else {
        print('❌ E2EApiService.uploadPublicKey - Errore: ${response.statusCode}');
        print('   Body: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ E2EApiService.uploadPublicKey - Errore: $e');
      return false;
    }
  }
  
  /// Recupera la chiave pubblica di un utente specifico
  static Future<String?> getUserPublicKey(String userId) async {
    try {
      print('🔐 E2EApiService.getUserPublicKey - Recupero chiave per utente $userId');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ E2EApiService.getUserPublicKey - Token non disponibile');
        return null;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/e2e/get-key/$userId/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ E2EApiService.getUserPublicKey - Chiave recuperata');
        print('   Username: ${data['username']}');
        print('   Key length: ${data['key_length']}');
        return data['public_key'] as String;
      } else if (response.statusCode == 404) {
        print('⚠️  E2EApiService.getUserPublicKey - Chiave non disponibile per utente $userId');
        return null;
      } else {
        print('❌ E2EApiService.getUserPublicKey - Errore: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ E2EApiService.getUserPublicKey - Errore: $e');
      return null;
    }
  }
  
  /// Recupera la propria chiave pubblica dal backend
  static Future<String?> getMyPublicKey() async {
    try {
      print('🔐 E2EApiService.getMyPublicKey - Recupero chiave personale');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ E2EApiService.getMyPublicKey - Token non disponibile');
        return null;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/e2e/my-key/'),
        headers: {
          'Authorization': 'Token $token',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ E2EApiService.getMyPublicKey - Chiave personale recuperata');
        return data['public_key'] as String;
      } else if (response.statusCode == 404) {
        print('⚠️  E2EApiService.getMyPublicKey - Chiave personale non configurata');
        return null;
      } else {
        print('❌ E2EApiService.getMyPublicKey - Errore: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ E2EApiService.getMyPublicKey - Errore: $e');
      return null;
    }
  }
  
  /// Recupera le chiavi pubbliche di più utenti in una volta
  static Future<Map<String, String>> getMultipleKeys(List<String> userIds) async {
    try {
      print('🔐 E2EApiService.getMultipleKeys - Recupero ${userIds.length} chiavi');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ E2EApiService.getMultipleKeys - Token non disponibile');
        return {};
      }
      
      final response = await http.post(
        Uri.parse('$baseUrl/e2e/get-keys/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'user_ids': userIds.map((id) => int.tryParse(id) ?? 0).toList(),
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final keysData = data['keys'] as Map<String, dynamic>;
        
        final result = <String, String>{};
        keysData.forEach((userId, userData) {
          final userMap = userData as Map<String, dynamic>;
          result[userId] = userMap['public_key'] as String;
        });
        
        print('✅ E2EApiService.getMultipleKeys - Recuperate ${result.length} chiavi');
        return result;
      } else {
        print('❌ E2EApiService.getMultipleKeys - Errore: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('❌ E2EApiService.getMultipleKeys - Errore: $e');
      return {};
    }
  }
}

