import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';
import '../services/connection_service.dart';
import '../services/unified_avatar_service.dart';

class ChatScreen extends StatefulWidget {
  final String? userId;
  
  const ChatScreen({super.key, this.userId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _messageFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messageFocusNode.removeListener(_onFocusChange);
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      // Il focus cambia automaticamente, non serve fare nulla qui
    });
  }

  @override
  Widget build(BuildContext context) {
    // Se non c'è userId, mostra la schermata generica
    if (widget.userId == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: const Text('Chat'),
          actions: [
            IconButton(
              onPressed: () {
                // TODO: Implementare ricerca
              },
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: () {
                // TODO: Implementare menu
              },
              icon: const Icon(Icons.more_vert),
            ),
          ],
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: AppTheme.textTertiary,
              ),
              SizedBox(height: 16),
              Text(
                'Le tue chat appariranno qui',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<UserModel?>(
      future: UserService.getUserById(widget.userId!),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        return Scaffold(
      backgroundColor: Colors.white,
      body: Theme(
        data: Theme.of(context).copyWith(
          // Personalizza il tema della tastiera
          inputDecorationTheme: const InputDecorationTheme(
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: () {
            // Nasconde la tastiera quando si tocca fuori dal campo di testo
            _messageFocusNode.unfocus();
          },
          child: Column(
            children: [
              // Header con gradiente identico a ChatDetailScreen
              _buildHeader(user),
              // Area messaggi vuota
              Expanded(
                child: _buildEmptyChatBody(),
              ),
              // Footer identico a ChatDetailScreen
              _buildInputBar(),
            ],
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
    );
      },
    );
  }

  Widget _buildHeader(UserModel? user) {
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
                      // Avatar con indicatore online
                      Consumer<ConnectionService>(
                        builder: (context, connectionService, child) {
                          return Stack(
                            children: [
                              _buildAvatar(user),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: connectionService.isUserOnline 
                                        ? const Color(ConnectionService.onlineColor)
                                        : const Color(ConnectionService.offlineColor),
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
                        },
                      ),
                      const SizedBox(width: 12),
                      // Nome e stato
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getDisplayName(user?.name ?? 'Utente'),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const Text(
                              'Online ora',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Icone azioni
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionIcon(Icons.phone, () {}),
                    const SizedBox(width: 8),
                    _buildActionIcon(Icons.videocam, () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(UserModel? user) {
    if (user == null) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }
    
    print('💬 ChatScreen._buildAvatar - User: ${user.name} (ID: ${user.id})');
    return UnifiedAvatarService.buildUserAvatar(
      userId: user.id,
      userName: user.name,
      profileImageUrl: user.profileImage,
      size: 40,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      // Se ci sono più nomi, prendi la prima lettera di ognuno (max 2)
      final initials = words.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
      return initials.toUpperCase();
    } else {
      // Se c'è solo un nome, prendi le prime due lettere
      final singleName = words[0];
      return singleName.length >= 2 
          ? singleName.substring(0, 2).toUpperCase()
          : singleName[0].toUpperCase();
    }
  }

  String _getDisplayName(String fullName) {
    final words = fullName.trim().split(' ');
    if (words.length <= 2) {
      return fullName;
    } else {
      return '${words[0]} ${words[1]}';
    }
  }

  Widget _buildActionIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEmptyChatBody() {
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
              'Nessun messaggio ancora',
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
              'Inizia la conversazione inviando\nil tuo primo messaggio',
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

  Widget _buildInputBar() {
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
          // Campo di testo
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
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                keyboardAppearance: Brightness.light,
                textCapitalization: TextCapitalization.sentences,
                autocorrect: true,
                enableSuggestions: true,
                onChanged: (text) {
                  final hasText = text.trim().isNotEmpty;
                  if (_hasText != hasText) {
                    setState(() {
                      _hasText = hasText;
                    });
                  }
                },
                onSubmitted: (text) {
                  if (text.trim().isNotEmpty) {
                    _sendMessage();
                  } else {
                    _messageFocusNode.unfocus();
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Scrivi Messaggio',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
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
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Mostra icona invio se c'è testo, altrimenti foto e microfono
          if (_hasText) ...[
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

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      // TODO: Implementare l'invio del messaggio
      print('Invio messaggio: ${_messageController.text}');
      
      // Pulisci il campo di testo
      _messageController.clear();
      setState(() {
        _hasText = false;
      });
      
      // Nasconde la tastiera dopo l'invio
      _messageFocusNode.unfocus();
    }
  }

  void _showAttachmentMenu() {
    // TODO: Implementare menu allegati
    print('Mostra menu allegati');
  }

  void _showCameraMenu() {
    // TODO: Implementare menu fotocamera
    print('Mostra menu fotocamera');
  }

  void _showAudioRecorder() {
    // TODO: Implementare registratore audio
    print('Mostra registratore audio');
  }

}
