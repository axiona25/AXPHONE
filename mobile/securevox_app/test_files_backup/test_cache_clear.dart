import 'package:flutter/material.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/message_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Cache Clear',
      home: CacheClearTestScreen(),
    );
  }
}

class CacheClearTestScreen extends StatefulWidget {
  @override
  _CacheClearTestScreenState createState() => _CacheClearTestScreenState();
}

class _CacheClearTestScreenState extends State<CacheClearTestScreen> {
  final AuthService _authService = AuthService();
  final MessageService _messageService = MessageService();
  String _status = 'Pronto per il test...';
  bool _isLoading = false;

  Future<void> _clearCacheAndLogin() async {
    setState(() {
      _isLoading = true;
      _status = 'Pulizia cache completa...';
    });

    try {
      // Pulisci cache autenticazione
      setState(() {
        _status = 'Pulizia cache autenticazione...';
      });
      await _authService.clearAllAppCache();

      // Pulisci cache messaggi
      setState(() {
        _status = 'Pulizia cache messaggi...';
      });
      await _messageService.clearAllCache();

      // Forza refresh chat
      setState(() {
        _status = 'Forzando refresh chat...';
      });
      await _messageService.forceRefreshChats();

      // Login
      setState(() {
        _status = 'Tentativo login...';
      });

      final result = await _authService.loginUser(
        email: 'r.amoroso80@gmail.com',
        password: 'raffaele123',
      );

      if (result['success']) {
        setState(() {
          _status = '✅ Login riuscito! Cache pulita e dati aggiornati.';
        });
      } else {
        setState(() {
          _status = '❌ Login fallito: ${result['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Errore: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Cache Clear'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                CircularProgressIndicator()
              else
                Icon(
                  Icons.cleaning_services,
                  color: Colors.blue,
                  size: 64,
                ),
              SizedBox(height: 20),
              Text(
                _status,
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _clearCacheAndLogin,
                child: Text('Pulisci Cache e Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
