import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
// import 'package:file_picker/file_picker.dart';  // Temporaneamente disabilitato
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../theme/app_theme.dart';
import '../services/unified_avatar_service.dart';
import '../services/master_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../widgets/custom_snackbar.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  void _loadCurrentUser() async {
    try {
      // Usa direttamente l'AuthService per ottenere l'utente autenticato
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = await authService.getCurrentUser();
      setState(() {
        _currentUser = user;
      });
    } catch (e) {
      print('Errore nel caricamento utente corrente: $e');
      setState(() {
        _currentUser = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // CORREZIONE: Non sovrascrivere _currentUser se è già aggiornato localmente
        // Aggiorna solo se l'ID è diverso (login/logout) non per aggiornamenti profilo
        if (_currentUser?.id != authService.currentUser?.id && _currentUser?.id == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _currentUser = authService.currentUser;
            });
          });
        }
        
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              // Header verde con status bar (esteso fino in alto)
              _buildHeader(),
              
              // Contenuto principale
              Expanded(
                child: _buildSettingsContent(),
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
                // Titolo Impostazioni allineato a sinistra
                const Text(
                  'Impostazioni',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                
                // Pulsante Logout
                GestureDetector(
                  onTap: _showLogoutDialog,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.logout,
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

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Sezione Profilo Utente
          _buildProfileSection(),
          
          const SizedBox(height: 24),
          
          // Sezione Impostazioni
          _buildSettingsSection(),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar con icona di modifica
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                child: _currentUser != null 
                    ? (() {
                        print('⚙️ SettingsScreen - User: ${_currentUser!.name} (ID: ${_currentUser!.id})');
                        return MasterAvatarWidget.fromUser(
                          user: _currentUser!,
                          size: 60,
                        );
                      })()
                    : Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                        ),
                        child: const Icon(Icons.person, color: Colors.white),
                      ),
              ),
              // Icona di modifica
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickProfileImage,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 16),
          
          // Informazioni utente
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentUser?.name ?? 'Nome Utente',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Never give up 💪',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    if (_currentUser == null) {
      return Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Icon(Icons.person, color: Colors.white),
      );
    }
    
    return MasterAvatarWidget.fromUser(
      user: _currentUser!,
      size: 60,
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      children: [
        _buildSettingItem(
          icon: Icons.key,
          title: 'Account',
          subtitle: 'Privacy, sicurezza, cambio numero',
          onTap: () => _onSettingTap('Account'),
        ),
        
        _buildSettingItem(
          icon: Icons.chat_bubble_outline,
          title: 'Chat',
          subtitle: 'Cronologia chat, tema, sfondi',
          onTap: () => _onSettingTap('Chat'),
        ),
        
        _buildSettingItem(
          icon: Icons.notifications,
          title: 'Notifiche',
          subtitle: 'Messaggi, gruppi e altro',
          onTap: () => _onSettingTap('Notifiche'),
        ),
        
        _buildSettingItem(
          icon: Icons.help_outline,
          title: 'Aiuto',
          subtitle: 'Centro assistenza, contattaci, privacy policy',
          onTap: () => _onSettingTap('Aiuto'),
        ),
        
        _buildSettingItem(
          icon: Icons.storage,
          title: 'Archiviazione e dati',
          subtitle: 'Utilizzo rete, utilizzo archiviazione',
          onTap: () => _onSettingTap('Archiviazione e dati'),
        ),
        
        _buildSettingItem(
          icon: Icons.person_add,
          title: 'Invita un amico',
          subtitle: '',
          onTap: () => _onSettingTap('Invita un amico'),
        ),
        
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
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
                // Icona
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.grey[600],
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Testo
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
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Freccia
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  void _onSettingTap(String setting) {
    // TODO: Implementare navigazione alle varie impostazioni
    CustomSnackBar.showPrimary(
      context,
      'Toccato: $setting',
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Logout',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: const Text(
            'Sei sicuro di voler effettuare il logout?',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _safePopDialog();
              },
              child: const Text(
                'Annulla',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                // Chiudi il dialog in modo sicuro
                _safePopDialog();
                await _performLogout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickProfileImage() async {
    try {
      // Mostra opzioni per scegliere l'immagine
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
              
              // Titolo
              const Text(
                'Modifica Avatar',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              
              // Opzioni in stile moderno (solo Galleria ed Elimina)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModernImageOption(
                    icon: Icons.image,
                    title: 'Galleria',
                    backgroundColor: const Color(0xFF4FC3F7), // Azzurro
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromGallery();
                    },
                  ),
                  // Opzione per eliminare la foto (solo se l'utente ha già una foto)
                  if (_currentUser?.profileImage != null && _currentUser!.profileImage!.isNotEmpty)
                    _buildModernImageOption(
                      icon: Icons.delete_forever,
                      title: 'Elimina foto',
                      backgroundColor: Colors.red[400]!,
                      onTap: () {
                        Navigator.pop(context);
                        _deleteProfileImage();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    } catch (e) {
      CustomSnackBar.showError(
        context,
        'Errore: ${e.toString()}',
      );
    }
  }

  Widget _buildModernImageOption({
    required IconData icon,
    required String title,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Cerchio colorato con icona (stile modale allegati)
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: backgroundColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: backgroundColor,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          // Testo sotto l'icona
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color ?? AppTheme.primaryColor,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      // FilePicker temporaneamente disabilitato
      /*
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = File(result.files.first.path!);
        await _updateProfileImage(file);
      }
      */
    } catch (e) {
      print('Errore selezione immagine dalla galleria: $e');
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Errore nella selezione dell\'immagine: ${e.toString()}',
        );
      }
    }
  }


  Future<void> _updateProfileImage(File imageFile) async {
    if (!mounted) return;
    
    bool dialogShown = false;
    
    try {
      // Mostra indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          },
        );
        dialogShown = true;
      }

      // Verifica che il widget sia ancora montato prima di procedere
      if (!mounted) {
        if (dialogShown) _safePopDialog();
        return;
      }

      // Ridimensiona l'immagine per l'avatar
      Uint8List? resizedImageBytes;
      try {
        resizedImageBytes = await _resizeImageForAvatar(imageFile);
        print('Immagine ridimensionata con successo: ${resizedImageBytes.length} bytes');
      } catch (e) {
        print('Errore nel ridimensionamento: $e');
        // Se il ridimensionamento fallisce, usa l'immagine originale
        resizedImageBytes = await imageFile.readAsBytes();
      }
      
      // Verifica che il widget sia ancora montato
      if (!mounted) {
        if (dialogShown) _safePopDialog();
        return;
      }
      
      // Salva l'immagine ridimensionata localmente per l'upload
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/avatar_${_currentUser?.id ?? 'user'}_$timestamp.jpg');
      await tempFile.writeAsBytes(resizedImageBytes);
      
      // Verifica che il widget sia ancora montato prima di procedere
      if (!mounted) {
        if (dialogShown) _safePopDialog();
        return;
      }
      
      // Carica l'avatar sul server tramite AuthService
      final authService = Provider.of<AuthService>(context, listen: false);
      UserModel updatedUser;
      
      try {
        final uploadResult = await authService.uploadAvatar(tempFile);
        
        if (uploadResult['success'] && uploadResult['user'] != null) {
          // Upload riuscito, usa i dati dal server
          updatedUser = uploadResult['user'] as UserModel;
          print('Upload riuscito: ${uploadResult['message']}');
          print('Avatar URL dal server: ${updatedUser.profileImage}');
        } else {
          // Upload fallito, aggiorna solo localmente
          print('Upload fallito: ${uploadResult['message']}');
          updatedUser = UserModel(
            id: _currentUser!.id,
            name: _currentUser!.name,
            email: _currentUser!.email,
            password: _currentUser!.password,
            createdAt: _currentUser!.createdAt,
            updatedAt: DateTime.now(),
            profileImage: 'file://${tempFile.path}',
          );
        }
      } catch (e) {
        print('Errore durante l\'upload al server: $e');
        // Upload fallito, aggiorna solo localmente
        updatedUser = UserModel(
          id: _currentUser!.id,
          name: _currentUser!.name,
          email: _currentUser!.email,
          password: _currentUser!.password,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
          profileImage: 'file://${tempFile.path}',
        );
      }
        
        // Verifica che il widget sia ancora montato
        if (!mounted) {
          if (dialogShown) _safePopDialog();
          return;
        }
        
        // Aggiorna lo stato locale
        print('Aggiornamento avatar con URL: ${updatedUser.profileImage}');
        setState(() {
          _currentUser = updatedUser;
        });
        print('Avatar aggiornato: ${_currentUser?.profileImage}');
        
        // NUOVO: Aggiorna il servizio master avatar
        await MasterAvatarService().updateUserProfilePhoto(
          _currentUser!.id, 
          _currentUser!.profileImage
        );
        
        // Chiudi il dialog di caricamento solo se è stato mostrato
        print('Dialog mostrato: $dialogShown');
        if (dialogShown) {
          print('Chiudendo il dialog di caricamento...');
          _safePopDialog();
        }
        
        // Mostra messaggio di successo
        final successMessage = updatedUser.profileImage!.startsWith('file://') 
            ? 'Avatar aggiornato localmente (connessione server non disponibile)'
            : 'Avatar aggiornato con successo!';
        
        CustomSnackBar.showSuccess(
          context,
          successMessage,
        );
    } catch (e) {
      print('Errore completo nel caricamento foto: $e');
      
      // Chiudi il dialog di caricamento se è ancora aperto
      print('Errore - Dialog mostrato: $dialogShown, Mounted: $mounted');
      if (mounted && dialogShown) {
        print('Chiudendo il dialog a causa di errore...');
        _safePopDialog();
      }
      
      if (mounted) {
        String errorMessage = 'Errore durante l\'aggiornamento dell\'avatar';
        if (e is TimeoutException) {
          errorMessage = 'Timeout: Il caricamento dell\'avatar ha impiegato troppo tempo';
        } else {
          errorMessage = 'Errore durante l\'aggiornamento dell\'avatar: ${e.toString()}';
        }
        
        CustomSnackBar.showError(
          context,
          errorMessage,
        );
      }
    }
  }

  /// Metodo sicuro per chiudere il dialog
  void _safePopDialog() {
    print('Tentativo di chiudere il dialog...');
    if (mounted) {
      try {
        // Usa context.pop() per go_router invece di Navigator.pop()
        context.pop();
        print('Dialog chiuso con successo');
      } catch (e) {
        print('Errore nel chiudere il dialog con context.pop(): $e');
        try {
          // Fallback al metodo tradizionale
          Navigator.of(context, rootNavigator: true).pop();
          print('Dialog chiuso con fallback Navigator');
        } catch (e2) {
          print('Errore anche con fallback: $e2');
        }
      }
    } else {
      print('Widget non montato, impossibile chiudere il dialog');
    }
  }

  /// Ridimensiona un'immagine per l'uso come avatar
  /// Dimensioni ottimali: 150x150 per avatar, 100x100 per chiamate
  Future<Uint8List> _resizeImageForAvatar(File imageFile) async {
    try {
      // Verifica che il file esista
      if (!await imageFile.exists()) {
        throw Exception('Il file immagine non esiste');
      }

      // Leggi i bytes dell'immagine
      final imageBytes = await imageFile.readAsBytes();
      
      if (imageBytes.isEmpty) {
        throw Exception('Il file immagine è vuoto');
      }
      
      // Decodifica l'immagine
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) {
        throw Exception('Impossibile decodificare l\'immagine');
      }
      
      // Dimensioni target per avatar (quadrato)
      const int targetSize = 150;
      
      // Calcola le dimensioni mantenendo le proporzioni
      int newWidth = targetSize;
      int newHeight = targetSize;
      
      if (originalImage.width > originalImage.height) {
        // Immagine più larga che alta
        newHeight = (targetSize * originalImage.height / originalImage.width).round();
      } else if (originalImage.height > originalImage.width) {
        // Immagine più alta che larga
        newWidth = (targetSize * originalImage.width / originalImage.height).round();
      }
      
      // Ridimensiona l'immagine
      final resizedImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic,
      );
      
      // Ritaglia l'immagine per renderla quadrata (centrata)
      final croppedImage = img.copyCrop(
        resizedImage,
        x: (resizedImage.width - targetSize) ~/ 2,
        y: (resizedImage.height - targetSize) ~/ 2,
        width: targetSize,
        height: targetSize,
      );
      
      // Applica un filtro di qualità per ridurre le dimensioni del file
      final optimizedImage = img.copyResize(
        croppedImage,
        width: targetSize,
        height: targetSize,
        interpolation: img.Interpolation.linear,
      );
      
      // Codifica l'immagine in JPEG con qualità ottimizzata
      final encodedImage = img.encodeJpg(optimizedImage, quality: 85);
      
      return Uint8List.fromList(encodedImage);
    } catch (e) {
      throw Exception('Errore durante il ridimensionamento dell\'immagine: $e');
    }
  }

  Future<void> _performLogout() async {
    if (!mounted) return;
    
    bool dialogShown = false;
    
    try {
      // Mostra un indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          },
        );
        dialogShown = true;
      }

      // Chiudi il dialog di caricamento in modo sicuro
      if (dialogShown) {
        _safePopDialog();
      }

      // Naviga alla schermata di login PRIMA di pulire i dati
      if (mounted) {
        context.go('/login');
      }
      
      // Effettua il logout DOPO la navigazione per evitare il flash dell'utente sconosciuto
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
    } catch (e) {
      print('Errore durante il logout: $e');
      
      // Chiudi il dialog di caricamento se è ancora aperto
      if (mounted && dialogShown) {
        _safePopDialog();
      }

      // Naviga comunque alla schermata di login anche in caso di errore
      if (mounted) {
        context.go('/login');
      }
      
      // Pulisci i dati anche in caso di errore
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
    }
  }

  Future<void> _deleteProfileImage() async {
    if (!mounted) return;
    
    bool dialogShown = false;
    
    try {
      // Mostra indicatore di caricamento
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          },
        );
        dialogShown = true;
      }

      // Verifica che il widget sia ancora montato prima di procedere
      if (!mounted) {
        if (dialogShown) _safePopDialog();
        return;
      }
      
      // Elimina l'avatar tramite AuthService
      final authService = Provider.of<AuthService>(context, listen: false);
      final deleteResult = await authService.deleteAvatar();
      
      // Verifica che il widget sia ancora montato
      if (!mounted) {
        if (dialogShown) _safePopDialog();
        return;
      }
      
      if (deleteResult['success']) {
        // Eliminazione riuscita, aggiorna l'utente locale
        final updatedUser = deleteResult['user'] as UserModel;
        print('Eliminazione avatar riuscita: ${deleteResult['message']}');
        
        // Aggiorna lo stato locale
        setState(() {
          _currentUser = updatedUser;
        });
        
        // NUOVO: Aggiorna il servizio master avatar
        await MasterAvatarService().updateUserProfilePhoto(
          _currentUser!.id, 
          null // Nessuna foto = torna alle iniziali
        );
        
        // Chiudi il dialog di caricamento
        if (dialogShown) {
          _safePopDialog();
        }
        
        // Mostra messaggio di successo
        CustomSnackBar.showSuccess(
          context,
          deleteResult['message'] ?? 'Foto profilo eliminata con successo!',
        );
      } else {
        // Eliminazione fallita
        print('Eliminazione avatar fallita: ${deleteResult['message']}');
        
        // Chiudi il dialog di caricamento
        if (dialogShown) {
          _safePopDialog();
        }
        
        // Mostra messaggio di errore
        CustomSnackBar.showError(
          context,
          deleteResult['message'] ?? 'Errore durante l\'eliminazione della foto',
        );
      }
    } catch (e) {
      print('Errore completo nell\'eliminazione foto: $e');
      
      // Chiudi il dialog di caricamento se è ancora aperto
      if (mounted && dialogShown) {
        _safePopDialog();
      }
      
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Errore durante l\'eliminazione della foto: ${e.toString()}',
        );
      }
    }
  }

}