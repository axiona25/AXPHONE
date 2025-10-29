import '../models/call_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/calls_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/chat_detail_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/incoming_call_screen.dart';
import 'screens/call_screen.dart';
import 'screens/audio_call_screen.dart';
import 'screens/video_call_screen.dart';
import 'screens/webrtc_call_screen.dart';
import 'screens/group_audio_call_screen.dart';
import 'screens/group_video_call_screen.dart';
import 'screens/test_call_pages.dart';
import 'services/real_chat_service.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'config/crash_prevention_config.dart';
import 'services/connection_service.dart';
import 'services/message_service.dart';
import 'services/global_navigation_service.dart';
import 'services/user_service.dart';
import 'services/master_avatar_service.dart';
import 'services/user_status_service.dart';
import 'services/realtime_status_service.dart';
import 'services/e2e_manager.dart';
import 'services/call_service.dart';
// import 'services/webrtc_call_service.dart'; // RIMOSSO: File eliminato
import 'services/call_notification_service.dart';
import 'services/call_history_service.dart';
import 'services/notification_service.dart';
import 'services/call_state_manager.dart';
import 'models/user_model.dart';
import 'models/chat_model.dart';
import 'widgets/auth_guard.dart';
import 'widgets/call_notification_handler.dart';
import 'services/global_navigation_service.dart';
import 'services/native_audio_call_service.dart';
import 'services/securevox_call_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🛡️ PREVENZIONE CRASH: Inizializza IMMEDIATAMENTE la prevenzione crash
  try {
    print('🛡️ App avviata - Inizializzazione IMMEDIATA CrashPreventionConfig...');
    await CrashPreventionConfig.instance.initialize();
    print('🛡️ CrashPreventionConfig inizializzato PRIMA di tutto il resto');
  } catch (e) {
    print('⚠️ Errore inizializzazione CrashPreventionConfig: $e');
  }
  
  // CORREZIONE AVATAR: Inizializza IMMEDIATAMENTE il servizio MASTER per gli avatar
  try {
    print('🎨 App avviata - Inizializzazione IMMEDIATA MasterAvatarService...');
    final masterAvatarService = MasterAvatarService();
    await masterAvatarService.initialize();
    print('🎨 MasterAvatarService inizializzato PRIMA di tutto il resto');
  } catch (e) {
    print('⚠️ Errore inizializzazione MasterAvatarService: $e');
  }
  
  // 🔐 CORREZIONE CRITICA: Logout automatico su hot reload/ricompilazione
  print('🔄 App avviata - Controllo stato precedente...');
  await _handleAppRestart();
  
  // 🚀 CORREZIONE NAVIGAZIONE: Inizializza GlobalNavigationService con router e navigatorKey
  print('🌐 Inizializzazione GlobalNavigationService...');
  GlobalNavigationService.initialize(_router, navigatorKey);
  print('✅ GlobalNavigationService inizializzato con router e navigatorKey');
  
  // Inizializza UserStatusService
  try {
    await UserStatusService().initialize();
  } catch (e) {
    print('⚠️ Errore inizializzazione UserStatusService: $e');
  }
  
  // 🔐 Inizializza sistema E2EE (End-to-End Encryption)
  try {
    print('🔐 Inizializzazione sistema E2EE...');
    await E2EManager.initialize();
    
    // Abilita E2EE di default per tutti gli utenti
    if (!E2EManager.isEnabled) {
      print('🔐 Abilitazione E2EE di default...');
      await E2EManager.enable();
    }
    
    print('✅ Sistema E2EE inizializzato e attivo');
  } catch (e) {
    print('⚠️ Errore inizializzazione E2EE: $e');
  }
  
  // NOTA: RealtimeStatusService sarà inizializzato dopo il login in AuthService
  // NOTA: NotificationService (SecureVox Notify) sarà inizializzato dopo il login
  print('📱 SecureVox Notify sarà inizializzato dopo il login');
  
  runApp(const SecureVoxApp());
}

