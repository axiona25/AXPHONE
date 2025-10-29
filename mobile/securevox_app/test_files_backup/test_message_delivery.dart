import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/message_service.dart';
import 'lib/services/realtime_sync_service.dart';
import 'lib/services/auth_service.dart';

/// Test per verificare la consegna dei messaggi
class MessageDeliveryTest extends StatefulWidget {
  const MessageDeliveryTest({Key? key}) : super(key: key);

  @override
  State<MessageDeliveryTest> createState() => _MessageDeliveryTestState();
}

class _MessageDeliveryTestState extends State<MessageDeliveryTest> {
  final MessageService _messageService = MessageService();
  final RealtimeSyncService _realtimeSync = RealtimeSyncService();
  final AuthService _authService = AuthService();
  
  String _status = 'Inizializzazione...';
  List<String> _logs = [];
  String _testChatId = 'test_chat_delivery_123';
  String _testRecipientId = '2';
  String _testMessage = 'Test di consegna messaggi';
  
  @override
  void initState() {
    super.initState();
    _initializeTest();
  }
  
  Future<void> _initializeTest() async {
    try {
      setState(() {
        _status = 'Inizializzazione servizi...';
        _logs.add('🔧 Inizializzazione servizi...');
      });
      
      // Inizializza il RealtimeSyncService
      await _realtimeSync.initialize();
      _logs.add('✅ RealtimeSyncService inizializzato');
      
      // Inizializza il MessageService
      await _messageService.initializeRealtimeSync();
      _logs.add('✅ MessageService inizializzato');
      
      setState(() {
        _status = 'Pronto per il test';
        _logs.add('🎯 Pronto per il test di consegna messaggi');
      });
      
    } catch (e) {
      setState(() {
        _status = 'Errore inizializzazione: $e';
        _logs.add('❌ Errore inizializzazione: $e');
      });
    }
  }
  
  Future<void> _testMessageDelivery() async {
    try {
      setState(() {
        _status = 'Invio messaggio di test...';
        _logs.add('📤 Invio messaggio di test...');
      });
      
      // Invia messaggio di test
      final result = await _messageService.sendMessage(
        chatId: _testChatId,
        text: _testMessage,
        recipientId: _testRecipientId,
      );
      
      if (result['success']) {
        setState(() {
          _status = 'Messaggio inviato con successo!';
          _logs.add('✅ Messaggio inviato con successo!');
          _logs.add('📱 ID messaggio: ${result['message_id']}');
        });
      } else {
        setState(() {
          _status = 'Errore invio messaggio: ${result['message']}';
          _logs.add('❌ Errore invio messaggio: ${result['message']}');
        });
      }
      
    } catch (e) {
      setState(() {
        _status = 'Errore test: $e';
        _logs.add('❌ Errore test: $e');
      });
    }
  }
  
  Future<void> _testDirectNotification() async {
    try {
      setState(() {
        _status = 'Test notifica diretta...';
        _logs.add('📡 Test notifica diretta...');
      });
      
      // Test notifica diretta
      await _realtimeSync.sendPushNotification(
        chatId: _testChatId,
        recipientId: _testRecipientId,
        messageId: 'test_${DateTime.now().millisecondsSinceEpoch}',
        content: _testMessage,
        messageType: 'text',
      );
      
      setState(() {
        _status = 'Notifica diretta inviata!';
        _logs.add('✅ Notifica diretta inviata!');
      });
      
    } catch (e) {
      setState(() {
        _status = 'Errore notifica diretta: $e';
        _logs.add('❌ Errore notifica diretta: $e');
      });
    }
  }
  
  Future<void> _testDeviceRegistration() async {
    try {
      setState(() {
        _status = 'Test registrazione dispositivo...';
        _logs.add('📱 Test registrazione dispositivo...');
      });
      
      // Test registrazione dispositivo
      await _realtimeSync.initialize();
      
      setState(() {
        _status = 'Dispositivo registrato!';
        _logs.add('✅ Dispositivo registrato con successo!');
      });
      
    } catch (e) {
      setState(() {
        _status = 'Errore registrazione dispositivo: $e';
        _logs.add('❌ Errore registrazione dispositivo: $e');
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Consegna Messaggi'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Text(
                _status,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Test buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testDeviceRegistration,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Registrazione'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testDirectNotification,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test Notifica'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            ElevatedButton(
              onPressed: _testMessageDelivery,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Invio Messaggio'),
            ),
            
            const SizedBox(height: 20),
            
            // Logs
            const Text(
              'Log del Test:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 10),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Funzione principale per eseguire il test
void main() {
  runApp(const MaterialApp(
    home: MessageDeliveryTest(),
  ));
}
