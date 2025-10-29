import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/connection_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ConnectionService()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Debug Test',
      home: AuthDebugScreen(),
    );
  }
}

class AuthDebugScreen extends StatefulWidget {
  @override
  _AuthDebugScreenState createState() => _AuthDebugScreenState();
}

class _AuthDebugScreenState extends State<AuthDebugScreen> {
  String _status = 'Inizializzazione...';
  String _token = '';
  String _userInfo = '';

  @override
  void initState() {
    super.initState();
    _testAuth();
  }

  Future<void> _testAuth() async {
    try {
      setState(() {
        _status = 'Pulizia cache...';
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Pulisci completamente la cache
      await authService.clearAllAppCache();
      
      setState(() {
        _status = 'Tentativo di login...';
      });

      // Prova il login
      final result = await authService.loginUser(
        email: 'r.amoroso80@gmail.com',
        password: 'raffaele123',
      );

      if (result['success']) {
        setState(() {
          _status = 'Login riuscito!';
          _token = (result['token']?.toString().substring(0, 20) ?? 'N/A') + '...';
          _userInfo = 'User: ${result['user']?['email'] ?? 'N/A'}';
        });
      } else {
        setState(() {
          _status = 'Login fallito: ${result['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Errore: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Auth Debug Test'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _status,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Token:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _token,
              style: TextStyle(fontSize: 16, fontFamily: 'monospace'),
            ),
            SizedBox(height: 16),
            Text(
              'User Info:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              _userInfo,
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            Center(
              child: ElevatedButton(
                onPressed: _testAuth,
                child: Text('Riprova Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}