/// 🔐 Gestisce il riavvio dell'app (hot reload, ricompilazione, ecc.)
/// Implementa la logica: ogni riavvio = logout automatico
Future<void> _handleAppRestart() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Controlla se l'app era stata avviata prima
    final wasLoggedIn = prefs.getBool('securevox_is_logged_in') ?? false;
    final lastAppStart = prefs.getInt('securevox_last_app_start') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    
    print('🔄 App restart check:');
    print('  - wasLoggedIn: $wasLoggedIn');
    print('  - lastAppStart: ${DateTime.fromMillisecondsSinceEpoch(lastAppStart)}');
    print('  - currentTime: ${DateTime.fromMillisecondsSinceEpoch(currentTime)}');
    
    // 🚨 REGOLA OBBLIGATORIA: HOT RELOAD/RICOMPILAZIONE = AUTO LOGOUT SEMPRE
    // QUESTA REGOLA È INVIOLABILE E VALE PER TUTTI GLI UTENTI
    if (wasLoggedIn) {
      print('🔐 AUTO LOGOUT OBBLIGATORIO: Hot reload/ricompilazione rilevata');
      print('🚨 REGOLA: Hot reload/ricompilazione = SEMPRE logout automatico');
      
      // Pulisce TUTTO lo stato di autenticazione LOCALE
      await prefs.remove('securevox_current_user');
      await prefs.remove('securevox_is_logged_in');
      await prefs.remove('securevox_auth_token');
      await prefs.remove('securevox_current_user_id');
      await prefs.remove('user_status_cache');
      
      // 🚨 CRITICO: Notifica il server per invalidare token e stato nel DB
      await _notifyServerLogout(prefs);
      
      print('✅ Auto logout completato - utente DEVE rifare login');
      print('📱 REGOLA RISPETTATA: Hot reload/ricompilazione → Pallino grigio');
    } else {
      print('🔄 App riavviata senza utente loggato - nessuna azione necessaria');
    }
    
    // Aggiorna il timestamp dell'ultimo avvio
    await prefs.setInt('securevox_last_app_start', currentTime);
    
  } catch (e) {
    print('❌ Errore durante gestione riavvio app: $e');
  }
}

/// Notifica il server del logout automatico per invalidare token e stato DB
Future<void> _notifyServerLogout(SharedPreferences prefs) async {
  try {
    final token = prefs.getString('securevox_auth_token');
    if (token == null) {
      print('⚠️ Nessun token da invalidare nel server');
      return;
    }
    
    print('🔄 Notifica server logout automatico per invalidare token...');
    print('🔄 Token da invalidare: ${token.substring(0, 10)}...');
    
    // Chiama l'API di logout per invalidare il token sul server
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8001/api/auth/logout/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Token $token',
      },
    ).timeout(const Duration(seconds: 5)); // Più tempo per essere sicuri
    
    if (response.statusCode == 200) {
      print('✅ Server notificato del logout automatico - token invalidato');
      print('✅ Stato utente nel DB aggiornato a offline');
    } else {
      print('⚠️ Server logout risposta: ${response.statusCode} - ${response.body}');
      // Anche se fallisce, continuiamo con il logout locale
    }
  } catch (e) {
    print('⚠️ Errore notifica server logout: $e');
    print('⚠️ Continuando con logout locale (stato DB potrebbe essere inconsistente)');
  }
}

class SecureVoxApp extends StatefulWidget {
  const SecureVoxApp({super.key});

  @override
  State<SecureVoxApp> createState() => _SecureVoxAppState();
}

