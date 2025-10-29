import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'lib/services/message_service.dart';
import 'lib/services/custom_push_notification_service.dart';
import 'lib/models/message_model.dart';

void main() {
  runApp(RealtimeMessageTestApp());
}

class RealtimeMessageTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Messaggi Realtime',
      home: ChangeNotifierProvider(
        create: (context) => MessageService(),
        child: RealtimeMessageTestScreen(),
      ),
    );
  }
}

class RealtimeMessageTestScreen extends StatefulWidget {
  @override
  _RealtimeMessageTestScreenState createState() => _RealtimeMessageTestScreenState();
}

class _RealtimeMessageTestScreenState extends State<RealtimeMessageTestScreen> {
  final List<String> _logMessages = [];
  MessageService? _messageService;
  CustomPushNotificationService? _pushService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      _addLog('🚀 Inizializzazione servizi...');
      
      // Inizializza il servizio messaggi
      _messageService = Provider.of<MessageService>(context, listen: false);
      await _messageService!.initializeRealtimeSync();
      _addLog('✅ MessageService inizializzato');
      
      // Inizializza il servizio notifiche
      _pushService = CustomPushNotificationService();
      await _pushService!.initialize();
      _addLog('✅ CustomPushNotificationService inizializzato');
      
      // Ascolta i messaggi in arrivo
      _pushService!.messageStream.listen((notification) {
        _addLog('📨 Notifica ricevuta: ${notification['title']}');
        _addLog('📨 Contenuto: ${notification['body']}');
        _addLog('📨 Dati: ${notification['data']}');
      });
      
      _addLog('🎯 Servizi pronti per ricevere messaggi realtime!');
      
    } catch (e) {
      _addLog('❌ Errore inizializzazione: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Messaggi Realtime'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test Sincronizzazione Messaggi Realtime',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Questo test verifica che i messaggi vengano ricevuti in tempo reale.',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _logMessages.length,
              itemBuilder: (context, index) {
                final message = _logMessages[index];
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: message.contains('❌') 
                        ? Colors.red 
                        : message.contains('✅') 
                          ? Colors.green 
                          : message.contains('📨')
                            ? Colors.blue
                            : Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Per testare:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  '1. Apri l\'app principale su un altro dispositivo\n'
                  '2. Invia un messaggio da lì\n'
                  '3. Dovresti vedere il messaggio qui in tempo reale',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pushService?.dispose();
    super.dispose();
  }
}
