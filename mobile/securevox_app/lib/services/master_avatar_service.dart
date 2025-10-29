import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import 'user_status_service.dart';

/// SERVIZIO MASTER per la gestione degli avatar
/// Questo è l'UNICO servizio che deve essere usato in tutta l'app
/// Garantisce consistenza totale secondo le specifiche:
/// 
/// 1. Ogni utente ha un colore fisso basato sul suo ID (non cambia mai)
/// 2. Se l'utente non ha foto: mostra iniziali Nome+Cognome o prime 2 lettere del nome
/// 3. Se l'utente ha foto: mostra sempre la foto caricata
/// 4. Avatar identici su TUTTE le schermate dell'app
class MasterAvatarService {
  static final MasterAvatarService _instance = MasterAvatarService._internal();
  factory MasterAvatarService() => _instance;
  MasterAvatarService._internal() {
    // CORREZIONE: Inizializza IMMEDIATAMENTE i colori comuni al momento della creazione
    _initializeCommonColors();
  }

  // Cache persistente per i colori degli avatar (basata su ID utente)
  static const String _avatarColorsKey = 'securevox_master_avatar_colors';
  static final Map<String, Color> _userColors = {}; // STATIC per persistenza globale
  
  // Cache persistente per le foto profilo degli utenti
  static const String _profilePhotosKey = 'securevox_master_profile_photos';
  static final Map<String, String> _userProfilePhotos = {}; // STATIC per persistenza globale
  
  // Cache per i widget avatar costruiti (per performance)
  final Map<String, Widget> _avatarWidgetCache = {};
  
  // NUOVO: Cache per le immagini scaricate (per evitare refresh continuo)
  static final Map<String, Uint8List?> _imageCache = {};
  
  // Flag per evitare inizializzazioni multiple
  static bool _isInitialized = false;

  // Colori deterministici per avatar - Palette coerente con SecureVox
  // RIPRISTINO: Ordine originale per mantenere consistenza colori
  static const List<Color> _avatarColors = [
    AppTheme.primaryColor,    // #26A884 - Verde principale
    AppTheme.secondaryColor,  // #0D7557 - Verde scuro
    Color(0xFF4FC3F7),        // Blu chiaro
    Color(0xFF81C784),        // Verde pastello
    Color(0xFFFFB74D),        // Arancione pastello
    Color(0xFFE57373),        // Rosa pastello
    Color(0xFFBA68C8),        // Viola pastello
    Color(0xFF64B5F6),        // Blu pastello
    Color(0xFF4DB6AC),        // Turchese
    Color(0xFFA1C181),        // Verde oliva
    Color(0xFF90A4AE),        // Grigio blu
    Color(0xFFFFD54F),        // Giallo pastello
  ];

  /// NUOVO: Inizializza immediatamente i colori comuni (sincrono)
  void _initializeCommonColors() {
    if (_isInitialized) return;
    
    print('🎨 MasterAvatarService - Inizializzazione IMMEDIATA colori comuni...');
    final commonUserIds = ['1', '2', '3', '4', '5', '9', '10'];
    
    for (final userId in commonUserIds) {
      if (!_userColors.containsKey(userId)) {
        final hash = userId.hashCode;
        final index = hash.abs() % _avatarColors.length;
        final color = _avatarColors[index];
        _userColors[userId] = color;
        print('🎨 MasterAvatarService - Colore IMMEDIATO per utente $userId: $color (hash: $hash, index: $index)');
        
        // CORREZIONE SPECIFICA: Debug per Riccardo (utente 3)
        if (userId == '3') {
          print('🔥 CORREZIONE RICCARDO - User 3 ha colore: $color');
          print('🔥 CORREZIONE RICCARDO - Hash: $hash, Index: $index, Palette size: ${_avatarColors.length}');
        }
      }
    }
    
    _isInitialized = true;
    print('🎨 MasterAvatarService - ✅ Inizializzazione IMMEDIATA completata: ${_userColors.length} colori');
    print('🔥 DEBUG CACHE: ${_userColors.toString()}');
  }

