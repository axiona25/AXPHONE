import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
// import 'package:flutter_webrtc/flutter_webrtc.dart'; // Temporaneamente disabilitato per problemi iOS
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Client Flutter per SecureVOX Call Server
/// Sostituisce NativeAudioCallService con WebRTC reale
class SecureVOXCallService extends ChangeNotifier {
  static final SecureVOXCallService _instance = SecureVOXCallService._internal();
  factory SecureVOXCallService() => _instance;
  SecureVOXCallService._internal();

  // Configurazione
  static const String CALL_SERVER_URL = 'http://127.0.0.1:8002';
  static const String BACKEND_URL = 'http://127.0.0.1:8001/api';
  
  // Socket connection
  IO.Socket? _socket;
  bool _isConnected = false;
  
  // WebRTC
  // RTCPeerConnection? _peerConnection; // Temporaneamente disabilitato per problemi iOS
  // MediaStream? _localStream; // Temporaneamente disabilitato per problemi iOS
  // MediaStream? _remoteStream; // Temporaneamente disabilitato per problemi iOS
  
  // Stato chiamata
  bool _isInitialized = false;
  bool _isCallActive = false;
  String? _currentSessionId;
  String? _currentUserId;
  String? _remoteUserId;
  
  // Controlli audio/video
  bool _isAudioMuted = false;
  bool _isVideoMuted = true; // Default audio-only
  bool _isSpeakerEnabled = false;
  
  // Timer
  DateTime? _callStartTime;
  Timer? _callTimer;
  Duration _callDuration = Duration.zero;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isCallActive => _isCallActive;
  bool get isConnected => _isConnected;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoMuted => _isVideoMuted;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  Duration get callDuration => _callDuration;
  // MediaStream? get localStream => _localStream; // Temporaneamente disabilitato per problemi iOS
  // MediaStream? get remoteStream => _remoteStream; // Temporaneamente disabilitato per problemi iOS
  
  /// Inizializza il servizio
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      print('🚀 SecureVOXCallService.initialize - Inizializzazione...');
      
      // Inizializza WebRTC
      await _initializeWebRTC();
      
      // Connetti al server di signaling
      await _connectToSignalingServer();
      
