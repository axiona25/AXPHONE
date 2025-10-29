// 🔄 Widget per notificare aggiornamenti disponibili

import 'package:flutter/material.dart';
import '../services/app_distribution_service.dart';

class UpdateNotificationWidget extends StatefulWidget {
  const UpdateNotificationWidget({Key? key}) : super(key: key);

  @override
  State<UpdateNotificationWidget> createState() => _UpdateNotificationWidgetState();
}

class _UpdateNotificationWidgetState extends State<UpdateNotificationWidget> {
  AppUpdateInfo? _updateInfo;
  bool _isLoading = false;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    if (_isDismissed) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final updateInfo = await AppDistributionService.checkForUpdates();
      if (mounted) {
        setState(() {
          _updateInfo = updateInfo;
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

  Future<void> _downloadUpdate() async {
    if (_updateInfo == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await AppDistributionService.downloadUpdate(_updateInfo!);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download avviato! Segui le istruzioni per installare.'),
              backgroundColor: Colors.green,
            ),
          );
          _dismissUpdate();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Errore nel download. Riprova più tardi.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _dismissUpdate() {
    setState(() {
      _isDismissed = true;
      _updateInfo = null;
    });
  }

  void _showUpdateDetails() {
    if (_updateInfo == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aggiornamento Disponibile'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_updateInfo!.name} v${_updateInfo!.version}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Build: ${_updateInfo!.buildNumber}'),
              if (_updateInfo!.isBeta)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'BETA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text('Dimensione: ${_updateInfo!.fileSizeMb.toStringAsFixed(1)} MB'),
              const SizedBox(height: 12),
              if (_updateInfo!.description.isNotEmpty) ...[
                const Text(
                  'Descrizione:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(_updateInfo!.description),
                const SizedBox(height: 12),
              ],
              if (_updateInfo!.releaseNotes != null && _updateInfo!.releaseNotes!.isNotEmpty) ...[
                const Text(
                  'Note di Rilascio:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(_updateInfo!.releaseNotes!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : () {
              Navigator.of(context).pop();
              _downloadUpdate();
            },
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Aggiorna'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Non mostrare nulla se non ci sono aggiornamenti o è stato dismisso
    if (_updateInfo == null || _isDismissed) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade400,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _showUpdateDetails,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(
                  Icons.system_update,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aggiornamento Disponibile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_updateInfo!.name} v${_updateInfo!.version}${_updateInfo!.isBeta ? " (BETA)" : ""}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_updateInfo!.fileSizeMb.toStringAsFixed(1)} MB',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      onPressed: _isLoading ? null : _downloadUpdate,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.download,
                              color: Colors.white,
                            ),
                    ),
                    IconButton(
                      onPressed: _dismissUpdate,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Widget per mostrare il badge di aggiornamento nell'app bar
class UpdateBadge extends StatefulWidget {
  const UpdateBadge({Key? key}) : super(key: key);

  @override
  State<UpdateBadge> createState() => _UpdateBadgeState();
}

class _UpdateBadgeState extends State<UpdateBadge> {
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await AppDistributionService.checkForUpdates();
      if (mounted) {
        setState(() {
          _hasUpdate = updateInfo != null;
        });
      }
    } catch (e) {
      // Ignora errori silenziosamente
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasUpdate) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        AppDistributionService.openDistributionPage();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.system_update,
              color: Colors.white,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Aggiorna',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
