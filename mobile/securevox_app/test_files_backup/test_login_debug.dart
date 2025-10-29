import 'package:flutter/material.dart';
import 'lib/services/auth_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Login Debug',
      home: LoginTestScreen(),
    );
  }
}

class LoginTestScreen extends StatefulWidget {
  @override
  _LoginTestScreenState createState() => _LoginTestScreenState();
}

class _LoginTestScreenState extends State<LoginTestScreen> {
  final AuthService _authService = AuthService();
  String _status = 'Pronto per il test...';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _testLogin();
  }

  Future<void> _testLogin() async {
    setState(() {
      _isLoading = true;
      _status = 'Iniziando test login...';
    });

    try {
      // Test 1: r.amoroso80@gmail.com
      setState(() {
        _status = 'Test 1: r.amoroso80@gmail.com';
      });

      final result1 = await _authService.loginUser(
        email: 'r.amoroso80@gmail.com',
        password: 'password123',
      );

      setState(() {
        _status = 'Test 1 risultato: ${result1['success']} - ${result1['message']}';
      });

      if (result1['success']) {
        await _authService.logout();
        setState(() {
          _status = 'Test 1 completato, effettuato logout';
        });

        // Test 2: r.dicamillo69@gmail.com
        setState(() {
          _status = 'Test 2: r.dicamillo69@gmail.com';
        });

        final result2 = await _authService.loginUser(
          email: 'r.dicamillo69@gmail.com',
          password: 'password123',
        );

        setState(() {
          _status = 'Test 2 risultato: ${result2['success']} - ${result2['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Errore durante il test: $e';
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
        title: Text('Test Login Debug'),
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
                  Icons.check_circle,
                  color: Colors.green,
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
                onPressed: _isLoading ? null : _testLogin,
                child: Text('Riprova Test'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
