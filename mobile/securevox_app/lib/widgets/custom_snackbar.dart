import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_sound_service.dart';

class CustomSnackBar {
  /// Mostra un toast di successo con icona verde
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    // SUONO: Riproduci suono di successo
    AppSoundService().playSuccessSound();
    
    _showSnackBar(
      context,
      message,
      Icons.check_circle,
      Colors.green,
      duration,
    );
  }

  /// Mostra un toast di errore con icona rossa
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    // SUONO: Riproduci suono di errore
    AppSoundService().playErrorSound();
    
    _showSnackBar(
      context,
      message,
      Icons.error,
      Colors.red,
      duration,
    );
  }

  /// Mostra un toast di informazione con icona blu
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    // SUONO: Riproduci suono informativo
    AppSoundService().playInfoSound();
    
    _showSnackBar(
      context,
      message,
      Icons.info,
      Colors.blue,
      duration,
    );
  }

  /// Mostra un toast di avviso con icona arancione
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    // SUONO: Riproduci suono di avviso
    AppSoundService().playWarningSound();
    
    _showSnackBar(
      context,
      message,
      Icons.warning,
      Colors.orange,
      duration,
    );
  }

  /// Mostra un toast personalizzato con colore primario del tema
  static void showPrimary(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    // SUONO: Riproduci suono di notifica
    AppSoundService().playNotificationSound();
    
    _showSnackBar(
      context,
      message,
      Icons.info_outline,
      AppTheme.primaryColor,
      duration,
    );
  }

  /// Mostra un toast di silenziamento
  static void showMuted(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackBar(
      context,
      message,
      Icons.notifications_off,
      Colors.orange,
      duration,
    );
  }

  /// Mostra un toast di archiviazione
  static void showArchived(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackBar(
      context,
      message,
      Icons.archive,
      Colors.blue,
      duration,
    );
  }

  /// Mostra un toast di copia
  static void showCopied(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    _showSnackBar(
      context,
      message,
      Icons.copy,
      Colors.green,
      duration,
    );
  }

  /// Metodo privato per mostrare il toast con lo stile standardizzato
  static void _showSnackBar(
    BuildContext context,
    String message,
    IconData icon,
    Color backgroundColor,
    Duration duration,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Mostra un toast con azione personalizzata
  static void showWithAction(
    BuildContext context,
    String message,
    String actionLabel,
    VoidCallback onActionPressed, {
    IconData icon = Icons.info_outline,
    Color backgroundColor = AppTheme.primaryColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: actionLabel,
          textColor: Colors.white,
          onPressed: onActionPressed,
        ),
      ),
    );
  }
}
