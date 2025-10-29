import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/integrated_realtime_service.dart';
import 'lib/services/message_service.dart';
import 'lib/services/real_chat_service.dart';

/// Test per la sincronizzazione realtime tra due utenti
class RealtimeIntegrationTest extends StatefulWidget {
  const RealtimeIntegrationTest({Key? key}) : super(key: key);

  @override
  State<RealtimeIntegrationTest> createState() => _RealtimeIntegrationTestState();
}

class _RealtimeIntegrationTestState extends State<RealtimeIntegrationTest> {
  final IntegratedRealtimeService _realtimeService = IntegratedRealtimeService();
  final MessageService _messageService = MessageService();
  
  String _status = 'Inizializzazione...';
  List<String> _logs = [];
  String _testMessage = '';
  String _chatId = '6a4e5a14-0ec8-4f57-84bd-f48ed9933643'; // Chat di test
  String _recipientId = '2'; // ID destinatario di test

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  Future<void> _initializeTest() async {
    try {
      setState(() {
        _status = 'Configurazione test...';
        _logs.add('🔧 Configurazione test iniziata');
      });

      // Simula login utente 1
      await _simulateUserLogin('1', 'user1@test.com', 'User One');
      
      setState(() {
        _status = 'Inizializzazione servizio realtime...';
        _logs.add('🚀 Inizializzazione servizio realtime');
      });

      // Inizializza il servizio realtime
      await _realtimeService.initialize();
      
      setState(() {
        _status = 'Servizio realtime pronto';
        _logs.add('✅ Servizio realtime inizializzato');
        _logs.add('📱 Token dispositivo: ${_realtimeService.deviceToken}');
        _logs.add('👤 User ID: ${_realtimeService.currentUserId}');
        _logs.add('🔗 Connesso: ${_realtimeService.isConnected}');
      });

    } catch (e) {
      setState(() {
        _status = 'Errore: $e';
        _logs.add('❌ Errore inizializzazione: $e');
      });
    }
  }

  Future<void> _simulateUserLogin(String userId, String email, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('securevox_user_id', userId);
    await prefs.setString('securevox_user_name', name);
    await prefs.setString('securevox_auth_token', 'test_token_$userId');
    await prefs.setString('securevox_is_logged_in', 'true');
    
    _logs.add('👤 Simulato login: $name (ID: $userId)');
  }

  Future<void> _sendTestMessage() async {
    if (_testMessage.isEmpty) {
      _logs.add('⚠️ Inserisci un messaggio di test');
      return;
    }

    try {
      setState(() {
        _status = 'Invio messaggio...';
        _logs.add('📤 Invio messaggio: "$_testMessage"');
      });

      final success = await _realtimeService.sendMessageWithNotification(
        chatId: _chatId,
        recipientId: _recipientId,
        content: _testMessage,
        messageType: 'text',
      );

      if (success) {
        setState(() {
          _status = 'Messaggio inviato con successo';
          _logs.add('✅ Messaggio inviato con successo');
        });
      } else {
        setState(() {
          _status = 'Errore invio messaggio';
          _logs.add('❌ Errore invio messaggio');
        });
      }

    } catch (e) {
      setState(() {
        _status = 'Errore: $e';
        _logs.add('❌ Errore invio: $e');
      });
    }
  }

  Future<void> _testPolling() async {
    try {
      setState(() {
        _status = 'Test polling messaggi...';
        _logs.add('🔍 Test polling messaggi');
      });

      // Simula un controllo manuale dei messaggi
      await _realtimeService._pollForMessages();
      
      setState(() {
        _status = 'Polling completato';
        _logs.add('✅ Polling completato');
      });

    } catch (e) {
      setState(() {
        _status = 'Errore polling: $e';
        _logs.add('❌ Errore polling: $e');
      });
    }
  }

  Future<void> _clearLogs() async {
    setState(() {
      _logs.clear();
      _logs.add('🧹 Logs puliti');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Realtime Integration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status: $_status',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Connesso: ${_realtimeService.isConnected ? "✅" : "❌"}'),
                    Text('Token: ${_realtimeService.deviceToken ?? "N/A"}'),
                    Text('User ID: ${_realtimeService.currentUserId ?? "N/A"}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Test Controls
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Test Controls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Messaggio di test',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => _testMessage = value,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _sendTestMessage,
                            child: const Text('Invia Messaggio'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _testPolling,
                            child: const Text('Test Polling'),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    ElevatedButton(
                      onPressed: _clearLogs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
                      child: const Text('Pulisci Logs'),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Logs
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Logs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Text(
                                _logs[index],
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Funzione di test standalone
Future<void> runRealtimeTest() async {
  print('🧪 Avvio test realtime integration...');
  
  try {
    final service = IntegratedRealtimeService();
    await service.initialize();
    
    print('✅ Servizio inizializzato');
    print('📱 Token: ${service.deviceToken}');
    print('👤 User ID: ${service.currentUserId}');
    print('🔗 Connesso: ${service.isConnected}');
    
    // Test invio messaggio
    final success = await service.sendMessageWithNotification(
      chatId: '6a4e5a14-0ec8-4f57-84bd-f48ed9933643',
      recipientId: '2',
      content: 'Test messaggio da Flutter',
      messageType: 'text',
    );
    
    print('📤 Messaggio inviato: $success');
    
  } catch (e) {
    print('❌ Errore test: $e');
  }
}