  /// Inizializza il servizio caricando i dati salvati
  Future<void> initialize() async {
    if (!_isInitialized) {
      _initializeCommonColors();
    }
    await _loadSavedData();
    print('🎨 MasterAvatarService - ✅ Inizializzato con ${_userColors.length} colori e ${_userProfilePhotos.length} foto profilo');
  }

  /// Carica i dati salvati dalle SharedPreferences
  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Carica colori salvati
      final savedColors = prefs.getString(_avatarColorsKey);
      if (savedColors != null) {
        final Map<String, dynamic> colorsMap = jsonDecode(savedColors);
        for (final entry in colorsMap.entries) {
          _userColors[entry.key] = Color(entry.value as int);
        }
      }
      
      // Carica foto profilo salvate
      final savedPhotos = prefs.getString(_profilePhotosKey);
      if (savedPhotos != null) {
        final Map<String, dynamic> photosMap = jsonDecode(savedPhotos);
        for (final entry in photosMap.entries) {
          _userProfilePhotos[entry.key] = entry.value.toString();
        }
      }
      
    } catch (e) {
      print('⚠️ MasterAvatarService - Errore caricamento dati: $e');
    }
  }

  /// Salva i dati nelle SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Salva colori
      final colorsToSave = <String, int>{};
      for (final entry in _userColors.entries) {
        colorsToSave[entry.key] = entry.value.value;
      }
      await prefs.setString(_avatarColorsKey, jsonEncode(colorsToSave));
      
      // Salva foto profilo
      await prefs.setString(_profilePhotosKey, jsonEncode(_userProfilePhotos));
      
    } catch (e) {
      print('⚠️ MasterAvatarService - Errore salvataggio dati: $e');
    }
  }

  /// Ottiene il colore FISSO per un utente basato sul suo ID
  /// Il colore non cambia MAI per lo stesso ID utente
  Color _getFixedColorForUser(String userId) {
    // Se già in cache, restituisci il colore salvato
    if (_userColors.containsKey(userId)) {
      print('🎨 MasterAvatarService - Colore trovato in cache per utente $userId: ${_userColors[userId]}');
      return _userColors[userId]!;
    }

    // Genera colore deterministico basato su user ID
    final hash = userId.hashCode;
    final index = hash.abs() % _avatarColors.length;
    final color = _avatarColors[index];

    // Salva in cache IMMEDIATAMENTE
    _userColors[userId] = color;
    
    // Salva in persistenza in background (non bloccare la UI)
    _saveData();

    print('🎨 MasterAvatarService - ✅ NUOVO colore assegnato per utente $userId: $color (index: $index, hash: $hash)');
    return color;
  }

  /// Metodo SINCRONO per ottenere il colore senza attendere il caricamento
  Color getColorForUserSync(String userId) {
    // Assicurati che l'inizializzazione sia avvenuta
    if (!_isInitialized) {
      _initializeCommonColors();
    }
    
    if (_userColors.containsKey(userId)) {
      print('🎨 MasterAvatarService - SYNC: Colore trovato in cache per utente $userId: ${_userColors[userId]}');
      return _userColors[userId]!;
    }
    
    // Genera immediatamente il colore deterministico
    final hash = userId.hashCode;
    final index = hash.abs() % _avatarColors.length;
    final color = _avatarColors[index];
    
    // Salva immediatamente in cache STATICA
    _userColors[userId] = color;
    
    print('🎨 MasterAvatarService - SYNC: Nuovo colore generato per utente $userId: $color (hash: $hash, index: $index)');
    return color;
  }

  /// Genera le iniziali secondo le specifiche:
  /// - Nome e Cognome: prima lettera di entrambi (es. "Mario Rossi" -> "MR")
  /// - Solo Nome: prime due lettere (es. "Mario" -> "MA")
  String _getInitials(String fullName) {
    if (fullName.isEmpty) {
      return 'U';
    }

    final cleanName = fullName.trim();
    final words = cleanName.split(RegExp(r'\s+'));

    if (words.length >= 2) {
      // Nome e Cognome: prendi prima lettera di entrambi
      final firstName = words[0];
      final lastName = words[1];
      
      if (firstName.isNotEmpty && lastName.isNotEmpty) {
        return '${firstName[0]}${lastName[0]}'.toUpperCase();
      }
    }
    
    // Solo Nome: prendi prime due lettere
    if (words.isNotEmpty && words[0].isNotEmpty) {
      final name = words[0];
      if (name.length >= 2) {
        return name.substring(0, 2).toUpperCase();
      } else {
        return name[0].toUpperCase();
      }
    }

    return 'U';
  }

  /// Aggiorna la foto profilo di un utente
  Future<void> updateUserProfilePhoto(String userId, String? photoUrl) async {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      _userProfilePhotos[userId] = photoUrl;
      print('🎨 MasterAvatarService - Aggiornata foto profilo per utente $userId');
    } else {
      _userProfilePhotos.remove(userId);
      print('🎨 MasterAvatarService - Rimossa foto profilo per utente $userId');
    }
    
    // Pulisci cache widget per questo utente
    _clearUserWidgetCache(userId);
    await _saveData();
  }

  /// Pre-carica tutti i dati utenti dal server
  Future<void> preloadAllUserData() async {
    try {
      print('🎨 MasterAvatarService - Pre-caricamento dati utenti...');
      
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8001/api/users/'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> users = json.decode(response.body);
        int preloadedColors = 0;
        int preloadedPhotos = 0;
        
        for (final userData in users) {
          final userId = userData['id'].toString();
          final profileImage = userData['profileImage']?.toString();
          
          // Pre-assegna colore fisso SOLO se non già presente
          if (!_userColors.containsKey(userId)) {
            _getFixedColorForUser(userId);
            preloadedColors++;
            print('🎨 MasterAvatarService - Colore pre-assegnato per utente $userId');
          }
          
          // Salva foto profilo se presente
          if (profileImage != null && profileImage.isNotEmpty) {
            _userProfilePhotos[userId] = profileImage;
            preloadedPhotos++;
          }
        }
        
        await _saveData();
        print('🎨 MasterAvatarService - ✅ Pre-caricamento completato:');
        print('  📊 ${users.length} utenti totali');
        print('  🎨 $preloadedColors nuovi colori assegnati');
        print('  📸 $preloadedPhotos foto profilo caricate');
        print('  💾 ${_userColors.length} colori totali in cache');
      } else {
        print('⚠️ MasterAvatarService - Errore server: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ MasterAvatarService - Errore pre-caricamento: $e');
      // Fallback: pre-carica almeno i colori per gli ID comuni
      _preloadCommonUserColors();
    }
  }

  /// Fallback: pre-carica colori per ID utente comuni
  void _preloadCommonUserColors() {
    print('🎨 MasterAvatarService - Fallback: pre-caricamento colori comuni...');
    final commonUserIds = ['1', '2', '3', '4', '5', '9', '10']; // ID comuni nel sistema
    
    for (final userId in commonUserIds) {
      if (!_userColors.containsKey(userId)) {
        getColorForUserSync(userId); // USA metodo sincrono
        print('🎨 MasterAvatarService - Colore fallback assegnato per utente $userId');
      }
    }
    _saveData();
  }

  /// NUOVO: Pre-caricamento SINCRONO per evitare delay nella UI
  void preloadColorsSync() {
    print('🎨 MasterAvatarService - Pre-caricamento SINCRONO colori...');
    final commonUserIds = ['1', '2', '3', '4', '5', '9', '10'];
    
    for (final userId in commonUserIds) {
      getColorForUserSync(userId);
    }
    
    print('🎨 MasterAvatarService - ✅ Pre-caricamento SINCRONO completato: ${_userColors.length} colori in cache');
  }

  /// METODO PRINCIPALE - Costruisce l'avatar per un utente
  /// Questo è l'UNICO metodo che deve essere usato nell'app
  Widget buildUserAvatar({
    required String userId,
    required String userName,
    String? profileImageUrl,
    double size = 48.0,
    bool showOnlineIndicator = false,
  }) {
    print('🎨 MasterAvatarService.buildUserAvatar - User: $userName (ID: $userId), showOnlineIndicator: $showOnlineIndicator');
    
    final cacheKey = 'user_${userId}_${size}_$showOnlineIndicator';
    
    // ⚡ CORREZIONE CRITICA: DISABILITA completamente la cache per tutti gli avatar
    // Questo garantisce che showOnlineIndicator venga sempre rispettato
    // if (!showOnlineIndicator && _avatarWidgetCache.containsKey(cacheKey)) {
    //   print('🎨 MasterAvatarService.buildUserAvatar - Cache HIT per $userName (static)');
    //   return _avatarWidgetCache[cacheKey]!;
    // }
    print('🎨 MasterAvatarService.buildUserAvatar - SEMPRE RICOSTRUITO (no cache) per $userName');

    Widget avatar;
    
    // Logica secondo le specifiche:
    // 1. Controlla se l'utente ha una foto profilo (da parametro o cache)
    String? effectivePhotoUrl = profileImageUrl;
    if ((effectivePhotoUrl == null || effectivePhotoUrl.isEmpty) && 
        _userProfilePhotos.containsKey(userId)) {
      effectivePhotoUrl = _userProfilePhotos[userId];
    }

    if (effectivePhotoUrl != null && effectivePhotoUrl.isNotEmpty) {
      // 2. Se ha foto: mostra la foto
      avatar = _buildPhotoAvatar(
        photoUrl: effectivePhotoUrl,
        fallbackInitials: _getInitials(userName),
        userId: userId,
        size: size,
      );
    } else {
      // 3. Se non ha foto: mostra iniziali con colore fisso
      avatar = _buildInitialsAvatar(
        initials: _getInitials(userName),
        userId: userId,
        size: size,
      );
    }

    // Aggiungi indicatore online se richiesto
    if (showOnlineIndicator) {
      print('🎨 MasterAvatarService.buildUserAvatar - Creando widget dinamico per $userName (ID: $userId)');
      avatar = _wrapWithOnlineIndicator(avatar, userId, size);
    }

    // ⚡ CORREZIONE: DISABILITA cache completamente per garantire aggiornamenti real-time
    // if (!showOnlineIndicator) {
    //   _avatarWidgetCache[cacheKey] = avatar;
    // }
    print('🎨 MasterAvatarService.buildUserAvatar - Avatar creato per $userName (showOnlineIndicator: $showOnlineIndicator)');
    return avatar;
  }

  /// Costruisce avatar con iniziali e colore fisso
  Widget _buildInitialsAvatar({
    required String initials,
    required String userId,
    required double size,
  }) {
    // USA METODO SINCRONO per evitare delay
    final color = getColorForUserSync(userId);
    print('🎨 MasterAvatarService._buildInitialsAvatar - User $userId: usando colore $color');
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: size * 0.375, // Proporzionale alla dimensione
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Costruisce avatar con foto profilo (OTTIMIZZATO per evitare refresh continuo)
  Widget _buildPhotoAvatar({
    required String photoUrl,
    required String fallbackInitials,
    required String userId,
    required double size,
  }) {
    final fullUrl = photoUrl.startsWith('http') ? photoUrl : 'http://127.0.0.1:8001$photoUrl';
    final color = getColorForUserSync(userId);
    
    print('🎨 MasterAvatarService._buildPhotoAvatar - Building per $userId con URL: $fullUrl');
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipOval(
        child: _CachedImageWidget(
          imageUrl: fullUrl,
          fallbackInitials: fallbackInitials,
          color: color,
          size: size,
          downloadImageBytes: _downloadImageBytes,
        ),
      ),
    );
  }

  /// Scarica i bytes dell'immagine con cache per evitare refresh continuo
  Future<Uint8List?> _downloadImageBytes(String imageUrl) async {
    // CORREZIONE: Controlla prima la cache
    if (_imageCache.containsKey(imageUrl)) {
      print('🎨 MasterAvatarService._downloadImageBytes - Cache HIT per: $imageUrl');
      return _imageCache[imageUrl];
    }
    
    try {
      print('🎨 MasterAvatarService._downloadImageBytes - Scaricando: $imageUrl');
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        // CORREZIONE: Salva in cache per evitare ricaricamenti
        _imageCache[imageUrl] = bytes;
        print('🎨 MasterAvatarService._downloadImageBytes - ✅ Immagine scaricata e cached');
        return bytes;
      } else {
        print('🎨 MasterAvatarService._downloadImageBytes - ❌ Errore HTTP: ${response.statusCode}');
        // Cache anche il fallimento per evitare tentativi ripetuti
        _imageCache[imageUrl] = null;
        return null;
      }
    } catch (e) {
      print('🎨 MasterAvatarService._downloadImageBytes - ❌ Errore: $e');
      // Cache anche il fallimento
      _imageCache[imageUrl] = null;
      return null;
    }
  }

  /// Aggiunge indicatore di stato online (widget dinamico)
  Widget _wrapWithOnlineIndicator(Widget avatar, String userId, double size) {
    return _DynamicStatusIndicator(
      avatar: avatar,
      userId: userId,
      size: size,
    );
  }
  
  /// Pulisce la cache widget per un utente specifico
  void _clearUserWidgetCache(String userId) {
    _avatarWidgetCache.removeWhere((key, value) => key.contains(userId));
  }
  
  /// Pulisce tutte le cache
  void clearAllCache() {
    _avatarWidgetCache.clear();
    _userColors.clear();
    _userProfilePhotos.clear();
    _imageCache.clear(); // NUOVO: Pulisci anche cache immagini
    _isInitialized = false; // Reset flag inizializzazione
    print('🧹 MasterAvatarService - Cache completamente pulita (incluse immagini)');
  }

  /// NUOVO: Forza la reinizializzazione dei colori comuni
  void forceReinitialize() {
    print('🔄 MasterAvatarService - FORZANDO reinizializzazione...');
    _isInitialized = false;
    _initializeCommonColors();
    print('🔄 MasterAvatarService - Reinizializzazione completata');
  }
  
  /// Ottiene il colore assegnato a un utente (per debug)
  Color? getUserColor(String userId) {
    return _userColors[userId];
  }

  /// Ottiene la foto profilo di un utente (per debug)
  String? getUserProfilePhoto(String userId) {
    return _userProfilePhotos[userId];
  }
}

