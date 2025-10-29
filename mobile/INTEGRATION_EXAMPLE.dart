// 📱 Esempio di integrazione del sistema di distribuzione app

import 'package:flutter/material.dart';
import 'lib/widgets/update_notification_widget.dart';
import 'lib/services/app_distribution_service.dart';

// Esempio 1: Integrare il widget di notifica aggiornamento nella home
class HomeScreenWithUpdates extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SecureVOX'),
        actions: [
          // Badge di aggiornamento nell'app bar
          const UpdateBadge(),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Menu opzioni
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Widget di notifica aggiornamento in cima
          const UpdateNotificationWidget(),
          
          // Resto del contenuto della home
          Expanded(
            child: ListView(
              children: [
                // I tuoi widget esistenti...
                ListTile(
                  title: const Text('Chat'),
                  leading: const Icon(Icons.chat),
                  onTap: () {
                    // Naviga alla chat
                  },
                ),
                ListTile(
                  title: const Text('Chiamate'),
                  leading: const Icon(Icons.call),
                  onTap: () {
                    // Naviga alle chiamate
                  },
                ),
                ListTile(
                  title: const Text('Contatti'),
                  leading: const Icon(Icons.contacts),
                  onTap: () {
                    // Naviga ai contatti
                  },
                ),
                
                // Sezione per aprire la pagina di distribuzione
                const Divider(),
                ListTile(
                  title: const Text('Aggiornamenti App'),
                  subtitle: const Text('Scarica le ultime versioni'),
                  leading: const Icon(Icons.system_update),
                  onTap: () {
                    AppDistributionService.openDistributionPage();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Esempio 2: Pagina dedicata agli aggiornamenti
class UpdatesPage extends StatefulWidget {
  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  AppUpdateInfo? _latestUpdate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUpdates();
  }

  Future<void> _loadUpdates() async {
    try {
      final updateInfo = await AppDistributionService.checkForUpdates();
      if (mounted) {
        setState(() {
          _latestUpdate = updateInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggiornamenti'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadUpdates();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _latestUpdate == null
              ? _buildNoUpdatesView()
              : _buildUpdateAvailableView(),
    );
  }

  Widget _buildNoUpdatesView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          const Text(
            'App Aggiornata',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stai usando l\'ultima versione disponibile',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              AppDistributionService.openDistributionPage();
            },
            child: const Text('Visita Pagina Distribuzione'),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateAvailableView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.system_update,
                        color: Colors.blue,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aggiornamento Disponibile',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_latestUpdate!.name} v${_latestUpdate!.version}',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Informazioni aggiornamento
                  _buildInfoRow('Build', _latestUpdate!.buildNumber),
                  _buildInfoRow('Dimensione', '${_latestUpdate!.fileSizeMb.toStringAsFixed(1)} MB'),
                  if (_latestUpdate!.isBeta)
                    _buildInfoRow('Tipo', 'BETA', isHighlighted: true),
                  
                  const SizedBox(height: 16),
                  
                  // Descrizione
                  if (_latestUpdate!.description.isNotEmpty) ...[
                    const Text(
                      'Descrizione:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_latestUpdate!.description),
                    const SizedBox(height: 16),
                  ],
                  
                  // Note di rilascio
                  if (_latestUpdate!.releaseNotes != null && _latestUpdate!.releaseNotes!.isNotEmpty) ...[
                    const Text(
                      'Note di Rilascio:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(_latestUpdate!.releaseNotes!),
                    const SizedBox(height: 16),
                  ],
                  
                  // Pulsanti azione
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await AppDistributionService.downloadUpdate(_latestUpdate!);
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Download avviato!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          },
                          child: const Text('Aggiorna Ora'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {
                          AppDistributionService.openDistributionPage();
                        },
                        child: const Text('Vedi Online'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Sezione feedback
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lascia un Feedback',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Aiutaci a migliorare l\'app condividendo la tua esperienza',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _showFeedbackDialog();
                    },
                    icon: const Icon(Icons.feedback),
                    label: const Text('Invia Feedback'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          isHighlighted
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Text(value),
        ],
      ),
    );
  }

  void _showFeedbackDialog() {
    int rating = 5;
    String comment = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback App'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Come valuti questa versione dell\'app?'),
              const SizedBox(height: 16),
              
              // Rating stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        rating = index + 1;
                      });
                    },
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 16),
              
              // Comment field
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Commento (opzionale)',
                  hintText: 'Condividi la tua esperienza...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) {
                  comment = value;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final success = await AppDistributionService.sendFeedback(rating, comment);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                          ? 'Grazie per il tuo feedback!' 
                          : 'Errore nell\'invio del feedback'
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Invia'),
          ),
        ],
      ),
    );
  }
}

// Esempio 3: Controllo aggiornamenti all'avvio dell'app
class AppWithUpdateCheck extends StatefulWidget {
  @override
  State<AppWithUpdateCheck> createState() => _AppWithUpdateCheckState();
}

class _AppWithUpdateCheckState extends State<AppWithUpdateCheck> {
  @override
  void initState() {
    super.initState();
    _checkForUpdatesOnStartup();
  }

  Future<void> _checkForUpdatesOnStartup() async {
    // Aspetta che l'app si carichi completamente
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      final updateInfo = await AppDistributionService.checkForUpdates();
      
      if (updateInfo != null && mounted) {
        // Mostra dialog di aggiornamento disponibile
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Aggiornamento Disponibile'),
            content: Text(
              'È disponibile la versione ${updateInfo.version} di ${updateInfo.name}.\n\n'
              'Vuoi aggiornare ora?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Più Tardi'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  AppDistributionService.downloadUpdate(updateInfo);
                },
                child: const Text('Aggiorna'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Ignora errori silenziosamente
      print('Errore controllo aggiornamenti: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureVOX',
      home: HomeScreenWithUpdates(),
    );
  }
}
