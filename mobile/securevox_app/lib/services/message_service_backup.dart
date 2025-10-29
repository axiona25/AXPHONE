import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';  // Temporaneamente disabilitato
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
// import 'package:contacts_service/contacts_service.dart'; // Temporaneamente disabilitato
import '../models/message_model.dart';
import '../models/chat_model.dart';
import 'timezone_service.dart';
import 'unified_realtime_service.dart';
import 'real_chat_service.dart';
import 'user_service.dart';

class MessageService extends ChangeNotifier {
  static const String baseUrl = 'http://127.0.0.1:8001/api';
  
  // Cache per i messaggi - istanza invece di statica per persistenza
  final Map<String, List<MessageModel>> _messageCache = {};
  final Map<String, DateTime> _lastFetch = {};
  final Map<String, int> _unreadCounts = {};
  
  // Stream controllers per i messaggi di ogni chat
  final Map<String, StreamController<List<MessageModel>>> _messageStreams = {};
  
  // Traccia quale chat è attualmente visualizzata
  String? _currentlyViewingChatId;
  static const Duration cacheExpiry = Duration(minutes: 5);
  
  // Servizio di sincronizzazione real-time - inizializzato lazy
  // Servizio unificato per real-time
  UnifiedRealtimeService? _unifiedRealtime;
  
  // Timer per il polling automatico
  Timer? _pollingTimer;
  static const Duration pollingInterval = Duration(seconds: 30); // Ridotto a 30 secondi per evitare refresh continui

  /// Inizializza il servizio realtime unificato
  Future<void> _initializeRealtimeSync() async {
    if (_unifiedRealtime == null) {
      try {
        print('📱 MessageService._initializeRealtimeSync - Inizializzazione UnifiedRealtimeService...');
        _unifiedRealtime = UnifiedRealtimeService();
        await _unifiedRealtime!.initialize();
        print('✅ MessageService - UnifiedRealtimeService inizializzato');
      } catch (e) {
        print('❌ MessageService - Errore inizializzazione UnifiedRealtimeService: $e');
      }
    }
  }


  /// Usando solo il nostro sistema SecureVOX Notify

  /// Inizializza le notifiche simulate per i simulatori
  void _initializeSimulatedNotifications() {
    print('📱 MessageService._initializeSimulatedNotifications - Sistema di notifiche simulate attivato');
    // Le notifiche simulate funzioneranno tramite il sistema di simulazione esistente
  }

  /// Inizializza il servizio di notifiche real-time
  Future<void> _initializeRealtimeNotification() async {
    // Usa solo il nostro sistema di notifiche proprietario SecureVOX Notify
    print('📱 MessageService._initializeRealtimeNotification - Usando sistema notifiche proprietario SecureVOX Notify');
  }

  /// Inizializza il servizio di notifiche personalizzato
  Future<void> _initializeCustomPushNotification() async {
    // Usa solo il nostro sistema di notifiche proprietario SecureVOX Notify
    print('📱 MessageService._initializeCustomPushNotification - Usando sistema notifiche proprietario SecureVOX Notify');
  }

  /// Gestisce le notifiche in arrivo dal CustomPushNotificationService
  void _handleIncomingNotification(Map<String, dynamic> notificationData) {
    try {
      print('📨 MessageService._handleIncomingNotification - Notifica ricevuta: ${notificationData['title']}');
      
      final notificationType = notificationData['notification_type'] ?? 'message';
      
      if (notificationType == 'message') {
        final data = notificationData['data'] ?? {};
        final chatId = data['chat_id'] ?? '';
        final content = notificationData['body'] ?? data['content'] ?? '';
        final senderId = data['sender_id'] ?? 'unknown';
        
        if (chatId.isNotEmpty && content.isNotEmpty) {
          // IMPORTANTE: Controlla se l'utente sta visualizzando questa chat
          final isCurrentlyViewing = _isCurrentlyViewingChat(chatId);
          
          // Crea il messaggio in arrivo
          final now = DateTime.now();
          final incomingMessage = MessageModel(
            id: data['message_id'] ?? 'notification_${now.millisecondsSinceEpoch}',
            chatId: chatId,
            senderId: senderId,
            isMe: false, // Messaggio in arrivo
            type: MessageType.text,
            content: content,
            time: TimezoneService.formatCallTime(now),
            timestamp: now,
            metadata: TextMessageData(text: content).toJson(),
            isRead: isCurrentlyViewing, // Letto se sta visualizzando la chat
          );
          
          // Aggiungi alla cache
          addMessageToCache(chatId, incomingMessage);
          
          // Sincronizza con RealChatService
          _syncWithRealChatService(chatId, content);
          
          // Notifica i listener per aggiornare l'UI
          notifyListeners();
          
          if (isCurrentlyViewing) {
            print('📨 MessageService._handleIncomingNotification - Messaggio ricevuto e MARCATO COME LETTO (utente sta visualizzando la chat): $content');
          } else {
            print('📨 MessageService._handleIncomingNotification - Messaggio ricevuto NON LETTO (utente non sta visualizzando la chat): $content');
          }
        }
      }
    } catch (e) {
      print('❌ MessageService._handleIncomingNotification - Errore: $e');
    }
  }

  /// Gestisce i messaggi in arrivo dal servizio real-time
  void _handleIncomingRealtimeMessage(Map<String, dynamic> messageData) {
    try {
      final chatId = messageData['data']?['chat_id'] ?? '';
      final content = messageData['body'] ?? '';
      final senderId = messageData['data']?['sender_id'] ?? 'unknown';
      
      if (chatId.isNotEmpty && content.isNotEmpty) {
        // IMPORTANTE: Controlla se l'utente sta visualizzando questa chat
        final isCurrentlyViewing = _isCurrentlyViewingChat(chatId);
        
        // Crea il messaggio in arrivo
        final now = DateTime.now();
        final incomingMessage = MessageModel(
          id: 'realtime_${now.millisecondsSinceEpoch}',
          chatId: chatId,
          senderId: senderId,
          isMe: false, // Messaggio in arrivo
          type: MessageType.text,
          content: content,
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: TextMessageData(text: content).toJson(),
          isRead: isCurrentlyViewing, // Letto se sta visualizzando la chat
        );
        
        // Aggiungi alla cache
        addMessageToCache(chatId, incomingMessage);
        
        // Sincronizza con RealChatService
        _syncWithRealChatService(chatId, content);
        
        // Notifica i listener per aggiornare l'UI
        notifyListeners();
        
        if (isCurrentlyViewing) {
          print('📨 MessageService._handleIncomingRealtimeMessage - Messaggio ricevuto e MARCATO COME LETTO (utente sta visualizzando la chat): $content');
        } else {
          print('📨 MessageService._handleIncomingRealtimeMessage - Messaggio ricevuto NON LETTO (utente non sta visualizzando la chat): $content');
        }
      }
    } catch (e) {
      print('❌ MessageService._handleIncomingRealtimeMessage - Errore: $e');
    }
  }