class _SecureVoxAppState extends State<SecureVoxApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    RealtimeStatusService().dispose();
    UserStatusService().dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        // App torna attiva - ripristina stato online
        RealtimeStatusService().setOnlineOnForeground();
        print('📱 App resumed - Stato online ripristinato');
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App va in background - imposta offline
        RealtimeStatusService().setOfflineOnBackground();
        print('📱 App paused - Stato offline impostato');
        
        // SVILUPPO: Cleanup automatico token E chiamate quando app viene fermata
        if (kDebugMode) {
          _runAutomaticCleanup('App paused/inactive');
          _cleanupActiveCallsOnAppStop('App paused/inactive');
        }
        break;
      case AppLifecycleState.detached:
        // App viene chiusa completamente - auto-logout
        print('📱 App detached - Esecuzione auto-logout...');
        try {
          // Crea un'istanza temporanea di AuthService per il logout
          final authService = AuthService();
          await authService.autoLogout();
        } catch (e) {
          print('⚠️ Errore durante auto-logout in app detached: $e');
        }
        
        // Cleanup servizi
        RealtimeStatusService().dispose();
        UserStatusService().dispose();
        
        // SVILUPPO: Cleanup automatico token E chiamate quando app viene chiusa
        if (kDebugMode) {
          _runAutomaticCleanup('App detached');
          _cleanupActiveCallsOnAppStop('App detached');
        }
        
        print('📱 App detached - Auto-logout e servizi fermati');
        break;
      default:
        break;
    }
  }

  /// Esegue cleanup automatico durante sviluppo
  void _runAutomaticCleanup(String reason) {
    try {
      print('🧹 Auto-cleanup avviato: $reason');
      
      // DISABILITATO: Gli script esterni causano crash su iOS
      // TODO: Implementare cleanup tramite API HTTP invece di script esterni
      print('⚠️ Auto-cleanup disabilitato per evitare crash su iOS');
      
    } catch (e) {
      print('❌ Errore avvio auto-cleanup: $e');
    }
  }

  /// Cleanup chiamate attive quando l'app viene fermata
  void _cleanupActiveCallsOnAppStop(String reason) {
    try {
      print('🧹 Cleanup chiamate attive: $reason');
      
      // DISABILITATO: Gli script esterni causano crash su iOS
      // TODO: Implementare cleanup tramite API HTTP invece di script esterni
      print('⚠️ Cleanup chiamate disabilitato per evitare crash su iOS');
      
    } catch (e) {
      print('❌ Cleanup chiamate errore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ConnectionService()),
        ChangeNotifierProvider(create: (_) => MessageService()),
        ChangeNotifierProvider(create: (_) => RealChatService()),
        ChangeNotifierProvider(create: (context) {
          final callService = CallService();
          final authService = context.read<AuthService>();
          callService.setAuthService(authService);
          return callService;
        }),
        ChangeNotifierProvider(create: (_) {
          final webrtcService = NativeAudioCallService();
          // Non inizializzare automaticamente per evitare crash
          // L'inizializzazione avverrà solo quando necessario
          return webrtcService;
        }),
        ChangeNotifierProvider(create: (_) => CallNotificationService()),
        ChangeNotifierProvider(create: (_) => CallHistoryService()),
        ChangeNotifierProvider(create: (_) => CallStateManager()),
        ChangeNotifierProvider(create: (_) => SecureVOXCallService()),
        Provider(create: (_) => ApiService()),
      ],
      child: MaterialApp.router(
        title: 'SecureVOX',
        theme: AppTheme.darkTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        // Aggiungi navigatorKey per accesso globale
        // navigatorKey: navigatorKey, // Non usato con GoRouter
        builder: (context, child) {
          return CallNotificationHandler(
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}

// Classe per disabilitare le transizioni
class NoTransitionPage extends Page<void> {
  const NoTransitionPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

// Funzione per caricare i dati della chat per il dettaglio
Future<ChatModel?> _loadChatForDetail(String chatId) async {
  try {
    print('🔄 _loadChatForDetail - Caricamento chat: $chatId');
    
    // Prima prova a ottenere dalla cache
    ChatModel? chat = RealChatService.getChatById(chatId);
    print('🔍 _loadChatForDetail - Chat dalla cache: ${chat?.name}');
    
    // Se la cache è vuota o i dati sono incompleti, forza il ricaricamento
    if (chat == null || chat.userId == null || chat.participants.isEmpty) {
      print('⚠️ _loadChatForDetail - Cache incompleta, forzando ricaricamento...');
      await RealChatService.getRealChats(); // Forza il ricaricamento
      chat = RealChatService.getChatById(chatId);
      print('🔍 _loadChatForDetail - Chat dopo ricaricamento: ${chat?.name}');
    }
    
    if (chat != null) {
      print('✅ _loadChatForDetail - Chat trovata: ${chat.name}');
      print('✅ _loadChatForDetail - userId: ${chat.userId}');
      print('✅ _loadChatForDetail - participants: ${chat.participants}');
    } else {
      print('❌ _loadChatForDetail - Chat non trovata');
    }
    
    return chat;
  } catch (e) {
    print('❌ _loadChatForDetail - Errore: $e');
    return null;
  }
}

// Global key per accedere al navigator da ovunque
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Router configuration
final GoRouter _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final email = extra?['email'] ?? '';
        final userId = extra?['userId'];
        final resetToken = extra?['resetToken'];
        return ResetPasswordScreen(
          email: email, 
          userId: userId,
          resetToken: resetToken,
        );
      },
    ),
    // Route per RISPONDERE a una chiamata (COMPLETAMENTE ISOLATA)
    GoRoute(
      path: '/answer-call/:sessionId',
      builder: (context, state) {
        final sessionId = state.pathParameters['sessionId']!;
        final callerId = state.uri.queryParameters['caller_id'] ?? '';
        final callerName = state.uri.queryParameters['caller_name'] ?? 'Utente';
        final callType = state.uri.queryParameters['type'] == 'video' 
            ? CallType.video 
            : CallType.audio;
        
        // CORREZIONE DRASTICA: Schermata completamente isolata con Provider
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NativeAudioCallService()),
              ChangeNotifierProvider(create: (_) => CallHistoryService()),
            ],
            child: CallScreen(
              calleeId: callerId,
              calleeName: callerName,
              callType: callType,
              isIncoming: true,
              sessionId: sessionId,
            ),
          ),
        );
      },
    ),
    // Route per INIZIARE una chiamata (COMPLETAMENTE ISOLATA)
    GoRoute(
      path: '/call/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final name = state.uri.queryParameters['name'] ?? 'Utente';
        final callType = state.uri.queryParameters['type'] == 'video' 
            ? CallType.video 
            : CallType.audio;
        
        // CORREZIONE DRASTICA: Schermata completamente isolata con Provider
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => NativeAudioCallService()),
              ChangeNotifierProvider(create: (_) => CallHistoryService()),
            ],
            child: CallScreen(
              calleeId: userId,
              calleeName: name,
              callType: callType,
              isIncoming: false,
            ),
          ),
        );
      },
    ),
    ShellRoute(
      builder: (context, state, child) {
        return MainNavigationWrapper(child: child);
      },
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const AuthGuard(child: HomeScreen()),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) => const AuthGuard(child: ChatScreen()),
        ),
        GoRoute(
          path: '/calls',
          builder: (context, state) => const AuthGuard(child: CallsScreen()),
        ),
        GoRoute(
          path: '/contacts',
          builder: (context, state) => const AuthGuard(child: ContactsScreen()),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const AuthGuard(child: SettingsScreen()),
        ),
      ],
    ),
    // Route per dettaglio chat (senza footer) - fuori dallo ShellRoute
    GoRoute(
      path: '/chat/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        print('Building chat detail for user ID: $userId');
        
        return AuthGuard(child: ChatScreen(userId: userId));
      },
    ),
    // Route per chat detail con dati mock (senza footer)
    GoRoute(
      path: '/chat-detail/:chatId',
      builder: (context, state) {
        final chatId = state.pathParameters['chatId']!;
        print('Building chat detail for ID: $chatId');
        
        // CORREZIONE: Forza il caricamento dei dati prima di costruire il ChatDetailScreen
        return FutureBuilder<ChatModel?>(
          future: _loadChatForDetail(chatId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AuthGuard(child: Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ));
            }
            
            if (snapshot.hasError) {
              print('Error loading chat: ${snapshot.error}');
              return const AuthGuard(child: HomeScreen());
            }
            
            final chat = snapshot.data;
            if (chat != null) {
              print('Found chat: ${chat.name}');
              return AuthGuard(child: ChatDetailScreen(chat: chat));
            } else {
              print('Chat not found with ID $chatId');
              return const AuthGuard(child: HomeScreen());
            }
          },
        );
      },
    ),
    // Route per chiamata in arrivo
    GoRoute(
      path: '/incoming-call/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        final isVideoCall = state.uri.queryParameters['video'] == 'true';
        return FutureBuilder<UserModel?>(
          future: UserService.getUserById(userId),
          builder: (context, snapshot) {
            final caller = snapshot.data ?? UserModel(
              id: userId,
              name: 'Utente Sconosciuto',
              email: '',
              password: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isActive: true,
            );
            return IncomingCallScreen(
              caller: caller,
              isVideoCall: isVideoCall,
            );
          },
        );
      },
    ),
    // Route per chiamata audio con WebRTC reale - TEMPORANEAMENTE DISABILITATA
    // GoRoute(
    //   path: '/audio-call/:userId',
    //   builder: (context, state) {
    //     final userId = state.pathParameters['userId']!;
    //     final name = state.uri.queryParameters['name'] ?? 'Utente';
    //     final sessionId = state.uri.queryParameters['sessionId'];
    //     
    //     return MaterialApp(
    //       debugShowCheckedModeBanner: false,
    //       home: MultiProvider(
    //         providers: [
    //           ChangeNotifierProvider(create: (_) => SecureVOXCallService()),
    //         ],
    //         child: WebRTCCallScreen(
    //           calleeId: userId,
    //           calleeName: name,
    //           callType: CallType.audio,
    //           sessionId: sessionId,
    //         ),
    //       ),
    //     );
    //   },
    // ),
    
    // Route per chiamata video con WebRTC reale - TEMPORANEAMENTE DISABILITATA
    // GoRoute(
    //   path: '/video-call/:userId',
    //   builder: (context, state) {
    //     final userId = state.pathParameters['userId']!;
    //     final name = state.uri.queryParameters['name'] ?? 'Utente';
    //     final sessionId = state.uri.queryParameters['sessionId'];
    //     
    //     return MaterialApp(
    //       debugShowCheckedModeBanner: false,
    //       home: MultiProvider(
    //         providers: [
    //           ChangeNotifierProvider(create: (_) => SecureVOXCallService()),
    //         ],
    //         child: WebRTCCallScreen(
    //           calleeId: userId,
    //           calleeName: name,
    //           callType: CallType.video,
    //           sessionId: sessionId,
    //         ),
    //       ),
    //     );
    //   },
    // ),
    
    // Route legacy per compatibilità
    GoRoute(
      path: '/legacy-audio-call/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return AuthGuard(child: AudioCallScreen(userId: userId));
      },
    ),
    GoRoute(
      path: '/legacy-video-call/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return AuthGuard(child: VideoCallScreen(userId: userId));
      },
    ),
    // Route per chiamata audio di gruppo
    GoRoute(
      path: '/group-audio-call',
      builder: (context, state) {
        final userIds = state.uri.queryParameters['users']?.split(',') ?? [];
        return AuthGuard(child: GroupAudioCallScreen(userIds: userIds));
      },
    ),
    // Route per chiamata video di gruppo
    GoRoute(
      path: '/group-video-call',
      builder: (context, state) {
        final userIds = state.uri.queryParameters['users']?.split(',') ?? [];
        return AuthGuard(child: GroupVideoCallScreen(userIds: userIds));
      },
    ),
    // Route per test delle pagine di chiamata
    GoRoute(
      path: '/test-call-pages',
      builder: (context, state) => const AuthGuard(child: TestCallPagesScreen()),
    ),
  ],
);

