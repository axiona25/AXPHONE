import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/keyboard_dismiss_wrapper.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardDismissWrapper(
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          onPressed: () => context.go('/login'),
        ),
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
            _nameFocusNode.unfocus();
            _emailFocusNode.unfocus();
            _passwordFocusNode.unfocus();
            _confirmPasswordFocusNode.unfocus();
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
                    
                    // Titolo con sottolineatura in secondo piano
                    Stack(
                      children: [
                        // Testo con sottolineatura invisibile per calcolare posizione
                        Opacity(
                          opacity: 0,
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Registrati con la tua ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                TextSpan(
                                  text: 'mail',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppTheme.primaryColor,
                                    decorationThickness: 3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Testo in primo piano senza sottolineatura
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Registrati con la tua ',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              TextSpan(
                                text: 'mail',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Sottotitolo
                    Text(
                      'Inizia a chattare con amici e familiari oggi stesso registrandoti a AXPHONE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Campi di input
                    _buildInputField(
                      label: 'Il tuo Nome e Cognome',
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      focusNode: _nameFocusNode,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildInputField(
                      label: 'La tua mail',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      focusNode: _emailFocusNode,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    _buildInputField(
                      label: 'Password',
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
                    
                    const SizedBox(height: 24),
                    
                    _buildInputField(
                      label: 'Conferma Password',
                      controller: _confirmPasswordController,
                      isPassword: true,
                      isPasswordVisible: _isConfirmPasswordVisible,
                      onTogglePassword: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                      focusNode: _confirmPasswordFocusNode,
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Pulsante Registrazione
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Crea Nuovo account',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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

  void _handleRegister() async {
    // Validazione nome
    if (_nameController.text.isEmpty) {
      CustomToast.showError(context, 'Inserisci il tuo nome');
      return;
    }

    if (_nameController.text.length < 2) {
      CustomToast.showError(context, 'Il nome deve essere di almeno 2 caratteri');
      return;
    }

    // Validazione email
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

    // Validazione password
    if (_passwordController.text.isEmpty) {
      CustomToast.showError(context, 'Inserisci una password');
      return;
    }

    if (_passwordController.text.length < 6) {
      CustomToast.showError(context, 'La password deve essere di almeno 6 caratteri');
      return;
    }

    // Validazione conferma password
    if (_confirmPasswordController.text.isEmpty) {
      CustomToast.showError(context, 'Conferma la password');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      CustomToast.showError(context, 'Le password non coincidono');
      return;
    }

    // Mostra toast di caricamento
    CustomToast.showInfo(context, 'Registrazione in corso...');
    
    // Chiama il server per la registrazione
    final authService = Provider.of<AuthService>(context, listen: false);
    final result = await authService.registerUser(
      name: _nameController.text.trim(),
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
      CustomToast.showError(context, result['message']);
    }
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

  void _showLoadingToast() {
    CustomToast.showInfo(context, 'Registrazione in corso...');
  }
}
