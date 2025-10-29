import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class SocialAuthService {
  static const String _baseUrl = 'http://127.0.0.1:8002/api';
  
  /// Login con Facebook
  static Future<Map<String, dynamic>> loginWithFacebook(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/social/facebook'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'access_token': accessToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': data['token'],
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante il login Facebook',
        };
      }
    } catch (e) {
      print('Errore durante il login Facebook: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  /// Login con Google
  static Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/social/google'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id_token': idToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': data['token'],
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante il login Google',
        };
      }
    } catch (e) {
      print('Errore durante il login Google: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  /// Login con Apple
  static Future<Map<String, dynamic>> loginWithApple(String identityToken) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/social/apple'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identity_token': identityToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'user': UserModel.fromJson(data['user']),
          'token': data['token'],
          'message': data['message'],
        };
      } else {
        final error = jsonDecode(response.body);
        return {
          'success': false,
          'message': error['message'] ?? 'Errore durante il login Apple',
        };
      }
    } catch (e) {
      print('Errore durante il login Apple: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  /// Ottieni i provider supportati
  static Future<Map<String, dynamic>> getSupportedProviders() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/social/providers'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'providers': data['providers'],
        };
      } else {
        return {
          'success': false,
          'message': 'Errore durante il recupero dei provider',
        };
      }
    } catch (e) {
      print('Errore durante il recupero dei provider: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }

  /// Verifica lo stato del servizio
  static Future<Map<String, dynamic>> checkServiceStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/social/status'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'],
          'version': data['version'],
          'supported_providers': data['supported_providers'],
        };
      } else {
        return {
          'success': false,
          'message': 'Servizio non disponibile',
        };
      }
    } catch (e) {
      print('Errore durante la verifica del servizio: $e');
      return {
        'success': false,
        'message': 'Errore di connessione al server',
      };
    }
  }
}
