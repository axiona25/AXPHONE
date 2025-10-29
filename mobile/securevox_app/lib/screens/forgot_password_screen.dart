import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/custom_snackbar.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;
  bool _isEmailValid = false;
  bool _isCheckingEmail = false;
  String? _userId; // ID utente associato all'email
  String? _emailError; // Errore specifico per email non trovata
  String? _debugToken; // Solo per debug
  Timer? _debounceTimer; // Timer per debounce della verifica email

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _emailController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _validateEmail() {
    final email = _emailController.text.trim();
    
    // Cancella il timer precedente
    _debounceTimer?.cancel();
    
    // Prima verifica il formato
    final hasValidFormat = email.isNotEmpty && 
                          RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
    
    if (!hasValidFormat) {
      setState(() {
        _isEmailValid = false;
        _emailError = null;
        _userId = null;
        _isCheckingEmail = false;
      });
      return;
    }
    
    // Se il formato è valido, avvia il timer per la verifica server (debounce)
    setState(() {
      _isCheckingEmail = true;
      _emailError = null;
    });
    
    _debounceTimer = Timer(const Duration(milliseconds: 800), () async {
      await _verifyEmailOnServer(email);
    });
  }

  Future<void> _verifyEmailOnServer(String email) async {
    try {
      final authService = AuthService();
      final result = await authService.verifyEmailExists(email);
      
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          
          if (result['success'] && result['exists']) {
            _isEmailValid = true;
            _userId = result['user_id'];
            _emailError = null;
            
            // Toast di successo quando email è trovata
            CustomSnackBar.showSuccess(
              context,
              '✅ Email verificata! Utente trovato nel sistema.',
            );
          } else {
            _isEmailValid = false;
            _userId = null;
            _emailError = result['message'] ?? 'Email non trovata nel sistema';
            
            // Toast di errore quando email non è trovata
            CustomSnackBar.showError(
              context,
              '❌ Email non registrata nel sistema. Verifica l\'indirizzo o registrati.',
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingEmail = false;
          _isEmailValid = false;
          _userId = null;
          _emailError = 'Errore durante la verifica email';
        });
        
        // Toast di errore per problemi di connessione
        CustomSnackBar.showError(
          context,
          '🌐 Errore di connessione durante la verifica email. Controlla la connessione.',
        );
      }
    }
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate() || !_isEmailValid || _userId == null) {
      CustomSnackBar.showError(
        context,
        'Verifica che l\'email sia corretta e presente nel sistema',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Toast informativo prima della navigazione
      CustomSnackBar.showPrimary(
        context,
        '🔄 Apertura pagina cambio password...',
      );
      
      // Naviga alla pagina di reset password con email e user ID
      await Future.delayed(const Duration(milliseconds: 500)); // Piccolo delay per UX
      
      if (mounted) {
        context.go('/reset-password', extra: {
          'email': _emailController.text.trim(),
          'userId': _userId,
        });
      }
    } catch (e) {
      CustomSnackBar.showError(
        context,
        '❌ Errore durante l\'apertura della pagina: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Recupera Password',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // Icona
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Titolo
                Text(
                  _emailSent ? 'Controlla la tua email' : 'Recupera la tua password',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Descrizione
                Text(
                  _emailSent 
                    ? 'Ti abbiamo inviato le istruzioni per resettare la password'
                    : 'Inserisci la tua email per ricevere le istruzioni di reset',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: AppTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                if (!_emailSent) ...[
                  // Campo email con verifica server
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Inserisci la tua email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      suffixIcon: _isCheckingEmail 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                ),
                              ),
                            )
                          : _isEmailValid 
                              ? const Icon(Icons.check_circle, color: Colors.green)
                              : _emailError != null
                                  ? const Icon(Icons.error, color: Colors.red)
                                  : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _emailError != null ? Colors.red : AppTheme.primaryColor,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.red,
                          width: 2,
                        ),
                      ),
                      errorText: _emailError,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email obbligatoria';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Email non valida';
                      }
                      if (_emailError != null) {
                        return _emailError;
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Pulsante modifica
                  ElevatedButton(
                    onPressed: (_isLoading || !_isEmailValid) ? null : _requestPasswordReset,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEmailValid ? AppTheme.primaryColor : Colors.grey[300],
                      foregroundColor: _isEmailValid ? Colors.white : Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: _isEmailValid ? 2 : 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Modifica',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ] else ...[
                  // Messaggio di successo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Email inviata con successo!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Controlla la tua casella di posta e segui le istruzioni per resettare la password.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Debug token (solo per sviluppo)
                        if (_debugToken != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DEBUG - Token per test:',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  _debugToken!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Pulsanti
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _emailSent = false;
                              _emailController.clear();
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primaryColor,
                            side: const BorderSide(color: AppTheme.primaryColor),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Invia di nuovo',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Torna al Login',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                
                const Spacer(),
                
                // Link al login
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text(
                    'Torna al Login',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      color: AppTheme.primaryColor,
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
}
