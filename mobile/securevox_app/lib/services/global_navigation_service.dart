import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Servizio globale per la navigazione che funziona anche fuori dal context
class GlobalNavigationService {
  static final GlobalNavigationService _instance = GlobalNavigationService._internal();
  factory GlobalNavigationService() => _instance;
  GlobalNavigationService._internal();

  static GoRouter? _router;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Inizializza il servizio con il router e navigator key
  static void initialize(GoRouter router, [GlobalKey<NavigatorState>? navigatorKey]) {
    _router = router;
    _navigatorKey = navigatorKey;
    print('🌐 GlobalNavigationService - Inizializzato con GoRouter e NavigatorKey');
  }

  /// Naviga a una rotta specifica usando GoRouter
  static bool push(String route) {
    try {
      // Metodo 1: Usa NavigatorKey se disponibile
      if (_navigatorKey?.currentContext != null) {
        _navigatorKey!.currentContext!.push(route);
        print('✅ GlobalNavigationService - Navigazione NavigatorKey riuscita: $route');
        return true;
      }
      
      // Metodo 2: Usa GoRouter direttamente
      if (_router != null) {
        _router!.push(route);
        print('✅ GlobalNavigationService - Navigazione GoRouter riuscita: $route');
        return true;
      }
      
      print('❌ GlobalNavigationService - Nessun context o router disponibile');
      return false;
      
    } catch (e) {
      print('❌ GlobalNavigationService - Errore navigazione: $e');
      return false;
    }
  }

  /// Naviga a una rotta sostituendo quella corrente
  static bool go(String route) {
    try {
      // Metodo 1: Usa NavigatorKey se disponibile
      if (_navigatorKey?.currentContext != null) {
        _navigatorKey!.currentContext!.go(route);
        print('✅ GlobalNavigationService - Go NavigatorKey riuscita: $route');
        return true;
      }
      
      // Metodo 2: Usa GoRouter direttamente
      if (_router != null) {
        _router!.go(route);
        print('✅ GlobalNavigationService - Go GoRouter riuscita: $route');
        return true;
      }
      
      print('❌ GlobalNavigationService - Nessun context o router disponibile');
      return false;
      
    } catch (e) {
      print('❌ GlobalNavigationService - Errore go: $e');
      return false;
    }
  }
}
