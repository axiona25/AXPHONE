import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/message_service.dart';
import 'lib/services/real_chat_service.dart';

/// Test per l'aggiornamento della preview dell'ultimo messaggio
class PreviewUpdateTest extends StatefulWidget {
  const PreviewUpdateTest({Key? key}) : super(key: key);

  @override
  State<PreviewUpdateTest> createState() => _PreviewUpdateTestState();
}

class _PreviewUpdateTestState extends State<PreviewUpdateTest> {
  final MessageService _messageService = MessageService();
  
  String _status = 'Inizializzazione...';
  List<String> _logs = [];
  String _testChatId = 'test_chat_preview_123';
  String _currentLastMessage = 'Nessun messaggio';
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
      
      // Aggiungi listener per aggiornamenti
      _messageService.addListener(_onMessageServiceChanged);
      
      setState(() {
        _status = 'Pronto per test preview ultimo messaggio';
      });

      _addLog('✅ Servizio messaggi inizializzato');
      _addLog('📱 Test pronto per verificare aggiornamento preview');
      
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

  void _onMessageServiceChanged() {
    // Aggiorna i dati quando il MessageService cambia
    _updateChatData();
  }

  void _updateChatData() {
    setState(() {
      _currentLastMessage = _messageService.getLastMessage(_testChatId);
      _unreadCount = _messageService.getUnreadCount(_testChatId);
    });
  }

  Future<void> _testPreviewUpdateWhileViewing() async {
    try {
      setState(() {
        _status = 'Test: Preview aggiornata mentre si visualizza la chat...';
      });

      _addLog('🧪 TEST: Preview aggiornata mentre si visualizza la chat');
      
      // 1. Simula che l'utente sta visualizzando la chat
      _messageService.markChatAsCurrentlyViewing(_testChatId);
      _addLog('✅ Chat marcata come visualizzata');
      
      // 2. Simula l'arrivo di un messaggio realtime
      final testMessage = 'Messaggio ricevuto mentre si visualizza: ${DateTime.now().millisecondsSinceEpoch}';
      _messageService._handleIncomingRealtimeMessage({
        'data': {
          'chat_id': _testChatId,
          'sender_id': 'other_user',
        },
        'body': testMessage,
      });
      _addLog('📨 Messaggio simulato ricevuto: "$testMessage"');
      
      // 3. Verifica che la preview sia aggiornata
      await Future.delayed(const Duration(milliseconds: 500));
      _updateChatData();
      
      if (_currentLastMessage == testMessage) {
        _addLog('✅ SUCCESSO: Preview aggiornata correttamente');
        _addLog('📊 Ultimo messaggio: "$_currentLastMessage"');
        _addLog('📊 Messaggi non letti: $_unreadCount');
        setState(() {
          _status = 'Test completato con successo';
        });
      } else {
        _addLog('❌ FALLIMENTO: Preview NON aggiornata');
        _addLog('❌ Atteso: "$testMessage"');
        _addLog('❌ Ottenuto: "$_currentLastMessage"');
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

  Future<void> _testPreviewUpdateWhileNotViewing() async {
    try {
      setState(() {
        _status = 'Test: Preview aggiornata mentre NON si visualizza la chat...';
      });

      _addLog('🧪 TEST: Preview aggiornata mentre NON si visualizza la chat');
      
      // 1. Simula che l'utente NON sta visualizzando la chat
      _messageService.markChatAsNotViewing();
      _addLog('✅ Chat marcata come NON visualizzata');
      
      // 2. Simula l'arrivo di un messaggio realtime
      final testMessage = 'Messaggio ricevuto mentre NON si visualizza: ${DateTime.now().millisecondsSinceEpoch}';
      _messageService._handleIncomingRealtimeMessage({
        'data': {
          'chat_id': _testChatId,
          'sender_id': 'other_user',
        },
        'body': testMessage,
      });
      _addLog('📨 Messaggio simulato ricevuto: "$testMessage"');
      
      // 3. Verifica che la preview sia aggiornata
      await Future.delayed(const Duration(milliseconds: 500));
      _updateChatData();
      
      if (_currentLastMessage == testMessage) {
        _addLog('✅ SUCCESSO: Preview aggiornata correttamente');
        _addLog('📊 Ultimo messaggio: "$_currentLastMessage"');
        _addLog('📊 Messaggi non letti: $_unreadCount (dovrebbe essere > 0)');
        
        if (_unreadCount > 0) {
          _addLog('✅ SUCCESSO: Messaggio marcato come NON letto');
          setState(() {
            _status = 'Test completato con successo';
          });
        } else {
          _addLog('⚠️ ATTENZIONE: Messaggio dovrebbe essere NON letto');
          setState(() {
            _status = 'Test parzialmente riuscito';
          });
        }
      } else {
        _addLog('❌ FALLIMENTO: Preview NON aggiornata');
        _addLog('❌ Atteso: "$testMessage"');
        _addLog('❌ Ottenuto: "$_currentLastMessage"');
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

  Future<void> _testMultipleMessages() async {
    try {
      setState(() {
        _status = 'Test: Più messaggi in sequenza...';
      });

      _addLog('🧪 TEST: Più messaggi in sequenza');
      
      // Invia 3 messaggi in sequenza
      for (int i = 1; i <= 3; i++) {
        final testMessage = 'Messaggio $i: ${DateTime.now().millisecondsSinceEpoch}';
        
        _messageService._handleIncomingRealtimeMessage({
          'data': {
            'chat_id': _testChatId,
            'sender_id': 'other_user',
          },
          'body': testMessage,
        });
        
        _addLog('📨 Messaggio $i inviato: "$testMessage"');
        
        // Attendi un po' tra i messaggi
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      // Verifica che l'ultimo messaggio sia quello corretto
      await Future.delayed(const Duration(milliseconds: 500));
      _updateChatData();
      
      if (_currentLastMessage.contains('Messaggio 3:')) {
        _addLog('✅ SUCCESSO: Preview aggiornata con l\'ultimo messaggio');
        _addLog('📊 Ultimo messaggio: "$_currentLastMessage"');
        _addLog('📊 Messaggi non letti: $_unreadCount');
        setState(() {
          _status = 'Test completato con successo';
        });
      } else {
        _addLog('❌ FALLIMENTO: Preview non aggiornata con l\'ultimo messaggio');
        _addLog('❌ Ottenuto: "$_currentLastMessage"');
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

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Preview Ultimo Messaggio'),
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
                    Text('Ultimo messaggio: $_currentLastMessage'),
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
                    onPressed: _testPreviewUpdateWhileViewing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test: Preview mentre visualizzi'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testPreviewUpdateWhileNotViewing,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test: Preview mentre NON visualizzi'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testMultipleMessages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Test: Più messaggi'),
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
    _messageService.removeListener(_onMessageServiceChanged);
    _messageService.dispose();
    super.dispose();
  }
}

/// Widget principale per il test
class PreviewUpdateTestApp extends StatelessWidget {
  const PreviewUpdateTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Preview Ultimo Messaggio',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PreviewUpdateTest(),
    );
  }
}

/// Funzione principale per eseguire il test
void main() {
  runApp(const PreviewUpdateTestApp());
}
