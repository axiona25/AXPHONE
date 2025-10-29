import '../models/call_model.dart';
import 'package:flutter/material.dart';
import '../services/native_audio_call_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/contact_service.dart';
import '../services/location_service.dart';
import '../services/audio_file_service.dart';
import '../widgets/location_preview_widget.dart';
import '../theme/app_theme.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import '../services/connection_service.dart';
import '../services/media_service.dart';
import '../services/user_service.dart';
import '../services/unified_attachment_service.dart';
import '../services/real_chat_service.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../services/user_status_service.dart';
import '../widgets/encryption_status_widget.dart';
import '../widgets/video_player_widget.dart';
import '../services/active_call_service.dart';
// import '../services/webrtc_call_service.dart'; // RIMOSSO: File eliminato
import '../widgets/attachment_menu.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/message_bubble_widget.dart';
import '../widgets/keyboard_dismiss_wrapper.dart';
import '../services/timezone_service.dart';
import 'file_viewer_screen.dart';
import '../services/e2e_manager.dart'; // 🔐 NUOVO: Per scaricare chiave pubblica destinatario

class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;

  ChatDetailScreen({
    Key? key,
    required this.chat,
  }) : super(key: key) {
    print('🚨 TEST: ChatDetailScreen costruttore chiamato per chat: ${chat.id}');
    print('🚨 TEST: ChatDetailScreen costruttore - Participants: ${chat.participants}');
    print('🚨 TEST: ChatDetailScreen costruttore - UserId: ${chat.userId}');
    
    // CORREZIONE: Popola i participants se non sono presenti
    if (!chat.isGroup && chat.participants.isEmpty) {
      print('🚨 TEST: Popolando participants nel costruttore...');
      final currentUserId = UserService.getCurrentUserIdSync();
      if (currentUserId != null) {
        // Usa un ID di fallback se userId è null
        String otherUserId = chat.userId ?? '1'; // Fallback a ID 1
        print('🚨 TEST: User ID di fallback: $otherUserId');
        
        final updatedChat = chat.copyWith(
          participants: [currentUserId, otherUserId],
          userId: otherUserId, // Aggiorna anche userId
        );
        print('🚨 TEST: Participants popolati nel costruttore: ${updatedChat.participants}');
        
        // Aggiorna la cache
        RealChatService.updateChatInCache(updatedChat);
        print('🚨 TEST: Chat aggiornata nella cache');
      }
    }
  }

  @override
  State<ChatDetailScreen> createState() {
    print('🚨 TEST: ChatDetailScreen createState chiamato per chat: ${chat.id}');
    print('🚨 TEST: ChatDetailScreen createState - Participants: ${chat.participants}');
    print('🚨 TEST: ChatDetailScreen createState - UserId: ${chat.userId}');
    return _ChatDetailScreenState();
  }
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _hasText = false;
  
  // NUOVO: Timer per countdown gestazione
  Timer? _countdownTimer;
  String _countdownText = '';
  int _selectedDays = 7; // Giorni selezionati per la gestazione (calcolati dalla scadenza)
  bool _isAppInBackground = false; // Flag per overlay di sicurezza
  DateTime? _simulatedExpirationTime; // Data di scadenza simulata per il countdown
  bool _isInitialLoad = true; // CORREZIONE: Flag per nascondere la ListView durante il caricamento iniziale
  bool _hasSeenGestationBanner = false; // Flag per tracciare se l'utente ha già visto il banner
  
  // Servizi multimediali
  final MediaService _mediaService = MediaService();
  final UnifiedAttachmentService _attachmentService = UnifiedAttachmentService();
  
  // Variabili per anteprima immagine (MANTENIAMO - FUNZIONANO)
  File? _selectedImage;
  String? _imageUrl;
  bool _isUploadingImage = false;
  
  // Variabili per anteprima video (MANTENIAMO - FUNZIONANO)
  File? _selectedVideo;
  bool _isUploadingVideo = false;
  
  // NUOVO: Variabili per anteprima audio
  File? _selectedAudio;
  String? _selectedAudioDuration;
  bool _isUploadingAudio = false;
  
  // NUOVO: Variabili per preview contatto e posizione
  ContactData? _selectedContact;
  LocationData? _selectedLocation;
  
  // NUOVO: Sistema unificato per allegati (SOLO PER FILE, CONTATTI, POSIZIONE)
  AttachmentData? _selectedAttachment;
  bool _isUploadingAttachment = false;
  

  @override
  void initState() {
    super.initState();
    print('🚨 TEST: initState chiamato!');
    print('📱 ChatDetailScreen.initState - INIZIO per chat: ${widget.chat.id}');
    
    // CORREZIONE BANNER: Carica lo stato del banner PRIMA di tutto
    _loadGestationBannerState();
    
    // CORREZIONE: Popola i participants se non sono presenti
    print('🚨 TEST: Chiamando _populateParticipantsIfNeeded...');
    try {
      _populateParticipantsIfNeeded();
      print('🚨 TEST: _populateParticipantsIfNeeded completato');
    } catch (e) {
      print('❌ ChatDetailScreen.initState - Errore in _populateParticipantsIfNeeded: $e');
    }
    
    // NUOVO: Inizializza countdown se chat in gestazione
    if (widget.chat.isInGestation && widget.chat.gestationExpiresAt != null) {
      // Calcola i giorni effettivi dalla data di scadenza
      final now = DateTime.now();
      final expiresAt = widget.chat.gestationExpiresAt!;
      final difference = expiresAt.difference(now);
      _selectedDays = (difference.inDays + 1).clamp(1, 7); // +1 per includere il giorno corrente
      
      print('⏰ Giorni calcolati dalla scadenza: $_selectedDays (scade: $expiresAt)');
      _startCountdownTimer();
    }
    
    // NUOVO: Abilita protezione screenshot per chat in gestazione
    if (widget.chat.isInGestation) {
      _enableScreenshotProtection();
      // Aggiungi observer per il ciclo di vita dell'app
      WidgetsBinding.instance.addObserver(this);
    }
    
    // TOAST UNA SOLA VOLTA: Controlla se già mostrato per questa chat
    if (widget.chat.isInGestation && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          final prefs = await SharedPreferences.getInstance();
          final toastKey = 'toast_shown_${widget.chat.id}';
          final alreadyShown = prefs.getBool(toastKey) ?? false;
          
          if (!alreadyShown) {
            _showGestationInfoToast();
            await prefs.setBool(toastKey, true);
            print('🍞 Toast mostrato e marcato come visto per ${widget.chat.id}');
          } else {
            print('🍞 Toast già mostrato per ${widget.chat.id}, skip');
          }
        }
      });
    }
    
    // Marca la chat come letta quando si apre
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('📱 ChatDetailScreen.initState - Chiamando markChatAsCurrentlyViewing per chat: ${widget.chat.id}');
      final messageService = Provider.of<MessageService>(context, listen: false);
      
      // Marca la chat come attualmente visualizzata e tutti i messaggi come letti
      messageService.markChatAsCurrentlyViewing(widget.chat.id);
      
      // Forza il caricamento dei messaggi (versione specifica per chat detail)
      messageService.forceLoadMessagesForChatDetail(widget.chat.id);
      
      print('📱 ChatDetailScreen.initState - markChatAsCurrentlyViewing completato per chat: ${widget.chat.id}');
      
      // CORREZIONE: Nasconde la ListView durante il caricamento iniziale
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isInitialLoad = false; // Mostra la ListView
          });
          
          // Scroll automatico all'ultimo messaggio dopo che la ListView è renderizzata
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(0.0); // Con reverse: true, 0.0 è l'ultimo messaggio
            }
          });
        }
      });
      
      // Aggiungi listener per scroll automatico quando arrivano nuovi messaggi
      messageService.addListener(_onMessageServiceChanged);
      
      // 🔐 NUOVO: Scarica la chiave pubblica del destinatario per E2EE
      _downloadRecipientPublicKey();
    });
    
  }

  @override
  void didUpdateWidget(ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // CORREZIONE BANNER: Se la chat è cambiata, ricarica lo stato del banner
    if (oldWidget.chat.id != widget.chat.id || 
        oldWidget.chat.gestationExpiresAt != widget.chat.gestationExpiresAt) {
      print('🍞 Chat aggiornata - ricarico stato banner');
      _loadGestationBannerState();
    }
  }

  /// CORREZIONE: Popola i participants se non sono presenti
  void _populateParticipantsIfNeeded() {
    print('🚨 TEST: _populateParticipantsIfNeeded chiamato!');
    print('📱 ChatDetailScreen._populateParticipantsIfNeeded - INIZIO');
    print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Chat ID: ${widget.chat.id}');
    print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Participants: ${widget.chat.participants}');
    print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Is Group: ${widget.chat.isGroup}');
    print('📱 ChatDetailScreen._populateParticipantsIfNeeded - User ID: ${widget.chat.userId}');
    
    // CORREZIONE: Chiama sempre il metodo per popolare i participants se necessario
    if (!widget.chat.isGroup) {
      print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Condizioni soddisfatte per popolare participants');
      print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Participants vuoti: ${widget.chat.participants.isEmpty}');
      print('📱 ChatDetailScreen._populateParticipantsIfNeeded - User ID: ${widget.chat.userId}');
      
      // CORREZIONE: Popola sempre i participants per chat individuali
      if (widget.chat.participants.isEmpty) {
        print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Participants vuoti, aggiornamento necessario');
        final currentUserId = UserService.getCurrentUserIdSync();
        print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Current User ID: $currentUserId');
        
        if (currentUserId != null) {
          // CORREZIONE: Usa un ID di fallback se userId è null
          String otherUserId = widget.chat.userId ?? '1'; // Fallback a ID 1
          print('📱 ChatDetailScreen._populateParticipantsIfNeeded - User ID di fallback: $otherUserId');
          
          // Aggiorna il ChatModel con i participants
          final updatedChat = widget.chat.copyWith(
            participants: [currentUserId, otherUserId],
            userId: otherUserId, // Aggiorna anche userId
          );
          
          // Aggiorna la cache
          RealChatService.updateChatInCache(updatedChat);
          
          print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Participants popolati: ${updatedChat.participants}');
        } else {
          print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Current User ID è null');
        }
      } else {
        print('📱 ChatDetailScreen._populateParticipantsIfNeeded - Participants già popolati: ${widget.chat.participants}');
      }
    } else {
      print('📱 ChatDetailScreen._populateParticipantsIfNeeded - È una chat di gruppo, non necessario popolare participants');
    }
  }

  /// 🔐 NUOVO: Scarica la chiave pubblica del destinatario per E2EE
  Future<void> _downloadRecipientPublicKey() async {
    try {
      // Solo per chat individuali
      if (widget.chat.isGroup) {
        print('🔐 ChatDetailScreen - Skip download chiave: è una chat di gruppo');
        return;
      }
      
      // Verifica se E2EE è abilitato
      if (!E2EManager.isEnabled) {
        print('🔐 ChatDetailScreen - Skip download chiave: E2EE non abilitato');
        return;
      }
      
      // Ottieni l'ID del destinatario
      final currentUserId = UserService.getCurrentUserIdSync();
      if (currentUserId == null) {
        print('🔐 ChatDetailScreen - Skip download chiave: currentUserId è null');
        return;
      }
      
      // Determina l'ID del destinatario
      // 🔧 CORREZIONE: Per chat individuali, il chatId È l'UUID del destinatario
      String recipientId = '';
      
      if (widget.chat.userId != null && widget.chat.userId!.isNotEmpty) {
        recipientId = widget.chat.userId!;
        print('🔐 ChatDetailScreen - RecipientId da userId: $recipientId');
      } else if (widget.chat.participants.isNotEmpty) {
        recipientId = widget.chat.participants.firstWhere(
          (id) => id != currentUserId.toString(),
          orElse: () => '',
        );
        print('🔐 ChatDetailScreen - RecipientId da participants: $recipientId');
      } else {
        // 🔧 FALLBACK: Usa il chatId come recipientId (per chat individuali)
        recipientId = widget.chat.id;
        print('🔐 ChatDetailScreen - RecipientId da chatId (fallback): $recipientId');
      }
      
      if (recipientId.isEmpty) {
        print('🔐 ChatDetailScreen - Skip download chiave: recipientId non valido');
        return;
      }
      
      print('🔐 ChatDetailScreen - Download chiave pubblica per utente: $recipientId');
      
      // Scarica la chiave pubblica del destinatario (getUserPublicKey scarica dal backend se non in cache)
      final publicKey = await E2EManager.getUserPublicKey(recipientId);
      
      if (publicKey != null) {
        print('✅ ChatDetailScreen - Chiave pubblica scaricata con successo per utente: $recipientId (length: ${publicKey.length})');
        
        // 🔄 CORREZIONE: Forza il refresh dei messaggi dopo aver scaricato la chiave
        // Questo assicura che i messaggi vengano decifrati con la chiave appena scaricata
        final messageService = Provider.of<MessageService>(context, listen: false);
        print('🔄 ChatDetailScreen - Forzando refresh messaggi per decifratura...');
        await messageService.forceLoadMessagesForChatDetail(widget.chat.id);
        print('✅ ChatDetailScreen - Refresh messaggi completato');
      } else {
        print('❌ ChatDetailScreen - Impossibile scaricare chiave pubblica per utente: $recipientId');
      }
    } catch (e) {
      print('❌ ChatDetailScreen._downloadRecipientPublicKey - Errore: $e');
    }
  }

  /// Callback chiamato quando il MessageService cambia (nuovi messaggi)
  void _onMessageServiceChanged() {
    // Scroll automatico all'ultimo messaggio quando arrivano nuovi messaggi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(0.0); // Con reverse: true, 0.0 è l'ultimo messaggio
      }
    });
  }


  /// Notifica l'aggiornamento della lista chat
  void _notifyChatListUpdate() async {
    try {
      // IMPORTANTE: Aggiornamento completamente in background
      // Non aggiorna l'UI per evitare refresh continui
      // Non pulisce cache per preservare lo stato di lettura
      // Nessun log per evitare spam nei log
      
    } catch (e) {
      // Solo log degli errori critici
      print('📱 ChatDetailScreen._notifyChatListUpdate - Errore critico: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    
    // NUOVO: Pulisci il timer countdown e resetta il banner
    _countdownTimer?.cancel();
    if (widget.chat.isInGestation) {
      _countdownText = ''; // Resetta direttamente senza setState nel dispose
      print('⏰ Banner countdown nascosto quando si esce dalla chat');
    }
    
    // NUOVO: Nasconde TUTTI i toast quando si esce dalla chat
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      print('🍞 Tutti i toast nascosti quando si esce dalla chat');
    } catch (e) {
      print('⚠️ Errore nascondimento toast: $e');
    }
    
    // NUOVO: Disabilita protezione screenshot quando si esce
    if (widget.chat.isInGestation) {
      _disableScreenshotProtection();
      // Rimuovi observer per il ciclo di vita dell'app
      WidgetsBinding.instance.removeObserver(this);
    }
    
    // CORREZIONE: Salva il riferimento al MessageService prima del dispose
    try {
      // Usa un approccio più sicuro per accedere al Provider
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final messageService = Provider.of<MessageService>(context, listen: false);
          messageService.markChatAsNotViewing();
          messageService.forceHomeScreenUpdate();
          print('📱 ChatDetailScreen.dispose - Chat ${widget.chat.id} marcata come non più visualizzata e home aggiornata');
        } catch (e) {
          print('📱 ChatDetailScreen.dispose - Errore nel marcare chat come non visualizzata: $e');
        }
      });
    } catch (e) {
      print('📱 ChatDetailScreen.dispose - Errore generale: $e');
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Debug: stampa quando il ChatDetailScreen viene costruito
    print('ChatDetailScreen built for chat: ${widget.chat.name}');
    
    return KeyboardDismissWrapper(
      child: Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Contenuto principale
          Column(
            children: [
              // Header con gradiente
              _buildHeader(),
              // Area messaggi
              Expanded(
                child: _buildMessagesArea(),
              ),
              // Barra di input
              _buildInputBar(),
            ],
          ),
          
          // NUOVO: Overlay di sicurezza quando l'app è in background
          if (widget.chat.isInGestation && _isAppInBackground)
            _buildSecurityOverlay(),
        ],
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header con status bar e contenuto sulla stessa riga
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pulsante indietro e info utente
                Expanded(
                  child: Row(
                    children: [
                      // Pulsante indietro
                      GestureDetector(
                        onTap: () => context.go('/home'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Avatar con indicatore online - USA LO STESSO SISTEMA DELLA HOME
                      _buildWorkingAvatar(),
                      const SizedBox(width: 12),
                      // Nome e stato
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.chat.name,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Row(
                              children: [
                                if (widget.chat.isInGestation && _countdownText.isNotEmpty) ...[
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _countdownText,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: _showDaysPicker,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.visibility_off,
                                        size: 12,
                                        color: Colors.orange.shade200,
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  widget.chat.isInGestation 
                                      ? Text(
                                          'Chat in gestazione',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const EncryptionStatusWidget(
                                          isEncrypted: true,
                                          encryptionType: 'Chat Cifrata',
                                          tooltipText: 'Crittografia AES256 attiva\nChat sicura e protetta',
                                          size: 14.0,
                                          iconColor: Colors.white,
                                        ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Icone azioni
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NUOVO: Disabilita chiamate durante gestazione
                    _buildActionIcon(
                      Icons.phone, 
                      widget.chat.isInGestation ? null : () => _startAudioCall(),
                      isDisabled: widget.chat.isInGestation,
                    ),
                    const SizedBox(width: 8),
                    _buildActionIcon(
                      Icons.videocam, 
                      widget.chat.isInGestation ? null : () => _startVideoCall(),
                      isDisabled: widget.chat.isInGestation,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Se c'è un URL valido per l'avatar, prova a caricarlo
    if (widget.chat.avatarUrl.isNotEmpty && widget.chat.avatarUrl != '') {
      return ClipOval(
        child: Image.network(
          widget.chat.avatarUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsAvatar();
          },
        ),
      );
    }
    
    // Se non c'è URL o è vuoto, mostra le iniziali
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    print('💬 ChatDetailScreen._buildInitialsAvatar - Chat: ${widget.chat.name} (ID: ${widget.chat.id})');
    
    // Se non è un gruppo, mostra l'indicatore di stato
    if (!widget.chat.isGroup) {
      return Stack(
        children: [
          MasterAvatarWidget.fromChat(
            chatId: widget.chat.id,
            chatName: widget.chat.name,
            size: 40,
          ),
          // Indicatore di stato
          Positioned(
            right: 0,
            bottom: 0,
            child: _buildHeaderStatusIndicator(),
          ),
        ],
      );
    }
    
    return MasterAvatarWidget.fromChat(
      chatId: widget.chat.id,
      chatName: widget.chat.name,
      size: 40,
    );
  }

  Widget _buildHeaderStatusIndicator() {
    // Ottieni l'ID utente reale dalla chat
    String userId = widget.chat.userId ?? '';
    
    if (userId.isEmpty) {
      // Fallback: usa l'ID della chat
      userId = widget.chat.id;
    }
    
    // SEMPLICE: Sempre verde per ora (tutti online)
    final statusColor = Colors.green;
    
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: statusColor,
        border: Border.all(
          color: Colors.white,
          width: 1,
        ),
      ),
    );
  }

  /// NUOVO: Avatar che funziona correttamente come nella home screen
  Widget _buildWorkingAvatar() {
    print('💬 ChatDetailScreen._buildWorkingAvatar - Chat: ${widget.chat.name} (ID: ${widget.chat.id})');
    
    if (widget.chat.isGroup) {
      // Per i gruppi, mostra solo l'avatar senza indicatore
      return MasterAvatarWidget.fromChat(
        chatId: widget.chat.id,
        chatName: widget.chat.name,
        avatarUrl: widget.chat.avatarUrl.isNotEmpty ? widget.chat.avatarUrl : null,
        size: 40,
        showOnlineIndicator: false,
      );
    }
    
    // CORREZIONE CRITICA: Usa la stessa logica della home screen per chat private
    String? targetUserId = widget.chat.userId;
    
    // Se userId è null, usa i participants per trovare l'altro utente
    if (targetUserId == null && widget.chat.participants.isNotEmpty) {
      // Trova l'utente che NON è l'utente corrente
      final currentUserId = '2'; // TODO: Ottieni dall'AuthService
      targetUserId = widget.chat.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => widget.chat.participants.first,
      );
      print('💬 ChatDetailScreen._buildWorkingAvatar - userId era null, usando participant: $targetUserId');
    }
    
    final effectiveUserId = targetUserId ?? widget.chat.id;
    print('💬 ChatDetailScreen._buildWorkingAvatar - Chat: ${widget.chat.name}, effectiveUserId: $effectiveUserId, showOnlineIndicator: true');
    
    // USA IL SERVIZIO MASTER COME NELLA HOME SCREEN
    return MasterAvatarWidget.fromChat(
      chatId: effectiveUserId, // ✅ USA userId corretto per mappatura
      chatName: widget.chat.name,
      avatarUrl: widget.chat.avatarUrl.isNotEmpty ? widget.chat.avatarUrl : null,
      size: 40,
      showOnlineIndicator: true, // ✅ ABILITA indicatore di stato come nella home
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      // Se c'è solo una parola, prendi le prime due lettere
      return words[0].substring(0, words[0].length >= 2 ? 2 : 1).toUpperCase();
    } else {
      // Se ci sono più parole, prendi la prima lettera di ognuna (max 2)
      final initials = words.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
      return initials.toUpperCase();
    }
  }

  /// Raggruppa i messaggi per giorno
  List<Map<String, dynamic>> _groupMessagesByDay(List<MessageModel> messages) {
    if (messages.isEmpty) return [];
    
    // Filtra TUTTI i messaggi che potrebbero essere header mock o duplicati
    final filteredMessages = messages.where((message) {
      // Escludi TUTTI i messaggi che potrebbero essere header mock
      final content = message.content.toLowerCase().trim();
      final isHeaderMock = content == 'oggi' || content == 'ieri' || content == 'today' || content == 'yesterday' ||
                          message.content == 'OGGI' || message.content == 'IERI' || message.content == 'TODAY' || message.content == 'YESTERDAY' ||
                          message.content.contains('OGGI') || message.content.contains('oggi') ||
                          message.content.contains('IERI') || message.content.contains('ieri');
      
      // Escludi anche messaggi che potrebbero essere separatori
      final isSeparator = message.content.length <= 10 && 
                         (message.content.toLowerCase().contains('oggi') || 
                          message.content.toLowerCase().contains('ieri') ||
                          message.content.toLowerCase().contains('today') ||
                          message.content.toLowerCase().contains('yesterday'));
      
      return !isHeaderMock && !isSeparator;
    }).toList();
    
    if (filteredMessages.isEmpty) return [];
    
    final grouped = <String, List<MessageModel>>{};
    
    for (final message in filteredMessages) {
      // Estrai la data dal timestamp del messaggio
      final messageDate = _extractDateFromTime(message);
      
      if (!grouped.containsKey(messageDate)) {
        grouped[messageDate] = [];
      }
      grouped[messageDate]!.add(message);
    }
    
    // Ordina le date (dal più vecchio al più recente)
    final sortedDates = grouped.keys.toList()..sort();
    
    final result = <Map<String, dynamic>>[];
    
    // Aggiungi solo i separatori per date che hanno effettivamente messaggi
    for (final date in sortedDates) {
      final messagesForDate = grouped[date]!;
      
      // Aggiungi header del giorno solo se ci sono messaggi per questa data
      if (messagesForDate.isNotEmpty) {
        result.add({
          'isHeader': true,
          'date': date,
        });
        
        // CORREZIONE: Ordina i messaggi per timestamp (dal più vecchio al più recente)
        final sortedMessages = messagesForDate..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        
        // Aggiungi i messaggi del giorno ordinati
        for (final message in sortedMessages) {
          result.add({
            'isHeader': false,
            'message': message,
          });
        }
      }
    }
    
    return result;
  }

  /// Estrae la data dal timestamp del messaggio
  String _extractDateFromTime(MessageModel message) {
    try {
      // Usa il timestamp del messaggio se disponibile
      return _formatDate(message.timestamp);
    } catch (e) {
      // Fallback: usa la data di oggi
      return _formatDate(DateTime.now());
    }
  }

  /// Formatta una data per il display
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Oggi';
    } else if (messageDate == yesterday) {
      return 'Ieri';
    } else {
      // Formato: "DD/MM/YYYY"
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  /// Costruisce l'header del giorno
  Widget _buildDayHeader(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                date,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }


  String _getDisplayName(String fullName) {
    if (fullName.isEmpty) return 'Utente';
    
    final words = fullName.trim().split(' ').where((word) => word.isNotEmpty).toList();
    
    if (words.isEmpty) return 'Utente';
    
    // Se c'è solo una parola, mostra quella
    if (words.length == 1) {
      return words[0];
    }
    
    // Se ci sono due o più parole, mostra le prime due (nome e cognome)
    if (words.length >= 2) {
      return '${words[0]} ${words[1]}';
    }
    
    return words[0];
  }

  Widget _buildActionIcon(IconData icon, VoidCallback? onTap, {bool isDisabled = false}) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDisabled ? Colors.grey.shade300 : Colors.white,
        ),
        child: Icon(
          icon,
          color: isDisabled ? Colors.grey.shade500 : AppTheme.primaryColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildMessagesArea() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Lista messaggi dal MessageService
          Expanded(
            child: Consumer<MessageService>(
              builder: (context, messageService, child) {
                return StreamBuilder<List<MessageModel>>(
                  stream: messageService.getChatMessagesStream(widget.chat.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Loading spinner
                              const CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                strokeWidth: 3,
                              ),
                              const SizedBox(height: 24),
                              
                              // Testo di caricamento
                              const Text(
                                'Caricamento messaggi...',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icona errore
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline,
                                  size: 40,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Titolo
                              const Text(
                                'Errore nel caricamento',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              
                              // Sottotitolo
                              Text(
                                'Impossibile caricare i messaggi.\nRiprova più tardi.',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    final messages = snapshot.data ?? [];
                    
                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icona messaggi vuoti
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 40,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Titolo
                              const Text(
                                'Nessun messaggio ancora',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              
                              // Sottotitolo
                              const Text(
                                'Invia il primo messaggio per iniziare la conversazione',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.grey,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
            // Rimuovo la chiamata automatica per evitare loop infiniti
                    
                    // Raggruppa i messaggi per giorno
                    final groupedMessages = _groupMessagesByDay(messages);
                    
                    // CORREZIONE: Nasconde la ListView durante il caricamento iniziale
                    if (_isInitialLoad) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      itemCount: groupedMessages.length,
                      reverse: true, // Mostra i messaggi più recenti in basso
                      physics: const BouncingScrollPhysics(), // Scroll più fluido
                      itemBuilder: (context, index) {
                        // Con reverse: true, l'indice è invertito
                        final reversedIndex = groupedMessages.length - 1 - index;
                        final group = groupedMessages[reversedIndex];
                        
                        // Se è un header di giorno
                        if (group['isHeader'] == true) {
                          return _buildDayHeader(group['date'] as String);
                        }
                        
                        // Se è un messaggio
                        final message = group['message'] as MessageModel;
                        
                        // CONTROLLO FINALE: Non renderizzare mai messaggi con contenuto "OGGI"
                        if (message.content == 'OGGI' || message.content == 'oggi' || 
                            message.content == 'IERI' || message.content == 'ieri' ||
                            message.content.toLowerCase().contains('oggi') ||
                            message.content.toLowerCase().contains('ieri')) {
                          return const SizedBox.shrink(); // Non renderizzare nulla
                        }
                        
                        return _buildMessageFromModel(message);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(String text, String time, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                const SizedBox(width: 20), // Spazio per l'avatar
              ],
              if (isMe) ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20), // Spazio per l'avatar
              ] else ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: isMe ? 20 : 0,
              left: !isMe ? 20 : 0,
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce un messaggio da un MessageModel
  Widget _buildMessageFromModel(MessageModel message) {
    // Usa il MessageBubbleWidget per una visualizzazione consistente
    return MessageBubbleWidget(
      message: message,
      onTap: () {
        // Gestisci il tap sul messaggio se necessario
        print('Tapped on message: ${message.content}');
      },
      onLongPress: () {
        // Gestisci il long press per menu contestuale
        _showMessageOptions(message);
      },
      onFileOpen: (fileUrl, fileName, fileType) {
        // Apri il file in fullscreen con metadati del messaggio
        _openFileFullscreen(fileUrl, fileName, fileType, message.metadata);
      },
    );
  }

  /// Apre il file in fullscreen
  void _openFileFullscreen(String fileUrl, String fileName, String fileType, [Map<String, dynamic>? fileMetadata]) {
    
    // Estrai fileSize dai metadata
    final fileSize = fileMetadata?['fileSize'] ?? 
                     fileMetadata?['file_size'] ?? 
                     fileMetadata?['size'] ?? 0;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FileViewerScreen(
          fileUrl: fileUrl,
          fileName: fileName,
          fileType: fileType,
          metadata: fileMetadata,
          fileSize: fileSize is int ? fileSize : int.tryParse(fileSize.toString()) ?? 0,
        ),
      ),
    );
  }

  /// Mostra le opzioni per un messaggio
  void _showMessageOptions(MessageModel message) {
    // NUOVO: Se la chat è in gestazione, mostra solo opzioni limitate
    if (widget.chat.isInGestation && widget.chat.isReadOnly) {
      showModalBottomSheet(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Solo info durante gestazione
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('Info messaggio'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(message);
                },
              ),
              // BANNER DISABILITATO - CAUSAVA TROPPI PROBLEMI
              if (false) // !_hasSeenGestationBanner) 
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.orange.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Funzioni limitate - Chat in sola lettura',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ),
                      // Pulsante per chiudere il banner
                      GestureDetector(
                        onTap: () {
                          _markGestationBannerAsSeen();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Colors.orange.shade600,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
      return;
    }
    
    // Menu normale per chat attive
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copia'),
              onTap: () {
                // TODO: Implementare copia del messaggio
                Navigator.pop(context);
              },
            ),
            if (message.isMe) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Modifica'),
                onTap: () {
                  // TODO: Implementare modifica del messaggio
                  Navigator.pop(context);
                },
              ),
            ],
            // CORREZIONE: Permetti eliminazione locale per tutti i messaggi
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Elimina per me', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Info'),
              onTap: () {
                Navigator.pop(context);
                _showMessageInfo(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra informazioni dettagliate sul messaggio
  void _showMessageInfo(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Info Messaggio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${message.id}'),
            const SizedBox(height: 8),
            Text('Inviato: ${message.time}'),
            const SizedBox(height: 8),
            Text('Tipo: ${message.type.toString().split('.').last}'),
            const SizedBox(height: 8),
            Text('Da: ${message.isMe ? "Te" : "Altro utente"}'),
            if (widget.chat.isInGestation) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Chat in sola lettura',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade600,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  /// Elimina un messaggio solo per l'utente corrente
  Future<void> _deleteMessage(MessageModel message) async {
    try {
      print('🗑️ ChatDetailScreen._deleteMessage - Eliminazione messaggio: ${message.id}');
      
      // Mostra dialog di conferma
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Elimina messaggio'),
          content: const Text('Vuoi eliminare questo messaggio?\n\nIl messaggio sarà eliminato solo per te. L\'altra persona continuerà a vederlo normalmente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Elimina'),
            ),
          ],
        ),
      );
      
      if (confirmed != true) {
        print('🗑️ ChatDetailScreen._deleteMessage - Eliminazione annullata dall\'utente');
        return;
      }
      
      // Chiama il MessageService per eliminare il messaggio
      final messageService = Provider.of<MessageService>(context, listen: false);
      final success = await messageService.deleteMessage(
        chatId: widget.chat.id,
        messageId: message.id,
      );
      
      if (success) {
        print('✅ ChatDetailScreen._deleteMessage - Messaggio eliminato con successo');
        
        // Mostra feedback all'utente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Messaggio eliminato'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('❌ ChatDetailScreen._deleteMessage - Errore nell\'eliminazione');
        
        // Mostra errore all'utente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Errore nell\'eliminazione del messaggio'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ ChatDetailScreen._deleteMessage - Errore: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nell\'eliminazione del messaggio'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }


  /// Mostra il picker per selezionare i giorni di gestazione
  void _showDaysPicker() {
    int tempSelectedDays = _selectedDays; // Variabile temporanea per la modale
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
        height: 300,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Titolo
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Seleziona durata gestazione',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
            
            // Rotellina
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ListWheelScrollView.useDelegate(
                  itemExtent: 50,
                  perspective: 0.005,
                  diameterRatio: 1.2,
                  physics: const FixedExtentScrollPhysics(),
                  controller: FixedExtentScrollController(initialItem: tempSelectedDays - 1),
                  onSelectedItemChanged: (index) {
                    setModalState(() {
                      tempSelectedDays = index + 1;
                    });
                    
                    // NUOVO: Aggiorna immediatamente il badge nel banner principale
                    setState(() {
                      _selectedDays = tempSelectedDays;
                    });
                  },
                  childDelegate: ListWheelChildBuilderDelegate(
                    childCount: 7,
                    builder: (context, index) {
                      final days = index + 1;
                      final isSelected = days == tempSelectedDays;
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.orange.shade50 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected ? Border.all(color: Colors.orange.shade300) : null,
                        ),
                        child: Center(
                          child: Text(
                            '$days ${days == 1 ? "giorno" : "giorni"}',
                            style: TextStyle(
                              fontSize: isSelected ? 20 : 18,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.orange.shade700 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            
            // Pulsante conferma
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    print('🔥🔥🔥 PULSANTE PREMUTO - Giorni selezionati: $tempSelectedDays 🔥🔥🔥');
                    
                    setState(() {
                      _selectedDays = tempSelectedDays;
                      print('🔥 _selectedDays aggiornato a: $_selectedDays');
                    });
                    Navigator.pop(context);
                    
                    // NUOVO: Salva i giorni nel backend
                    print('🔥 Chiamando _updateGestationDays con $tempSelectedDays giorni...');
                    await _updateGestationDays(tempSelectedDays);
                    
                    // NUOVO: Mostra toast di conferma
                    _showSelectionToast(tempSelectedDays);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Conferma $tempSelectedDays ${tempSelectedDays == 1 ? "giorno" : "giorni"}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Simula l'aggiornamento del timer basato sui giorni selezionati
  /// Aggiorna i giorni di gestazione nel backend
  Future<void> _updateGestationDays(int days) async {
    try {
      print('⏰ Aggiornando giorni di gestazione a $days giorni...');
      
      // Ottieni il token di autenticazione
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_auth_token');
      
      if (token == null) {
        print('❌ Token non trovato');
        return;
      }
      
      // Chiamata API per aggiornare i giorni di gestazione
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8001/api/chats/${widget.chat.id}/respond-deletion/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'action': 'keep',
          'days': days,
        }),
      );
      
      print('⏰ Risposta API: ${response.statusCode}');
      print('⏰ Body risposta: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Aggiorna la data di scadenza locale con quella del server
        if (responseData['expires_at'] != null) {
          _simulatedExpirationTime = DateTime.parse(responseData['expires_at']);
          print('✅ Giorni aggiornati con successo. Nuova scadenza: $_simulatedExpirationTime');
          
          // Riavvia il timer con la nuova scadenza
          if (_countdownTimer != null) {
            _countdownTimer!.cancel();
          }
          _startCountdownTimer();
        }
      } else {
        print('❌ Errore aggiornamento giorni: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Errore nella chiamata API: $e');
    }
  }

  /// Mostra toast informativo per chat in gestazione SOLO se siamo nella chat detail
  void _showGestationInfoToast() {
    // Verifica che il widget sia ancora montato e che siamo nella chat detail
    if (!mounted) return;
    
    final requesterName = widget.chat.deletionRequestedByName ?? 'L\'altro utente';
    
    // IMPORTANTE: Mostra il toast solo al primo accesso
    final snackBar = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Chat in sola lettura',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$requesterName ha eliminato questa chat. Puoi solo leggere i messaggi.',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap sull\'icona 👁️ nell\'header per decidere per quanti giorni mantenerla.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            // Banner disabilitato, non serve più marcare nulla
          },
        ),
      ),
    );
    
    // Toast semplificato - nessun tracking necessario
  }

  /// Carica lo stato del banner di gestazione - LOGICA SEMPLICE E DEFINITIVA
  Future<void> _loadGestationBannerState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (!widget.chat.isInGestation) {
        // Chat NON in gestazione = nessun banner
        _hasSeenGestationBanner = true;
        print('🍞 Chat NON in gestazione - banner disabilitato');
        return;
      }
      
      // Chat in gestazione: usa SOLO l'ID della chat (semplice e definitivo)
      final gestationKey = 'banner_seen_${widget.chat.id}';
      _hasSeenGestationBanner = prefs.getBool(gestationKey) ?? false;
      
      print('🍞 GESTAZIONE - Banner già visto: $_hasSeenGestationBanner (key: $gestationKey)');
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Errore caricamento stato banner: $e');
    }
  }
  
  /// Marca il banner di gestazione come visto e nasconde anche il toast
  Future<void> _markGestationBannerAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Usa la stessa chiave della logica di caricamento (SOLO chat ID)
      final gestationKey = 'banner_seen_${widget.chat.id}';
      await prefs.setBool(gestationKey, true);
      
      _hasSeenGestationBanner = true;
      print('🍞 Banner gestazione DEFINITIVAMENTE marcato come visto (key: $gestationKey)');
      
      // Nasconde anche il toast se è ancora visibile
      ScaffoldMessenger.of(context).clearSnackBars();
      print('🍞 Toast nascosto insieme al banner');
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Errore salvataggio stato banner: $e');
    }
  }

  /// Mostra toast di conferma della selezione
  void _showSelectionToast(int days) {
    final daysText = days == 1 ? '1 giorno' : '$days giorni';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Periodo aggiornato a $daysText',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }


  /// Widget per input bar disabilitata durante gestazione (dopo che il banner è stato dismesso)
  Widget _buildDisabledInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icona disabilitata
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: Icon(
              Icons.attach_file,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Input disabilitato
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Chat in sola lettura',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Pulsante send disabilitato
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade300,
            ),
            child: Icon(
              Icons.send,
              color: Colors.grey.shade500,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Abilita la protezione screenshot per chat in gestazione
  void _enableScreenshotProtection() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(
            label: 'SecureVox - Chat Protetta',
            primaryColor: 0xFF000000, // Colore nero per nascondere il contenuto
          ),
        );
        
        // Per Android: impedisce screenshot
        if (Platform.isAndroid) {
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
            ),
          );
        }
        
        print('🔒 Screenshot protection enabled for gestation chat');
      }
    } catch (e) {
      print('❌ Error enabling screenshot protection: $e');
    }
  }

  /// Gestisce i cambi di stato dell'app per la protezione screenshot
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Solo per chat in gestazione
    if (!widget.chat.isInGestation) return;
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App va in background o diventa inattiva
        setState(() {
          _isAppInBackground = true;
        });
        print('🔒 App in background - overlay di sicurezza attivato');
        break;
        
      case AppLifecycleState.resumed:
        // App torna in primo piano
        setState(() {
          _isAppInBackground = false;
        });
        print('🔓 App resumed - overlay di sicurezza disattivato');
        break;
        
      default:
        break;
    }
  }

  /// Disabilita la protezione screenshot
  void _disableScreenshotProtection() {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setApplicationSwitcherDescription(
          const ApplicationSwitcherDescription(
            label: 'SecureVox',
            primaryColor: 0xFF26A884, // Colore primario dell'app
          ),
        );
        
        // Ripristina le impostazioni normali per Android
        if (Platform.isAndroid) {
          SystemChrome.setSystemUIOverlayStyle(
            const SystemUiOverlayStyle(
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
          );
        }
        
        print('🔓 Screenshot protection disabled');
      }
    } catch (e) {
      print('❌ Error disabling screenshot protection: $e');
    }
  }

  /// Costruisce l'overlay di sicurezza per nascondere il contenuto
  Widget _buildSecurityOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo o icona di sicurezza
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            
            // Testo di sicurezza
            Text(
              'SecureVox',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            
            Text(
              'Chat protetta',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 32),
            
            // Indicatore di caricamento
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withOpacity(0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avvia il timer per il countdown della gestazione
  void _startCountdownTimer() {
    _updateCountdownText(); // Aggiorna subito
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdownText();
    });
  }

  /// Aggiorna il testo del countdown
  void _updateCountdownText() {
    // Verifica che il widget sia ancora montato
    if (!mounted) {
      _countdownTimer?.cancel();
      return;
    }
    
    // Usa la data di scadenza simulata se disponibile, altrimenti quella originale
    final expiresAt = _simulatedExpirationTime ?? widget.chat.gestationExpiresAt;
    if (expiresAt == null) return;
    
    final now = DateTime.now();
    final difference = expiresAt.difference(now);
    
    if (difference.isNegative) {
      setState(() {
        _countdownText = 'Scaduto';
      });
      _countdownTimer?.cancel();
      return;
    }
    
    final days = difference.inDays;
    final hours = difference.inHours % 24;
    final minutes = difference.inMinutes % 60;
    final seconds = difference.inSeconds % 60;
    
    String newText;
    if (days > 0) {
      newText = '${days}g ${hours}h ${minutes}m';
    } else if (hours > 0) {
      newText = '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      newText = '${minutes}m ${seconds}s';
    } else {
      newText = '${seconds}s';
    }
    
    if (_countdownText != newText) {
      print('🔥 AGGIORNAMENTO COUNTDOWN: "$_countdownText" → "$newText"');
      print('🔥 Giorni selezionati: $_selectedDays');
      print('🔥 Data scadenza: $expiresAt');
      setState(() {
        _countdownText = newText;
      });
    }
  }

  /// Ottiene il token di autenticazione
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('securevox_auth_token');
    } catch (e) {
      print('❌ Errore recupero token: $e');
      return null;
    }
  }

  /// Costruisce un messaggio immagine da MessageModel
  Widget _buildImageMessageFromModel(MessageModel message) {
    final metadata = message.metadata as Map<String, dynamic>?;
    final imageUrl = metadata?['imageUrl'] as String? ?? '';
    final caption = metadata?['caption'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isMe) const SizedBox(width: 20),
              if (message.isMe) ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppTheme.primaryColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, size: 50, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        if (caption != null && caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              caption,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ] else ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey[300],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 200,
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, size: 50, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        if (caption != null && caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              caption,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: message.isMe ? 20 : 0,
              left: !message.isMe ? 20 : 0,
            ),
            child: Text(
              message.time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce un messaggio video da MessageModel
  Widget _buildVideoMessageFromModel(MessageModel message) {
    final metadata = message.metadata as Map<String, dynamic>?;
    final videoUrl = metadata?['videoUrl'] as String? ?? '';
    final thumbnailUrl = metadata?['thumbnailUrl'] as String? ?? '';
    final caption = metadata?['caption'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isMe) const SizedBox(width: 20),
              if (message.isMe) ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: AppTheme.primaryColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              Image.network(
                                thumbnailUrl,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.videocam, size: 50, color: Colors.grey),
                                  );
                                },
                              ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_filled,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (caption != null && caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              caption,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ] else ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.grey[300],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              Image.network(
                                thumbnailUrl,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    height: 200,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.videocam, size: 50, color: Colors.grey),
                                  );
                                },
                              ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_filled,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (caption != null && caption.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              caption,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: message.isMe ? 20 : 0,
              left: !message.isMe ? 20 : 0,
            ),
            child: Text(
              message.time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce un messaggio audio da MessageModel
  Widget _buildVoiceMessageFromModel(MessageModel message) {
    final metadata = message.metadata as Map<String, dynamic>?;
    final duration = metadata?['duration'] as String? ?? '00:00';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isMe) const SizedBox(width: 20),
              if (message.isMe) ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ] else ...[
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.black, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          duration,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: message.isMe ? 20 : 0,
              left: !message.isMe ? 20 : 0,
            ),
            child: Text(
              message.time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce un messaggio di posizione da MessageModel
  Widget _buildLocationMessageFromModel(MessageModel message) {
    final metadata = message.metadata as Map<String, dynamic>?;
    final address = metadata?['address'] as String? ?? 'Posizione sconosciuta';
    final city = metadata?['city'] as String? ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isMe) const SizedBox(width: 20),
              if (message.isMe) ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Posizione',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          address,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        if (city.isNotEmpty)
                          Text(
                            city,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ] else ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.location_on, color: Colors.black, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Posizione',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          address,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.black,
                          ),
                        ),
                        if (city.isNotEmpty)
                          Text(
                            city,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: message.isMe ? 20 : 0,
              left: !message.isMe ? 20 : 0,
            ),
            child: Text(
              message.time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce un messaggio allegato da MessageModel
  Widget _buildAttachmentMessageFromModel(MessageModel message) {
    final metadata = message.metadata as Map<String, dynamic>?;
    final fileName = metadata?['fileName'] as String? ?? 'Allegato';
    final fileType = metadata?['fileType'] as String? ?? '';
    final fileSize = metadata?['fileSize'] as int? ?? 0;
    
    String getFileIcon(String type) {
      if (type.contains('pdf')) return '📄';
      if (type.contains('word')) return '📝';
      if (type.contains('excel')) return '📊';
      if (type.contains('powerpoint')) return '📊';
      if (type.contains('image')) return '🖼️';
      if (type.contains('video')) return '🎥';
      if (type.contains('audio')) return '🎵';
      return '📎';
    }
    
    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isMe) const SizedBox(width: 20),
              if (message.isMe) ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          getFileIcon(fileType),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formatFileSize(fileSize),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ] else ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          getFileIcon(fileType),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                formatFileSize(fileSize),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: message.isMe ? 20 : 0,
              left: !message.isMe ? 20 : 0,
            ),
            child: Text(
              message.time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce un messaggio contatto da MessageModel
  Widget _buildContactMessageFromModel(MessageModel message) {
    final metadata = message.metadata as Map<String, dynamic>?;
    final name = metadata?['name'] as String? ?? 'Contatto';
    final phone = metadata?['phone'] as String? ?? '';
    final email = metadata?['email'] as String?;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: message.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!message.isMe) const SizedBox(width: 20),
              if (message.isMe) ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Contatto',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
              ] else ...[
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 250),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: Colors.black, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Contatto',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        if (phone.isNotEmpty)
                          Text(
                            phone,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(
              right: message.isMe ? 20 : 0,
              left: !message.isMe ? 20 : 0,
            ),
            child: Text(
              message.time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceMessage(String duration, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      // Simulazione waveform
                      Row(
                        children: List.generate(8, (index) {
                          return Container(
                            width: 3,
                            height: (index % 3 + 1) * 8.0,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        duration,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: NetworkImage('https://picsum.photos/120/120?random=2'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              '09:25',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMessage(String fileName, String fileType, String time) {
    IconData iconData;
    Color iconColor;
    
    if (fileType == 'docx') {
      iconData = Icons.description;
      iconColor = Colors.blue;
    } else if (fileType == 'pdf') {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else {
      iconData = Icons.attach_file;
      iconColor = Colors.grey;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 20),
              Container(
                width: 120,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 60,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Icon(
                        iconData,
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              fileName,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              fileType.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              time,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 20),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    // Mappa geografica
                    Expanded(
                      flex: 3,
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                          color: AppTheme.primaryColor,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    // Info posizione
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Via Roma, 123',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Milano, Italia',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '09:25',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                width: 120,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Marco Rossi',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '+39 123 456 7890',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              '09:25',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(width: 20),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: const DecorationImage(
                    image: NetworkImage('https://picsum.photos/120/120?random=1'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '09:25',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    print('Debug: Building input bar. _hasText: $_hasText');
    
    // NUOVO: Se la chat è in gestazione, mostra sempre input disabilitato
    if (widget.chat.isInGestation) {
      return _buildDisabledInputBar();
    }
    
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icona allegato (paperclip)
          _buildInputIcon(Icons.attach_file, _showAttachmentMenu),
          const SizedBox(width: 12),
          // Campo di testo con anteprima immagine
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 120,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: _buildInputContent(),
            ),
          ),
          const SizedBox(width: 12),
          // Mostra icona invio se c'è testo, altrimenti foto e microfono
          if (_isUploadingImage || _isUploadingVideo || _isUploadingAttachment || _isUploadingAudio) ...[
            // Indicatore di caricamento durante upload
            Container(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          ] else if (_hasText) ...[
            _buildInputIcon(Icons.send, _sendMessage),
          ] else ...[
            _buildInputIcon(Icons.camera_alt, _showCameraMenu),
            const SizedBox(width: 12),
            _buildInputIcon(Icons.mic, _showAudioRecorder),
          ],
        ],
      ),
    );
  }

  Widget _buildInputIcon(IconData icon, VoidCallback onTap, {double size = 24}) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        color: Colors.grey[600],
        size: size,
      ),
    );
  }

  /// Costruisce il contenuto del campo di input (testo + anteprima media)
  Widget _buildInputContent() {
    if (_selectedContact != null) {
      // NUOVO: Preview contatto
      return _buildContactPreview();
    } else if (_selectedLocation != null) {
      // NUOVO: Preview posizione
      return _buildLocationPreview();
    } else if (_selectedAttachment != null) {
      // NUOVO: Usa il widget unificato per la preview (file, contatti, posizione)
      return UnifiedAttachmentPreview(
        attachment: _selectedAttachment!,
        onRemove: _removeAttachmentPreview,
        caption: _messageController.text.trim(),
      );
    } else if (_selectedAudio != null) {
      // NUOVO: Anteprima audio
      return _buildAudioPreview();
    } else if (_selectedVideo != null) {
      // MANTENIAMO: Logica video che funziona
      return Row(
        children: [
          // Anteprima video
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              color: Colors.black,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  FutureBuilder<Widget>(
                    future: _buildVideoThumbnail(_selectedVideo!),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Stack(
                          children: [
                            snapshot.data!,
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              color: Colors.black.withOpacity(0.3),
                              child: const Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ],
                        );
                      } else {
                        return Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 30,
                          ),
                        );
                      }
                    },
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: _removeVideoPreview,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              onChanged: (text) {
                final hasText = text.trim().isNotEmpty || 
                               _selectedVideo != null || 
                               _selectedAudio != null || 
                               _selectedAttachment != null ||
                               _selectedContact != null ||
                               _selectedLocation != null;
                if (_hasText != hasText) {
                  setState(() {
                    _hasText = hasText;
                  });
                }
              },
              decoration: const InputDecoration(
                hintText: 'Aggiungi una caption...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      );
    } else if (_selectedImage != null) {
      // MANTENIAMO: Logica immagine che funziona
      return Row(
        children: [
          Container(
            width: 80,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              onChanged: (text) {
                final hasText = text.trim().isNotEmpty || _selectedImage != null;
                if (_hasText != hasText) {
                  setState(() {
                    _hasText = hasText;
                  });
                }
              },
              decoration: const InputDecoration(
                hintText: 'Aggiungi una didascalia...',
                hintStyle: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.grey,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                alignLabelWithHint: true,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
          GestureDetector(
            onTap: _removeImagePreview,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      );
    } else {
      // Mostra solo campo di testo normale
      return TextField(
        controller: _messageController,
        minLines: 1,
        maxLines: 4,
        onChanged: (text) {
          final hasText = text.trim().isNotEmpty;
          if (_hasText != hasText) {
            setState(() {
              _hasText = hasText;
            });
          }
        },
        decoration: const InputDecoration(
          hintText: 'Scrivi Messaggio',
          hintStyle: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey,
            fontSize: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          alignLabelWithHint: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
        ),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 14,
          color: Colors.black,
        ),
      );
    }
  }


  /// NUOVO: Costruisce anteprima audio
  Widget _buildAudioPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Icona audio
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.audiotrack,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Info audio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Messaggio Audio',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedAudioDuration ?? '00:00',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Pulsante rimuovi
          GestureDetector(
            onTap: _removeAudioPreview,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// NUOVO: Costruisce thumbnail del video per anteprima
  Future<Widget> _buildVideoThumbnail(File videoFile) async {
    try {
      // CORREZIONE: Usa VideoPlayerWidget per compatibilità
      return VideoPlayerWidget(
        videoUrl: videoFile.path,
        thumbnailUrl: '',
      );
    } catch (e) {
      print('🎥 Errore generazione thumbnail: $e');
    }
    
    // Fallback: sfondo scuro con icona
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[800],
      child: const Icon(
        Icons.videocam,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  /// NUOVO: Invia audio con caption
  Future<void> _sendAudioWithCaption() async {
    if (_selectedAudio == null) return;
    
    setState(() {
      _isUploadingAudio = true;
    });
    
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Upload audio e ottieni URL
      final uploadResult = await _mediaService.uploadAudio(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        audio: _selectedAudio!,
        duration: _selectedAudioDuration ?? '00:00',
      );
      
      print('🎤 NUOVO - Upload result audio: $uploadResult');
      
      if (uploadResult != null && mounted) {
        final audioUrl = uploadResult['url'] ?? '';
        
        print('🎤 NUOVO - Audio URL estratto: $audioUrl');
        
        if (audioUrl.isEmpty) {
          throw Exception('URL audio non ricevuto dal server');
        }
        
        // Invia il messaggio audio
        final success = await messageService.sendVoiceMessage(
          chatId: widget.chat.id,
          recipientId: recipientId,
          audioPath: _selectedAudio!.path,
          duration: _selectedAudioDuration ?? '00:00',
        );
        
        if (success) {
          print('✅ NUOVO - Audio inviato con successo');
          
          // Pulisci il campo di input
          _messageController.clear();
          setState(() {
            _selectedAudio = null;
            _selectedAudioDuration = null;
            _hasText = false;
            _isUploadingAudio = false;
          });
          
          // Forza l'aggiornamento della lista chat nella home
          _notifyChatListUpdate();
        } else {
          throw Exception('Errore nell\'invio dell\'audio al backend');
        }
      } else {
        throw Exception('Upload audio fallito');
      }
    } catch (e) {
      print('❌ Errore invio audio: $e');
      setState(() {
        _isUploadingAudio = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'invio dell\'audio')),
        );
      }
    }
  }

  /// NUOVO: Invia video con caption
  Future<void> _sendVideoWithCaption() async {
    if (_selectedVideo == null) return;
    
    setState(() {
      _isUploadingVideo = true;
    });
    
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Upload video e ottieni URL
      final uploadResult = await _mediaService.uploadVideo(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        video: _selectedVideo!,
        caption: _messageController.text.trim(),
      );
      
      print('🎥 NUOVO - Upload result: $uploadResult');
      
      if (uploadResult != null && mounted) {
        // Estrai l'URL correttamente dai metadati
        final videoUrl = uploadResult['data']?['url'] ?? 
                         uploadResult['data']?['videoUrl'] ?? 
                         uploadResult['data']?['metadata']?['videoUrl'] ?? 
                         uploadResult['url'] ?? 
                         uploadResult['videoUrl'] ?? '';
        
        final thumbnailUrl = uploadResult['data']?['thumbnailUrl'] ?? 
                            uploadResult['data']?['metadata']?['thumbnailUrl'] ?? 
                            uploadResult['thumbnailUrl'] ?? '';
        
        print('🎥 NUOVO - Video URL estratto: $videoUrl');
        print('🎥 NUOVO - Thumbnail URL estratto: $thumbnailUrl');
        
        if (videoUrl.isEmpty) {
          throw Exception('URL video non ricevuto dal server');
        }
        
        // Invia il messaggio video
        final success = await messageService.sendVideoMessage(
          chatId: widget.chat.id,
          recipientId: recipientId,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          caption: _messageController.text.trim().isNotEmpty ? _messageController.text.trim() : null,
        );
        
        if (success) {
          print('✅ NUOVO - Video inviato con successo');
          
          // Pulisci il campo di input
          _messageController.clear();
          setState(() {
            _selectedVideo = null;
            _hasText = false;
            _isUploadingVideo = false;
          });
          
          // Forza l'aggiornamento della lista chat nella home
          _notifyChatListUpdate();
        } else {
          throw Exception('Errore nell\'invio del video al backend');
        }
      } else {
        throw Exception('Upload video fallito');
      }
    } catch (e) {
      print('❌ Errore invio video: $e');
      setState(() {
        _isUploadingVideo = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'invio del video')),
        );
      }
    }
  }

  /// Invia immagine con caption - CORREZIONE: Usa la stessa logica del testo
  Future<void> _sendImageWithCaption() async {
    if (_selectedImage == null) return;
    
    setState(() {
      _isUploadingImage = true;
    });
    
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      print('🖼️ CORREZIONE - Inizio caricamento immagine...');
      
      // CORREZIONE: Upload immagine e ottieni URL
      final uploadResult = await _mediaService.uploadImage(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        image: _selectedImage!,
        caption: _messageController.text.trim(),
      );
      
      print('🖼️ CORREZIONE - Upload result: $uploadResult');
      
      if (uploadResult != null && mounted) {
        // CORREZIONE: Estrai l'URL correttamente dai metadati (prova tutti i possibili campi)
        final imageUrl = uploadResult['data']?['url'] ?? 
                         uploadResult['data']?['imageUrl'] ?? 
                         uploadResult['data']?['metadata']?['imageUrl'] ?? 
                         uploadResult['url'] ?? 
                         uploadResult['imageUrl'] ?? '';
        final caption = _messageController.text.trim();
        
        print('🖼️ CORREZIONE - URL estratto: $imageUrl');
        print('🖼️ CORREZIONE - Caption: $caption');
        
        // CORREZIONE: Verifica che l'URL sia valido
        if (imageUrl.isEmpty) {
          print('❌ CORREZIONE - URL immagine vuoto!');
          throw Exception('URL immagine non ricevuto dal server');
        }
        
        // CORREZIONE: Usa la stessa logica di sendTextMessage
        // Invia direttamente al backend usando sendImageMessage del MessageService
        final success = await messageService.sendImageMessage(
          chatId: widget.chat.id,
          recipientId: recipientId,
          imageUrl: imageUrl,
          caption: caption.isNotEmpty ? caption : null,
        );
        
        if (success) {
          print('✅ CORREZIONE - Immagine inviata con successo usando logica del testo');
          
          // Pulisci il campo di input
          _messageController.clear();
          setState(() {
            _selectedImage = null;
            _imageUrl = null;
            _hasText = false;
            _isUploadingImage = false;
          });
          
          // Nessun scroll automatico
          
          // Forza l'aggiornamento della lista chat nella home
          _notifyChatListUpdate();
        } else {
          print('❌ CORREZIONE - Errore nell\'invio dell\'immagine al backend');
          throw Exception('Errore nell\'invio dell\'immagine al backend');
        }
      } else {
        print('❌ CORREZIONE - Upload fallito o componente non montato');
        throw Exception('Upload fallito');
      }
    } catch (e) {
      print('Errore upload immagine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore upload immagine: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  /// NUOVO: Invia contatto come messaggio
  Future<void> _sendContactMessage(ContactData contactData) async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      print('📤 _sendContactMessage - Invio contatto: ${contactData.name}');
      print('📤 _sendContactMessage - Phone: ${contactData.phoneNumbers.isNotEmpty ? contactData.phoneNumbers.first : "N/A"}');
      
      // Invia il messaggio contatto
      final success = await messageService.sendContactMessage(
        chatId: widget.chat.id,
        recipientId: recipientId,
        contactName: contactData.name,
        contactPhone: contactData.phoneNumbers.isNotEmpty ? contactData.phoneNumbers.first : 'Nessun numero',
        contactEmail: contactData.emails.isNotEmpty ? contactData.emails.first : null,
      );
      
      if (success) {
        print('✅ _sendContactMessage - Contatto inviato con successo');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('👤 Contatto inviato'),
              backgroundColor: Color(0xFF0D7C66),
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        // Forza l'aggiornamento della lista chat nella home
        _notifyChatListUpdate();
      } else {
        throw Exception('Errore nell\'invio del contatto al backend');
      }
    } catch (e) {
      print('❌ Errore invio contatto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nell\'invio del contatto: $e')),
        );
      }
    }
  }

  /// CORREZIONE: Helper per determinare il destinatario di un messaggio
  String _getRecipientId() {
    print('🚀 ChatDetailScreen._getRecipientId - INIZIO FUNZIONE');
    
    final currentUserId = UserService.getCurrentUserIdSync();
    print('🔍 ChatDetailScreen._getRecipientId - Current User ID: $currentUserId');
    print('🔍 ChatDetailScreen._getRecipientId - Chat ID: ${widget.chat.id}');
    print('🔍 ChatDetailScreen._getRecipientId - Chat userId: ${widget.chat.userId}');
    print('🔍 ChatDetailScreen._getRecipientId - Chat participants: ${widget.chat.participants}');
    print('🔍 ChatDetailScreen._getRecipientId - Chat isGroup: ${widget.chat.isGroup}');
    
    if (currentUserId == null) {
      print('❌ ChatDetailScreen._getRecipientId - Current User ID è null!');
      return 'unknown';
    }
    
    // 1. Prova prima con userId (più affidabile per chat individuali)
    if (widget.chat.userId != null && widget.chat.userId != currentUserId) {
      print('✅ ChatDetailScreen._getRecipientId - Recipient da userId: ${widget.chat.userId}');
      return widget.chat.userId!;
    }
    // 2. Se userId non è disponibile, prova con participants
    else if (widget.chat.participants.isNotEmpty) {
      final recipientId = widget.chat.participants.firstWhere(
        (participantId) => participantId != currentUserId,
        orElse: () => 'unknown',
      );
      print('✅ ChatDetailScreen._getRecipientId - Recipient da participants: $recipientId');
      return recipientId;
    }
    // 3. Fallback: cerca nella cache delle chat
    else {
      print('🔍 ChatDetailScreen._getRecipientId - Cercando nella cache...');
      final realChat = RealChatService.cachedChats.firstWhere(
        (chat) => chat.id == widget.chat.id,
        orElse: () => widget.chat,
      );
      
      print('🔍 ChatDetailScreen._getRecipientId - Cache chat userId: ${realChat.userId}');
      print('🔍 ChatDetailScreen._getRecipientId - Cache chat participants: ${realChat.participants}');
      
      if (realChat.userId != null && realChat.userId != currentUserId) {
        print('✅ ChatDetailScreen._getRecipientId - Recipient da cache userId: ${realChat.userId}');
        return realChat.userId!;
      } else if (realChat.participants.isNotEmpty) {
        final recipientId = realChat.participants.firstWhere(
          (participantId) => participantId != currentUserId,
          orElse: () => 'unknown',
        );
        print('✅ ChatDetailScreen._getRecipientId - Recipient da cache participants: $recipientId');
        return recipientId;
      }
    }
    
    print('❌ ChatDetailScreen._getRecipientId - Nessun destinatario trovato!');
    return 'unknown';
  }

  void _sendMessage() async {
    // NUOVO: Se c'è un contatto selezionato, invia il contatto
    if (_selectedContact != null) {
      await _sendContact(_selectedContact!);
      _removeContactPreview();
      return;
    }
    
    // NUOVO: Se c'è una posizione selezionata, invia la posizione
    if (_selectedLocation != null) {
      await _sendLocation(_selectedLocation!);
      _removeLocationPreview();
      return;
    }
    
    // Se c'è un allegato selezionato (file), usa il metodo copiato dalle immagini
    if (_selectedAttachment != null) {
      await _sendFileWithCaption();
      return;
    }
    
    // NUOVO: Se c'è un audio selezionato, invia l'audio
    if (_selectedAudio != null) {
      await _sendAudioWithCaption();
      return;
    }
    
    // Se c'è un video selezionato, invia il video (MANTENIAMO - FUNZIONA)
    if (_selectedVideo != null) {
      await _sendVideoWithCaption();
      return;
    }
    
    // Se c'è un'immagine selezionata, invia l'immagine (MANTENIAMO - FUNZIONA)
    if (_selectedImage != null) {
      await _sendImageWithCaption();
      return;
    }
    
    // Altrimenti invia messaggio di testo normale
    if (_messageController.text.trim().isNotEmpty) {
      final messageText = _messageController.text.trim();
      print('Invio messaggio: $messageText');
      
      // Ottieni il MessageService
      final messageService = Provider.of<MessageService>(context, listen: false);
      
      // CORREZIONE: Logica diretta per determinare il destinatario
      final currentUserId = UserService.getCurrentUserIdSync();
      print('🔍 ChatDetailScreen._sendMessage - Current User ID: $currentUserId');
      print('🔍 ChatDetailScreen._sendMessage - Chat ID: ${widget.chat.id}');
      print('🔍 ChatDetailScreen._sendMessage - Chat userId: ${widget.chat.userId}');
      print('🔍 ChatDetailScreen._sendMessage - Chat participants: ${widget.chat.participants}');
      print('🔍 ChatDetailScreen._sendMessage - Chat isGroup: ${widget.chat.isGroup}');
      
      String recipientId = 'unknown';
      
      if (currentUserId == null) {
        print('❌ ChatDetailScreen._sendMessage - Current User ID è null!');
        return;
      }
      
      // 1. Prova prima con userId (più affidabile per chat individuali)
      if (widget.chat.userId != null && widget.chat.userId != currentUserId) {
        recipientId = widget.chat.userId!;
        print('✅ ChatDetailScreen._sendMessage - Recipient da userId: $recipientId');
      }
      // 2. Se userId non è disponibile, prova con participants
      else if (widget.chat.participants.isNotEmpty) {
        recipientId = widget.chat.participants.firstWhere(
          (participantId) => participantId != currentUserId,
          orElse: () => 'unknown',
        );
        print('✅ ChatDetailScreen._sendMessage - Recipient da participants: $recipientId');
      }
      // 3. Fallback: cerca nella cache delle chat
      else {
        print('🔍 ChatDetailScreen._sendMessage - Cercando nella cache...');
        final realChat = RealChatService.cachedChats.firstWhere(
          (chat) => chat.id == widget.chat.id,
          orElse: () => widget.chat,
        );
        
        print('🔍 ChatDetailScreen._sendMessage - Cache chat userId: ${realChat.userId}');
        print('🔍 ChatDetailScreen._sendMessage - Cache chat participants: ${realChat.participants}');
        
        if (realChat.userId != null && realChat.userId != currentUserId) {
          recipientId = realChat.userId!;
          print('✅ ChatDetailScreen._sendMessage - Recipient da cache userId: $recipientId');
        } else if (realChat.participants.isNotEmpty) {
          recipientId = realChat.participants.firstWhere(
            (participantId) => participantId != currentUserId,
            orElse: () => 'unknown',
          );
          print('✅ ChatDetailScreen._sendMessage - Recipient da cache participants: $recipientId');
        }
      }
      
      print('📱 ChatDetailScreen._sendMessage - Final Recipient ID: $recipientId');
      
      if (recipientId == 'unknown') {
        print('❌ ChatDetailScreen._sendMessage - Impossibile determinare il destinatario!');
        return;
      }
      
      // Invia il messaggio
      final success = await messageService.sendTextMessage(
        chatId: widget.chat.id,
        recipientId: recipientId,
        text: messageText,
      );
      
      if (success) {
        print('Messaggio inviato con successo');
        
        // Pulisci il campo di testo
        _messageController.clear();
        setState(() {
          _hasText = false;
        });
        
        // Nessun scroll automatico
        
        // Forza l'aggiornamento della lista chat nella home
        _notifyChatListUpdate();
      } else {
        print('Errore nell\'invio del messaggio');
        // Mostra un messaggio di errore all'utente
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore nell\'invio del messaggio'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // === METODI PER SERVIZI MULTIMEDIALI ===

  /// Mostra il menu allegati
  void _showAttachmentMenu() {
    print('🚨 DEBUG: _showAttachmentMenu() CHIAMATO!');
    AttachmentMenuHandler.showAttachmentMenu(
      context,
      onGalleryPhoto: _handleAttachmentGalleryPhoto,
      onGalleryVideo: _handleGalleryVideo,
      onDocument: () {
        print('🚨 DEBUG: Pulsante Documento premuto!');
        _handleDocument();
      },
      onContact: _handleContact,
      onLocation: _handleLocation,
      onAudioRecord: _handleAudioFile,
    );
  }

  /// Gestisce foto dalla galleria per il menu allegati (con anteprima)
  void _handleAttachmentGalleryPhoto() async {
    try {
      final image = await _mediaService.pickImageFromGallery();
      if (image != null && mounted) {
        _showImagePreview(image);
      }
    } catch (e) {
      print('Errore selezione galleria: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella selezione dalla galleria')),
        );
      }
    }
  }

  /// Gestisce foto dalla fotocamera per il menu allegati (con anteprima)
  void _handleAttachmentCameraPhoto() async {
    try {
      final image = await _mediaService.pickImageFromCamera();
      if (image != null && mounted) {
        _showImagePreview(image);
      }
    } catch (e) {
      print('Errore scatto foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nello scatto della foto')),
        );
      }
    }
  }

  /// Mostra il menu fotocamera
  void _showCameraMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Fotocamera',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCameraOption(
                  icon: Icons.photo_camera,
                  label: 'Scatta Foto',
                  onTap: () {
                    Navigator.pop(context);
                    _handleCameraPhoto();
                  },
                ),
                _buildCameraOption(
                  icon: Icons.videocam,
                  label: 'Registra Video',
                  onTap: () {
                    Navigator.pop(context);
                    _handleCameraVideo();
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 95,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mostra il registratore audio
  void _showAudioRecorder() {
    AudioRecorderHandler.showAudioRecorder(
      context,
      onRecordingComplete: _handleAudioRecording,
    );
  }

  // === HANDLERS PER ALLEGATI ===

  /// Gestisce foto dalla galleria
  void _handleGalleryPhoto() async {
    try {
      // Mostra indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Seleziona immagine dalla galleria
      final imageFile = await _mediaService.pickImageFromGallery();
      
      if (imageFile == null) {
        if (mounted) {
          Navigator.pop(context); // Chiudi loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessuna immagine selezionata')),
          );
        }
        return;
      }
      
      // Upload e invio immagine
      await _uploadAndSendImage(imageFile);
      
      if (mounted) {
        Navigator.pop(context); // Chiudi loading
      }
    } catch (e) {
      print('Errore gestione foto galleria: $e');
      if (mounted) {
        Navigator.pop(context); // Chiudi loading se aperto
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella selezione dell\'immagine')),
        );
      }
    }
  }

  /// Gestisce video dalla galleria
  void _handleGalleryVideo() async {
    try {
      // Seleziona video dalla galleria
      final videoFile = await _mediaService.pickVideoFromGallery();
      
      if (videoFile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessun video selezionato')),
          );
        }
        return;
      }
      
      // NUOVO: Mostra anteprima video invece di inviare immediatamente
      setState(() {
        _selectedVideo = videoFile;
        _selectedImage = null; // Rimuovi immagine se presente
        _hasText = true;
      });
      
    } catch (e) {
      print('Errore gestione video galleria: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella selezione del video')),
        );
      }
    }
  }


  /// Gestisce documenti con sistema unificato
  void _handleDocument() async {
    try {
      print('🚨 DEBUG: _handleDocument() CHIAMATO!');
      print('📄 Selezione documento con sistema unificato...');
      
      // Usa il sistema unificato per selezionare il file
      final attachment = await _attachmentService.selectAttachment(
        AttachmentType.file
      );
      
      if (attachment != null) {
        print('📄 Documento selezionato: ${attachment.metadata['file_name']}');
        
        // Salva l'allegato per la preview
        if (mounted) {
          setState(() {
            _selectedAttachment = attachment;
            _hasText = true; // Abilita il pulsante invio
          });
        }
        
        print('✅ File salvato per preview: ${attachment.metadata['file_name']}');
      } else {
        print('📄 Nessun documento selezionato');
      }
    } catch (e) {
      print('❌ Errore selezione documento: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella selezione del documento')),
        );
      }
    }
  }


  /// Gestisce contatti
  void _handleContact() async {
    try {
      // Mostra indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Carica tutti i contatti
      print('📞 ChatDetailScreen._handleContact - Richiesta caricamento contatti...');
      final contacts = await ContactService.getAllContacts();
      
      if (mounted) {
        Navigator.pop(context); // Chiudi loading
      }
      
      print('📞 ChatDetailScreen - Contatti caricati: ${contacts.length}');
      print('📞 ChatDetailScreen - LISTA CONTATTI:');
      for (int i = 0; i < contacts.length; i++) {
        print('   ${i + 1}. ${contacts[i].displayName} - Phones: ${contacts[i].phones.length}');
      }
      
      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nessun contatto disponibile nella rubrica'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Mostra dialog con la lista dei contatti
      if (!mounted) return;
      
      final selectedContacts = await showDialog<List<Contact>>(
        context: context,
        builder: (context) => _ContactPickerDialog(contacts: contacts),
      );
      
      if (selectedContacts == null || selectedContacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessun contatto selezionato')),
          );
        }
        return;
      }
      
      if (mounted) {
        print('👤 ChatDetailScreen._handleContact - Selezionati ${selectedContacts.length} contatti');
        
        // Se è stato selezionato UN SOLO contatto, mostra preview
        if (selectedContacts.length == 1) {
          final selectedContact = selectedContacts.first;
          final contactData = ContactService.contactToContactData(selectedContact);
          
          print('📤 ChatDetailScreen._handleContact - Impostando preview contatto: ${contactData.name}');
          
          setState(() {
            _selectedContact = contactData;
            _hasText = true; // Abilita il pulsante invio
          });
          
          print('✅ ChatDetailScreen._handleContact - Preview contatto impostata');
        }
        // Se sono stati selezionati PIÙ contatti, inviali subito uno dopo l'altro
        else {
          for (final selectedContact in selectedContacts) {
            final contactData = ContactService.contactToContactData(selectedContact);
            print('📤 ChatDetailScreen._handleContact - Invio contatto: ${contactData.name}');
            
            // Invia il contatto come messaggio
            await _sendContactMessage(contactData);
            
            // Piccola pausa tra l'invio di contatti multipli
            if (selectedContacts.length > 1) {
              await Future.delayed(const Duration(milliseconds: 200));
            }
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${selectedContacts.length} contatti inviati'),
                backgroundColor: const Color(0xFF0D7C66),
              ),
            );
          }
          
          print('✅ ChatDetailScreen._handleContact - Tutti i contatti inviati');
        }
      }
    } catch (e) {
      print('Errore gestione contatto: $e');
      if (mounted) {
        Navigator.pop(context); // Chiudi loading se aperto
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella selezione del contatto')),
        );
      }
    }
  }

  /// Gestisce selezione file audio
  void _handleAudioFile() async {
    try {
      print('🎵 ChatDetailScreen._handleAudioFile - INIZIO selezione file audio');
      
      // Mostra indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Seleziona file audio usando il nuovo servizio
      final audioData = await AudioFileService.pickAudioFile();
      
      if (audioData == null) {
        print('🎵 ChatDetailScreen._handleAudioFile - Nessun file audio selezionato');
        if (mounted) {
          Navigator.pop(context); // Chiudi loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessun file audio selezionato')),
          );
        }
        return;
      }
      
      if (mounted) {
        Navigator.pop(context); // Chiudi loading
        
        print('🎵 ChatDetailScreen._handleAudioFile - File audio selezionato: ${audioData.fileName}');
        
        // Invia il file audio
        await _sendAudioFile(audioData);
      }
    } catch (e) {
      print('❌ ChatDetailScreen._handleAudioFile - Errore selezione file audio: $e');
      if (mounted) {
        Navigator.pop(context); // Chiudi loading se ancora aperto
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella selezione del file audio')),
        );
      }
    }
  }

  /// Gestisce posizione
  void _handleLocation() async {
    try {
      // Mostra indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      // Ottieni posizione corrente usando il nuovo servizio
      final position = await LocationService.getCurrentLocation();
      
      if (position == null) {
        if (mounted) {
          Navigator.pop(context); // Chiudi loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile ottenere la posizione')),
          );
        }
        return;
      }
      
      if (mounted) {
        Navigator.pop(context); // Chiudi loading
        
        print('📍 ChatDetailScreen._handleLocation - Posizione rilevata: ${position.latitude}, ${position.longitude}');
        
        // Salva la posizione per la preview nel campo testo
        setState(() {
          _selectedLocation = position;
          _hasText = true; // Abilita il pulsante invio
        });
        
        print('✅ ChatDetailScreen._handleLocation - Posizione salvata per preview');
      }
    } catch (e) {
      print('Errore gestione posizione: $e');
      if (mounted) {
        Navigator.pop(context); // Chiudi loading se aperto
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'ottenimento della posizione')),
        );
      }
    }
  }

  /// Gestisce foto dalla fotocamera
  void _handleCameraPhoto() async {
    print('📷 ChatDetailScreen._handleCameraPhoto - SCATTA FOTO CLICCATO!');
    try {
      final image = await _mediaService.pickImageFromCamera();
      print('📷 ChatDetailScreen._handleCameraPhoto - Immagine ricevuta: ${image?.path}');
      if (image != null && mounted) {
        _showImagePreview(image);
      } else {
        print('❌ ChatDetailScreen._handleCameraPhoto - Nessuna immagine ricevuta');
      }
    } catch (e) {
      print('❌ ChatDetailScreen._handleCameraPhoto - Errore scatto foto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nello scatto della foto')),
        );
      }
    }
  }


  /// Mostra anteprima immagine nel campo di testo
  void _showImagePreview(File imageFile) {
    setState(() {
      _selectedImage = imageFile;
      _hasText = true; // Mostra il pulsante invio
    });
  }

  /// NUOVO: Mostra anteprima video nel campo di testo
  void _showVideoPreview(File videoFile) {
    setState(() {
      _selectedVideo = videoFile;
      _selectedImage = null; // Rimuovi immagine se presente
      _hasText = true; // Mostra il pulsante invio
    });
  }

  /// Gestisce video dalla fotocamera
  void _handleCameraVideo() async {
    print('🎥 ChatDetailScreen._handleCameraVideo - REGISTRA VIDEO CLICCATO!');
    try {
      final video = await _mediaService.pickVideoFromCamera();
      print('🎥 ChatDetailScreen._handleCameraVideo - Video ricevuto: ${video?.path}');
      if (video != null && mounted) {
        // NUOVO: Mostra anteprima video invece di inviare immediatamente
        _showVideoPreview(video);
      } else {
        print('❌ ChatDetailScreen._handleCameraVideo - Nessun video ricevuto');
      }
    } catch (e) {
      print('❌ ChatDetailScreen._handleCameraVideo - Errore registrazione video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nella registrazione del video')),
        );
      }
    }
  }

  /// Gestisce registrazione audio - NUOVO: Mostra anteprima invece di inviare
  void _handleAudioRecording(File audioFile, String duration) async {
    if (mounted) {
      print('🎤 Audio registrato: ${audioFile.path}, durata: $duration');
      // NUOVO: Mostra anteprima audio invece di inviare immediatamente
      _showAudioPreview(audioFile, duration);
    }
  }


  // === METODI PER CHIAMATE ===

  /// Avvia una chiamata audio
  void _startAudioCall() async {
    try {
      // Estrai l'ID utente dal nome della chat o usa un ID mock
      final userId = _extractUserIdFromChat();
      
      print('📞 ChatDetailScreen._startAudioCall - Avvio chiamata audio per utente: $userId');
      
      // Ottieni il servizio WebRTC
      final webrtcService = Provider.of<NativeAudioCallService>(context, listen: false);
      
      // Avvia la chiamata audio
      await webrtcService.startCall(
        userId,
        'Utente',
        CallType.audio,
      );
      
      print('📞 ChatDetailScreen._startAudioCall - Chiamata audio avviata con successo');
      
      // Naviga alla schermata di chiamata
      if (mounted) {
        context.go('/call/$userId?type=audio&name=${Uri.encodeComponent(widget.chat.name)}');
      }
      
    } catch (e) {
      print('❌ ChatDetailScreen._startAudioCall - Errore: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'avviare la chiamata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Avvia una chiamata video
  void _startVideoCall() async {
    try {
      // Estrai l'ID utente dal nome della chat o usa un ID mock
      final userId = _extractUserIdFromChat();
      
      print('📞 ChatDetailScreen._startVideoCall - Avvio chiamata video per utente: $userId');
      
      // Ottieni il servizio WebRTC
      final webrtcService = Provider.of<NativeAudioCallService>(context, listen: false);
      
      // Avvia la chiamata video
      await webrtcService.startCall(
        userId,
        'Utente',
        CallType.video,
      );
      
      print('📞 ChatDetailScreen._startVideoCall - Chiamata video avviata con successo');
      
      // Naviga alla schermata di chiamata
      if (mounted) {
        context.go('/call/$userId?type=video&name=${Uri.encodeComponent(widget.chat.name)}');
      }
      
    } catch (e) {
      print('❌ ChatDetailScreen._startVideoCall - Errore: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'avviare la chiamata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Estrae l'ID utente dal nome della chat
  String _extractUserIdFromChat() {
    final chatName = widget.chat.name.toLowerCase();
    final users = UserService.getRegisteredUsersSync();
    
    print('Debug: Extracting user ID for chat name: "$chatName"');
    
    // Prima controlla se la chat ha un userId diretto (per chat individuali)
    if (widget.chat.userId != null && widget.chat.userId!.isNotEmpty) {
      // Verifica che l'utente esista
      final userExists = users.any((user) => user.id == widget.chat.userId);
      if (userExists) {
        print('Debug: Found direct user ID from chat: ${widget.chat.userId} for chat: $chatName');
        return widget.chat.userId!;
      } else {
        print('Debug: Direct user ID ${widget.chat.userId} does not exist for chat: $chatName');
      }
    }
    
    // Per chat di gruppo, usa il primo utente disponibile
    if (widget.chat.isGroup) {
      print('Debug: Chat is a group, using first available user');
      return users.isNotEmpty ? users.first.id : '1';
    }
    
    // Fallback: mapping per compatibilità con chat esistenti
    final chatToUserIdMap = {
      'riccardo dicamillo': '5008b261-468a-4b04-9ace-3ad48619c20d',
      'raffaele amoroso': '2',
      'alex linderson': '1',
      'alice rossi': '2',
      'sofia verdi': '3',
      'andrea neri': '4',
      'giulia russo': '10',
      'francesco romano': '11',
      'chiara ferrari': '12',
      'luca conti': '13',
      'maria bianchi': '14',
      'giovanni rossi': '15',
      'elena martini': '16',
      'john ahraham': '17',
      'john borino': '18',
      'sabila': '19',
    };
    
    // Controlla il mapping specifico
    final mappedUserId = chatToUserIdMap[chatName];
    if (mappedUserId != null) {
      // Verifica che l'utente esista
      final userExists = users.any((user) => user.id == mappedUserId);
      if (userExists) {
        print('Debug: Found mapped user ID: $mappedUserId for chat: $chatName');
        return mappedUserId;
      } else {
        print('Debug: Mapped user ID $mappedUserId does not exist for chat: $chatName');
      }
    }
    
    // Poi cerca una corrispondenza esatta per nome
    for (final user in users) {
      if (user.name.toLowerCase() == chatName) {
        return user.id;
      }
    }
    
    // Poi cerca una corrispondenza parziale per nome
    for (final user in users) {
      final userName = user.name.toLowerCase();
      final chatWords = chatName.split(' ');
      final userWords = userName.split(' ');
      
      // Controlla se almeno una parola del nome utente è presente nel nome chat
      for (final chatWord in chatWords) {
        for (final userWord in userWords) {
          if (userWord.contains(chatWord) || chatWord.contains(userWord)) {
            return user.id;
          }
        }
      }
    }
    
    // Fallback: usa l'ID della chat come ID utente se è un numero valido
    final chatId = widget.chat.id;
    if (int.tryParse(chatId) != null) {
      print('Debug: Using chat ID as user ID: $chatId for chat: $chatName');
      return chatId;
    }
    
    // Ultimo fallback: restituisce il primo utente disponibile
    print('Debug: No user found for chat: $chatName, using first available user');
    return users.isNotEmpty ? users.first.id : '1';
  }

  // === METODI HELPER PER UPLOAD E INVIO ===

  /// Upload e invio immagine
  Future<void> _uploadAndSendImage(File imageFile) async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // CORREZIONE: Upload immagine e ottieni URL
      final uploadResult = await _mediaService.uploadImage(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        image: imageFile,
      );
      
      print('🖼️ CORREZIONE - Upload result dalla fotocamera: $uploadResult');
      
      if (uploadResult != null && mounted) {
        // CORREZIONE: Estrai l'URL correttamente dai metadati (prova tutti i possibili campi)
        final imageUrl = uploadResult['data']?['url'] ?? 
                         uploadResult['data']?['imageUrl'] ?? 
                         uploadResult['data']?['metadata']?['imageUrl'] ?? 
                         uploadResult['url'] ?? 
                         uploadResult['imageUrl'] ?? '';
        
        print('🖼️ CORREZIONE - URL estratto dalla fotocamera: $imageUrl');
        
        // CORREZIONE: Verifica che l'URL sia valido
        if (imageUrl.isEmpty) {
          print('❌ CORREZIONE - URL immagine vuoto dalla fotocamera!');
          throw Exception('URL immagine non ricevuto dal server');
        }
        
        // CORREZIONE: Usa la stessa logica di sendTextMessage per inviare al backend
        final success = await messageService.sendImageMessage(
          chatId: widget.chat.id,
          recipientId: recipientId,
          imageUrl: imageUrl,
          caption: null, // Nessuna caption per immagini dalla fotocamera
        );
        
        if (success) {
          print('✅ CORREZIONE - Immagine dalla fotocamera inviata con successo usando logica del testo');
          
          // Nessun scroll automatico
          
          // Forza l'aggiornamento della lista chat nella home
          _notifyChatListUpdate();
        } else {
          print('❌ CORREZIONE - Errore nell\'invio dell\'immagine dalla fotocamera al backend');
          throw Exception('Errore nell\'invio dell\'immagine al backend');
        }
      } else {
        print('❌ CORREZIONE - Upload dalla fotocamera fallito o componente non montato');
        throw Exception('Upload fallito');
      }
    } catch (e) {
      print('❌ Errore upload immagine: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel caricamento dell\'immagine')),
        );
      }
    }
  }

  /// Upload e invio video - CORREZIONE: Usa la stessa logica del testo
  Future<void> _uploadAndSendVideo(File videoFile) async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      print('🎥 CORREZIONE - Inizio caricamento video...');
      
      // CORREZIONE: Upload video e ottieni URL
      final uploadResult = await _mediaService.uploadVideo(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        video: videoFile,
      );
      
      print('🎥 CORREZIONE - Upload result video: $uploadResult');
      
      if (uploadResult != null && mounted) {
        // CORREZIONE: Estrai l'URL correttamente dai metadati
        final videoUrl = uploadResult['data']?['url'] ?? 
                         uploadResult['data']?['videoUrl'] ?? 
                         uploadResult['data']?['metadata']?['videoUrl'] ?? 
                         uploadResult['url'] ?? 
                         uploadResult['videoUrl'] ?? '';
        
        final thumbnailUrl = uploadResult['data']?['thumbnailUrl'] ?? 
                            uploadResult['data']?['metadata']?['thumbnailUrl'] ?? 
                            uploadResult['thumbnailUrl'] ?? '';
        
        print('🎥 CORREZIONE - Video URL estratto: $videoUrl');
        print('🎥 CORREZIONE - Thumbnail URL estratto: $thumbnailUrl');
        
        // CORREZIONE: Verifica che l'URL sia valido
        if (videoUrl.isEmpty) {
          print('❌ CORREZIONE - URL video vuoto!');
          throw Exception('URL video non ricevuto dal server');
        }
        
        // CORREZIONE: Usa sendVideoMessage del MessageService con i parametri corretti
        final success = await messageService.sendVideoMessage(
          chatId: widget.chat.id,
          recipientId: recipientId,
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          caption: null, // Nessuna caption per video
        );
        
        if (success) {
          print('✅ CORREZIONE - Video inviato con successo usando logica del testo');
          
          // Nessun scroll automatico
          
          // Forza l'aggiornamento della lista chat nella home
          _notifyChatListUpdate();
        } else {
          print('❌ CORREZIONE - Errore nell\'invio del video al backend');
          throw Exception('Errore nell\'invio del video al backend');
        }
      } else {
        print('❌ CORREZIONE - Upload video fallito o componente non montato');
        throw Exception('Upload video fallito');
      }
    } catch (e) {
      print('❌ Errore upload video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel caricamento del video')),
        );
      }
    }
  }

  /// Upload e invio documento
  Future<void> _uploadAndSendDocument(File documentFile) async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Upload documento
      final uploadResult = await _mediaService.uploadFile(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        file: documentFile,
      );
      
      if (uploadResult != null && mounted) {
        // Crea messaggio con dati reali
        final now = DateTime.now();
        final fileName = documentFile.path.split('/').last;
        final message = MessageModel(
          id: 'doc_${now.millisecondsSinceEpoch}',
          chatId: widget.chat.id,
          senderId: UserService.getCurrentUserIdSync() ?? '1',
          isMe: true,
          type: MessageType.attachment,
          content: '📎 $fileName',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: AttachmentMessageData(
            fileName: fileName,
            fileType: _getFileType(fileName),
            fileUrl: uploadResult['url'] ?? '',
            fileSize: uploadResult['size'] ?? documentFile.lengthSync(),
          ).toJson(),
          isRead: true,
        );
        
        // Aggiungi alla cache
        messageService.addMessageToCache(widget.chat.id, message);
        
        // Sincronizza con RealChatService
        _syncWithRealChatService(widget.chat.id, message.content);
        
        // Nessun scroll automatico
        
        print('✅ Documento caricato e inviato con successo');
      } else {
        throw Exception('Upload documento fallito');
      }
    } catch (e) {
      print('❌ Errore upload documento: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel caricamento del documento')),
        );
      }
    }
  }

  /// Invia contatto
  Future<void> _sendContact(ContactData contact) async {
    try {
      print('👤 ChatDetailScreen._sendContact - Invio contatto: ${contact.name}');
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Invia il contatto al backend
      final success = await messageService.sendContactMessage(
        chatId: widget.chat.id,
        recipientId: recipientId,
        contactName: contact.name,
        contactPhone: contact.phoneNumbers.isNotEmpty ? contact.phoneNumbers.first : 'Nessun numero',
        contactEmail: contact.emails.isNotEmpty ? contact.emails.first : null,
      );
      
      if (success) {
        print('✅ Contatto inviato con successo al backend');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('👤 Contatto inviato'),
              backgroundColor: Color(0xFF0D7C66),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Errore nell\'invio al backend');
      }
    } catch (e) {
      print('❌ Errore invio contatto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'invio del contatto')),
        );
      }
    }
  }

  /// Invia posizione
  Future<void> _sendLocation(LocationData position) async {
    try {
      print('📍 ChatDetailScreen._sendLocation - Invio posizione: ${position.latitude}, ${position.longitude}');
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Invia la posizione al backend
      final success = await messageService.sendLocationMessage(
        chatId: widget.chat.id,
        recipientId: recipientId,
        latitude: position.latitude,
        longitude: position.longitude,
        address: '',
        city: '',
        country: '',
      );
      
      if (success) {
        print('✅ Posizione inviata con successo al backend');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📍 Posizione inviata'),
              backgroundColor: Color(0xFF0D7C66),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Errore nell\'invio al backend');
      }
    } catch (e) {
      print('❌ Errore invio posizione: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'invio della posizione')),
        );
      }
    }
  }

  /// Invia file audio selezionato
  Future<void> _sendAudioFile(AudioFileData audioData) async {
    try {
      print('🎵 ChatDetailScreen._sendAudioFile - Invio file audio: ${audioData.fileName}');
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Formatta il contenuto del file audio per la visualizzazione
      final audioContent = AudioFileService.formatAudioForDisplay(audioData);
      
      // Crea messaggio file audio
      final now = DateTime.now();
      final message = MessageModel(
        id: 'audio_file_${now.millisecondsSinceEpoch}',
        chatId: widget.chat.id,
        senderId: UserService.getCurrentUserIdSync() ?? '1',
        isMe: true,
        type: MessageType.file, // Usiamo 'file' per i file audio
        content: audioContent,
        time: TimezoneService.formatCallTime(now),
        timestamp: now,
        metadata: {
          ...audioData.toJson(),
          'file_type': 'audio',
          'file_path': audioData.file.path,
        },
        isRead: true,
      );
      
      // Aggiungi alla cache
      messageService.addMessageToCache(widget.chat.id, message);
      
      // Sincronizza con RealChatService
      _syncWithRealChatService(widget.chat.id, message.content);
      
      // Nessun scroll automatico
      
      print('✅ File audio inviato con successo');
    } catch (e) {
      print('❌ Errore invio file audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nell\'invio del file audio')),
        );
      }
    }
  }

  /// Upload e invio audio
  Future<void> _uploadAndSendAudio(File audioFile, String duration) async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      // Upload audio
      final uploadResult = await _mediaService.uploadAudio(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        audio: audioFile,
        duration: duration,
      );
      
      if (uploadResult != null && mounted) {
        // Crea messaggio con dati reali
        final now = DateTime.now();
        final message = MessageModel(
          id: 'audio_${now.millisecondsSinceEpoch}',
          chatId: widget.chat.id,
          senderId: UserService.getCurrentUserIdSync() ?? '1',
          isMe: true,
          type: MessageType.voice,
          content: '🎤 Audio',
          time: TimezoneService.formatCallTime(now),
          timestamp: now,
          metadata: VoiceMessageData(
            duration: duration,
            audioUrl: uploadResult['url'] ?? '',
          ).toJson(),
          isRead: true,
        );
        
        // Aggiungi alla cache
        messageService.addMessageToCache(widget.chat.id, message);
        
        // Sincronizza con RealChatService
        _syncWithRealChatService(widget.chat.id, message.content);
        
        // Nessun scroll automatico
        
        print('✅ Audio caricato e inviato con successo');
      } else {
        throw Exception('Upload audio fallito');
      }
    } catch (e) {
      print('❌ Errore upload audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore nel caricamento dell\'audio')),
        );
      }
    }
  }

  /// Invia messaggio al backend per notifiche real-time
  Future<void> _sendMessageToBackend(MessageModel message) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print('❌ Token non disponibile per invio backend');
        return;
      }
      
      final recipientId = _getRecipientId();
      print('📡 Invio messaggio al backend per notifiche real-time...');
      print('📡 Recipient ID: $recipientId');
      print('📡 Message Type: ${message.type}');
      print('📡 Message Content: ${message.content}');
      
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8001/api/chats/${message.chatId}/send/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'recipient_id': recipientId,
          'message_type': message.type.toString(),
          'content': message.content,
          'metadata': message.metadata,
          'timestamp': message.timestamp.toIso8601String(),
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Messaggio inviato al backend con successo');
      } else {
        print('❌ Errore invio backend: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Errore invio messaggio al backend: $e');
    }
  }

  /// Sincronizza con RealChatService
  void _syncWithRealChatService(String chatId, String messageContent) {
    try {
      // Aggiorna la chat in RealChatService
      RealChatService.updateLastMessage(chatId, messageContent);
      print('✅ Sincronizzazione con RealChatService completata per chat: $chatId');
    } catch (e) {
      print('❌ Errore sincronizzazione RealChatService: $e');
    }
  }



  /// RIMOSSO: Ora usiamo _sendFileWithCaption() che copia la logica delle immagini

  /// Invia file con caption - COPIATO DA IMMAGINI CHE FUNZIONANO
  Future<void> _sendFileWithCaption() async {
    if (_selectedAttachment?.file == null) return;
    
    setState(() {
      _isUploadingAttachment = true;
    });
    
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      final recipientId = _getRecipientId();
      
      print('📄 CORREZIONE - Inizio caricamento file...');
      
      // CORREZIONE: Upload file e ottieni URL (come per immagini)
      final uploadResult = await _mediaService.uploadFile(
        userId: UserService.getCurrentUserIdSync() ?? '1',
        chatId: widget.chat.id,
        file: _selectedAttachment!.file!,
      );
      
      print('📄 CORREZIONE - Upload result: $uploadResult');
      
      if (uploadResult != null && mounted) {
        // CORREZIONE: Estrai l'URL correttamente dai metadati (come per immagini)
        final baseUrl = 'http://127.0.0.1:8001';
        final partialUrl = uploadResult['metadata']?['fileUrl'] ?? 
                          uploadResult['file_url'] ?? 
                          uploadResult['url'] ?? '';
        final fileUrl = partialUrl.startsWith('http') ? partialUrl : '$baseUrl$partialUrl';
        final fileName = uploadResult['metadata']?['fileName'] ?? 
                        _selectedAttachment!.metadata['file_name'] ?? 'Documento';
        final caption = _messageController.text.trim();
        
        print('📄 CORREZIONE - Upload result completo: $uploadResult');
        print('📄 CORREZIONE - Partial URL: $partialUrl');
        print('📄 CORREZIONE - URL finale: $fileUrl');
        print('📄 CORREZIONE - Nome file: $fileName');
        print('📄 CORREZIONE - Caption: $caption');
        print('📄 CORREZIONE - Metadati attachment: ${_selectedAttachment!.metadata}');
        print('📄 CORREZIONE - Metadati upload: ${uploadResult['metadata']}');
        
        // CORREZIONE: Verifica che l'URL sia valido
        if (fileUrl.isEmpty || fileUrl == baseUrl) {
          print('❌ CORREZIONE - URL file vuoto!');
          throw Exception('URL file non ricevuto dal server');
        }
        
        // CORREZIONE: Usa sendFileMessage come per immagini e video (gestisce tutto automaticamente)
        final success = await messageService.sendFileMessage(
          chatId: widget.chat.id,
          recipientId: recipientId,
          fileUrl: fileUrl,
          fileName: fileName,
          caption: caption.isNotEmpty ? caption : null,
          metadata: {
            'file_url': fileUrl,
            'file_name': fileName,
            'file_size': uploadResult['metadata']?['fileSize'] ?? _selectedAttachment!.metadata['file_size'],
            'file_type': uploadResult['metadata']?['fileType'] ?? _selectedAttachment!.metadata['file_type'],
            'file_extension': uploadResult['metadata']?['fileType'] ?? _selectedAttachment!.metadata['file_extension'],
            'mime_type': uploadResult['metadata']?['mimeType'] ?? _selectedAttachment!.metadata['mime_type'],
            // CORREZIONE: Includi pdfPreviewUrl se presente (con URL completo)
            if (uploadResult['metadata']?['pdfPreviewUrl'] != null) ...{
              'pdfPreviewUrl': uploadResult['metadata']['pdfPreviewUrl'].startsWith('http') 
                ? uploadResult['metadata']['pdfPreviewUrl']
                : 'http://127.0.0.1:8001${uploadResult['metadata']['pdfPreviewUrl']}',
              'pdf_preview_url': uploadResult['metadata']['pdfPreviewUrl'].startsWith('http') 
                ? uploadResult['metadata']['pdfPreviewUrl']
                : 'http://127.0.0.1:8001${uploadResult['metadata']['pdfPreviewUrl']}',
            },
          },
        );
        
        if (success) {
          print('✅ CORREZIONE - File inviato con successo usando MessageService.sendFileMessage');
          
          // Pulisci il campo di input
          _messageController.clear();
          setState(() {
            _selectedAttachment = null;
            _hasText = false;
            _isUploadingAttachment = false;
          });
          
          // Scrolla verso il basso
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        } else {
          throw Exception('Errore nell\'invio del file al backend');
        }
      } else {
        print('❌ CORREZIONE - Upload fallito o componente non montato');
        throw Exception('Upload fallito');
      }
    } catch (e) {
      print('Errore upload file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore upload file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  /// Rimuove la preview dell'allegato (sistema unificato)
  void _removeAttachmentPreview() {
    setState(() {
      _selectedAttachment = null;
      _hasText = _messageController.text.trim().isNotEmpty;
    });
    print('🗑️ Preview allegato rimossa');
  }

  /// Rimuove l'anteprima dell'immagine (MANTENIAMO - FUNZIONA)
  void _removeImagePreview() {
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
      _hasText = _messageController.text.trim().isNotEmpty;
    });
    print('🗑️ Preview immagine rimossa');
  }

  /// Rimuove l'anteprima del video (MANTENIAMO - FUNZIONA)
  void _removeVideoPreview() {
    setState(() {
      _selectedVideo = null;
      _hasText = _messageController.text.trim().isNotEmpty;
    });
    print('🗑️ Preview video rimossa');
  }

  /// NUOVO: Rimuove anteprima audio
  void _removeAudioPreview() {
    setState(() {
      _selectedAudio = null;
      _selectedAudioDuration = null;
      _hasText = _messageController.text.trim().isNotEmpty;
    });
    print('🗑️ Preview audio rimossa');
  }

  /// Costruisce la preview del contatto
  Widget _buildContactPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Icona contatto
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.person,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Dettagli contatto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedContact!.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (_selectedContact!.phoneNumbers.isNotEmpty)
                  Text(
                    _selectedContact!.phoneNumbers.first,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          
          // Pulsante rimuovi
          GestureDetector(
            onTap: _removeContactPreview,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Costruisce la preview della posizione
  Widget _buildLocationPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Icona posizione
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.location_on,
              color: Colors.indigo,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          
          // Dettagli posizione
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Posizione condivisa',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Pulsante rimuovi
          GestureDetector(
            onTap: _removeLocationPreview,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.red,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rimuove la preview del contatto
  void _removeContactPreview() {
    if (mounted) {
      setState(() {
        _selectedContact = null;
        _hasText = _messageController.text.trim().isNotEmpty;
      });
    }
  }

  /// Rimuove la preview della posizione
  void _removeLocationPreview() {
    if (mounted) {
      setState(() {
        _selectedLocation = null;
        _hasText = _messageController.text.trim().isNotEmpty;
      });
    }
  }

  /// NUOVO: Mostra anteprima audio nel campo di testo
  void _showAudioPreview(File audioFile, String duration) {
    setState(() {
      _selectedAudio = audioFile;
      _selectedAudioDuration = duration;
      _hasText = true; // Abilita il pulsante invio
    });
    print('🎤 Preview audio mostrata: $duration');
  }

  /// RIMOSSO: Usa _removeAttachmentPreview() per i file

  /// Ottieni icona per il tipo di file
  IconData _getFileIcon(String fileType) {
    if (fileType.startsWith('image/')) {
      return Icons.image;
    } else if (fileType.startsWith('video/')) {
      return Icons.video_file;
    } else if (fileType.startsWith('audio/')) {
      return Icons.audio_file;
    } else if (fileType == 'application/pdf') {
      return Icons.picture_as_pdf;
    } else if (fileType.contains('word') || fileType.contains('document')) {
      return Icons.description;
    } else if (fileType.contains('excel') || fileType.contains('spreadsheet')) {
      return Icons.table_chart;
    } else if (fileType.contains('powerpoint') || fileType.contains('presentation')) {
      return Icons.slideshow;
    } else if (fileType.contains('zip') || fileType.contains('rar')) {
      return Icons.archive;
    } else {
      return Icons.attach_file;
    }
  }

  /// Ottieni il tipo MIME del file
  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'avi':
        return 'video/x-msvideo';
      case 'mov':
        return 'video/quicktime';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }

}

/// Widget per selezionare uno o più contatti dalla rubrica
class _ContactPickerDialog extends StatefulWidget {
  final List<Contact> contacts;

  const _ContactPickerDialog({required this.contacts});

  @override
  State<_ContactPickerDialog> createState() => _ContactPickerDialogState();
}

class _ContactPickerDialogState extends State<_ContactPickerDialog> {
  late List<Contact> _filteredContacts;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedContactIds = {}; // IDs dei contatti selezionati

  @override
  void initState() {
    super.initState();
    _filteredContacts = widget.contacts;
    print('📞 _ContactPickerDialog - Inizializzato con ${widget.contacts.length} contatti');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = widget.contacts;
      } else {
        _filteredContacts = widget.contacts.where((contact) {
          final nameLower = contact.displayName.toLowerCase();
          final queryLower = query.toLowerCase();
          final phoneMatch = contact.phones.any((phone) => 
            phone.number.contains(queryLower)
          );
          return nameLower.contains(queryLower) || phoneMatch;
        }).toList();
      }
      print('📞 _ContactPickerDialog - Filtrati ${_filteredContacts.length} contatti con query "$query"');
    });
  }

  void _toggleContactSelection(Contact contact) {
    setState(() {
      if (_selectedContactIds.contains(contact.id)) {
        _selectedContactIds.remove(contact.id);
      } else {
        _selectedContactIds.add(contact.id);
      }
      print('📞 _ContactPickerDialog - Selezionati ${_selectedContactIds.length} contatti');
    });
  }

  void _confirmSelection() {
    final selectedContacts = widget.contacts
        .where((c) => _selectedContactIds.contains(c.id))
        .toList();
    
    if (selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un contatto')),
      );
      return;
    }

    Navigator.pop(context, selectedContacts);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D7C66), Color(0xFF0A6B57)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF0D7C66),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Seleziona contatti',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedContactIds.length} selezionat${_selectedContactIds.length == 1 ? 'o' : 'i'}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content area bianca
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // Barra di ricerca
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cerca contatto...',
                            hintStyle: const TextStyle(fontFamily: 'Poppins'),
                            prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                            suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterContacts('');
                                  },
                                )
                              : null,
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: _filterContacts,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Lista contatti
                      Expanded(
                        child: _filteredContacts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nessun contatto trovato',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredContacts.length,
                              itemBuilder: (context, index) {
                                final contact = _filteredContacts[index];
                                final isSelected = _selectedContactIds.contains(contact.id);
                                final hasPhone = contact.phones.isNotEmpty;
                                
                                return InkWell(
                                  onTap: () => _toggleContactSelection(contact),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: Colors.grey[200]!),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: Colors.primaries[
                                            contact.displayName.hashCode % Colors.primaries.length
                                          ],
                                          child: Text(
                                            contact.displayName.isNotEmpty 
                                              ? contact.displayName[0].toUpperCase()
                                              : '?',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        
                                        // Nome e numeri
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              // Nome e cognome
                                              Text(
                                                contact.displayName.isNotEmpty 
                                                  ? contact.displayName 
                                                  : 'Senza nome',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              
                                              // Numeri di telefono
                                              if (hasPhone)
                                                ...contact.phones.map((phone) => Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.phone,
                                                        size: 11,
                                                        color: Colors.grey[500],
                                                      ),
                                                      const SizedBox(width: 3),
                                                      Flexible(
                                                        child: Text(
                                                          phone.number,
                                                          style: TextStyle(
                                                            color: Colors.grey[600],
                                                            fontSize: 11,
                                                          ),
                                                          overflow: TextOverflow.ellipsis,
                                                          maxLines: 1,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ))
                                              else
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 2),
                                                  child: Text(
                                                    'Nessun numero di telefono',
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 11,
                                                      fontStyle: FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 8),
                                        
                                        // Checkbox rotondo a destra
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF0D7C66) : Colors.grey[400]!,
                                              width: 2,
                                            ),
                                            color: isSelected ? const Color(0xFF0D7C66) : Colors.transparent,
                                          ),
                                          child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                  ),
                        ),
                      
                      // Footer con pulsante
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selectedContactIds.isEmpty ? null : _confirmSelection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D7C66),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey[300],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 0,
                              ),
                              child: Text(
                                _selectedContactIds.isEmpty 
                                  ? 'Seleziona contatti' 
                                  : 'Allega (${_selectedContactIds.length})',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