class MainNavigationWrapper extends StatefulWidget {
  final Widget child;
  
  const MainNavigationWrapper({
    super.key,
    required this.child,
  });

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  bool _shouldHideFooter(BuildContext context) {
    // Controlla la route corrente usando GoRouter in modo sicuro
    try {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        final currentLocation = router.routerDelegate.currentConfiguration.uri.path;
        print('🔍 MainNavigationWrapper - Current route: $currentLocation');
        
        // CORREZIONE: Nascondi footer per chat detail E chiamate
        final shouldHide = currentLocation.startsWith('/chat-detail/') ||
               currentLocation.startsWith('/answer-call/') ||
               currentLocation.startsWith('/call/') ||
               currentLocation.startsWith('/audio-call/') ||
               currentLocation.startsWith('/video-call/') ||
               currentLocation.startsWith('/incoming-call/') ||
               currentLocation.startsWith('/group-audio-call') ||
               currentLocation.startsWith('/group-video-call');
        
        print('🔍 MainNavigationWrapper - Should hide footer: $shouldHide');
        return shouldHide;
      }
    } catch (e) {
      print('❌ MainNavigationWrapper - Error getting current route: $e');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Controlla se siamo in una chat detail
    final shouldHideFooter = _shouldHideFooter(context);
    
    print('🔍 MainNavigationWrapper.build - Footer nascosto: $shouldHideFooter');
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: widget.child,
      bottomNavigationBar: shouldHideFooter ? null : Container(
        height: 80, // Altezza fissa per centrare meglio
        decoration: const BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border(
            top: BorderSide(color: AppTheme.surfaceColor, width: 0.5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
            _buildNavItem(1, Icons.phone_outlined, Icons.phone, 'Chiamate'),
            _buildNavItem(2, Icons.people_outlined, Icons.people, 'Contatti'),
            _buildNavItem(3, Icons.settings_outlined, Icons.settings, 'Impostazioni'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/calls');
            break;
          case 2:
            context.go('/contacts');
            break;
          case 3:
            context.go('/settings');
            break;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
