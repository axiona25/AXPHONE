import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../models/chat_model.dart';
import '../models/user_model.dart';
import '../services/chat_service.dart';
import '../services/test_chat_service.dart';
import '../services/real_chat_service.dart';
import '../services/connection_service.dart';
import '../services/message_service.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../widgets/chat_item.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../services/user_status_service.dart';
import '../widgets/swipeable_chat_item.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/custom_toast.dart';
import '../widgets/call_pip_widget.dart';
import '../services/unified_realtime_service.dart';
import '../services/active_call_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ===== COSTANTI =====
  static const String baseUrl = 'http://localhost:8000/api';
  
  // ===== VARIABILI DI STATO =====
  List<ChatModel> _chats = [];
  List<ChatModel> _filteredChats = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isEmptyMode = false;
  bool _isLoading = false;
  String _currentTime = '00:00';
  String? _swipedChatId; // Traccia quale chat ha il menu aperto
  Timer? _debounceTimer; // Timer per debounce degli aggiornamenti
  StreamSubscription<Map<String, dynamic>>? _globalEventsSubscription; // Listener per eventi globali

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentTime = _getCurrentTime();
    _loadChats();
    _searchController.addListener(_onSearchChanged);
    
    
    // Inizializza i servizi
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final connectionService = Provider.of<ConnectionService>(context, listen: false);
            final messageService = Provider.of<MessageService>(context, listen: false);
            connectionService.initialize();
            // NON pulire la cache dei messaggi per preservare lo stato di lettura
            // messageService.clearMessageCache();
            // Inizializza la sincronizzazione real-time
            await messageService.initializeRealtimeSync();
            
            // CORREZIONE AVATAR: Pre-carica tutti i colori utenti per evitare il flash verde
            print('🎨 HomeScreen.initState - Pre-caricamento colori avatar...');
            final masterAvatarService = MasterAvatarService();
            await masterAvatarService.preloadAllUserData();
            print('🎨 HomeScreen.initState - Pre-caricamento avatar completato');
            
            // Forza aggiornamento UI dopo il pre-caricamento
            if (mounted) {
              setState(() {
                // Trigger rebuild per mostrare i colori corretti
              });
            }
            
            // IMPORTANTE: Aggiungi listener per aggiornare la UI quando arrivano nuovi messaggi
            // CORREZIONE: Usa il nuovo metodo per listener real-time
            messageService.addRealtimeListener(_onMessageServiceChanged);
            print('📱 HomeScreen.initState - Listener real-time aggiunto per aggiornamenti');
          });
    
    // Aggiorna l'ora ogni minuto
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = _getCurrentTime();
        });
      }
    });
    
    // Aggiorna l'UI quando lo stato della chiamata cambia
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Forza il rebuild per aggiornare il widget PIP
        });
      }
    });
    
    // Sincronizzazione in background completamente trasparente
    _startBackgroundSync();
    
    // NUOVO: Listener per eventi globali (eliminazione chat, ecc.)
    _globalEventsSubscription = UnifiedRealtimeService.globalEvents.listen(_handleGlobalEvent);
    print('📡 HomeScreen - Listener eventi globali inizializzato');
    
    // Listener per aggiornamenti stati utenti in real-time
    UserStatusService().addListener(() {
      if (mounted) {
        setState(() {
          // Aggiorna UI quando cambiano gli stati utenti
        });
      }
    });
    
    // REAL-TIME: Forza aggiornamento immediato degli stati dal server
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🏠 HomeScreen - Forzando aggiornamento stati real-time...');
      await UserStatusService().forceUpdate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // CORREZIONE: Aggiorna la home quando si torna dalla chat
    // Questo viene chiamato ogni volta che si naviga verso questa schermata
    
    // CORREZIONE AVATAR: Pre-caricamento SINCRONO IMMEDIATO per evitare flash verde
    print('🎨 HomeScreen.didChangeDependencies - Pre-caricamento SINCRONO colori avatar...');
    final masterAvatarService = MasterAvatarService();
    masterAvatarService.preloadColorsSync(); // SINCRONO - non blocca
    print('🎨 HomeScreen.didChangeDependencies - Colori avatar pronti IMMEDIATAMENTE');
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        print('📱 HomeScreen.didChangeDependencies - Home screen attiva, aggiornamento chat');
        
        // Pre-caricamento completo in background (async)
        await masterAvatarService.preloadAllUserData();
        
        // CORREZIONE: Forza il reset dello stato di visualizzazione quando si naviga alla home
        final messageService = Provider.of<MessageService>(context, listen: false);
        messageService.forceResetForHome();
        
        _refreshChatsWithMessageService();
        
        // CORREZIONE: Assicurati che il listener sia sempre attivo quando si naviga alla home
        messageService.addRealtimeListener(_onMessageServiceChanged);
        print('📱 HomeScreen.didChangeDependencies - Listener real-time riattivato per aggiornamenti');
      }
    });
  }

  /// Callback chiamato quando il MessageService cambia (nuovi messaggi)
  void _onMessageServiceChanged() {
    // CORREZIONE: Aggiorna immediatamente la lista chat quando arrivano nuovi messaggi
    print('📱 HomeScreen._onMessageServiceChanged - LISTENER CHIAMATO!');
    if (mounted) {
      print('📱 HomeScreen._onMessageServiceChanged - Aggiornamento immediato per nuovi messaggi');
      _refreshChatsWithMessageService();
    } else {
      print('❌ HomeScreen._onMessageServiceChanged - Widget non montato, skip aggiornamento');
    }
  }
  
  /// NUOVO: Gestisce eventi globali (eliminazione chat, ecc.)
  void _handleGlobalEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    
    final eventType = event['type'];
    print('📡 HomeScreen - Evento globale ricevuto: $eventType');
    
    if (eventType == 'chat_deletion_notification') {
      final requestingUserName = event['requesting_user_name'];
      final message = event['message'];
      
      // Mostra toast di notifica
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message ?? '$requestingUserName ha eliminato la chat',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      
      // Forza refresh della lista chat per aggiornare le icone
      _refreshChatsWithMessageService();
      
      print('🍞 Toast eliminazione chat mostrato per $requestingUserName');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _debounceTimer?.cancel();
    _globalEventsSubscription?.cancel(); // Cleanup listener eventi globali
    
    // Reset dello stato di swipe
    _swipedChatId = null;
    
    // CORREZIONE: Rimuovi il listener real-time
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      messageService.removeRealtimeListener(_onMessageServiceChanged);
      print('📱 HomeScreen.dispose - Listener real-time rimosso');
    } catch (e) {
      print('📱 HomeScreen.dispose - Errore rimozione listener: $e');
    }
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final connectionService = Provider.of<ConnectionService>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        connectionService.onAppResumed();
        // IMPORTANTE: Aggiorna la lista chat quando l'app torna in primo piano
        // per sincronizzare lo stato di lettura
        print('📱 HomeScreen.didChangeAppLifecycleState - App ripresa, aggiornamento chat');
        _refreshChatsWithMessageService();
        break;
      case AppLifecycleState.paused:
        connectionService.onAppPaused();
        break;
      case AppLifecycleState.detached:
        connectionService.onAppCrashed();
        break;
      default:
        break;
    }
  }

  /// Metodo chiamato quando si torna dalla chat di dettaglio
  void onReturnFromChat() {
    print('📱 HomeScreen.onReturnFromChat - Aggiornamento forzato dalla chat');
    if (mounted) {
      // CORREZIONE: Forza il reset dello stato di visualizzazione quando si torna alla home
      final messageService = Provider.of<MessageService>(context, listen: false);
      messageService.forceResetForHome();
      
      _refreshChatsWithMessageService();
      
      // CORREZIONE AVATAR: Assicurati che i colori siano sempre caricati
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        print('🎨 HomeScreen.onReturnFromChat - Verifica colori avatar...');
        final masterAvatarService = MasterAvatarService();
        await masterAvatarService.preloadAllUserData();
        if (mounted) {
          setState(() {
            // Trigger rebuild per aggiornare avatar se necessario
          });
        }
      });
      
      // CORREZIONE: Riattiva il listener quando si torna dalla chat
      messageService.addRealtimeListener(_onMessageServiceChanged);
      print('📱 HomeScreen.onReturnFromChat - Listener real-time riattivato');
    }
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Usa il nuovo metodo che mantiene lo stato di lettura
      await _refreshChatsWithMessageService();
      
      setState(() {
        _isLoading = false;
        // Reset dello stato di swipe quando si ricaricano le chat
        _swipedChatId = null;
      });
    } catch (e) {
      print('Errore nel caricamento chat: $e');
      
      // Fallback al metodo originale
      final chats = _isEmptyMode ? TestChatService.getEmptyChats() : ChatService.getRealUserChatsSync();
      final filteredChats = chats;
      
      setState(() {
        _chats = filteredChats;
        _filteredChats = filteredChats;
        _isLoading = false;
        // Reset dello stato di swipe quando si ricaricano le chat
        _swipedChatId = null;
      });
    }
  }

  /// Avvia la sincronizzazione in background completamente trasparente
  void _startBackgroundSync() {
    // Sincronizza ogni 60 secondi in background senza aggiornare l'UI
    // Ridotta frequenza per evitare refresh continui
    // Nessun log per evitare spam nei log
    Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _syncInBackground();
      }
    });
  }

  /// Sincronizza i dati in background senza aggiornare l'UI
  Future<void> _syncInBackground() async {
    try {
      // IMPORTANTE: Sincronizzazione completamente in background
      // Non aggiorna l'UI per evitare refresh continui
      // Non pulisce cache per preservare lo stato di lettura
      // Nessun log per evitare spam nei log
      
      final messageService = Provider.of<MessageService>(context, listen: false);
      await messageService.syncInBackground();
      
    } catch (e) {
      // Solo log degli errori critici
      print('🔄 HomeScreen._syncInBackground - Errore critico: $e');
    }
  }

  /// Aggiorna la lista chat usando il MessageService per mantenere lo stato di lettura
  Future<void> _refreshChatsWithMessageService() async {
    try {
      final messageService = Provider.of<MessageService>(context, listen: false);
      List<ChatModel> chats;
      
      if (_isEmptyMode) {
        chats = TestChatService.getEmptyChats();
      } else {
        // RIPRISTINATO: Caricamento chat reali con fallback intelligente
        print('🔄 HomeScreen._refreshChatsWithMessageService - Tentativo ricaricamento dal backend...');
        try {
          chats = await RealChatService.getRealChats();
          print('✅ HomeScreen._refreshChatsWithMessageService - RealChatService completato: ${chats.length} chat');
        } catch (e) {
          print('❌ HomeScreen._refreshChatsWithMessageService - Errore RealChatService: $e');
          chats = RealChatService.cachedChats;
          print('🔄 HomeScreen._refreshChatsWithMessageService - Cache caricata: ${chats.length} chat');
        }
        
        // FALLBACK: Se non ci sono chat (server throttled), usa chat di test SOLO come ultimo resort
        if (chats.isEmpty) {
          print('⚠️ HomeScreen._refreshChatsWithMessageService - Server throttled, aspettando o usando fallback...');
          // Prova una volta la cache diretta
          chats = RealChatService.cachedChats;
          if (chats.isEmpty) {
            print('💡 HomeScreen._refreshChatsWithMessageService - Usando chat di test temporaneamente...');
            chats = TestChatService.getAllChats();
          }
        }
      }
        
      // IMPORTANTE: Aggiorna lo stato di lettura usando il MessageService
      for (final chat in chats) {
        final unreadCount = messageService.getUnreadCount(chat.id);
        final lastMessage = messageService.getLastMessage(chat.id);
        
        // CORREZIONE: Aggiorna sempre la chat con i dati dal MessageService
        final updatedChat = ChatModel(
          id: chat.id,
          name: chat.name,
          lastMessage: lastMessage.isNotEmpty ? lastMessage : chat.lastMessage,
          timestamp: chat.timestamp,
          avatarUrl: chat.avatarUrl,
          isOnline: chat.isOnline,
          unreadCount: unreadCount,
          isGroup: chat.isGroup,
        );
        
        // Aggiorna la cache di RealChatService
        RealChatService.updateChatInCache(updatedChat);
        
        // Sostituisci nella lista
        final index = chats.indexWhere((c) => c.id == chat.id);
        if (index != -1) {
          chats[index] = updatedChat;
        }
        
        print('📱 HomeScreen._refreshChatsWithMessageService - Chat ${chat.id}: $unreadCount non letti, ultimo: "$lastMessage"');
      }
      
      // Aggiorna solo se ci sono cambiamenti
      if (chats.length != _chats.length || !_areChatsEqual(chats, _chats)) {
        final filteredChats = chats; // Mostra tutte le chat
        
        setState(() {
          _chats = filteredChats;
          _filteredChats = filteredChats;
        });
        
        print('📋 HomeScreen._refreshChatsWithMessageService - Lista chat aggiornata: ${chats.length} chat');
      }
    } catch (e) {
      print('Errore nel refresh chat con MessageService: $e');
    }
  }

  /// Aggiorna la lista chat senza mostrare il loading (solo per uso interno)
  Future<void> _refreshChats() async {
    try {
      List<ChatModel> chats;
      
      if (_isEmptyMode) {
        chats = TestChatService.getEmptyChats();
      } else {
        // PRIORITÀ: Usa la cache di RealChatService per mantenere lo stato di lettura
        chats = RealChatService.cachedChats;
        
        // Se la cache è vuota, carica i dati dal backend
        if (chats.isEmpty) {
          chats = await RealChatService.getRealChats();
          
          // Se RealChatService non ha dati, fallback a ChatService
          if (chats.isEmpty) {
            final fallbackChats = await ChatService.getRealUserChats();
            if (fallbackChats.isNotEmpty) {
              // Aggiorna RealChatService con i dati dal backend
              for (final chat in fallbackChats) {
                RealChatService.updateChatInCache(chat);
              }
              chats = fallbackChats;
            }
          }
        }
      }
      
      // Aggiorna solo se ci sono cambiamenti
      if (chats.length != _chats.length || 
          !_areChatsEqual(chats, _chats)) {
        
        final filteredChats = chats; // Mostra tutte le chat
        
        setState(() {
          _chats = filteredChats;
          _filteredChats = filteredChats;
        });
        
        print('📋 HomeScreen._refreshChats - Lista chat aggiornata: ${chats.length} chat');
      }
    } catch (e) {
      print('Errore nel refresh chat: $e');
    }
  }

  /// Confronta due liste di chat per vedere se sono uguali
  bool _areChatsEqual(List<ChatModel> chats1, List<ChatModel> chats2) {
    if (chats1.length != chats2.length) return false;
    
    for (int i = 0; i < chats1.length; i++) {
      if (chats1[i].id != chats2[i].id || 
          chats1[i].lastMessage != chats2[i].lastMessage ||
          chats1[i].unreadCount != chats2[i].unreadCount) {
        return false;
      }
    }
    
    return true;
  }

  void _toggleEmptyMode() {
    setState(() {
      _isEmptyMode = !_isEmptyMode;
    });
    _loadChats();
  }

  void _showChatMoreOptions(BuildContext context, ChatModel chat) {
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
            // Handle del bottom sheet
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Titolo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                chat.name,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            
            // Opzioni
            _buildMoreOption(
              icon: Icons.info_outline,
              title: 'Info Chat',
              subtitle: 'Visualizza dettagli della chat',
              onTap: () {
                Navigator.pop(context);
                _showChatInfo(chat);
              },
            ),
            _buildMoreOption(
              icon: Icons.notifications_off,
              title: 'Silenzia',
              subtitle: 'Disabilita le notifiche',
              onTap: () {
                Navigator.pop(context);
                _muteChat(chat);
              },
            ),
            _buildMoreOption(
              icon: Icons.archive,
              title: 'Archivia',
              subtitle: 'Sposta nella cartella archivio',
              onTap: () {
                Navigator.pop(context);
                _archiveChat(chat);
              },
            ),
            _buildMoreOption(
              icon: Icons.delete_outline,
              title: 'Elimina',
              subtitle: 'Rimuovi la chat',
              onTap: () {
                Navigator.pop(context);
                _deleteChat(chat);
              },
              isDestructive: true,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive 
                    ? Colors.red.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDestructive ? Colors.red : Colors.black,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChatInfo(ChatModel chat) {
    // Ottieni lo stato reale dell'utente dal UserStatusService
    final userStatusService = UserStatusService();
    
    // Determina l'ID utente corretto per lo stato
    String? targetUserId = chat.userId;
    
    // Se userId è null, usa i participants per trovare l'altro utente
    if (targetUserId == null && chat.participants.isNotEmpty) {
      final currentUserId = '2'; // TODO: Ottieni dall'AuthService
      targetUserId = chat.participants.firstWhere(
        (id) => id != currentUserId,
        orElse: () => chat.participants.first,
      );
    }
    
    final effectiveUserId = targetUserId ?? chat.id;
    
    // Mostra dialog con le informazioni della chat
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (BuildContext context) {
        return Dialog(
          alignment: Alignment.center,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con avatar e titolo
                    Row(
                      children: [
                        // Avatar della chat usando MasterAvatarWidget
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor,
                          ),
                          child: Center(
                            child: Text(
                              chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Info Chat',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Informazioni della chat
                    _buildInfoRow('Nome', chat.name),
                    const SizedBox(height: 12),
                    
                    // Ultimo messaggio con icona allegato se presente
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            'Ultimo\nmessaggio:',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              // Icona allegato se il messaggio è un file
                              if (chat.lastMessage.contains('.'))
                                const Icon(
                                  Icons.attach_file,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              if (chat.lastMessage.contains('.'))
                                const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  chat.lastMessage.isEmpty ? 'Nessun messaggio' : chat.lastMessage,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow('Data', _formatTimestamp(chat.timestamp)),
                    const SizedBox(height: 12),
                    
                    // Stato online con indicatore colorato - usa UserStatusService per stato reale
                    Builder(
                      builder: (context) {
                        final realUserStatus = userStatusService.getUserStatus(effectiveUserId);
                        final statusColor = userStatusService.getStatusColor(realUserStatus);
                        final statusText = userStatusService.getStatusText(realUserStatus);
                        
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text(
                                'Stato:',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            // Indicatore di stato reale dal UserStatusService
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow('Non letti', chat.unreadCount.toString()),
                    const SizedBox(height: 12),
                    
                    _buildInfoRow('Tipo', chat.isGroup ? 'Gruppo' : 'Chat privata'),
                    
                    const SizedBox(height: 24),
                    
                    // Pulsante chiudi centrato
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          'Chiudi',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final timestampDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    // 1. Giorno in corso - mostra ora precisa (13:15)
    if (timestampDate == today) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
    
    // 2. Ieri - mostra "Ieri" + ora
    if (timestampDate == yesterday) {
      return 'Ieri ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
    
    // 3. Dopo ieri - mostra data completa (14/09/25)
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year.toString().substring(2)}';
  }

  void _muteChat(ChatModel chat) {
    // Implementa il silenziamento della chat
    print('Silenzia chat: ${chat.name}');
    
    // Mostra toast di conferma con nuovo stile
    CustomSnackBar.showMuted(
      context,
      'Chat con ${chat.name} silenziata',
    );
  }

  void _archiveChat(ChatModel chat) {
    // Implementa l'archiviazione della chat
    print('Archivia chat: ${chat.name}');
    
    // Mostra toast di conferma con nuovo stile
    CustomSnackBar.showArchived(
      context,
      'Chat con ${chat.name} archiviata',
    );
  }

  void _deleteChat(ChatModel chat) {
    // Mostra dialog di conferma
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Elimina Chat',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: Text(
            'Sei sicuro di voler eliminare la chat con "${chat.name}"? Questa azione non può essere annullata.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
          actions: [
            // Pulsante Annulla
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Annulla',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            // Pulsante Elimina
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmDeleteChat(chat);
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.1),
              ),
              child: const Text(
                'Elimina',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteChat(ChatModel chat) async {
    try {
      // Verifica che l'utente sia autenticato
      final authService = Provider.of<AuthService>(context, listen: false);
      final isLoggedIn = await authService.isLoggedIn();
      
      if (!isLoggedIn) {
        CustomSnackBar.showError(
          context,
          'Devi essere loggato per eliminare una chat',
        );
        return;
      }
      
      // Prova sempre a eliminare dal backend
      print('🗑️ Tentativo di eliminazione chat: ${chat.name} (ID: ${chat.id})');
      
      // Chiama l'API per eliminare la chat dal database
      final success = await _deleteChatFromBackend(chat.id);
      
      if (success) {
        // Rimuovi la chat dalla lista solo se l'eliminazione è riuscita
        setState(() {
          _chats.removeWhere((c) => c.id == chat.id);
          _filteredChats.removeWhere((c) => c.id == chat.id);
          // Reset dello stato di swipe se la chat eliminata era quella aperta
          if (_swipedChatId == chat.id) {
            _swipedChatId = null;
          }
        });

        // Mostra toast di conferma per gestation
        CustomSnackBar.showSuccess(
          context,
          'Richiesta eliminazione inviata a ${chat.name}',
        );
      } else {
        // Mostra errore se l'eliminazione fallisce
        CustomSnackBar.showError(
          context,
          'Impossibile eliminare la chat. Verifica i permessi.',
        );
      }

      print('Chat eliminata: ${chat.name} (ID: ${chat.id})');
    } catch (e) {
      print('Errore durante l\'eliminazione della chat: $e');
      // Mostra errore se si verifica un'eccezione
      CustomSnackBar.showError(
        context,
        'Errore durante l\'eliminazione della chat',
      );
    }
  }


  /// Elimina una chat dal backend
  Future<bool> _deleteChatFromBackend(String chatId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final token = await authService.getToken();
      
      print('🔑 Token recuperato per eliminazione chat: ${token != null ? '${token.substring(0, 10)}...' : 'NULL'}');
      
      if (token == null) {
        print('❌ Token di autenticazione non disponibile');
        return false;
      }

      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      };
      
      // CORREZIONE: Usa dati FRESCHI dal backend, non cache locale corrotta
      final freshChats = await RealChatService.getRealChats();
      final chat = freshChats.firstWhere((c) => c.id == chatId);
      final isInGestation = chat.isInGestation;
      
      // Eliminazione chat: gestazione o definitiva
      print('🗑️ Eliminazione ${chat.name}: ${isInGestation ? "DEFINITIVA" : "GESTAZIONE"}');
      
      late http.Response response;
      
      if (isInGestation) {
        // Chat già in gestazione: eliminazione definitiva
        response = await http.delete(
          Uri.parse('$baseUrl/chats/$chatId/'),
          headers: headers,
        );
      } else {
        // Chat normale: richiesta gestazione
        response = await http.post(
          Uri.parse('$baseUrl/chats/$chatId/request-deletion/'),
          headers: headers,
          body: json.encode({}),
        );
      }

      if (response.statusCode == 200) {
        print('✅ Eliminazione completata: $chatId');
        
        // CORREZIONE: Se era richiesta gestazione, forza refresh immediato per tutti
        if (!isInGestation) {
          print('⏳ Richiesta gestazione inviata - forzo refresh globale');
          // Forza refresh della cache per tutti gli utenti
          RealChatService.forceRefresh().then((_) {
            // Forza anche la notifica dei widget
            RealChatService.notifyWidgets();
            print('🔔 Widget notificati del cambiamento');
          });
        }
        
        // CORREZIONE BUG: Forza ricaricamento completo della lista chat
        print('🔄 Eliminazione riuscita - ricarico lista chat...');
        await _refreshChatsWithMessageService();
        
        return true;
      } else if (response.statusCode == 403) {
        print('❌ Accesso negato per eliminare la chat: $chatId');
        print('❌ Dettagli errore: ${response.body}');
        return false;
      } else if (response.statusCode == 404) {
        print('❌ Chat non trovata: $chatId');
        print('❌ Dettagli errore: ${response.body}');
        return false;
      } else {
        print('❌ Errore nell\'eliminazione della chat: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Errore nella chiamata API per eliminare la chat: $e');
      return false;
    }
  }

  void _handleSwipeStateChanged(String chatId) {
    if (mounted) {
      setState(() {
        // Se una chat diversa ha il menu aperto, chiudi quello precedente
        if (_swipedChatId != null && _swipedChatId != chatId) {
          // Chiudi il menu precedente
          _swipedChatId = null;
        } else {
          // Aggiorna lo stato della chat corrente
          _swipedChatId = _swipedChatId == chatId ? null : chatId;
        }
      });
    }
  }

  /// NUOVO: Pull-to-refresh per forzare aggiornamento chat
  Future<void> _onRefresh() async {
    print('🔄 HomeScreen._onRefresh - Inizio pull-to-refresh');
    try {
      // Forza il refresh della cache RealChatService
      final refreshedChats = await RealChatService.forceRefresh();
      print('✅ HomeScreen._onRefresh - Cache aggiornata: ${refreshedChats.length} chat');
      
      // Aggiorna lo stato delle chat
      setState(() {
        _chats = refreshedChats;
        _filteredChats = _chats;
      });
      
      // Aggiorna anche il MessageService per sincronizzare i messaggi
      final messageService = Provider.of<MessageService>(context, listen: false);
      await messageService.initializeRealtimeSync();
      print('✅ HomeScreen._onRefresh - MessageService sincronizzato');
      
    } catch (e) {
      print('❌ HomeScreen._onRefresh - Errore: $e');
      // Mostra un messaggio di errore all'utente
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore durante l\'aggiornamento'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _isSearching = query.isNotEmpty;
      // Reset dello stato di swipe quando si cambia la ricerca
      _swipedChatId = null;
      
      if (query.isEmpty) {
        _filteredChats = _chats;
      } else {
        _filteredChats = _chats.where((chat) {
          return chat.name.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredChats = _chats;
    });
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              // Header verde con status bar (esteso fino in alto)
              _buildHeader(),
              
              // Barra di ricerca
              _buildSearchBar(),
              
              // 🔍 WIDGET DI DEBUG TEMPORANEO (DISABILITATO PER PERFORMANCE)
              // if (kDebugMode) const DebugStatusWidget(),
              
              // Lista chat
              Expanded(
                child: _buildChatList(),
              ),
            ],
          ),
          
          // Widget di chiamata attiva in picture-in-picture
          if (ActiveCallService.isCallActive)
            Positioned(
              top: 100,
              right: 20,
              child: CallPipWidget(
                callType: ActiveCallService.callType ?? 'audio',
                userId: ActiveCallService.userId,
                userIds: ActiveCallService.userIds,
                onExpand: () => ActiveCallService.navigateToFullScreen(context),
                onEnd: () => ActiveCallService.endCall(),
              ),
            ),
        ],
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
          // Header con status bar e titolo sulla stessa riga
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
                // Titolo Chat allineato a sinistra
                const Text(
                  'Chat',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                  // Pulsante aggiungi chat
                  GestureDetector(
                    onTap: _showNewChatDialog,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cerca chat...',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey,
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.grey,
            size: 24,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          color: Colors.black,
        ),
      ),
    );
  }

  Widget _buildChatList() {
    if (_chats.isEmpty) {
      return _buildEmptyState();
    }

    if (_filteredChats.isEmpty && _isSearching) {
      return _buildNoResultsState();
    }

    // NUOVO: RefreshIndicator per pull-to-refresh
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 8),
        itemCount: _filteredChats.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1,
          color: Color(0xFFF0F0F0),
          indent: 78,
        ),
        itemBuilder: (context, index) {
          final chat = _filteredChats[index];
          // NUOVO: Consumer per ascoltare aggiornamenti RealChatService
          return Consumer<RealChatService>(
            builder: (context, realChatService, child) {
              // Ottieni la chat aggiornata dalla cache
              final updatedChat = RealChatService.getChatById(chat.id) ?? chat;
              
              return SwipeableChatItem(
                chat: updatedChat,
                isSwiped: _swipedChatId == chat.id,
                onMoreAction: () => _showChatMoreOptions(context, updatedChat),
                onSwipeStateChanged: () => _handleSwipeStateChanged(chat.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icona chat vuota
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 60,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            
            // Titolo
            const Text(
              'Nessuna chat creata',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Sottotitolo
            const Text(
              'Le chat vengono create solo quando\nesplicitamente richieste tramite "Crea nuova chat"',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.grey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icona ricerca
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off,
                size: 40,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Titolo
            const Text(
              'Nessun risultato',
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
              'Nessuna chat trovata per "${_searchController.text}"',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Pulsante per cancellare ricerca
            TextButton(
              onPressed: _clearSearch,
              child: const Text(
                'Cancella ricerca',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _showNewChatDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Options
            _buildNewChatOption(
              icon: Icons.chat_bubble_outline,
              title: 'Nuova Chat',
              subtitle: 'Inizia una nuova conversazione',
              onTap: () {
                Navigator.pop(context);
                _showAddContactDialog();
              },
            ),
            const SizedBox(height: 16),
            
            _buildNewChatOption(
              icon: Icons.group_add,
              title: 'Chat di Gruppo',
              subtitle: 'Crea un gruppo di chat',
              onTap: () {
                Navigator.pop(context);
                _showCreateGroupDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewChatOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddContactDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Titolo
            const Text(
              'Seleziona Contatto',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            
            // Sottotitolo
            const Text(
              'Scegli un contatto per iniziare una nuova chat',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // Lista contatti
            Expanded(
              child: _buildContactsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactsList() {
    return FutureBuilder<List<UserModel>>(
      future: UserService.getRegisteredUsersExcludingCurrent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
                SizedBox(height: 16),
                Text(
                  'Caricamento contatti...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Errore nel caricamento contatti',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    // Ricarica la lista
                    setState(() {});
                  },
                  child: const Text(
                    'Riprova',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final users = snapshot.data ?? [];
        
        if (users.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Nessun contatto disponibile',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return _buildContactItem(user);
          },
        );
      },
    );
  }

  Widget _buildContactItem(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _createChatWithUser(user),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.cardColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar - MASTER: MasterAvatarService
                MasterAvatarWidget.fromUser(
                  user: user,
                  size: 48,
                ),
                const SizedBox(width: 12),
                
                // Informazioni contatto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome utente
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Email
                      Text(
                        user.email,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Icona freccia
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(UserModel user) {
    print('🏠 HomeScreen._buildInitialsAvatar - User: ${user.name} (ID: ${user.id})');
    return MasterAvatarWidget.fromUser(
      user: user,
      size: 48,
    );
  }


  void _createChatWithUser(UserModel user) async {
    Navigator.pop(context); // Chiudi la modale
    
    try {
      // Crea la nuova chat
      final newChat = await ChatService.createNewChat(
        participantId: user.id,
        name: user.name,
        avatarUrl: user.profileImage,
        isGroup: false,
      );
      
      if (newChat != null) {
        // Aggiorna immediatamente la lista delle chat
        setState(() {
          _chats.insert(0, newChat); // Aggiungi all'inizio della lista
          _filteredChats.insert(0, newChat); // Aggiungi anche alla lista filtrata
          _swipedChatId = null; // Reset dello stato di swipe
        });
        
        // Mostra messaggio di conferma con CustomToast (come nel login)
        CustomToast.showSuccess(context, 'Chat creata con ${user.name}');
        
        // Naviga alla chat dettaglio usando l'ID della chat creata
        context.go('/chat-detail/${newChat.id}');
      } else {
        CustomToast.showError(context, 'Errore nella creazione della chat');
      }
    } catch (e) {
      print('Errore nella creazione della chat: $e');
      CustomToast.showError(context, 'Errore nella creazione della chat');
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Crea gruppo',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Funzionalità in sviluppo',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRScanner() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Scanner QR',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Funzionalità in sviluppo',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}