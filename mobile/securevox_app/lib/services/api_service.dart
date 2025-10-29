import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/api_config.dart';

class ApiService {
  static String get baseUrl => ApiConfig.apiUrl;
  late Dio _dio;
  String? _deviceToken;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (object) => print(object),
    ));
    
    _loadDeviceToken();
  }

  Future<void> _loadDeviceToken() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceToken = prefs.getString('device_token');
  }

  Future<String?> _getAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('securevox_auth_token');
  }

  Future<void> _saveDeviceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_token', token);
    _deviceToken = token;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_deviceToken != null) {
      headers['Authorization'] = 'Device $_deviceToken';
    }
    
    return headers;
  }

  Future<Map<String, String>> get _authHeaders async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    final authToken = await _getAuthToken();
    if (authToken != null) {
      headers['Authorization'] = 'Token $authToken';
    }
    
    return headers;
  }

  // Device Registration
  Future<Map<String, dynamic>> registerDevice({
    required String deviceName,
    required String deviceType,
    required String deviceFingerprint,
    String? fcmToken,
    String? apnsToken,
  }) async {
    try {
      final response = await _dio.post(
        '/devices/register/',
        data: {
          'device_name': deviceName,
          'device_type': deviceType,
          'device_fingerprint': deviceFingerprint,
          'fcm_token': fcmToken,
          'apns_token': apnsToken,
        },
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Health Check
  Future<Map<String, dynamic>> healthCheck() async {
    try {
      final response = await _dio.get(
        '/health/',
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Crypto APIs
  Future<Map<String, dynamic>> uploadKeyBundle({
    required Map<String, dynamic> identityKey,
    required Map<String, dynamic> signedPreKey,
    required List<Map<String, dynamic>> oneTimePreKeys,
  }) async {
    try {
      final response = await _dio.post(
        '/crypto/keybundle/upload/',
        data: {
          'identity_key': identityKey,
          'signed_prekey': signedPreKey,
          'one_time_prekeys': oneTimePreKeys,
        },
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> getKeyBundle(int userId) async {
    try {
      final response = await _dio.get(
        '/crypto/keybundle/$userId/',
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Messaging APIs
  Future<Map<String, dynamic>> sendMessage({
    required String recipientId,
    required String messageType,
    required String encryptedContentHash,
    String? encryptedPayload,
  }) async {
    try {
      final response = await _dio.post(
        '/messages/send/',
        data: {
          'recipient_id': recipientId,
          'message_type': messageType,
          'encrypted_content_hash': encryptedContentHash,
          'encrypted_payload': encryptedPayload,
        },
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // WebRTC APIs
  Future<Map<String, dynamic>> getIceServers() async {
    try {
      final headers = await _authHeaders;
      
      final response = await _dio.get(
        '/webrtc/ice-servers/',
        options: Options(headers: headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createCall({
    required String calleeId,
    required String callType,
    String? encryptedPayload,
  }) async {
    try {
      final headers = await _authHeaders;
      
      final response = await _dio.post(
        '/webrtc/calls/create/',
        data: {
          'callee_id': calleeId,
          'call_type': callType,
          'encrypted_payload': encryptedPayload,
        },
        options: Options(headers: headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> createGroupCall({
    required String roomName,
    required int maxParticipants,
  }) async {
    try {
      final response = await _dio.post(
        '/webrtc/calls/group/',
        data: {
          'room_name': roomName,
          'max_participants': maxParticipants,
        },
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> endCall({
    required String sessionId,
  }) async {
    try {
      final response = await _dio.post(
        '/webrtc/calls/end/',
        data: {
          'session_id': sessionId,
        },
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Call Notification APIs
  Future<Map<String, dynamic>> getPendingCalls() async {
    try {
      final headers = await _authHeaders;
      
      final response = await _dio.get(
        '/notifications/calls/pending/',
        options: Options(headers: headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> markCallSeen({
    required String callId,
  }) async {
    try {
      final headers = await _authHeaders;
      
      final response = await _dio.post(
        '/notifications/calls/mark-seen/',
        data: {
          'call_id': callId,
        },
        options: Options(headers: headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Call History APIs
  Future<Map<String, dynamic>> getCallHistory() async {
    try {
      final headers = await _authHeaders;
      
      final response = await _dio.get(
        '/webrtc/calls/',
        options: Options(headers: headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Admin APIs
  Future<Map<String, dynamic>> remoteWipe({
    required String deviceId,
    required String reason,
    String? encryptedPayload,
  }) async {
    try {
      final response = await _dio.post(
        '/api/admin/remote-wipe/',
        data: {
          'device_id': deviceId,
          'reason': reason,
          'encrypted_payload': encryptedPayload,
        },
        options: Options(headers: _headers),
      );
      
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Error Handling
  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map<String, dynamic> && data.containsKey('error')) {
        return data['error'];
      }
      return 'Errore del server: ${e.response!.statusCode}';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      return 'Timeout di connessione';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      return 'Timeout di ricezione';
    } else if (e.type == DioExceptionType.connectionError) {
      return 'Errore di connessione';
    } else {
      return 'Errore sconosciuto: ${e.message}';
    }
  }
}
