import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/master_avatar_widget.dart';
import '../services/user_status_service.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isLoading = false;
  Map<String, List<UserModel>> _groupedUsers = {};
  List<UserModel> _onlineUsers = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadUsers();
  }

  Future<void> _initializeServices() async {
    // Inizializza il servizio di stato utenti
    await UserStatusService().initialize();
    
    // Aggiungi listener per aggiornamenti stati
    UserStatusService().addListener(() {
      if (mounted) {
        setState(() {
          // Ricarica la UI quando cambiano gli stati
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final groupedUsers = await UserService.getUsersGroupedByAlphabetExcludingCurrent();
      final onlineUsers = await UserService.getOnlineUsersExcludingCurrent();
      
      setState(() {
        _groupedUsers = groupedUsers;
        _onlineUsers = onlineUsers;
        _isLoading = false;
      });
    } catch (e) {
      print('Errore nel caricamento utenti: $e');
      setState(() {
        final users = UserService.getRegisteredUsersExcludingCurrentSync();
        _groupedUsers = _groupUsersByAlphabet(users);
        _onlineUsers = UserService.getOnlineUsersExcludingCurrentSync();
        _isLoading = false;
      });
    }
  }

  Map<String, List<UserModel>> _groupUsersByAlphabet(List<UserModel> users) {
    final grouped = <String, List<UserModel>>{};
    
    for (final user in users) {
      final firstLetter = user.name.isNotEmpty ? user.name[0].toUpperCase() : '#';
      grouped[firstLetter] ??= [];
      grouped[firstLetter]!.add(user);
    }
    
    // Ordina le chiavi alfabeticamente
    final sortedKeys = grouped.keys.toList()..sort();
    final sortedGrouped = <String, List<UserModel>>{};
    
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  void _onSearchChanged(String query) async {
    setState(() {
      _isSearching = query.isNotEmpty;
    });
    
    if (query.isEmpty) {
      final groupedUsers = await UserService.getUsersGroupedByAlphabetExcludingCurrent();
      setState(() {
        _groupedUsers = groupedUsers;
      });
    } else {
      final groupedUsers = await UserService.getUsersGroupedByAlphabetWithSearchExcludingCurrent(query);
      setState(() {
        _groupedUsers = groupedUsers;
      });
    }
  }

  void _clearSearch() async {
    _searchController.clear();
    setState(() {
      _isSearching = false;
    });
    
    final groupedUsers = await UserService.getUsersGroupedByAlphabetExcludingCurrent();
    setState(() {
      _groupedUsers = groupedUsers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserStatusService(),
      builder: (context, child) {
        return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header verde con status bar (esteso fino in alto)
          _buildHeader(),
          
          // Barra di ricerca
          _buildSearchBar(),
          
          // Lista contatti
          Expanded(
            child: _buildContactsList(),
          ),
        ],
      ),
    );
      },
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
                // Titolo Contatti allineato a sinistra
                const Text(
                  'Contatti',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                // Pulsante invita utente
                GestureDetector(
                  onTap: _showInviteUserDialog,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.share,
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
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Cerca contatti...',
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
      ),
    );
  }

  Widget _buildContactsList() {
    if (_groupedUsers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _groupedUsers.length,
      itemBuilder: (context, index) {
        final sortedKeys = _groupedUsers.keys.toList()..sort();
        final letter = sortedKeys[index];
        final users = _groupedUsers[letter]!;
        
        return _buildAlphabetGroup(letter, users);
      },
    );
  }

  Widget _buildAlphabetGroup(String letter, List<UserModel> users) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header della lettera
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            letter,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        
        // Lista utenti per questa lettera
        ...users.map((user) => _buildContactItem(user)).toList(),
        
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildContactItem(UserModel user) {
    final userStatus = UserStatusService().getUserStatus(user.id);
    final statusColor = UserStatusService().getStatusColor(userStatus);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onContactTap(user),
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
                // Avatar senza indicatore (rimosso duplicato)
                _buildAvatar(user),
                const SizedBox(width: 10),
                
                // Informazioni contatto
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome utente in bold
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
                      
                      // Email (senza testo stato)
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
                
                const SizedBox(width: 8),
                
                // Indicatore di stato con colori unificati
                Container(
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserModel user) {
    return MasterAvatarWidget.fromUser(
      user: user,
      size: 48,
      showOnlineIndicator: false, // Rimosso pallino duplicato - c'è già quello a destra
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? 'Nessun contatto trovato' : 'Nessun contatto disponibile',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isSearching 
                ? 'Prova a modificare la ricerca'
                : 'I contatti appariranno qui quando gli utenti si registreranno',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }


  void _onContactTap(UserModel user) {
    // TODO: Implementare navigazione al profilo utente o avvio chat
    CustomSnackBar.showPrimary(
      context,
      'Toccato: ${user.name}',
    );
  }

  void _showInviteUserDialog() {
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
            
            // Icona invito
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.share,
                color: AppTheme.primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            
            // Titolo
            const Text(
              'Invita un nuovo utente',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            
            // Sottotitolo
            const Text(
              'Condividi il link per scaricare SecureVox\ne invitare nuovi utenti',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Link di invito
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'https://securevox.app/download',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _copyInviteLink(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.copy,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Pulsante condividi
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _shareInviteLink(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Condividi Link',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _copyInviteLink() {
    const String inviteLink = 'https://securevox.app/download';
    Clipboard.setData(const ClipboardData(text: inviteLink));
    CustomSnackBar.showCopied(
      context,
      'Link copiato negli appunti!',
    );
  }

  void _shareInviteLink() {
    const String inviteLink = 'https://securevox.app/download';
    const String message = 'Scarica SecureVox per comunicazioni sicure! $inviteLink';
    
    // Per ora mostriamo un messaggio, in futuro si può integrare share_plus
    CustomSnackBar.showWithAction(
      context,
      'Link pronto per la condivisione: $inviteLink',
      'Copia',
      _copyInviteLink,
      icon: Icons.share,
      backgroundColor: AppTheme.primaryColor,
    );
  }
}