      _isInitialized = true;
      print('✅ SecureVOXCallService inizializzato');
      
    } catch (e) {
      print('❌ Errore inizializzazione SecureVOXCallService: $e');
      rethrow;
    }
  }
  
  /// Inizializza WebRTC
  Future<void> _initializeWebRTC() async {
    print('🔧 Inizializzazione WebRTC...');
    
    // Configurazione ICE servers
    // final configuration = { // Temporaneamente disabilitato per problemi iOS
    //   'iceServers': [
    //     {'urls': 'stun:stun.l.google.com:19302'},
    //     {'urls': 'stun:stun1.l.google.com:19302'},
    //     // TODO: Aggiungere TURN server proprietario
    //   ]
    // };
    
    // Crea peer connection
    // _peerConnection = await createPeerConnection(configuration); // Temporaneamente disabilitato per problemi iOS
    
    // Setup event handlers
    // _peerConnection!.onIceCandidate = (candidate) { // Temporaneamente disabilitato per problemi iOS
    //   _sendIceCandidate(candidate);
    // };
    
    // _peerConnection!.onAddStream = (stream) { // Temporaneamente disabilitato per problemi iOS
    //   print('📺 Remote stream ricevuto');
    //   _remoteStream = stream;
    //   notifyListeners();
    // };
    
    // _peerConnection!.onConnectionState = (state) { // Temporaneamente disabilitato per problemi iOS
    //   print('🔗 Connection state: $state');
    //   if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
    //     _callStartTime = DateTime.now();
    //     _startCallTimer();
    //   }
    // };
    
    print('✅ WebRTC inizializzato (modalità placeholder)');
  }
  
  /// Connette al server di signaling
  Future<void> _connectToSignalingServer() async {
    print('🔌 Connessione a SecureVOX Call Server...');
    
    _socket = IO.io(CALL_SERVER_URL, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    
    // Event handlers
    _socket!.on('connect', (_) {
      print('✅ Connesso a SecureVOX Call Server');
      _isConnected = true;
      notifyListeners();
    });
    
    _socket!.on('disconnect', (_) {
      print('🔌 Disconnesso da SecureVOX Call Server');
      _isConnected = false;
      notifyListeners();
    });
    
    _socket!.on('authenticated', (data) {
      print('🔐 Autenticato: $data');
    });
    
    _socket!.on('call_joined', (data) {
      _handleCallJoined(data);
    });
    
    _socket!.on('participant_joined', (data) {
      _handleParticipantJoined(data);
    });
    
    _socket!.on('participant_left', (data) {
      _handleParticipantLeft(data);
    });
    
    _socket!.on('offer', (data) {
      _handleOffer(data);
    });
    
    _socket!.on('answer', (data) {
      _handleAnswer(data);
    });
    
    _socket!.on('ice_candidate', (data) {
      _handleIceCandidate(data);
    });
    
    _socket!.connect();
  }
  
  /// Autentica con il server
  Future<void> authenticate(String userId) async {
    if (!_isConnected) {
      throw Exception('Non connesso al server');
    }
    
    // Ottieni token dal backend Django
    final token = await _getCallToken(userId);
    
    _socket!.emit('authenticate', {
      'token': token,
      'userId': userId
    });
    
    _currentUserId = userId;
  }
  
  /// Ottiene token di chiamata dal backend
  Future<String> _getCallToken(String userId, {String? sessionId}) async {
    final prefs = await SharedPreferences.getInstance();
    final authToken = prefs.getString('securevox_auth_token');
    
    if (authToken == null) {
      throw Exception('Token di autenticazione non trovato');
    }
    
    final response = await http.post(
      Uri.parse('$CALL_SERVER_URL/api/call/token'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $authToken',
      },
      body: jsonEncode({
        'userId': userId,
        'sessionId': sessionId,
        'role': 'participant'
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Errore ottenimento token: ${response.statusCode}');
    }
    
    final data = jsonDecode(response.body);
    return data['token'];
  }
  
  /// Avvia una chiamata
  Future<bool> startCall(String targetUserId, String sessionId, {bool isVideoCall = false}) async {
    try {
      print('📞 Avvio chiamata a $targetUserId...');
      
      if (!_isInitialized) await initialize();
      if (_currentUserId == null) throw Exception('Utente non autenticato');
      
      _currentSessionId = sessionId;
      _remoteUserId = targetUserId;
      _isVideoMuted = !isVideoCall;
      
      // Ottieni media stream locale
      await _getUserMedia(audio: true, video: isVideoCall);
      
      // Unisciti alla chiamata
      _socket!.emit('join_call', {
        'sessionId': sessionId,
        'userId': _currentUserId
      });
      
      _isCallActive = true;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      print('❌ Errore avvio chiamata: $e');
      return false;
    }
  }
  
  /// Risponde a una chiamata
  Future<bool> answerCall(String sessionId) async {
    try {
      print('📞 Risposta chiamata $sessionId...');
      
      if (!_isInitialized) await initialize();
      if (_currentUserId == null) throw Exception('Utente non autenticato');
      
      _currentSessionId = sessionId;
      
      // Ottieni media stream locale
      await _getUserMedia(audio: true, video: false);
      
      // Unisciti alla chiamata
      _socket!.emit('join_call', {
        'sessionId': sessionId,
        'userId': _currentUserId
      });
      
      _isCallActive = true;
      notifyListeners();
      
      return true;
      
    } catch (e) {
      print('❌ Errore risposta chiamata: $e');
      return false;
    }
  }
  

  /// Termina la chiamata
  Future<void> endCall() async {
    try {
      print('📞 Terminando chiamata...');
      
      if (_currentSessionId != null && _currentUserId != null) {
        _socket!.emit('leave_call', {
          'sessionId': _currentSessionId,
          'userId': _currentUserId
        });
      }
      
      // Cleanup WebRTC
      await _cleanupWebRTC();
      
      _isCallActive = false;
      _currentSessionId = null;
      _remoteUserId = null;
      _callStartTime = null;
      _stopCallTimer();
      
      notifyListeners();
      
    } catch (e) {
      print('❌ Errore terminazione chiamata: $e');
    }
  }
  
  /// Ottiene stream media utente
  Future<void> _getUserMedia({required bool audio, required bool video}) async {
    // final constraints = { // Temporaneamente disabilitato per problemi iOS
    //   'audio': audio,
    //   'video': video ? {
    //     'width': 640,
    //     'height': 480,
    //     'facingMode': 'user'
    //   } : false
    // };
    
    // _localStream = await navigator.mediaDevices.getUserMedia(constraints); // Temporaneamente disabilitato per problemi iOS
    
    // if (_peerConnection != null) { // Temporaneamente disabilitato per problemi iOS
    //   await _peerConnection!.addStream(_localStream!);
    // }
    
    notifyListeners();
  }
  
  /// Invia offer WebRTC
  Future<void> _sendOffer() async {
    // if (_peerConnection == null || _remoteUserId == null) return; // Temporaneamente disabilitato per problemi iOS
    
    // final offer = await _peerConnection!.createOffer(); // Temporaneamente disabilitato per problemi iOS
    // await _peerConnection!.setLocalDescription(offer); // Temporaneamente disabilitato per problemi iOS
    
    // _socket!.emit('offer', { // Temporaneamente disabilitato per problemi iOS
    //   'sessionId': _currentSessionId,
    //   'targetUserId': _remoteUserId,
    //   'offer': offer.toMap()
    // });
  }
  
  /// Invia answer WebRTC
  Future<void> _sendAnswer(String targetUserId) async {
    // if (_peerConnection == null) return; // Temporaneamente disabilitato per problemi iOS
    
    // final answer = await _peerConnection!.createAnswer(); // Temporaneamente disabilitato per problemi iOS
    // await _peerConnection!.setLocalDescription(answer); // Temporaneamente disabilitato per problemi iOS
    
    // _socket!.emit('answer', { // Temporaneamente disabilitato per problemi iOS
    //   'sessionId': _currentSessionId,
    //   'targetUserId': targetUserId,
    //   'answer': answer.toMap()
    // });
  }
  
  /// Invia ICE candidate
  void _sendIceCandidate(dynamic candidate) {
    // if (_remoteUserId == null) return; // Temporaneamente disabilitato per problemi iOS
    
    // _socket!.emit('ice_candidate', { // Temporaneamente disabilitato per problemi iOS
    //   'sessionId': _currentSessionId,
    //   'targetUserId': _remoteUserId,
    //   'candidate': candidate.toMap()
    // });
  }
  
  // Event handlers
  void _handleCallJoined(dynamic data) {
    print('✅ Unito alla chiamata: $data');
    
    // Se ci sono altri partecipanti, invia offer
    final participants = data['participants'] as List?;
    if (participants != null && participants.length > 1) {
      _sendOffer();
    }
  }
  
  void _handleParticipantJoined(dynamic data) {
    print('👥 Partecipante unito: $data');
    _sendOffer();
  }
  
  void _handleParticipantLeft(dynamic data) {
    print('👋 Partecipante uscito: $data');
  }
  
  void _handleOffer(dynamic data) async {
    print('📡 Offer ricevuto da ${data['fromUserId']}');
    
    // final offer = RTCSessionDescription( // Temporaneamente disabilitato per problemi iOS
    //   data['offer']['sdp'],
    //   data['offer']['type']
    // );
    
    // await _peerConnection!.setRemoteDescription(offer); // Temporaneamente disabilitato per problemi iOS
    // await _sendAnswer(data['fromUserId']); // Temporaneamente disabilitato per problemi iOS
  }
  
  void _handleAnswer(dynamic data) async {
    print('📡 Answer ricevuto da ${data['fromUserId']}');
    
    // final answer = RTCSessionDescription( // Temporaneamente disabilitato per problemi iOS
    //   data['answer']['sdp'],
    //   data['answer']['type']
    // );
    
    // await _peerConnection!.setRemoteDescription(answer); // Temporaneamente disabilitato per problemi iOS
  }
  
  void _handleIceCandidate(dynamic data) async {
    print('🧊 ICE candidate ricevuto');
    
    // final candidate = RTCIceCandidate( // Temporaneamente disabilitato per problemi iOS
    //   data['candidate']['candidate'],
    //   data['candidate']['sdpMid'],
    //   data['candidate']['sdpMLineIndex']
    // );
    
    // await _peerConnection!.addCandidate(candidate); // Temporaneamente disabilitato per problemi iOS
  }
  
  /// Toggle audio
  void toggleAudio() {
    // if (_localStream != null) { // Temporaneamente disabilitato per problemi iOS
    //   final audioTracks = _localStream!.getAudioTracks();
    //   if (audioTracks.isNotEmpty) {
        _isAudioMuted = !_isAudioMuted;
        // audioTracks.first.enabled = !_isAudioMuted; // Temporaneamente disabilitato per problemi iOS
        
        _socket!.emit('mute_audio', {
          'sessionId': _currentSessionId,
          'muted': _isAudioMuted
        });
        
        notifyListeners();
    //   }
    // }
  }
  
  /// Toggle video
  void toggleVideo() {
    // if (_localStream != null) { // Temporaneamente disabilitato per problemi iOS
    //   final videoTracks = _localStream!.getVideoTracks();
    //   if (videoTracks.isNotEmpty) {
        _isVideoMuted = !_isVideoMuted;
        // videoTracks.first.enabled = !_isVideoMuted; // Temporaneamente disabilitato per problemi iOS
        
        _socket!.emit('mute_video', {
          'sessionId': _currentSessionId,
          'muted': _isVideoMuted
        });
        
        notifyListeners();
    //   }
    // }
  }
  
  /// Toggle speaker
  void toggleSpeaker() {
    _isSpeakerEnabled = !_isSpeakerEnabled;
    // TODO: Implementare controllo speaker
    notifyListeners();
  }
  
  // Timer chiamata
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_callStartTime != null) {
        _callDuration = DateTime.now().difference(_callStartTime!);
        notifyListeners();
      }
    });
  }
  
  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callDuration = Duration.zero;
  }
  
  // Cleanup
  Future<void> _cleanupWebRTC() async {
    // await _localStream?.dispose(); // Temporaneamente disabilitato per problemi iOS
    // await _remoteStream?.dispose(); // Temporaneamente disabilitato per problemi iOS
    // await _peerConnection?.close(); // Temporaneamente disabilitato per problemi iOS
    
    // _localStream = null; // Temporaneamente disabilitato per problemi iOS
    // _remoteStream = null; // Temporaneamente disabilitato per problemi iOS
  }
  
  @override
  void dispose() {
    _stopCallTimer();
    _cleanupWebRTC();
    _socket?.disconnect();
    super.dispose();
  }
}
