import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/message_service.dart';
import 'lib/services/real_chat_service.dart';

/// Test per la sincronizzazione dello stato di lettura dei messaggi
class ReadStatusSyncTest extends StatefulWidget {
  const ReadStatusSyncTest({Key? key}) : super(key: key);

  @override
  State<ReadStatusSyncTest> createState() => _ReadStatusSyncTestState();
}

class _ReadStatusSyncTestState extends State<ReadStatusSyncTest> {
  final MessageService _messageService = MessageService();
  
  String _status = 'Inizializzazione...';
  List<String> _logs = [];
  String _testChatId = 'test_chat_123';
  int _unreadCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  Future<void> _initializeTest() async {
    try {
      setState(() {
        _status = 'Inizializzazione test...';
      });

      // Inizializza il servizio messaggi
      await _messageService.initializeRealtimeSync();
      
      setState(() {
        _status = 'Pronto per test stato di lettura';
      });

      _addLog('✅ Servizio messaggi inizializzato');
      _addLog('📱 Test pronto per verificare stato di lettura');
      
    } catch (e) {
      _addLog('❌ Errore inizializzazione: $e');
      setState(() {
        _status = 'Errore inizializzazione';
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testMessageReceivedWhileViewing() async {
    try {
      setState(() {
        _status = 'Test: Messaggio ricevuto mentre si visualizza la chat...';
      });

      _addLog('🧪 TEST: Messaggio ricevuto mentre si visualizza la chat');
      
      // 1. Simula che l'utente sta visualizzando la chat
      _messageService.markChatAsCurrentlyViewing(_testChatId);
      _addLog('✅ Chat marcata come visualizzata');
      
      // 2. Simula l'arrivo di un messaggio realtime
      _messageService._handleIncomingRealtimeMessage({
        'data': {
          'chat_id': _testChatId,
          'sender_id': 'other_user',
        },
        'body': 'Messaggio ricevuto mentre si visualizza la chat',
      });
      _addLog('📨 Messaggio simulato ricevuto');
      
      // 3. Verifica che il messaggio sia marcato come letto
      await Future.delayed(const Duration(milliseconds: 500));
      final unreadCount = _messageService.getUnreadCount(_testChatId);
      _updateUnreadCount(unreadCount);
      
      if (unreadCount == 0) {
        _addLog('✅ SUCCESSO: Messaggio marcato come letto automaticamente');
        setState(() {
          _status = 'Test completato con successo';
        });
      } else {
        _addLog('❌ FALLIMENTO: Messaggio NON marcato come letto (unread: $unreadCount)');
        setState(() {
          _status = 'Test fallito';
        });
      }
      
    } catch (e) {
      _addLog('❌ Errore durante il test: $e');
      setState(() {
        _status = 'Errore durante il test';
      });
    }
  }

  Future<void> _testMessageReceivedWhileNotViewing() async {
    try {
      setState(() {
        _status = 'Test: Messaggio ricevuto mentre NON si visualizza la chat...';
      });

      _addLog('🧪 TEST: Messaggio ricevuto mentre NON si visualizza la chat');
      
      // 1. Simula che l'utente NON sta visualizzando la chat
      _messageService.markChatAsNotViewing();
      _addLog('✅ Chat marcata come NON visualizzata');
      
      // 2. Simula l'arrivo di un messaggio realtime
      _messageService._handleIncomingRealtimeMessage({
        'data': {
          'chat_id': _testChatId,
          'sender_id': 'other_user',
        },
        'body': 'Messaggio ricevuto mentre NON si visualizza la chat',
      });
      _addLog('📨 Messaggio simulato ricevuto');
      
      // 3. Verifica che il messaggio sia marcato come NON letto
      await Future.delayed(const Duration(milliseconds: 500));
      final unreadCount = _messageService.getUnreadCount(_testChatId);
      _updateUnreadCount(unreadCount);
      
      if (unreadCount > 0) {
        _addLog('✅ SUCCESSO: Messaggio marcato come NON letto correttamente');
        setState(() {
          _status = 'Test completato con successo';
        });
      } else {
        _addLog('❌ FALLIMENTO: Messaggio dovrebbe essere NON letto (unread: $unreadCount)');
        setState(() {
          _status = 'Test fallito';
        });
      }
      
    } catch (e) {
      _addLog('❌ Errore durante il test: $e');
      setState(() {
        _status = 'Errore durante il test';
      });
    }
  }

  Future<void> _testMarkChatAsRead() async {
    try {
      setState(() {
        _status = 'Test: Marcatura chat come letta...';
      });

      _addLog('🧪 TEST: Marcatura chat come letta');
      
      // 1. Assicurati che ci siano messaggi non letti
      _messageService.markChatAsNotViewing();
      _messageService._handleIncomingRealtimeMessage({
        'data': {
          'chat_id': _testChatId,
          'sender_id': 'other_user',
        },
        'body': 'Messaggio da marcare come letto',
      });
      
      await Future.delayed(const Duration(milliseconds: 500));
      final unreadBefore = _messageService.getUnreadCount(_testChatId);
      _addLog('📊 Messaggi non letti prima: $unreadBefore');
      
      // 2. Marca la chat come letta
      _messageService.markChatAsRead(_testChatId);
      _addLog('✅ Chat marcata come letta');
      
      // 3. Verifica che tutti i messaggi siano marcati come letti
      await Future.delayed(const Duration(milliseconds: 500));
      final unreadAfter = _messageService.getUnreadCount(_testChatId);
      _updateUnreadCount(unreadAfter);
      
      if (unreadAfter == 0) {
        _addLog('✅ SUCCESSO: Tutti i messaggi marcati come letti');
        setState(() {
          _status = 'Test completato con successo';
        });
      } else {
        _addLog('❌ FALLIMENTO: Alcuni messaggi non marcati come letti (unread: $unreadAfter)');
        setState(() {
          _status = 'Test fallito';
        });
      }
      
    } catch (e) {
      _addLog('❌ Errore durante il test: $e');
      setState(() {
        _status = 'Errore durante il test';
      });
    }
  }

  void _updateUnreadCount(int count) {
    setState(() {
      _unreadCount = count;
    });
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Stato di Lettura Messaggi'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Text('Chat ID: $_testChatId'),
                    Text('Messaggi non letti: $_unreadCount'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Pulsanti test
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testMessageReceivedWhileViewing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test: Messaggio mentre visualizzi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testMessageReceivedWhileNotViewing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test: Messaggio mentre NON visualizzi'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testMarkChatAsRead,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test: Marca chat come letta'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearLogs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Pulisci Log'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Log
            const Text(
              'Log Test:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
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
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageService.dispose();
    super.dispose();
  }
}

/// Widget principale per il test
class ReadStatusTestApp extends StatelessWidget {
  const ReadStatusTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Stato di Lettura Messaggi',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ReadStatusSyncTest(),
    );
  }
}

/// Funzione principale per eseguire il test
void main() {
  runApp(const ReadStatusTestApp());
}
