import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/logo_service.dart';
import '../models/logo_model.dart';
import '../widgets/custom_toast.dart';
import '../widgets/keyboard_dismiss_wrapper.dart';
import '../services/auth_service.dart';
import '../services/social_auth_service.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isLoggingIn = false; // NUOVO: Stato di login in corso
  Map<String, LogoModel> _logos = {};

  @override
  void initState() {
    super.initState();
    _loadLogos();
    
    // DEBUG: Controlla se i controller vengono pre-popolati
    print('🔐 LoginScreen.initState - Email controller: "${_emailController.text}"');
    print('🔐 LoginScreen.initState - Password controller: "${_passwordController.text}"');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadLogos() async {
    await LogoService.initializeDefaultLogos();
    final logos = await LogoService.getAllLogos();
    setState(() {
      _logos = {
        for (var logo in logos) logo.platform: logo
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissWrapper(
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          // Personalizza il tema della tastiera
          inputDecorationTheme: const InputDecorationTheme(
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: Colors.black,
              height: 1.4,
            ),
          ),
        ),
        child: GestureDetector(
          onTap: () {
            // Nasconde la tastiera quando si tocca fuori dai campi di input
            _emailFocusNode.unfocus();
            _passwordFocusNode.unfocus();
          },
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
              const SizedBox(height: 40),
              
              // Titolo semplice senza sottolineatura
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Accedi a ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    TextSpan(
                      text: 'AX',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    TextSpan(
                      text: 'PHONE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Sottotitolo
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Benvenuto! Accedi utilizzando il tuo account oppure registrati ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => context.go('/register'),
                        child: Text(
                          'cliccando qui',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                            // Rimossa decoration: TextDecoration.underline
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Pulsanti social
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButtonFromDB(
                    platform: 'facebook',
                    color: const Color(0xFF1877F2),
                    onTap: () => _handleSocialLogin('Facebook'),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButtonFromDB(
                    platform: 'google',
                    color: Colors.white,
                    borderColor: Colors.black,
                    onTap: () => _handleSocialLogin('Google'),
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButtonFromDB(
                    platform: 'apple',
                    color: Colors.white,
                    borderColor: Colors.black,
                    onTap: () => _handleSocialLogin('Apple'),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Separatore OR
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OPPURE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
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
              
              const SizedBox(height: 40),
              
              // Campi di input
              _buildInputField(
                label: 'La tua email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                focusNode: _emailFocusNode,
              ),
              
              const SizedBox(height: 24),
              
              _buildInputField(
                label: 'La tua Password',
                controller: _passwordController,
                isPassword: true,
                isPasswordVisible: _isPasswordVisible,
                onTogglePassword: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                focusNode: _passwordFocusNode,
              ),
              
              const SizedBox(height: 40),
              
              // Pulsante Login
              SizedBox(
                width: double.infinity,
                height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoggingIn ? null : _handleLogin, // Disabilita durante login
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      shadowColor: Colors.transparent,
                    ),
                    child: _isLoggingIn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Log in',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Link Recupera Password
              TextButton(
                onPressed: _handleForgotPassword,
                child: Text(
                  'Recupera Password',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Link per registrazione
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Non hai un account? ',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: Text(
                      'Registrati',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSocialButtonFromDB({
    required String platform,
    required Color color,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    final logo = _logos[platform];
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1)
              : null,
        ),
        child: Center(
          child: logo != null
              ? Image.asset(
                  logo.assetPath,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                )
              : Icon(
                  _getFallbackIcon(platform),
                  color: borderColor != null ? Colors.black : Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }

  IconData _getFallbackIcon(String platform) {
    switch (platform) {
      case 'facebook':
        return Icons.facebook;
      case 'google':
        return Icons.g_mobiledata;
      case 'apple':
        return Icons.apple;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    FocusNode? focusNode,
  }) {
    final isEmailField = keyboardType == TextInputType.emailAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: isPassword && !isPasswordVisible,
          keyboardAppearance: Brightness.light,
          textCapitalization: TextCapitalization.none,
          autocorrect: !isEmailField && !isPassword,
          enableSuggestions: !isEmailField && !isPassword,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
          decoration: InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey[600],
                    ),
                    onPressed: onTogglePassword,
                  )
                : null,
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  void _handleSocialLogin(String platform) async {
    try {
      // Mostra toast di caricamento
      CustomToast.showInfo(context, 'Accesso con $platform in corso...');
      
      Map<String, dynamic> result;
      
      switch (platform.toLowerCase()) {
        case 'facebook':
          // Simula token Facebook (in produzione usare Facebook SDK)
          result = await SocialAuthService.loginWithFacebook('test_facebook_token');
          break;
        case 'google':
          // Simula token Google (in produzione usare Google Sign-In)
          result = await SocialAuthService.loginWithGoogle('test_google_token');
          break;
        case 'apple':
          // Simula token Apple (in produzione usare Sign in with Apple)
          result = await SocialAuthService.loginWithApple('test_apple_token');
          break;
        default:
          CustomToast.showError(context, 'Provider non supportato');
          return;
      }
      
      if (result['success']) {
        // Salva i dati dell'utente e il token localmente
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.setCurrentUser(result['user']);
        await authService.setAuthToken(result['token']);
        await authService.setLoggedInStatus(true);
        
        CustomToast.showSuccess(context, result['message']);
        
        // Naviga alla home dopo un breve delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            context.go('/home');
          }
        });
      } else {
        CustomToast.showError(context, result['message']);
      }
    } catch (e) {
      CustomToast.showError(context, 'Errore durante il login social: $e');
    }
  }

  void _handleLogin() async {
    // Evita doppi click durante il login
    if (_isLoggingIn) return;
    
    if (_emailController.text.isEmpty) {
      CustomToast.showError(context, 'Inserisci la tua email');
      return;
    }

    if (!_isValidEmail(_emailController.text)) {
      final email = _emailController.text.trim();
      if (email.contains('..') || email.startsWith('.') || email.endsWith('.')) {
        CustomToast.showError(context, 'Formato email non valido');
      } else if (email.split('@').length > 1) {
        final domain = email.split('@')[1].toLowerCase();
        final disposableDomains = ['10minutemail.com', 'tempmail.org', 'guerrillamail.com', 'mailinator.com'];
        if (disposableDomains.contains(domain)) {
          CustomToast.showError(context, 'Email temporanea non consentita');
        } else {
          CustomToast.showError(context, 'Formato email non valido');
        }
      } else {
        CustomToast.showError(context, 'Formato email non valido');
      }
      return;
    }

    if (_passwordController.text.isEmpty) {
      CustomToast.showError(context, 'Inserisci la tua password');
      return;
    }

    if (_passwordController.text.length < 6) {
      CustomToast.showError(context, 'La password deve essere di almeno 6 caratteri');
      return;
    }
    
    // Imposta stato di login in corso
    setState(() {
      _isLoggingIn = true;
    });
    
    // Mostra toast di caricamento
    CustomToast.showInfo(context, 'Connessione al server...');
    
    try {
      // DEBUG: Controlla cosa viene effettivamente inviato
      print('🔐 LoginScreen._handleLogin - Email da controller: "${_emailController.text.trim()}"');
      print('🔐 LoginScreen._handleLogin - Password da controller: "${_passwordController.text}"');
      
      // Chiama il server per il login
      final authService = Provider.of<AuthService>(context, listen: false);
      final result = await authService.loginUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success']) {
        CustomToast.showSuccess(context, result['message']);
        
        // Naviga alla home dopo un breve delay
        Future.delayed(const Duration(seconds: 1), () {
          context.go('/home');
        });
      } else {
        // Gestione errori più specifica
        String errorMessage = result['message'];
        
        // Messaggi più user-friendly per errori comuni
        if (errorMessage.contains('connessione') || errorMessage.contains('timeout')) {
          errorMessage = 'Problema di connessione. Riprova tra qualche secondo.';
        } else if (errorMessage.contains('server')) {
          errorMessage = 'Server temporaneamente non disponibile. Riprova.';
        }
        
        CustomToast.showError(context, errorMessage);
      }
    } catch (e) {
      // Gestione errori di rete generici
      print('❌ LoginScreen._handleLogin - Errore inatteso: $e');
      CustomToast.showError(context, 'Problema di connessione. Verifica la rete e riprova.');
    } finally {
      // Ripristina stato di login
      if (mounted) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  void _handleForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ForgotPasswordScreen(),
      ),
    );
  }

  bool _isValidEmail(String email) {
    // Validazione formato base
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return false;
    }
    
    // Controlli aggiuntivi per email valide
    if (email.contains('..') || email.startsWith('.') || email.endsWith('.')) {
      return false;
    }
    
    // Controllo domini temporanei comuni
    final disposableDomains = [
      '10minutemail.com', 'tempmail.org', 'guerrillamail.com',
      'mailinator.com', 'yopmail.com', 'temp-mail.org',
      'throwaway.email', 'getnada.com', 'maildrop.cc',
      'sharklasers.com', 'guerrillamail.info', 'pokemail.net',
      'spam4.me', 'bccto.me', 'chacuo.net', 'dispostable.com',
      'mailnesia.com', 'mintemail.com', 'mytrashmail.com',
      'notsharingmy.info', 'spam.la', 'spambox.us',
      'spamcowboy.com', 'spamgourmet.com', 'spamhole.com',
      'trashmail.net', 'trashymail.com', 'trbvm.com',
      'tyldd.com', 'wegwerfadresse.de', 'wegwerfmail.de',
      'wegwerfmail.net', 'wegwerfmail.org', 'wegwerpmailadres.nl'
    ];
    
    final domain = email.split('@')[1].toLowerCase();
    if (disposableDomains.contains(domain)) {
      return false;
    }
    
    return true;
  }
}
