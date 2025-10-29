import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import 'auth_service.dart';
import 'unified_avatar_service.dart';
import 'user_service.dart';
import 'e2e_manager.dart';

class RealChatService extends ChangeNotifier {
  static const String baseUrl = 'http://127.0.0.1:8001'; // Backend URL
  
  // Cache per le chat
  static List<ChatModel> _cachedChats = [];
  static DateTime? _lastFetch;
  static const Duration cacheExpiry = Duration(minutes: 2);
  
  // Istanza singleton per notificare i listener
  static final RealChatService _instance = RealChatService._internal();
  factory RealChatService() => _instance;
  RealChatService._internal();
  
  /// NUOVO: Metodo pubblico per notificare i listener
  static void notifyWidgets() {
    _instance.notifyListeners();
  }
  
  /// Callback per aggiornare la cache delle icone timer
  static Function(String, bool)? _updateTimerCacheCallback;
  
  static void setTimerCacheCallback(Function(String, bool) callback) {
    _updateTimerCacheCallback = callback;
  }
  
  static void updateTimerCache(String chatId, bool isInGestation) {
    if (_updateTimerCacheCallback != null) {
      _updateTimerCacheCallback!(chatId, isInGestation);
    }
  }

  // Getter pubblico per accedere alla cache
  static List<ChatModel> get cachedChats => List.from(_cachedChats);
  
  /// NUOVO: Forza il refresh della cache (per pull-to-refresh)
  static Future<List<ChatModel>> forceRefresh() async {
    print('🔄🔄🔄 RealChatService.forceRefresh - FORZANDO AGGIORNAMENTO COMPLETO 🔄🔄🔄');
    _lastFetch = null; // Invalida la cache
    _cachedChats.clear(); // Pulisce la cache
    print('🧹 RealChatService.forceRefresh - Cache completamente pulita');
    final result = await getRealChats();
    print('🔄 RealChatService.forceRefresh - Nuovi dati caricati: ${result.length} chat');
    return result;
  }
  
  /// Ottiene una chat specifica dalla cache
  static ChatModel? getChatById(String chatId) {
    print('🔍 RealChatService.getChatById - Cercando chat: $chatId');
    print('🔍 RealChatService.getChatById - Cache size: ${_cachedChats.length}');
    
    try {
      final chat = _cachedChats.firstWhere((chat) => chat.id == chatId);
      print('🔍 RealChatService.getChatById - Chat trovata: ${chat.name}');
      print('🔍 RealChatService.getChatById - Chat userId: ${chat.userId}');
      print('🔍 RealChatService.getChatById - Chat participants: ${chat.participants}');
      print('🔥 RealChatService.getChatById - GESTAZIONE: ${chat.isInGestation}');
      print('🔥 RealChatService.getChatById - READ_ONLY: ${chat.isReadOnly}');
      print('🔥 RealChatService.getChatById - DELETION_BY: ${chat.deletionRequestedBy}');
      print('🔥 RealChatService.getChatById - EXPIRES_AT: ${chat.gestationExpiresAt}');
      return chat;
    } catch (e) {
      print('❌ RealChatService.getChatById - Chat non trovata: $e');
      return null;
    }
  }

  /// Ottiene tutte le chat reali dal database
  static Future<List<ChatModel>> getRealChats() async {
    print('🚀 RealChatService.getRealChats - INIZIO');
    
    // Controlla se la cache è ancora valida E ha dati corretti
    if (_cachedChats.isNotEmpty && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!) < cacheExpiry) {
      
      // CORREZIONE: Verifica che la cache abbia dati corretti
      final hasValidData = _cachedChats.any((chat) => 
        chat.userId != null || chat.participants.isNotEmpty);
      
      if (hasValidData) {
        print('📋 RealChatService.getRealChats - Usando cache (${_cachedChats.length} chat)');
        return List.from(_cachedChats);
      } else {
        print('⚠️ RealChatService.getRealChats - Cache vuota o dati invalidi, forzando refresh...');
      }
    }

    try {
      // Ottieni il token di autenticazione
      final authService = AuthService();
      final token = await authService.getToken();
      
      print('🔍 RealChatService.getRealChats - Token recuperato: ${token?.substring(0, 10)}...');
      
      if (token == null) {
        print('❌ RealChatService.getRealChats - Token di autenticazione non disponibile');
        return [];
      }

      print('🔄 RealChatService.getRealChats - Chiamata al backend...');
      print('🔍 RealChatService.getRealChats - URL: $baseUrl/api/chats/');
      
      // Chiamata al backend per ottenere le chat
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );
      
