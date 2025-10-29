import '../models/call_model.dart';
import 'package:flutter/material.dart';
import '../services/native_audio_call_service.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/call_history_service.dart';
// import '../services/webrtc_call_service.dart'; // RIMOSSO: File eliminato
import '../theme/app_theme.dart';
import '../services/unified_avatar_service.dart';
import '../widgets/master_avatar_widget.dart';
import 'call_screen.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  late TabController _tabController;
  List<CallModel> _filteredCalls = [];
  int _selectedTabIndex = 0; // Traccia quale badge è attivo

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _selectedTabIndex) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
    
    // Carica lo storico delle chiamate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callHistoryService = Provider.of<CallHistoryService>(context, listen: false);
      callHistoryService.loadCallHistory(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // CORREZIONE: Aggiorna automaticamente quando si torna alla schermata delle chiamate
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final callHistoryService = Provider.of<CallHistoryService>(context, listen: false);
        callHistoryService.clearCache(); // Pulisce la cache
        callHistoryService.loadCallHistory(forceRefresh: true); // Forza il refresh
      }
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _isSearching = query.isNotEmpty;
    });
    
    if (query.isNotEmpty) {
      final callHistoryService = Provider.of<CallHistoryService>(context, listen: false);
      _filteredCalls = callHistoryService.searchCalls(query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _filteredCalls.clear();
    });
  }

  Future<void> _refreshCalls() async {
    final callHistoryService = Provider.of<CallHistoryService>(context, listen: false);
    await callHistoryService.loadCallHistory(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallHistoryService>(
      builder: (context, callHistoryService, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              if (!_isSearching) _buildTabBar(),
              Expanded(
                child: _isSearching
                    ? _buildSearchResults()
                    : _buildTabContent(callHistoryService),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabBadge('Tutte', 0),
          _buildTabBadge('Effettuate', 1),
          _buildTabBadge('Ricevute', 2),
          _buildTabBadge('Perse', 3),
        ],
      ),
    );
  }

  Widget _buildTabBadge(String text, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        print('🏷️ Badge tappato: $text (index: $index)');
        setState(() {
          _selectedTabIndex = index;
        });
        _tabController.animateTo(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(CallHistoryService callHistoryService) {
    if (callHistoryService.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (callHistoryService.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Errore nel caricamento',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              callHistoryService.error!,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshCalls,
              child: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildCallsList(callHistoryService.allCalls, 'Nessuna chiamata'),
        _buildCallsList(callHistoryService.outgoingCalls, 'Nessuna chiamata effettuata'),
        _buildCallsList(callHistoryService.incomingCalls, 'Nessuna chiamata ricevuta'),
        _buildCallsList(callHistoryService.missedCalls, 'Nessuna chiamata persa'),
      ],
    );
  }

  Widget _buildSearchResults() {
    return _buildCallsList(_filteredCalls, 'Nessun risultato trovato');
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header con status bar e titolo sulla stessa riga
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: 20,
              right: 20,
              bottom: 16,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Titolo Chiamate
                const Text(
                  'Chiamate',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cerca chiamate...',
          hintStyle: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.grey,
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Colors.grey,
            size: 24,
          ),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                  ),
                  onPressed: _clearSearch,
                )
              : null,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          color: Colors.black,
        ),
      ),
    );
  }


  Widget _buildCallsList(List<CallModel> calls, String emptyMessage) {
    if (calls.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.phone_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshCalls,
      child: ListView.builder(
        itemCount: calls.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final call = calls[index];
          return _buildCallItem(call);
        },
      ),
    );
  }

  Widget _buildCallItem(CallModel call) {
    final isMissed = call.status == CallStatus.missed || call.direction == CallDirection.missed;
    final isOutgoing = call.direction == CallDirection.outgoing;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onCallTap(call),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMissed ? Colors.red.withOpacity(0.3) : AppTheme.cardColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Avatar del contatto
                _buildAvatar(call),
                const SizedBox(width: 16),
                
                // Info della chiamata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nome contatto
                      Text(
                        call.contactName,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isMissed ? Colors.red : Colors.black,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Info chiamata (direzione, tipo, durata)
                      Row(
                        children: [
                          // Icona direzione
                          Icon(
                            isOutgoing 
                                ? Icons.call_made 
                                : isMissed 
                                    ? Icons.call_received 
                                    : Icons.call_received,
                            size: 16,
                            color: isMissed 
                                ? Colors.red 
                                : isOutgoing 
                                    ? Colors.green 
                                    : Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          
                          // Icona tipo chiamata
                          Icon(
                            call.type == CallType.audio ? Icons.phone : Icons.videocam,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          
                          // Stato o durata
                          Text(
                            _getCallStatusText(call),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: isMissed ? Colors.red : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Orario e azioni
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(call.timestamp),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _startCallBack(call),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          call.type == CallType.audio ? Icons.phone : Icons.videocam,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
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

  String _getCallStatusText(CallModel call) {
    switch (call.status) {
      case CallStatus.ringing:
        return 'Squillante';
      case CallStatus.answered:
        return 'Risposta';
      case CallStatus.completed:
        return _formatDuration(call.duration);
      case CallStatus.missed:
        return 'Persa';
      case CallStatus.declined:
        return 'Rifiutata';
      case CallStatus.cancelled:
        return 'Cancellata';
      case CallStatus.ended:
        return 'Terminata';
      default:
        return 'Sconosciuto';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds == 0) return '0s';
    
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // Oggi - mostra solo l'orario
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Ieri
      return 'Ieri';
    } else if (difference.inDays < 7) {
      // Questa settimana
      const weekdays = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Data completa
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  Widget _buildAvatar(CallModel call) {
    if (call.contactId != null) {
      return MasterAvatarWidget(
        userId: call.contactId!,
        userName: call.contactName,
        size: 45,
        showOnlineIndicator: false,
      );
    }
    
    // Fallback avatar
    return CircleAvatar(
      radius: 22.5,
      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
      child: Text(
        call.contactName.isNotEmpty ? call.contactName[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  void _onCallTap(CallModel call) {
    // Mostra dettagli della chiamata o avvia nuova chiamata
    _startCallBack(call);
  }

  void _startCallBack(CallModel call) async {
    if (call.contactId == null) return;
    
    try {
      final webrtcService = Provider.of<NativeAudioCallService>(context, listen: false);
      
      // Determina il tipo di chiamata basato sulla chiamata originale
      final callType = call.type == CallType.audio 
          ? CallType.audio 
          : CallType.video;
      
      await webrtcService.startCall(
        call.contactId!,
        call.contactName,
        callType,
      );
      
      if (mounted) {
        final callTypeParam = call.type == CallType.audio ? 'audio' : 'video';
        context.go('/call/${call.contactId}?type=$callTypeParam&name=${Uri.encodeComponent(call.contactName)}');
      }
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nell\'avviare la chiamata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