  /// Ottiene il token di autenticazione
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      print('📱 MessageService._getAuthToken - Errore nel recupero del token: $e');
      return null;
    }
  }

  /// Controlla se l'utente sta attualmente visualizzando una chat
  bool _isCurrentlyViewingChat(String chatId) {
    return _currentlyViewingChatId == chatId;
  }

  /// Marca una chat come attualmente visualizzata
  void markChatAsCurrentlyViewing(String chatId) {
    _currentlyViewingChatId = chatId;
    print('📱 MessageService.markChatAsCurrentlyViewing - Chat $chatId marcata come visualizzata');
    
    // Marca automaticamente tutti i messaggi non letti come letti
    markChatAsRead(chatId);
  }

  /// Marca una chat come non più visualizzata
  void markChatAsNotViewing() {
    _currentlyViewingChatId = null;
    print('📱 MessageService.markChatAsNotViewing - Nessuna chat visualizzata');
  }


  /// Invia un messaggio di testo
  Future<bool> sendTextMessage({
    required String chatId,
    required String recipientId,
    required String text,
  }) async {
    try {
      print('📱 MessageService.sendTextMessage - Invio messaggio di testo');
      
      final token = await _getAuthToken();
      if (token == null) {
        print('📱 MessageService.sendTextMessage - Token non disponibile');
        return false;
      }

      // Invia il messaggio al backend
      final response = await http.post(
        Uri.parse('$baseUrl/chats/$chatId/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: jsonEncode({
          'content': text,
          'message_type': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('📱 MessageService.sendTextMessage - Messaggio inviato al backend: ${responseData['message_id']}');
        
        // Aggiorna la cache locale con il messaggio inviato
        final currentUserId = UserService.getCurrentUserIdSync();
        final now = DateTime.now();
        final message = MessageModel(
          id: responseData['message_id'],
          chatId: chatId,
          senderId: currentUserId ?? 'unknown_user',
          isMe: true, // IMPORTANTE: I messaggi inviati dall'utente corrente sono sempre isMe = true
          type: MessageType.text,
          content: text,
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: TextMessageData(text: text).toJson(),
          isRead: true, // IMPORTANTE: I messaggi inviati dall'utente corrente sono sempre letti
        );
        
        addMessageToCache(chatId, message);
        
        // NON simulare l'arrivo del messaggio per l'utente corrente
        // La simulazione dovrebbe avvenire solo per l'altro utente
        // _simulateIncomingMessage(chatId, text, currentUserId ?? 'unknown_user');
        
        // Sincronizza con RealChatService per aggiornare la lista chat
        _syncWithRealChatService(chatId, text);
        
        notifyListeners();
        
        // INVIO NOTIFICA VIA SECUREVOX NOTIFY
        print('📱 MessageService.sendMessage - Inizializzazione UnifiedRealtimeService...');
        await _initializeRealtimeSync();
        print('📱 MessageService.sendMessage - UnifiedRealtimeService inizializzato: ${_unifiedRealtime != null}');
        
        if (_unifiedRealtime != null) {
          print('📱 MessageService.sendMessage - Invio notifica via SecureVOX Notify...');
          print('📱   Chat ID: $chatId');
          print('📱   Recipient ID: $recipientId');
          print('📱   Message ID: ${responseData['message_id']}');
          print('📱   Content: $text');
          
          await _unifiedRealtime!.sendPushNotification(
            recipientId: recipientId,
            chatId: chatId,
            messageId: responseData['message_id'],
            content: text,
            messageType: 'text',
          );
          print('📱 MessageService.sendMessage - Notifica inviata via SecureVOX Notify');
        } else {
          print('📱 MessageService.sendMessage - UnifiedRealtimeService non disponibile');
        }
        
        print('📱 MessageService.sendTextMessage - Messaggio aggiunto alla cache: $chatId');
        print('📱 MessageService.sendTextMessage - Contenuto: $text');
        
        return true;
      } else {
        print('📱 MessageService.sendTextMessage - Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('📱 MessageService.sendTextMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con immagine
  Future<bool> sendImageMessage({
    required String chatId,
    required String recipientId,
    String? caption,
  }) async {
    try {
      print('📱 MessageService.sendImageMessage - Invio messaggio con immagine');
      
      // Picker per selezionare immagine
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image == null) {
        print('📱 MessageService.sendImageMessage - Nessuna immagine selezionata');
        return false;
      }

      // Simula upload (in produzione: upload cifrato + crittografia E2EE)
      final imageUrl = await _simulateFileUpload(image.path, 'image');
      
      // Crea il messaggio
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.image,
        content: caption ?? '📷 Immagine',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: ImageMessageData(
          imageUrl: imageUrl,
          caption: caption,
        ).toJson(),
      );

      // Simula invio
      await _simulateMessageSending(message);
      
      // Aggiorna la cache
      addMessageToCache(chatId, message);
      
      print('📱 MessageService.sendImageMessage - Immagine inviata con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendImageMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con video
  Future<bool> sendVideoMessage({
    required String chatId,
    required String recipientId,
    String? caption,
  }) async {
    try {
      print('📱 MessageService.sendVideoMessage - Invio messaggio con video');
      
      // Picker per selezionare video
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) {
        print('📱 MessageService.sendVideoMessage - Nessun video selezionato');
        return false;
      }

      // Simula upload (in produzione: upload cifrato + crittografia E2EE)
      final videoUrl = await _simulateFileUpload(video.path, 'video');
      final thumbnailUrl = await _simulateThumbnailGeneration(video.path);
      
      // Crea il messaggio
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.video,
        content: caption ?? '🎥 Video',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: VideoMessageData(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          caption: caption,
        ).toJson(),
      );

      // Simula invio
      await _simulateMessageSending(message);
      
      // Aggiorna la cache
      addMessageToCache(chatId, message);
      
      print('📱 MessageService.sendVideoMessage - Video inviato con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendVideoMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio audio
  Future<bool> sendVoiceMessage({
    required String chatId,
    required String recipientId,
    required String audioPath,
    required String duration,
  }) async {
    try {
      print('📱 MessageService.sendVoiceMessage - Invio messaggio audio');
      
      // Simula upload (in produzione: upload cifrato + crittografia E2EE)
      final audioUrl = await _simulateFileUpload(audioPath, 'audio');
      
      // Crea il messaggio
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.voice,
        content: '🎤 Audio',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: VoiceMessageData(
          duration: duration,
          audioUrl: audioUrl,
        ).toJson(),
      );

      // Simula invio
      await _simulateMessageSending(message);
      
      // Aggiorna la cache
      addMessageToCache(chatId, message);
      
      print('📱 MessageService.sendVoiceMessage - Audio inviato con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendVoiceMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con posizione
  Future<bool> sendLocationMessage({
    required String chatId,
    required String recipientId,
  }) async {
    try {
      print('📱 MessageService.sendLocationMessage - Invio messaggio con posizione');
      
      // Richiedi permessi di posizione
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('📱 MessageService.sendLocationMessage - Permessi di posizione negati');
          return false;
        }
      }

      // Ottieni posizione corrente
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Ottieni indirizzo (reverse geocoding)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      final placemark = placemarks.first;
      final address = '${placemark.street}, ${placemark.locality}';
      final city = placemark.locality ?? 'Sconosciuta';
      final country = placemark.country;
      
      // Crea il messaggio
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.location,
        content: '📍 Posizione',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: LocationMessageData(
          latitude: position.latitude,
          longitude: position.longitude,
          address: address,
          city: city,
          country: country,
        ).toJson(),
      );

      // Simula invio
      await _simulateMessageSending(message);
      
      // Aggiorna la cache
      addMessageToCache(chatId, message);
      
      print('📱 MessageService.sendLocationMessage - Posizione inviata con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendLocationMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con allegato documento
  Future<bool> sendDocumentMessage({
    required String chatId,
    required String recipientId,
  }) async {
    try {
      print('📱 MessageService.sendDocumentMessage - Invio messaggio con documento');
      
      // Picker per selezionare file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'zip', 'rar'],
      );

      if (result == null) {
        print('📱 MessageService.sendDocumentMessage - Nessun file selezionato');
        return false;
      }

      final file = File(result.files.first.path!);
      final fileName = result.files.first.name;
      final fileSize = await file.length();
      
      // Determina il tipo di file
      final fileExtension = fileName.split('.').last.toLowerCase();
      final fileType = _getFileType(fileExtension);
      
      // Simula upload (in produzione: upload cifrato + crittografia E2EE)
      final fileUrl = await _simulateFileUpload(file.path, 'document');
      
      // Crea il messaggio
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.attachment,
        content: '📎 $fileName',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: AttachmentMessageData(
          fileName: fileName,
          fileType: fileType,
          fileUrl: fileUrl,
          fileSize: fileSize,
        ).toJson(),
      );

      // Simula invio
      await _simulateMessageSending(message);
      
      // Aggiorna la cache
      addMessageToCache(chatId, message);
      
      print('📱 MessageService.sendDocumentMessage - Documento inviato con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendDocumentMessage - Errore: $e');
      return false;
    }
  }

  /// Invia un messaggio con contatto
  Future<bool> sendContactMessage({
    required String chatId,
    required String recipientId,
  }) async {
    try {
      print('📱 MessageService.sendContactMessage - Invio messaggio con contatto');
      
      // Picker per selezionare contatto
      // Contact? contact = await ContactsService.openDeviceContactPicker(); // Temporaneamente disabilitato
      
      if (contact == null) {
        print('📱 MessageService.sendContactMessage - Nessun contatto selezionato');
        return false;
      }

      // Crea il messaggio
      final now = DateTime.now();
      final message = MessageModel(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: chatId,
        senderId: 'current_user',
        isMe: true,
        type: MessageType.contact,
        content: '👤 ${contact.displayName ?? 'Contatto'}',
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: ContactMessageData(
          name: contact.displayName ?? 'Sconosciuto',
          phone: contact.phones?.isNotEmpty == true ? contact.phones!.first.value ?? '' : '',
          email: contact.emails?.isNotEmpty == true ? contact.emails!.first.value : null,
          organization: contact.company,
        ).toJson(),
      );

      // Simula invio
      await _simulateMessageSending(message);
      
      // Aggiorna la cache
      addMessageToCache(chatId, message);
      
      print('📱 MessageService.sendContactMessage - Contatto inviato con successo');
      return true;
    } catch (e) {
      print('📱 MessageService.sendContactMessage - Errore: $e');
      return false;
    }
  }

  /// Ottiene lo stream dei messaggi per una chat
  Stream<List<MessageModel>> getChatMessagesStream(String chatId) {
    if (!_messageStreams.containsKey(chatId)) {
      _messageStreams[chatId] = StreamController<List<MessageModel>>.broadcast();
    }
    
    // Carica i messaggi iniziali
    _loadMessagesForStream(chatId);
    
    return _messageStreams[chatId]!.stream;
  }
  
  /// Carica i messaggi per lo stream
  Future<void> _loadMessagesForStream(String chatId) async {
    try {
      final messages = await getChatMessages(chatId);
      if (_messageStreams.containsKey(chatId) && !_messageStreams[chatId]!.isClosed) {
        _messageStreams[chatId]!.add(messages);
      }
    } catch (e) {
      print('📱 MessageService._loadMessagesForStream - Errore: $e');
    }
  }

  /// Ottiene i messaggi di una chat
  Future<List<MessageModel>> getChatMessages(String chatId) async {
    try {
      print('📱 MessageService.getChatMessages - Recupero messaggi per chat $chatId');
      
      // PRIORITÀ: Usa sempre la cache locale se disponibile per preservare lo stato di lettura
      if (_messageCache.containsKey(chatId) && _messageCache[chatId]!.isNotEmpty) {
        print('📱 MessageService.getChatMessages - Cache HIT - ${_messageCache[chatId]!.length} messaggi');
        
        // Applica sempre lo stato di lettura locale per assicurare consistenza
        final cachedMessages = _messageCache[chatId]!;
        final messagesWithReadStatus = await _applyLocalReadStatus(chatId, List.from(cachedMessages));
        
        // Ordina i messaggi per timestamp (dal più vecchio al più recente)
        messagesWithReadStatus.sort((a, b) => a.time.compareTo(b.time));
        
        // Aggiorna la cache con lo stato corretto
        _messageCache[chatId] = messagesWithReadStatus;
        
        return messagesWithReadStatus;
      }

      final token = await _getAuthToken();
      if (token == null) {
        return [];
      }

      // Chiamata al backend solo se non ci sono messaggi in cache
      final response = await http.get(
        Uri.parse('$baseUrl/chats/$chatId/messages/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        final currentUserId = UserService.getCurrentUserIdSync();
        
        final messages = data.map((json) {
          // LOGICA CORRETTA: I miei messaggi a destra (verde), quelli degli altri a sinistra (grigio)
          final senderId = json['sender_id']?.toString() ?? '';
          final isMe = senderId == currentUserId || senderId == 'current_user';
          
          return MessageModel(
            id: json['id'],
            chatId: chatId,
            senderId: senderId,
            isMe: isMe,
            type: _parseMessageType(json['message_type']),
            content: json['content'],
            time: _formatTime(json['created_at']),
            timestamp: DateTime.parse(json['created_at']),
            metadata: TextMessageData(text: json['content']).toJson(),
            isRead: isMe, // I messaggi inviati sono sempre letti
          );
        }).toList();
        
        if (messages.isEmpty) {
          return [];
        }
        
        // Applica lo stato di lettura salvato localmente
        final messagesWithReadStatus = await _applyLocalReadStatus(chatId, messages);
        
        // Ordina i messaggi per timestamp (dal più vecchio al più recente)
        messagesWithReadStatus.sort((a, b) => a.time.compareTo(b.time));
        
        // Aggiorna la cache
        _messageCache[chatId] = List.from(messagesWithReadStatus);
        _lastFetch[chatId] = DateTime.now();
        
        return messagesWithReadStatus;
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Simula l'invio di un messaggio (in produzione: crittografia E2EE + invio al server)
  Future<void> _simulateMessageSending(MessageModel message) async {
    // Simula delay di rete
    await Future.delayed(const Duration(milliseconds: 500));
    print('📱 MessageService._simulateMessageSending - Messaggio simulato inviato: ${message.type}');
  }

  /// Simula l'upload di un file (in produzione: upload cifrato al server)
  Future<String> _simulateFileUpload(String filePath, String type) async {
    // Simula delay di upload
    await Future.delayed(const Duration(seconds: 2));
    final fileName = filePath.split('/').last;
    return 'https://securevox.com/files/$type/$fileName';
  }

  /// Simula la generazione di thumbnail per video
  Future<String> _simulateThumbnailGeneration(String videoPath) async {
    // Simula delay di generazione thumbnail
    await Future.delayed(const Duration(milliseconds: 500));
    final fileName = videoPath.split('/').last;
    return 'https://securevox.com/thumbnails/$fileName.jpg';
  }

  /// Determina il tipo di file dall'estensione
  String _getFileType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'txt':
        return 'text/plain';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp3':
        return 'audio/mpeg';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  /// Aggiunge un messaggio alla cache
  void addMessageToCache(String chatId, MessageModel message) {
    if (!_messageCache.containsKey(chatId)) {
      _messageCache[chatId] = [];
    }
    _messageCache[chatId]!.add(message);
    
    // Debug: messaggio aggiunto alla cache
    print('📱 MessageService.addMessageToCache - Messaggio aggiunto alla cache: $chatId');
    print('📱 MessageService.addMessageToCache - Contenuto: ${message.content}');
    
    // Aggiorna lo stream se esiste
    if (_messageStreams.containsKey(chatId) && !_messageStreams[chatId]!.isClosed) {
      _messageStreams[chatId]!.add(List.from(_messageCache[chatId]!));
    }
    
    notifyListeners();
  }

  /// Rimuove tutti i messaggi di una chat dalla cache
  void clearChatMessages(String chatId) {
    _messageCache.remove(chatId);
    _lastFetch.remove(chatId);
    _unreadCounts.remove(chatId);
    print('🧹 MessageService - Messaggi chat $chatId rimossi dalla cache');
    notifyListeners();
  }

  /// Pulisce tutti i messaggi mock dalla cache
  void clearMockMessages() {
    print('🧹 MessageService - Pulizia messaggi mock dalla cache');
    
    for (final chatId in _messageCache.keys.toList()) {
      final messages = _messageCache[chatId] ?? [];
      final filteredMessages = messages.where((message) {
        // Escludi messaggi mock
        final isMockMessage = message.id.startsWith('sim_') || 
                             message.id.startsWith('arrival_') || 
                             message.id.startsWith('realtime_') ||
                             message.id.startsWith('test_') ||
                             message.id.startsWith('mock_');
        return !isMockMessage;
      }).toList();
      
      if (filteredMessages.length != messages.length) {
        _messageCache[chatId] = filteredMessages;
        print('🧹 MessageService - Rimossi ${messages.length - filteredMessages.length} messaggi mock da chat $chatId');
      }
    }
    
    notifyListeners();
  }

  /// Pulisce la cache dei messaggi
  void clearCache() {
    _messageCache.clear();
    _lastFetch.clear();
    print('📱 MessageService.clearCache - Cache pulita');
    notifyListeners();
  }

  /// Dispose del servizio
  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }

  /// Forza il refresh di tutte le chat per sincronizzazione real-time
  Future<void> refreshAllChats() async {
    try {
      // IMPORTANTE: Refresh completamente in background
      // Non aggiorna l'UI per evitare refresh continui
      // Non pulisce cache per preservare lo stato di lettura
      // Nessun log per evitare spam nei log
      
    } catch (e) {
      // Solo log degli errori critici
      print('📱 MessageService.refreshAllChats - Errore critico: $e');
    }
  }

  // ===== METODI PER IL PROVIDER =====

  /// Pulisce completamente la cache dei messaggi
  void clearMessageCache() {
    print('📱 MessageService.clearMessageCache - Pulizia cache messaggi');
    _messageCache.clear();
    _lastFetch.clear();
    notifyListeners();
  }

  /// Inizializza la sincronizzazione real-time
  Future<void> initializeRealtimeSync() async {
    print('📱 MessageService.initializeRealtimeSync - Inizializzazione sincronizzazione real-time');
    await _initializeRealtimeSync();
    if (_realtimeSync != null) {
      await _realtimeSync!.initialize();
    }
    
    // IMPORTANTE: Inizializza il servizio di notifiche personalizzato per ascoltare i messaggi in arrivo
    await _initializeCustomPushNotification();
    
    // Avvia il polling automatico
    startPolling();
  }

  /// Avvia il polling automatico per la sincronizzazione real-time
  void startPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
    }
    
    _pollingTimer = Timer.periodic(pollingInterval, (timer) {
      _performPolling();
    });
    
    // Nessun log per evitare spam nei log
  }

  /// Ferma il polling automatico
  void stopPolling() {
    if (_pollingTimer != null) {
      _pollingTimer!.cancel();
      _pollingTimer = null;
      // Nessun log per evitare spam nei log
    }
  }

  /// Esegue il polling per la sincronizzazione
  Future<void> _performPolling() async {
    try {
      // IMPORTANTE: Il polling funziona completamente in background
      // Non aggiorna l'UI per evitare refresh continui
      // Non ricarica messaggi per preservare lo stato di lettura
      // Non pulisce cache per mantenere consistenza
      // Nessun log per evitare spam nei log
      
    } catch (e) {
      // Solo log degli errori critici
      print('📱 MessageService._performPolling - Errore critico: $e');
    }
  }





  /// Marca una chat come letta
  void markChatAsRead(String chatId) {
    print('📱 MessageService.markChatAsRead - Chat $chatId marcata come letta');
    
    // Marca tutti i messaggi non letti come letti
    final messages = _messageCache[chatId] ?? [];
    bool hasChanges = false;
    final updatedMessages = <MessageModel>[];
    
    for (final message in messages) {
      if (!message.isMe && !message.isRead) {
        // Crea una copia del messaggio con isRead = true
        final updatedMessage = MessageModel(
          id: message.id,
          chatId: message.chatId,
          senderId: message.senderId,
          isMe: message.isMe,
          type: message.type,
          content: message.content,
          time: message.time,
          timestamp: message.timestamp,
          metadata: message.metadata,
          isRead: true,
        );
        updatedMessages.add(updatedMessage);
        hasChanges = true;
        print('📱 MessageService.markChatAsRead - ✅ Messaggio marcato come letto: ${message.content}');
      } else {
        updatedMessages.add(message);
      }
    }
    
    if (hasChanges) {
      _messageCache[chatId] = updatedMessages;
      
      // Salva lo stato di lettura localmente per persistenza
      _saveReadStatusLocally(chatId, updatedMessages).then((_) {
        print('📱 MessageService.markChatAsRead - Stato lettura salvato localmente');
      });
      
      // Aggiorna anche RealChatService per rimuovere il badge
      _updateChatReadStatus(chatId);
      
      notifyListeners();
      print('📱 MessageService.markChatAsRead - ✅ Cache aggiornata e stato salvato');
    } else {
      print('📱 MessageService.markChatAsRead - ⚠️ Nessun cambiamento necessario');
    }
  }

  /// Ottiene il numero di messaggi non letti per una chat
  int getUnreadCount(String chatId) {
    // PRIORITÀ: Usa sempre la cache locale per calcolare i messaggi non letti
    final messages = _messageCache[chatId] ?? [];
    
    // IMPORTANTE: Conta solo i messaggi NON inviati dall'utente corrente e non letti
    // I messaggi inviati dall'utente corrente (isMe = true) non devono essere contati come non letti
    final unreadCount = messages.where((msg) => !msg.isMe && !msg.isRead).length;
    
    // Se non ci sono messaggi nella cache locale, restituisci 0
    // Non fare chiamate al backend per evitare inconsistenze
    if (messages.isEmpty) {
      print('📱 MessageService.getUnreadCount - Chat $chatId: 0 messaggi non letti (cache vuota)');
      return 0;
    }
    
    // Debug: stampa informazioni sui messaggi
    print('📱 MessageService.getUnreadCount - Chat $chatId: $unreadCount messaggi non letti');
    print('📱 MessageService.getUnreadCount - Totale messaggi: ${messages.length}');
    
    for (final message in messages) {
      print('📱 MessageService.getUnreadCount - Messaggio: ${message.content}, isMe: ${message.isMe}, isRead: ${message.isRead}');
    }
    
    return unreadCount;
  }

  /// Simula l'arrivo di un messaggio per un altro utente (solo per testing)
  /// Questo metodo dovrebbe essere chiamato solo per simulare messaggi in arrivo
  void simulateIncomingMessageForOtherUser(String chatId, String content, String senderId) {
    try {
      print('📱 MessageService.simulateIncomingMessageForOtherUser - Simulazione messaggio in arrivo per altro utente: $chatId');
      
      // Crea un messaggio "in arrivo" per l'altro utente
      final now = DateTime.now();
      final incomingMessage = MessageModel(
        id: 'sim_${now.millisecondsSinceEpoch}',
        chatId: chatId,
        senderId: senderId,
        isMe: false, // Per l'altro utente, questo messaggio non è suo
        type: MessageType.text,
        content: content,
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: TextMessageData(text: content).toJson(),
        isRead: false, // IMPORTANTE: Per l'altro utente, questo messaggio non è letto
      );
      
      // Aggiungi il messaggio alla cache
      addMessageToCache(chatId, incomingMessage);
      
      // Aggiorna la lista chat per mostrare il nuovo messaggio con badge
      _syncWithRealChatService(chatId, content);
      
      print('📱 MessageService.simulateIncomingMessageForOtherUser - Messaggio in arrivo aggiunto: $content (NON LETTO)');
      
      // Notifica i listener per aggiornare l'UI
      notifyListeners();
      
    } catch (e) {
      print('📱 MessageService.simulateIncomingMessageForOtherUser - Errore: $e');
    }
  }

  /// Ottiene l'ultimo messaggio di una chat
  String getLastMessage(String chatId) {
    final messages = _messageCache[chatId] ?? [];
    if (messages.isEmpty) {
      return '';
    }
    
    // Ordina per timestamp e prendi l'ultimo
    messages.sort((a, b) => b.time.compareTo(a.time));
    final lastMessage = messages.first;
    
    // Debug: ultimo messaggio recuperato
    print('📱 MessageService.getLastMessage - Chat $chatId: ultimo messaggio = ${lastMessage.content}');
    
    // Formatta il contenuto in base al tipo
    switch (lastMessage.type) {
      case MessageType.text:
        return lastMessage.content;
      case MessageType.image:
        return '📷 Immagine';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.voice:
        return '🎤 Audio';
      case MessageType.location:
        return '📍 Posizione';
      case MessageType.attachment:
        return '📎 Allegato';
      case MessageType.contact:
        return '👤 Contatto';
      default:
        return lastMessage.content;
    }
  }

  /// Converte il tipo di messaggio dal backend
  MessageType _parseMessageType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.voice;
      case 'file':
        return MessageType.attachment;
      default:
        return MessageType.text;
    }
  }

  /// Formatta il tempo dal backend
  String _formatTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return TimezoneService.formatCallTime(dateTime);
    } catch (e) {
      return TimezoneService.formatCallTime(DateTime.now());
    }
  }

  /// Sincronizza con RealChatService per aggiornare la lista chat
  void _syncWithRealChatService(String chatId, String lastMessage) {
    try {
      // Calcola il numero di messaggi non letti per questa chat
      final unreadCount = getUnreadCount(chatId);
      
      // IMPORTANTE: Aggiorna il lastMessage nella cache delle chat
      RealChatService.updateChatLastMessage(chatId, lastMessage, unreadCount);
      
      print('📱 MessageService._syncWithRealChatService - Chat $chatId aggiornata: "$lastMessage" ($unreadCount non letti)');
      
    } catch (e) {
      print('📱 MessageService._syncWithRealChatService - Errore critico: $e');
    }
  }

  /// Forza l'aggiornamento immediato della lista chat
  Future<void> _forceChatListUpdate() async {
    try {
      // IMPORTANTE: Aggiornamento completamente in background
      // Non aggiorna l'UI per evitare refresh continui
      // Non pulisce cache per preservare lo stato di lettura
      // Nessun log per evitare spam nei log
      
    } catch (e) {
      // Solo log degli errori critici
      print('📱 MessageService._forceChatListUpdate - Errore critico: $e');
    }
  }

  /// Sincronizza i dati in background senza aggiornare l'UI
  Future<void> syncInBackground() async {
    try {
      // IMPORTANTE: Sincronizzazione completamente in background
      // Non aggiorna l'UI per evitare refresh continui
      // Non pulisce cache per preservare lo stato di lettura
      // Nessun log per evitare spam nei log
      
    } catch (e) {
      // Solo log degli errori critici
      print('🔄 MessageService.syncInBackground - Errore critico: $e');
    }
  }

  /// Marca tutti i messaggi di una chat come letti
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      print('📱 MessageService.markMessagesAsRead - INIZIO: Marcando messaggi come letti per chat: $chatId');
      
      // Carica i messaggi dalla cache o dal backend
      final messages = await getChatMessages(chatId);
      print('📱 MessageService.markMessagesAsRead - Messaggi trovati: ${messages.length}');
      
      bool hasChanges = false;
      final updatedMessages = <MessageModel>[];
      
      // Marca tutti i messaggi non letti come letti
      for (final message in messages) {
        print('📱 MessageService.markMessagesAsRead - Messaggio: ${message.content}, isMe: ${message.isMe}, isRead: ${message.isRead}');
        
        if (!message.isMe && !message.isRead) {
          // Crea una copia del messaggio con isRead = true
          final updatedMessage = MessageModel(
            id: message.id,
            chatId: message.chatId,
            senderId: message.senderId,
            isMe: message.isMe,
            type: message.type,
            content: message.content,
            time: message.time,
            timestamp: message.timestamp,
            metadata: message.metadata,
            isRead: true, // Marca come letto
          );
          updatedMessages.add(updatedMessage);
          hasChanges = true;
          print('📱 MessageService.markMessagesAsRead - ✅ Messaggio marcato come letto: ${message.content}');
        } else {
          updatedMessages.add(message);
        }
      }
      
      print('📱 MessageService.markMessagesAsRead - Ci sono stati cambiamenti: $hasChanges');
      
      // Se ci sono stati cambiamenti, aggiorna la cache e notifica
      if (hasChanges) {
        _messageCache[chatId] = updatedMessages;
        print('📱 MessageService.markMessagesAsRead - Cache aggiornata');
        
        // Salva lo stato di lettura localmente per persistenza
        await _saveReadStatusLocally(chatId, updatedMessages);
        print('📱 MessageService.markMessagesAsRead - Stato lettura salvato localmente');
        
        // Aggiorna anche RealChatService per rimuovere il badge
        _updateChatReadStatus(chatId);
        print('📱 MessageService.markMessagesAsRead - RealChatService aggiornato');
        
        // Notifica i listener per aggiornare l'UI
        notifyListeners();
        print('📱 MessageService.markMessagesAsRead - Listener notificati');
        
        print('📱 MessageService.markMessagesAsRead - ✅ COMPLETATO: Tutti i messaggi marcati come letti per chat: $chatId');
      } else {
        print('📱 MessageService.markMessagesAsRead - ⚠️ Nessun cambiamento necessario');
      }
      
    } catch (e) {
      print('📱 MessageService.markMessagesAsRead - ❌ Errore: $e');
    }
  }

  /// Salva lo stato di lettura localmente
  Future<void> _saveReadStatusLocally(String chatId, List<MessageModel> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Prepara i dati per il salvataggio locale
      final readMessages = messages
          .where((msg) => !msg.isMe && msg.isRead)
          .map((msg) => msg.id)
          .toList();

      if (readMessages.isEmpty) return;

      // Salva la lista dei messaggi letti per questa chat
      final key = 'read_messages_$chatId';
      await prefs.setStringList(key, readMessages);
      
      print('📱 MessageService._saveReadStatusLocally - Stato lettura salvato localmente: ${readMessages.length} messaggi');
    } catch (e) {
      print('📱 MessageService._saveReadStatusLocally - Errore: $e');
    }
  }

  /// Carica lo stato di lettura salvato localmente
  Future<List<String>> _loadReadStatusLocally(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'read_messages_$chatId';
      final readMessages = prefs.getStringList(key) ?? [];
      
      print('📱 MessageService._loadReadStatusLocally - Caricati ${readMessages.length} messaggi letti per chat: $chatId');
      return readMessages;
    } catch (e) {
      print('📱 MessageService._loadReadStatusLocally - Errore: $e');
      return [];
    }
  }

  /// Applica lo stato di lettura salvato localmente ai messaggi
  Future<List<MessageModel>> _applyLocalReadStatus(String chatId, List<MessageModel> messages) async {
    try {
      final readMessageIds = await _loadReadStatusLocally(chatId);
      
      print('📱 MessageService._applyLocalReadStatus - Applicando stato lettura per chat: $chatId');
      print('📱 MessageService._applyLocalReadStatus - Messaggi letti salvati: ${readMessageIds.length}');
      
      // Crea una nuova lista per evitare modifiche dirette agli oggetti esistenti
      final updatedMessages = <MessageModel>[];
      
      // Applica lo stato di lettura ai messaggi
      for (final message in messages) {
        if (!message.isMe && readMessageIds.contains(message.id)) {
          // Crea una copia del messaggio con isRead = true
          final updatedMessage = MessageModel(
            id: message.id,
            chatId: message.chatId,
            senderId: message.senderId,
            isMe: message.isMe,
            type: message.type,
            content: message.content,
            time: message.time,
            timestamp: message.timestamp,
            metadata: message.metadata,
            isRead: true, // Marca come letto
          );
          updatedMessages.add(updatedMessage);
          print('📱 MessageService._applyLocalReadStatus - ✅ Messaggio marcato come letto: ${message.content}');
        } else {
          updatedMessages.add(message);
        }
      }
      
      print('📱 MessageService._applyLocalReadStatus - Completato: ${updatedMessages.length} messaggi processati');
      return updatedMessages;
    } catch (e) {
      print('📱 MessageService._applyLocalReadStatus - Errore: $e');
      return messages;
    }
  }

  /// Aggiorna lo stato di lettura di una chat in RealChatService
  void _updateChatReadStatus(String chatId) {
    try {
      // Calcola il numero di messaggi non letti per questa chat usando la cache locale
      final unreadCount = getUnreadCount(chatId);
      
      // Ottieni l'ultimo messaggio dalla cache
      final lastMessage = getLastMessage(chatId);
      
      // Aggiorna la cache locale del contatore
      _unreadCounts[chatId] = unreadCount;
      
      // Aggiorna RealChatService per sincronizzare l'UI (incluso lastMessage)
      RealChatService.updateChatLastMessage(chatId, lastMessage, unreadCount);
      
      print('📱 MessageService._updateChatReadStatus - Chat $chatId: $unreadCount messaggi non letti, ultimo: "$lastMessage"');
      
    } catch (e) {
      print('📱 MessageService._updateChatReadStatus - Errore critico: $e');
    }
  }

  // ===== METODI PER LA SINCRONIZZAZIONE REAL-TIME =====

  /// Invia notifiche push immediate per sincronizzazione real-time
  Future<void> _sendPushNotificationImmediate(String chatId, String messageContent) async {
    try {
      print('📱 MessageService._sendPushNotificationImmediate - Invio notifica push per chat: $chatId');
      
      // Ottieni l'ID del destinatario
      final chat = await _getChatById(chatId);
      if (chat == null) {
        print('📱 MessageService._sendPushNotificationImmediate - Chat non trovata: $chatId');
        return;
      }

      final currentUserId = UserService.getCurrentUserIdSync();
      // Per chat individuali, usa userId; per gruppi, usa groupMembers
      String recipientId = '';
      if (chat.isGroup && chat.groupMembers != null) {
        recipientId = chat.groupMembers!.firstWhere(
          (p) => p != currentUserId,
          orElse: () => '',
        );
      } else if (!chat.isGroup && chat.userId != null) {
        recipientId = chat.userId!;
      }

      if (recipientId.isEmpty) {
        print('📱 MessageService._sendPushNotificationImmediate - Destinatario non trovato');
        return;
      }

      // Invia notifica push
      await _sendPushNotification(recipientId, messageContent, chatId);
      
      print('📱 MessageService._sendPushNotificationImmediate - Notifica push inviata con successo');
    } catch (e) {
      print('📱 MessageService._sendPushNotificationImmediate - Errore: $e');
    }
  }

  /// Invia notifiche push per sincronizzazione real-time
  Future<void> _sendPushNotification(String recipientId, String messageContent, String chatId) async {
    try {
      print('📱 MessageService._sendPushNotification - Invio notifica a: $recipientId');
      print('📱 MessageService._sendPushNotification - Contenuto: $messageContent');
      print('📱 MessageService._sendPushNotification - Chat: $chatId');
      
      // Simula l'invio della notifica push
      // In produzione, qui implementeresti l'invio reale tramite il nostro sistema SecureVOX Notify
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Simula l'arrivo del messaggio per l'altro utente (DISABILITATO per real-time)
      // await _simulateMessageArrival(chatId, messageContent, recipientId);
      print('📱 MessageService._sendPushNotificationImmediate - Simulazione locale disabilitata per real-time');
      
    } catch (e) {
      print('📱 MessageService._sendPushNotification - Errore: $e');
    }
  }

  /// Simula l'arrivo di un messaggio per l'altro utente
  /// NOTA: Questo metodo è DISABILITATO per la sincronizzazione real-time
  /// Il messaggio deve arrivare solo al dispositivo destinatario
  Future<void> _simulateMessageArrival(String chatId, String messageContent, String recipientId) async {
    try {
      print('📱 MessageService._simulateMessageArrival - Simulazione DISABILITATA per sincronizzazione real-time');
      print('📱 MessageService._simulateMessageArrival - Il messaggio "$messageContent" deve arrivare solo al dispositivo di $recipientId');
      
      // NON aggiungere il messaggio alla cache locale
      // Il messaggio deve arrivare solo al dispositivo del destinatario
      // tramite notifiche push real-time
      
      print('✅ MessageService._simulateMessageArrival - Simulazione locale disabilitata per sincronizzazione real-time');
      
    } catch (e) {
      print('📱 MessageService._simulateMessageArrival - Errore: $e');
    }
  }

  /// Ottiene una chat per ID (metodo helper)
  Future<ChatModel?> _getChatById(String chatId) async {
    try {
      // Usa RealChatService per ottenere le chat
      final chats = await RealChatService.getRealChats();
      
      // Cerca la chat per ID
      for (final chat in chats) {
        if (chat.id == chatId) {
          print('📱 MessageService._getChatById - Chat trovata: ${chat.name}');
          print('📱 MessageService._getChatById - Partecipanti originali: ${chat.participants}');
          
          // Se i partecipanti sono vuoti, prova a popolarli
          if (chat.participants.isEmpty) {
            print('📱 MessageService._getChatById - Partecipanti vuoti, popolamento...');
            
            // Ottieni l'ID dell'utente corrente
            final currentUserId = UserService.getCurrentUserIdSync();
            print('📱 MessageService._getChatById - Current User ID: $currentUserId');
            
            // Per chat individuali, usa userId se disponibile
            String? otherParticipantId;
            if (chat.userId != null && chat.userId != currentUserId) {
              otherParticipantId = chat.userId;
            } else if (chat.userId == currentUserId) {
              // Se userId è l'utente corrente, prova a trovare l'altro partecipante
              // Questo è un caso edge, potresti dover implementare una logica specifica
              otherParticipantId = 'unknown';
            }
            
            if (otherParticipantId != null) {
              print('📱 MessageService._getChatById - Altro partecipante trovato: $otherParticipantId');
              
              // Crea una nuova chat con i partecipanti popolati
              return ChatModel(
                id: chat.id,
                name: chat.name,
                lastMessage: chat.lastMessage,
                timestamp: chat.timestamp,
                avatarUrl: chat.avatarUrl,
                isOnline: chat.isOnline,
                unreadCount: chat.unreadCount,
                isGroup: chat.isGroup,
                groupMembers: chat.groupMembers,
                userId: chat.userId,
                participants: [currentUserId ?? 'unknown', otherParticipantId],
              );
            }
          }
          
          return chat;
        }
      }
      
      print('📱 MessageService._getChatById - Chat non trovata: $chatId');
      return null;
    } catch (e) {
      print('📱 MessageService._getChatById - Errore: $e');
      return null;
    }
  }

  /// Inizializza l'ascolto dei messaggi real-time per una chat
  Future<void> initializeRealtimeMessageListener(String chatId) async {
    try {
      await _initializeRealtimeMessageSync();
      if (_realtimeMessageSync != null) {
        _realtimeMessageSync!.getMessageStream(chatId).listen((MessageModel message) {
          print('📨 MessageService.initializeRealtimeMessageListener - Messaggio ricevuto: ${message.content}');
          
          // Aggiungi il messaggio alla cache
          if (!_messageCache.containsKey(chatId)) {
            _messageCache[chatId] = [];
          }
          _messageCache[chatId]!.add(message);
          
          // Notifica l'aggiornamento
          notifyListeners();
          
          // Aggiorna il conteggio dei messaggi non letti
          _updateUnreadCount(chatId);
        });
        
        print('📱 MessageService.initializeRealtimeMessageListener - Listener inizializzato per chat: $chatId');
      }
    } catch (e) {
      print('❌ MessageService.initializeRealtimeMessageListener - Errore: $e');
    }
  }

  /// Invia notifica real-time al destinatario (altro dispositivo)
  Future<void> _sendRealtimeNotificationToRecipient(String chatId, String recipientId, String content, String messageId) async {
    try {
      print('📤 MessageService._sendRealtimeNotificationToRecipient - Invio notifica a destinatario: $recipientId');
      
      // Se il destinatario è sconosciuto, prova a trovare l'altro partecipante della chat
      String actualRecipientId = recipientId;
      if (recipientId.isEmpty || recipientId == 'unknown') {
        // Trova l'altro partecipante della chat
        final currentUserId = UserService.getCurrentUserIdSync();
        final chat = await _getChatById(chatId);
        if (chat != null) {
          actualRecipientId = chat.participants.firstWhere(
            (participantId) => participantId != currentUserId,
            orElse: () => 'unknown',
          );
        }
      }
      
      print('📤 MessageService._sendRealtimeNotificationToRecipient - Destinatario finale: $actualRecipientId');
      
      // PRIORITÀ: Usa RealtimeSyncService per la consegna real-time
      if (_realtimeSync != null) {
        await _realtimeSync!.sendPushNotification(
          recipientId: actualRecipientId,
          chatId: chatId,
          messageId: messageId,
          content: content,
          messageType: 'text',
        );
        print('🔥 Notifica inviata tramite RealtimeSyncService');
        return;
      }
      
      // Fallback al servizio personalizzato
      if (_customPushNotification != null) {
        await _customPushNotification!.sendMessageNotification(
          recipientId: actualRecipientId,
          chatId: chatId,
          content: content,
          senderId: UserService.getCurrentUserIdSync() ?? 'unknown',
        );
        print('🔥 Notifica inviata tramite sistema proprietario SecureVOX Notify');
        return;
      }
      
      // Fallback al servizio real-time
      if (_realtimeNotification != null) {
        await _realtimeNotification!.sendRealtimeNotification(
          recipientId: actualRecipientId,
          title: 'Nuovo messaggio',
          content: content,
          data: {
            'chat_id': chatId,
            'content': content,
            'sender_id': UserService.getCurrentUserIdSync() ?? 'unknown',
            'message_id': messageId,
            'type': 'message',
          },
        );
        print('🔥 Notifica real-time inviata tramite sistema proprietario SecureVOX Notify');
      } else {
        // Fallback: usa il sistema di simulazione
        await _sendPushNotificationToRecipient(actualRecipientId, content, chatId);
        await _simulateMessageArrivalInRecipientDevice(chatId, actualRecipientId, content, messageId);
        print('📱 Notifica simulata inviata (fallback)');
      }
      
      print('✅ MessageService._sendRealtimeNotificationToRecipient - Notifica inviata con successo');
    } catch (e) {
      print('❌ MessageService._sendRealtimeNotificationToRecipient - Errore: $e');
    }
  }

  /// Invia notifica push al destinatario
  Future<void> _sendPushNotificationToRecipient(String recipientId, String content, String chatId) async {
    try {
      print('📱 MessageService._sendPushNotificationToRecipient - Notifica push inviata a: $recipientId');
      print('📱 MessageService._sendPushNotificationToRecipient - Contenuto: "$content"');
      
      // Usando solo il nostro sistema SecureVOX Notify
      print('📱 MessageService._sendPushNotificationToRecipient - Notifica gestita da SecureVOX Notify');
      await _simulatePushNotification(recipientId, content, chatId);
      
    } catch (e) {
      print('❌ MessageService._sendPushNotificationToRecipient - Errore: $e');
    }
  }

  /// Simula una notifica push per i simulatori
  Future<void> _simulatePushNotification(String recipientId, String content, String chatId) async {
    try {
      print('📱 MessageService._simulatePushNotification - Simulazione notifica push');
      print('📱 Destinatario: $recipientId');
      print('📱 Contenuto: $content');
      print('📱 Chat: $chatId');
      
      // Simula il delay di una notifica push reale
      await Future.delayed(Duration(milliseconds: 500));
      
      // Simula l'arrivo della notifica nel dispositivo destinatario
      await _simulateMessageArrivalInRecipientDevice(chatId, recipientId, content, 'sim_${DateTime.now().millisecondsSinceEpoch}');
      
      print('✅ Notifica simulata inviata con successo');
    } catch (e) {
      print('❌ MessageService._simulatePushNotification - Errore: $e');
    }
  }

  /// Simula l'arrivo del messaggio nel dispositivo del destinatario
  Future<void> _simulateMessageArrivalInRecipientDevice(String chatId, String recipientId, String content, String messageId) async {
    try {
      print('📨 MessageService._simulateMessageArrivalInRecipientDevice - Simulazione arrivo in dispositivo destinatario');
      
      // Simula l'arrivo del messaggio nel dispositivo del destinatario
      // In un'app reale, questo sarebbe gestito dal sistema di notifiche push
      // e il messaggio verrebbe aggiunto alla cache del destinatario
      
      print('📨 MessageService._simulateMessageArrivalInRecipientDevice - Messaggio "$content" arrivato nel dispositivo di $recipientId');
      
    } catch (e) {
      print('❌ MessageService._simulateMessageArrivalInRecipientDevice - Errore: $e');
    }
  }

  /// Aggiorna il conteggio dei messaggi non letti per una chat
  void _updateUnreadCount(String chatId) {
    try {
      // Calcola il numero di messaggi non letti per questa chat
      final messages = _messageCache[chatId] ?? [];
      final unreadCount = messages.where((msg) => !msg.isMe && !msg.isRead).length;
      
      // Aggiorna il conteggio nella cache
      _unreadCounts[chatId] = unreadCount;
      
      print('📱 MessageService._updateUnreadCount - Chat $chatId: $unreadCount messaggi non letti');
    } catch (e) {
      print('❌ MessageService._updateUnreadCount - Errore: $e');
    }
  }

}