      print('🔍 RealChatService.getRealChats - Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // Debug rimosso per performance
        final currentUserId = UserService.getCurrentUserIdSync();
        
        // CORREZIONE BUG: Pulisci completamente la cache prima di ricaricare
        _cachedChats.clear();
        print('🧹 Cache completamente pulita prima del ricaricamento');
        
        // 🔐 CORREZIONE: Decifra lastMessage per ogni chat (inclusi messaggi inviati da me)
        final List<ChatModel> processedChats = [];
        for (final json in data) {
          String lastMessage = json['lastMessage'] ?? '';
          
          // 🔐 Decifra il lastMessage se cifrato
          final metadata = json['last_message_metadata'] as Map<String, dynamic>?;
          final isEncrypted = metadata?['encrypted'] == true || metadata?['iv'] != null;
          final senderId = json['last_message_sender_id'];
          
          if (isEncrypted && E2EManager.isEnabled) {
            final iv = metadata?['iv'] as String?;
            final mac = metadata?['mac'] as String?;
            if (iv != null) {
              try {
                final encryptedData = {
                  'ciphertext': lastMessage,
                  'iv': iv,
                  if (mac != null) 'mac': mac,
                };
                
                // CORREZIONE: Determina il corretto userId per la decifratura
                String? userIdForDecryption;
                if (senderId != null && senderId.toString() == currentUserId) {
                  // Messaggio inviato da me: usa userId dell'altra persona (recipient)
                  userIdForDecryption = json['userId']?.toString();
                  print('🔐 RealChatService - Messaggio inviato da me, uso recipientId: $userIdForDecryption');
                } else {
                  // Messaggio ricevuto: usa senderId
                  userIdForDecryption = senderId?.toString();
                  print('🔐 RealChatService - Messaggio ricevuto, uso senderId: $userIdForDecryption');
                }
                
                if (userIdForDecryption != null) {
                  final decryptedText = await E2EManager.decryptMessage(
                    userIdForDecryption,
                    encryptedData,
                  );
                  if (decryptedText != null) {
                    lastMessage = decryptedText;
                    print('🔐 RealChatService - ✅ lastMessage decifrato per chat ${json['name']}');
                  } else {
                    lastMessage = '...';  // ⚡ FIX: Placeholder che viene ignorato da updateChatLastMessage
                    print('❌ RealChatService - Impossibile decifrare lastMessage per chat ${json['name']}');
                  }
                } else {
                  lastMessage = '...';  // ⚡ FIX: Placeholder che viene ignorato da updateChatLastMessage
                  print('❌ RealChatService - UserId per decifratura non disponibile');
                }
              } catch (e) {
                print('❌ RealChatService - Errore decifratura lastMessage: $e');
                lastMessage = '...';  // ⚡ FIX: Placeholder che viene ignorato da updateChatLastMessage
              }
            }
          }
          
          // Aggiorna json con lastMessage decifrato
          final updatedJson = Map<String, dynamic>.from(json);
          updatedJson['lastMessage'] = lastMessage;
          
          final chat = ChatModel.fromJson(updatedJson);
          
          // CORREZIONE: Aggiorna cache URL avatar se disponibile
          if (!chat.isGroup && chat.userId != null && chat.avatarUrl.isNotEmpty) {
            UnifiedAvatarService.updateUserAvatarUrl(chat.userId!, chat.avatarUrl);
          }
          
          // Log semplificato solo per gestazioni
          if (chat.isInGestation) {
            print('⏰ Chat in gestazione: ${chat.name}');
          }
          
          // CORREZIONE: Popola i partecipanti per le chat individuali PRESERVANDO i dati di gestazione
          if (!chat.isGroup && chat.userId != null && currentUserId != null) {
            final updatedChat = chat.copyWith(
              participants: [currentUserId, chat.userId!],
              // IMPORTANTE: Preserva ESPLICITAMENTE tutti i campi di gestazione
              isInGestation: chat.isInGestation,
              isReadOnly: chat.isReadOnly,
              deletionRequestedBy: chat.deletionRequestedBy,
              deletionRequestedByName: chat.deletionRequestedByName,
              deletionRequestedAt: chat.deletionRequestedAt,
              gestationExpiresAt: chat.gestationExpiresAt,
            );
            print('✅ RealChatService - Chat aggiornata con participants: ${updatedChat.participants}');
            print('✅ RealChatService - GESTAZIONE PRESERVATA: ${updatedChat.isInGestation}');
            processedChats.add(updatedChat);
          } else {
            print('⚠️ RealChatService - Chat non aggiornata (isGroup: ${chat.isGroup}, userId: ${chat.userId}, currentUserId: $currentUserId)');
            processedChats.add(chat);
          }
        }
        
        _cachedChats = processedChats;
        
        print('📋 RealChatService - Cache aggiornata: ${_cachedChats.length} chat caricate');
        
        _lastFetch = DateTime.now();
        
        // NUOVO: Notifica i widget del cambiamento
        _instance.notifyListeners();
        print('📢 RealChatService - Notificato aggiornamento ai widget');
        
        return List.from(_cachedChats);
      } else if (response.statusCode == 403) {
        print('❌ RealChatService.getRealChats - Errore 403 - Token invalido, pulizia token vecchi...');
        final authService = AuthService();
        await authService.clearOldTokens();
        return [];
      } else {
        print('❌ RealChatService.getRealChats - Errore nel recupero chat: ${response.statusCode}');
        print('❌ RealChatService.getRealChats - Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ RealChatService.getRealChats - Errore di connessione: $e');
      return [];
    }
  }

  /// Crea una nuova chat
  static Future<ChatModel?> createChat({
    required String participantId,
    bool isGroup = false,
    String? groupName,
  }) async {
    try {
      // Ottieni il token di autenticazione
      final authService = AuthService();
      final token = await authService.getToken();
      
      print('Token per creazione chat: ${token?.substring(0, 10)}...');
      
      if (token == null) {
        print('Token di autenticazione non disponibile');
        return null;
      }

      // Prepara i dati per la richiesta
      final requestData = {
        'participant_id': participantId,
        'is_group': isGroup,
        if (groupName != null) 'group_name': groupName,
      };

      // Chiamata al backend per creare la chat
      final response = await http.post(
        Uri.parse('$baseUrl/api/chats/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode(requestData),
      );

      print('Risposta API creazione chat: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        // Pulisci la cache per forzare il refresh
        _cachedChats.clear();
        _lastFetch = null;
        
        // Crea un oggetto ChatModel per la risposta
        return ChatModel(
          id: data['chat_id'],
          name: data['name'],
          lastMessage: 'Chat creata',
          timestamp: DateTime.now(),
          avatarUrl: '',
          isOnline: false,
          unreadCount: 0,
          isGroup: isGroup,
          groupMembers: isGroup ? [] : [],
        );
      } else if (response.statusCode == 403) {
        print('Errore 403 - Token invalido, pulizia token vecchi...');
        final authService = AuthService();
        await authService.clearOldTokens();
        return null;
      } else {
        print('Errore nella creazione chat: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Errore di connessione: $e');
      return null;
    }
  }

  /// Ottiene i messaggi di una chat
  static Future<List<Map<String, dynamic>>> getChatMessages(String chatId) async {
    try {
      // Ottieni il token di autenticazione
      final authService = AuthService();
      final token = await authService.getToken();
      
      if (token == null) {
        print('Token di autenticazione non disponibile');
        return [];
      }

      // Chiamata al backend per ottenere i messaggi
      final response = await http.get(
        Uri.parse('$baseUrl/api/chats/$chatId/messages/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        print('Errore nel recupero messaggi: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Errore di connessione: $e');
      return [];
    }
  }

  /// Pulisce la cache
  static void clearCache() {
    _cachedChats.clear();
    _lastFetch = null;
  }

  /// Aggiorna una chat esistente nella cache
  static void updateChatInCache(ChatModel updatedChat) {
    final currentUserId = UserService.getCurrentUserIdSync();
    
    // CORREZIONE: Popola i partecipanti se non sono già presenti
    ChatModel chatWithParticipants = updatedChat;
    if (!updatedChat.isGroup && updatedChat.userId != null && currentUserId != null && updatedChat.participants.isEmpty) {
      chatWithParticipants = updatedChat.copyWith(
        participants: [currentUserId, updatedChat.userId!],
        // PRESERVA dati di gestazione
        isInGestation: updatedChat.isInGestation,
        isReadOnly: updatedChat.isReadOnly,
        deletionRequestedBy: updatedChat.deletionRequestedBy,
        deletionRequestedByName: updatedChat.deletionRequestedByName,
        deletionRequestedAt: updatedChat.deletionRequestedAt,
        gestationExpiresAt: updatedChat.gestationExpiresAt,
      );
    }
    
    final index = _cachedChats.indexWhere((chat) => chat.id == chatWithParticipants.id);
    if (index != -1) {
      _cachedChats[index] = chatWithParticipants;
    } else {
      _cachedChats.insert(0, chatWithParticipants);
    }
  }

  /// Rimuove una chat dalla cache
  static void removeChatFromCache(String chatId) {
    _cachedChats.removeWhere((chat) => chat.id == chatId);
  }

  /// Aggiorna il contatore di messaggi non letti per una chat
  static void updateChatUnreadCount(String chatId, int unreadCount) {
    final index = _cachedChats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final updatedChat = ChatModel(
        id: _cachedChats[index].id,
        name: _cachedChats[index].name,
        lastMessage: _cachedChats[index].lastMessage,
        timestamp: _cachedChats[index].timestamp,
        avatarUrl: _cachedChats[index].avatarUrl,
        isOnline: _cachedChats[index].isOnline,
        unreadCount: unreadCount,
        isGroup: _cachedChats[index].isGroup,
      );
      _cachedChats[index] = updatedChat;
      print('📱 RealChatService.updateChatUnreadCount - Chat $chatId: $unreadCount messaggi non letti');
    }
  }

  /// Aggiorna l'ultimo messaggio e il contatore per una chat
  static void updateChatLastMessage(String chatId, String lastMessage, int unreadCount) {
    // ⚡ FIX: Se il messaggio non è decifrato (placeholder), mantieni il precedente
    if (lastMessage == '...' || lastMessage.contains('[Messaggio cifrato]') || lastMessage.contains('[Errore decifratura]')) {
      print('⚠️ RealChatService.updateChatLastMessage - Messaggio non decifrato, mantengo precedente per chat $chatId');
      return; // Non aggiornare, mantieni il messaggio precedente
    }
    
    final index = _cachedChats.indexWhere((chat) => chat.id == chatId);
    if (index != -1) {
      final currentChat = _cachedChats[index];
      final updatedChat = currentChat.copyWith(
        lastMessage: lastMessage,
        timestamp: DateTime.now(), // Aggiorna il timestamp
        unreadCount: unreadCount,
        // PRESERVA dati di gestazione
        isInGestation: currentChat.isInGestation,
        isReadOnly: currentChat.isReadOnly,
        deletionRequestedBy: currentChat.deletionRequestedBy,
        deletionRequestedByName: currentChat.deletionRequestedByName,
        deletionRequestedAt: currentChat.deletionRequestedAt,
        gestationExpiresAt: currentChat.gestationExpiresAt,
      );
      _cachedChats[index] = updatedChat;
      
      // CORREZIONE: Notifica i listener per aggiornare l'UI immediatamente
      _instance.notifyListeners();
      
      print('📱 RealChatService.updateChatLastMessage - Chat $chatId: "$lastMessage" ($unreadCount non letti)');
    } else {
      // Se la chat non esiste nella cache, crea una nuova entry
      final currentUserId = UserService.getCurrentUserIdSync();
      final newChat = ChatModel(
        id: chatId,
        name: 'Chat $chatId',
        lastMessage: lastMessage,
        timestamp: DateTime.now(),
        avatarUrl: '',
        isOnline: false,
        unreadCount: unreadCount,
        isGroup: false,
        participants: currentUserId != null ? [currentUserId, 'unknown'] : [],
      );
      _cachedChats.insert(0, newChat); // Inserisci all'inizio
      print('📱 RealChatService.updateChatLastMessage - Nuova chat creata: $chatId: "$lastMessage" ($unreadCount non letti)');
    }
  }

  /// Sincronizza i dati in background senza aggiornare l'UI
  static Future<void> syncInBackground() async {
    try {
      print('🔄 RealChatService.syncInBackground - Sincronizzazione in background');
      
      // Aggiorna solo i dati interni, non l'UI
      await getRealChats();
      
      print('🔄 RealChatService.syncInBackground - Sincronizzazione completata');
    } catch (e) {
      print('🔄 RealChatService.syncInBackground - Errore: $e');
    }
  }

  /// Aggiorna l'ultimo messaggio di una chat
  static void updateLastMessage(String chatId, String messageContent) {
    try {
      final chatIndex = _cachedChats.indexWhere((chat) => chat.id == chatId);
      if (chatIndex != -1) {
        final updatedChat = _cachedChats[chatIndex].copyWith(
          lastMessage: messageContent,
          timestamp: DateTime.now(),
          // PRESERVA dati di gestazione
          isInGestation: _cachedChats[chatIndex].isInGestation,
          isReadOnly: _cachedChats[chatIndex].isReadOnly,
          deletionRequestedBy: _cachedChats[chatIndex].deletionRequestedBy,
          deletionRequestedByName: _cachedChats[chatIndex].deletionRequestedByName,
          deletionRequestedAt: _cachedChats[chatIndex].deletionRequestedAt,
          gestationExpiresAt: _cachedChats[chatIndex].gestationExpiresAt,
        );
        _cachedChats[chatIndex] = updatedChat;
        print('✅ RealChatService.updateLastMessage - Chat $chatId aggiornata con ultimo messaggio: $messageContent');
      } else {
        print('⚠️ RealChatService.updateLastMessage - Chat $chatId non trovata nella cache');
      }
    } catch (e) {
      print('❌ RealChatService.updateLastMessage - Errore: $e');
    }
  }
}
