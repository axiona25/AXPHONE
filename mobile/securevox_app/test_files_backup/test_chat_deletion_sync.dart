import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/services/integrated_realtime_service.dart';
import 'lib/services/real_chat_service.dart';
import 'lib/services/message_service.dart';

/// Test per la sincronizzazione dell'eliminazione chat
class ChatDeletionSyncTest extends StatefulWidget {
  const ChatDeletionSyncTest({Key? key}) : super(key: key);

  @override
  State<ChatDeletionSyncTest> createState() => _ChatDeletionSyncTestState();
}

class _ChatDeletionSyncTestState extends State<ChatDeletionSyncTest> {
  final IntegratedRealtimeService _realtimeService = IntegratedRealtimeService();
  final MessageService _messageService = MessageService();
  
  String _status = 'Inizializzazione...';
  List<String> _logs = [];
  List<String> _chats = [];
  String _selectedChatId = '';
  
  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  Future<void> _initializeTest() async {
    try {
      setState(() {
        _status = 'Inizializzazione servizi...';
      });

      // Inizializza il servizio realtime
      await _realtimeService.initialize();
      
      // Carica le chat esistenti
      await _loadChats();
      
      setState(() {
        _status = 'Pronto per test eliminazione chat';
      });

      _addLog('✅ Servizi inizializzati correttamente');
      _addLog('📱 Servizio realtime attivo');
      
    } catch (e) {
      _addLog('❌ Errore inizializzazione: $e');
      setState(() {
        _status = 'Errore inizializzazione';
      });
    }
  }

  Future<void> _loadChats() async {
    try {
      final chats = await RealChatService.getRealChats();
      setState(() {
        _chats = chats.map((chat) => '${chat.id}: ${chat.name}').toList();
      });
      _addLog('📋 Caricate ${chats.length} chat');
    } catch (e) {
      _addLog('❌ Errore caricamento chat: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  Future<void> _testChatDeletion() async {
    if (_selectedChatId.isEmpty) {
      _addLog('⚠️ Seleziona una chat da eliminare');
      return;
    }

    try {
      setState(() {
        _status = 'Eliminazione chat in corso...';
      });

      _addLog('🗑️ Iniziando eliminazione chat: $_selectedChatId');
      
      // Simula eliminazione chat (chiamata al backend)
      final success = await _deleteChatFromBackend(_selectedChatId);
      
      if (success) {
        _addLog('✅ Chat eliminata con successo dal backend');
        _addLog('🔄 Verificando sincronizzazione realtime...');
        
        // Attendi un po' per vedere se arriva la notifica
        await Future.delayed(const Duration(seconds: 3));
        
        // Verifica che la chat sia stata rimossa dalla cache locale
        final remainingChats = await RealChatService.getRealChats();
        final chatStillExists = remainingChats.any((chat) => chat.id == _selectedChatId);
        
        if (!chatStillExists) {
          _addLog('✅ Chat rimossa correttamente dalla cache locale');
          _addLog('🎉 Sincronizzazione eliminazione chat FUNZIONA!');
          setState(() {
            _status = 'Test completato con successo';
          });
        } else {
          _addLog('⚠️ Chat ancora presente nella cache locale');
          _addLog('❌ Sincronizzazione eliminazione chat NON funziona');
          setState(() {
            _status = 'Test fallito - chat non sincronizzata';
          });
        }
        
        // Ricarica le chat
        await _loadChats();
        
      } else {
        _addLog('❌ Errore nell\'eliminazione chat dal backend');
        setState(() {
          _status = 'Errore eliminazione chat';
        });
      }
      
    } catch (e) {
      _addLog('❌ Errore durante il test: $e');
      setState(() {
        _status = 'Errore durante il test';
      });
    }
  }

  Future<bool> _deleteChatFromBackend(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('securevox_token');
      
      if (token == null) {
        _addLog('❌ Token di autenticazione non trovato');
        return false;
      }

      final response = await _realtimeService.httpClient.delete(
        Uri.parse('${_realtimeService.djangoBaseUrl}/chats/$chatId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
      );

      _addLog('📡 Risposta backend: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final responseData = response.body;
        _addLog('📋 Risposta: $responseData');
        return true;
      } else {
        _addLog('❌ Errore backend: ${response.statusCode} - ${response.body}');
        return false;
      }
      
    } catch (e) {
      _addLog('❌ Errore chiamata backend: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Eliminazione Chat Sincronizzata'),
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
                    Text('Chat caricate: ${_chats.length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Selezione chat
            if (_chats.isNotEmpty) ...[
              const Text(
                'Seleziona Chat da Eliminare:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedChatId.isEmpty ? null : _selectedChatId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Chat',
                ),
                items: _chats.map((chat) {
                  final chatId = chat.split(':')[0];
                  return DropdownMenuItem(
                    value: chatId,
                    child: Text(chat),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedChatId = value ?? '';
                  });
                },
              ),
              const SizedBox(height: 16),
            ],
            
            // Pulsante test
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _chats.isNotEmpty ? _testChatDeletion : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  '🗑️ ELIMINA CHAT E TESTA SINCRONIZZAZIONE',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Pulsante ricarica chat
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadChats,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('🔄 Ricarica Chat'),
              ),
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
    _realtimeService.dispose();
    super.dispose();
  }
}

/// Widget principale per il test
class ChatDeletionTestApp extends StatelessWidget {
  const ChatDeletionTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Eliminazione Chat Sincronizzata',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const ChatDeletionSyncTest(),
    );
  }
}

/// Funzione principale per eseguire il test
void main() {
  runApp(const ChatDeletionTestApp());
}