/// Widget ottimizzato per immagini cached che evita refresh continuo
class _CachedImageWidget extends StatefulWidget {
  final String imageUrl;
  final String fallbackInitials;
  final Color color;
  final double size;
  final Future<Uint8List?> Function(String) downloadImageBytes;

  const _CachedImageWidget({
    required this.imageUrl,
    required this.fallbackInitials,
    required this.color,
    required this.size,
    required this.downloadImageBytes,
  });

  @override
  State<_CachedImageWidget> createState() => _CachedImageWidgetState();
}

class _CachedImageWidgetState extends State<_CachedImageWidget> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      print('🎨 _CachedImageWidget._loadImage - Caricando: ${widget.imageUrl}');
      final bytes = await widget.downloadImageBytes(widget.imageUrl);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
          _hasError = bytes == null;
        });
        print('🎨 _CachedImageWidget._loadImage - ✅ Caricamento completato, hasError: $_hasError');
      }
    } catch (e) {
      print('🎨 _CachedImageWidget._loadImage - ❌ Errore: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Durante il caricamento: mostra iniziali
      return Container(
        width: widget.size,
        height: widget.size,
        color: widget.color,
        child: Center(
          child: Text(
            widget.fallbackInitials,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white,
              fontSize: widget.size * 0.375,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    if (!_hasError && _imageBytes != null) {
      // Foto caricata: mostra la foto
      return Image.memory(
        _imageBytes!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    }

    // Errore nel caricamento: mostra iniziali
    return Container(
      width: widget.size,
      height: widget.size,
      color: widget.color,
      child: Center(
        child: Text(
          widget.fallbackInitials,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: widget.size * 0.375,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Widget dinamico per indicatore di stato che si aggiorna in real-time
class _DynamicStatusIndicator extends StatefulWidget {
  final Widget avatar;
  final String userId;
  final double size;

  const _DynamicStatusIndicator({
    required this.avatar,
    required this.userId,
    required this.size,
  });

  @override
  State<_DynamicStatusIndicator> createState() => _DynamicStatusIndicatorState();
}

class _DynamicStatusIndicatorState extends State<_DynamicStatusIndicator> {
  late UserStatusService _statusService;
  UserStatus _currentStatus = UserStatus.offline;
  StreamSubscription? _statusSubscription;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _statusService = UserStatusService();
    
    print('🎨 _DynamicStatusIndicator - INIZIALIZZANDO widget per User ${widget.userId}');
    
    // REAL-TIME: Ascolta sia ChangeNotifier che Stream per massima reattività
    _statusService.addListener(_onStatusChanged);
    print('🎨 _DynamicStatusIndicator - ChangeNotifier listener registrato per User ${widget.userId}');
    
    // REAL-TIME: Stream listener per aggiornamenti immediati
    _statusSubscription = _statusService.statusStream.listen((statusMap) {
      print('🎨 _DynamicStatusIndicator - STREAM UPDATE ricevuto per User ${widget.userId}');
      _updateStatus();
    });
    print('🎨 _DynamicStatusIndicator - Stream listener registrato per User ${widget.userId}');
    
    // CORREZIONE: Forza aggiornamento periodico per sicurezza
    _periodicTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        print('🎨 _DynamicStatusIndicator - Timer periodico per User ${widget.userId}');
        _updateStatus();
      }
    });
    
    // Aggiornamento iniziale
    _updateStatus();
  }

  @override
  void dispose() {
    _statusService.removeListener(_onStatusChanged);
    _statusSubscription?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  void _onStatusChanged() {
    print('🎨 _DynamicStatusIndicator - LISTENER CHIAMATO per User ${widget.userId}');
    _updateStatus();
  }

  void _updateStatus() {
    final newStatus = _statusService.getUserStatus(widget.userId);
    print('🎨 _DynamicStatusIndicator - User ${widget.userId}: Checking status...');
    print('🎨 _DynamicStatusIndicator - Current: ${_statusService.getStatusText(_currentStatus)}, New: ${_statusService.getStatusText(newStatus)}');
    
    // REAL-TIME: Aggiorna sempre, anche se apparentemente uguale
    if (newStatus != _currentStatus || true) { // Forza sempre aggiornamento
      print('🎨 _DynamicStatusIndicator - User ${widget.userId}: AGGIORNANDO UI ${_statusService.getStatusText(_currentStatus)} → ${_statusService.getStatusText(newStatus)}');
      if (mounted) {
        setState(() {
          _currentStatus = newStatus;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusService.getStatusColor(_currentStatus);
    
    return Stack(
      children: [
        widget.avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: widget.size * 0.25,
            height: widget.size * 0.25,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
