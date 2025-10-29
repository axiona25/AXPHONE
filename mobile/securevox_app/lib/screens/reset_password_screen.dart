import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/custom_snackbar.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String? userId; // ID utente associato all'email
  final String? resetToken; // Token di reset se necessario
  
  const ResetPasswordScreen({
    super.key, 
    required this.email,
    this.userId,
    this.resetToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isFormValid = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validateForm);
    _confirmPasswordController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_validateForm);
    _confirmPasswordController.removeListener(_validateForm);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateForm() {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    
    final isValid = newPassword.isNotEmpty && 
                   confirmPassword.isNotEmpty &&
                   newPassword.length >= 6 &&
                   newPassword == confirmPassword;
    
    if (_isFormValid != isValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      CustomSnackBar.showError(
        context,
        '⚠️ Verifica che le password siano valide e coincidano.',
      );
      return;
    }
    
    if (!_isFormValid) {
      CustomSnackBar.showError(
        context,
        '⚠️ Completa tutti i campi correttamente prima di salvare.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final result = await authService.resetPassword(
        email: widget.email,
        userId: widget.userId,
        newPassword: _newPasswordController.text.trim(),
        resetToken: widget.resetToken,
      );

      if (result['success']) {
        // Toast di successo dettagliato
        CustomSnackBar.showSuccess(
          context,
          '🎉 Password aggiornata con successo! Ora puoi accedere con la nuova password.',
        );
        
        // Mostra un secondo toast informativo
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          CustomSnackBar.showPrimary(
            context,
            '🔐 Reindirizzamento al login in corso...',
          );
        }
        
        // Naviga al login dopo un breve delay
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          context.go('/login');
        }
      } else {
        // Toast di errore dettagliato
        CustomSnackBar.showError(
          context,
          '❌ Impossibile cambiare la password: ${result['message'] ?? 'Errore sconosciuto'}. Riprova.',
        );
      }
    } catch (e) {
      // Toast di errore dettagliato per eccezioni
      CustomSnackBar.showError(
        context,
        '🌐 Errore di connessione durante il cambio password: ${e.toString()}. Verifica la connessione e riprova.',
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
          'Nuova Password',
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
                      shape: BoxShape.circle,
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
                const Text(
                  'Inserisci la tua nuova password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Sottotitolo con email
                Text(
                  'Per l\'account: ${widget.email}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Campo Nuova Password
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: !_isNewPasswordVisible,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Inserisci Nuova Password',
                    hintText: 'Almeno 6 caratteri',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isNewPasswordVisible = !_isNewPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password obbligatoria';
                    }
                    if (value.length < 6) {
                      return 'La password deve essere di almeno 6 caratteri';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Campo Conferma Password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_isConfirmPasswordVisible,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Conferma Nuova Password',
                    hintText: 'Ripeti la password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppTheme.primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Conferma password obbligatoria';
                    }
                    if (value != _newPasswordController.text) {
                      return 'Le password non coincidono';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Pulsante Salva
                ElevatedButton(
                  onPressed: (_isLoading || !_isFormValid) ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFormValid ? AppTheme.primaryColor : Colors.grey[300],
                    foregroundColor: _isFormValid ? Colors.white : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _isFormValid ? 2 : 0,
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
                          'SALVA',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                
                const Spacer(),
                
                // Info sicurezza
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'La tua password verrà aggiornata immediatamente e potrai usarla per il prossimo accesso.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ),
                    ],
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