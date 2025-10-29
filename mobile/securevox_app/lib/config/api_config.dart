/// Configurazione centralizzata degli URL API per SecureVOX
/// 
/// Questo file gestisce tutti gli URL del backend in base all'ambiente
class ApiConfig {
  // Ambiente corrente
  static const bool isProduction = false;
  
  // URL Backend principale (Django)
  // Per simulatore iOS: usa 127.0.0.1 o localhost
  // Per dispositivo fisico: usa l'IP della rete locale
  static const String _devBackendUrl = 'http://127.0.0.1:8001';
  static const String _prodBackendUrl = 'https://api.securevox.it';
  
  // URL Server notifiche
  static const String _devNotifyUrl = 'http://127.0.0.1:8002';
  static const String _prodNotifyUrl = 'https://notify.securevox.it';
  
  // URL Server chiamate
  static const String _devCallUrl = 'http://127.0.0.1:8003';
  static const String _prodCallUrl = 'https://calls.securevox.it';
  
  // Getters pubblici
  static String get backendUrl => isProduction ? _prodBackendUrl : _devBackendUrl;
  static String get notifyUrl => isProduction ? _prodNotifyUrl : _devNotifyUrl;
  static String get callUrl => isProduction ? _prodCallUrl : _devCallUrl;
  
  // URL API completi
  static String get apiUrl => '$backendUrl/api';
  static String get authUrl => '$apiUrl/auth';
  static String get usersUrl => '$apiUrl/users';
  static String get chatsUrl => '$apiUrl/chats';
  static String get callsUrl => '$apiUrl/webrtc/calls';
  static String get mediaUrl => '$apiUrl/media';
  static String get notificationsUrl => '$apiUrl/notifications';
  static String get healthUrl => '$apiUrl/health';
  
  // Configurazione App Distribution
  static const String appDistributionUrl = 'https://securevox.it/app-distribution/api';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // Debug
  static void printConfig() {
    print('🔧 ===== API CONFIGURATION =====');
    print('🔧 Ambiente: ${isProduction ? "PRODUZIONE" : "SVILUPPO"}');
    print('🔧 Backend URL: $backendUrl');
    print('🔧 API URL: $apiUrl');
    print('🔧 Notify URL: $notifyUrl');
    print('🔧 Call URL: $callUrl');
    print('🔧 ===============================');
  }
}

