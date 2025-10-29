import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/app_sound_service.dart';

class CustomToast {
  static void showSuccess(BuildContext context, String message) {
    // SUONO: Riproduci suono di successo
    AppSoundService().playSuccessSound();
    
    _showToast(
      context,
      message,
      AppTheme.primaryColor,
      Icons.check_circle,
      Colors.white,
    );
  }

  static void showError(BuildContext context, String message) {
    // SUONO: Riproduci suono di errore
    AppSoundService().playErrorSound();
    
    _showToast(
      context,
      message,
      AppTheme.errorColor,
      Icons.error,
      Colors.white,
    );
  }

  static void showInfo(BuildContext context, String message) {
    // SUONO: Riproduci suono informativo
    AppSoundService().playInfoSound();
    
    _showToast(
      context,
      message,
      AppTheme.primaryColor,
      Icons.info,
      Colors.white,
    );
  }

  static void _showToast(
    BuildContext context,
    String message,
    Color backgroundColor,
    IconData icon,
    Color iconColor,
  ) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => overlayEntry.remove(),
                  child: Icon(
                    Icons.close,
                    color: iconColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto remove after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
