import 'dart:async';
import 'package:flutter/material.dart';
import '../models/call_model.dart';
import 'api_service.dart';

class CallHistoryService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<CallModel> _callHistory = [];
  bool _isLoading = false;
  String? _error;
  DateTime? _lastFetch;
  
  // Getters
  List<CallModel> get callHistory => _callHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  // Filtri per tipo di chiamata
  List<CallModel> get allCalls => _callHistory;
  List<CallModel> get outgoingCalls => _callHistory.where((call) => call.direction == CallDirection.outgoing).toList();
  List<CallModel> get incomingCalls => _callHistory.where((call) => call.direction == CallDirection.incoming).toList();
  List<CallModel> get missedCalls => _callHistory.where((call) => call.direction == CallDirection.missed || call.status == CallStatus.missed).toList();
  
  /// Carica lo storico delle chiamate dal server
  Future<void> loadCallHistory({bool forceRefresh = false}) async {
    // Evita richieste multiple simultanee
    if (_isLoading) return;
    
    // CORREZIONE: Cache ridotta a 5 secondi per aggiornamenti più frequenti
    if (!forceRefresh && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      if (timeSinceLastFetch.inSeconds < 5) {
        return;
      }
    }
    
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      print('📞 CallHistoryService.loadCallHistory - Caricando storico chiamate...');
      
      final response = await _apiService.getCallHistory();
      final callsData = response['calls'] as List<dynamic>? ?? [];
      
      _callHistory = callsData.map((callData) {
        try {
          // CORREZIONE: Usa il timestamp del server se disponibile, altrimenti usa quello del JSON
          DateTime timestamp;
          if (callData['created_at'] != null) {
            try {
              timestamp = DateTime.parse(callData['created_at']);
              print('📅 CallHistoryService - Usando timestamp server: $timestamp');
            } catch (e) {
              print('⚠️ CallHistoryService - Errore parsing server timestamp: $e');
              timestamp = DateTime.parse(callData['timestamp']);
            }
          } else {
            timestamp = DateTime.parse(callData['timestamp']);
          }
          
          // Crea un nuovo CallModel con il timestamp corretto
          return CallModel(
            id: callData['id'],
            contactName: callData['contactName'],
            contactAvatar: callData['contactAvatar'] ?? '',
            contactId: callData['contactId'],
            callerId: callData['callerId'],
            calleeId: callData['calleeId'],
            timestamp: timestamp, // Usa il timestamp del server
            type: CallType.values.firstWhere((e) => e.name == callData['type']),
            direction: CallDirection.values.firstWhere((e) => e.name == callData['direction']),
            status: CallStatus.values.firstWhere((e) => e.name == callData['status']),
            duration: Duration(seconds: callData['duration'] ?? 0),
            phoneNumber: callData['phoneNumber'],
          );
        } catch (e) {
          print('❌ CallHistoryService - Errore parsing chiamata: $e');
          print('❌ Dati problematici: $callData');
          return null;
        }
      }).where((call) => call != null).cast<CallModel>().toList();
      
      _lastFetch = DateTime.now();
      _error = null;
      
      print('✅ CallHistoryService.loadCallHistory - Caricate ${_callHistory.length} chiamate');
      
    } catch (e) {
      print('❌ CallHistoryService.loadCallHistory - Errore: $e');
      _error = 'Errore nel caricamento dello storico chiamate: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Filtra le chiamate per testo di ricerca
  List<CallModel> searchCalls(String query) {
    if (query.isEmpty) return _callHistory;
    
    final lowercaseQuery = query.toLowerCase();
    return _callHistory.where((call) {
      return call.contactName.toLowerCase().contains(lowercaseQuery) ||
             (call.phoneNumber?.contains(query) ?? false);
    }).toList();
  }
  
  /// Raggruppa le chiamate per data
  Map<String, List<CallModel>> groupCallsByDate() {
    final Map<String, List<CallModel>> groupedCalls = {};
    final now = DateTime.now();
    
    for (final call in _callHistory) {
      String dateKey;
      final callDate = call.timestamp;
      final difference = now.difference(callDate).inDays;
      
      if (difference == 0) {
        dateKey = 'Oggi';
      } else if (difference == 1) {
        dateKey = 'Ieri';
      } else if (difference < 7) {
        const weekdays = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
        dateKey = weekdays[callDate.weekday - 1];
      } else {
        dateKey = '${callDate.day}/${callDate.month}/${callDate.year}';
      }
      
      if (!groupedCalls.containsKey(dateKey)) {
        groupedCalls[dateKey] = [];
      }
      groupedCalls[dateKey]!.add(call);
    }
    
    return groupedCalls;
  }
  
  /// Ottieni statistiche delle chiamate
  Map<String, int> getCallStatistics() {
    return {
      'total': _callHistory.length,
      'outgoing': outgoingCalls.length,
      'incoming': incomingCalls.length,
      'missed': missedCalls.length,
    };
  }
  
  /// Pulisce la cache
  void clearCache() {
    _callHistory.clear();
    _lastFetch = null;
    _error = null;
    notifyListeners();
  }
  
  /// Aggiorna una chiamata specifica (per aggiornamenti real-time)
  void updateCall(CallModel updatedCall) {
    final index = _callHistory.indexWhere((call) => call.id == updatedCall.id);
    if (index != -1) {
      _callHistory[index] = updatedCall;
      notifyListeners();
    }
  }
  
  /// Aggiunge una nuova chiamata (per aggiornamenti real-time)
  void addCall(CallModel newCall) {
    _callHistory.insert(0, newCall); // Inserisce all'inizio (più recente)
    notifyListeners();
  }
}
