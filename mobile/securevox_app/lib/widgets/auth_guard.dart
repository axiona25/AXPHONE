import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  
  const AuthGuard({
    super.key,
    required this.child,
  });

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final isLoggedIn = await authService.isLoggedIn();
      
      if (mounted) {
        setState(() {
          _isAuthenticated = isLoggedIn;
          _isLoading = false;
        });

        // Se non è autenticato, reindirizza al login
        if (!isLoggedIn) {
          context.go('/login');
        }
      }
    } catch (e) {
      print('Errore durante la verifica dell\'autenticazione: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
        });
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const SizedBox.shrink(); // Sarà reindirizzato al login
    }

    return widget.child;
  }
}
