import 'dart:io';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Servizio per gestire la posizione geografica e navigazione
class LocationService {
  
  /// Ottiene la posizione corrente del dispositivo
  static Future<LocationData?> getCurrentLocation() async {
    try {
      print('📍 LocationService.getCurrentLocation - INIZIO rilevamento posizione');
      
      // Controlla se i servizi di localizzazione sono abilitati
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ LocationService.getCurrentLocation - Servizi di localizzazione disabilitati');
        
        // SIMULAZIONE per il simulatore iOS/Android quando i servizi sono disabilitati
        print('🧪 LocationService.getCurrentLocation - Usando posizione simulata per testing');
        return LocationData(
          latitude: 41.9028,  // Roma, Italia
          longitude: 12.4964,
          accuracy: 10.0,
          timestamp: DateTime.now(),
        );
      }
      
      // Richiedi permessi di localizzazione
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ LocationService.getCurrentLocation - Permessi localizzazione negati');
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        print('❌ LocationService.getCurrentLocation - Permessi localizzazione negati permanentemente');
        return null;
      }
      
      print('📍 LocationService.getCurrentLocation - Permessi OK, rilevando posizione...');
      
      // Ottieni la posizione corrente
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      
      print('📍 LocationService.getCurrentLocation - Posizione rilevata:');
      print('   Latitudine: ${position.latitude}');
      print('   Longitudine: ${position.longitude}');
      print('   Accuratezza: ${position.accuracy}m');
      
      // Crea oggetto LocationData
      final locationData = LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: DateTime.now(),
      );
      
      return locationData;
      
    } catch (e) {
      print('❌ LocationService.getCurrentLocation - Errore rilevamento posizione: $e');
      
      // Fallback: posizione simulata in caso di errore
      print('🧪 LocationService.getCurrentLocation - Usando posizione simulata dopo errore');
      return LocationData(
        latitude: 41.9028,  // Roma, Italia
        longitude: 12.4964,
        accuracy: 10.0,
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Apre la posizione nel navigatore di default con scelta opzionale
  static Future<void> openLocationInMaps(LocationData location) async {
    try {
      print('🗺️ LocationService.openLocationInMaps - Apertura mappe per: ${location.latitude}, ${location.longitude}');
      
      // Prova prima con il navigatore di sistema (quello di default)
      await _tryOpenDefaultNavigator(location);
      
    } catch (e) {
      print('❌ LocationService.openLocationInMaps - Errore apertura mappe: $e');
    }
  }
  
  /// Prova ad aprire il navigatore di default del sistema
  static Future<void> _tryOpenDefaultNavigator(LocationData location) async {
    final lat = location.latitude;
    final lng = location.longitude;
    
    // Lista di URL da provare in ordine di priorità
    // PRIORITÀ: 1. Google Maps, 2. Apple Maps, 3. Waze, 4. Browser
    final List<String> navigationUrls = [
      // 1. Google Maps (app nativa se disponibile)
      'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
      
      // 2. Google Maps (web se app non disponibile)
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
      
      // 3. Apple Maps (iOS) - app nativa
      'maps://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
      
      // 4. Apple Maps (iOS) - http fallback
      'http://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
      
      // 5. Waze (se disponibile)
      'waze://?ll=$lat,$lng&navigate=yes',
      'https://waze.com/ul?ll=$lat,$lng&navigate=yes',
      
      // 6. URL universale geo (Android)
      'geo:$lat,$lng?q=$lat,$lng',
      
      // 7. Fallback finale - Google Maps nel browser
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    ];
    
    print('🗺️ LocationService._tryOpenDefaultNavigator - Tentativo apertura navigatori...');
    print('🗺️ LocationService._tryOpenDefaultNavigator - Priorità: 1. Google Maps, 2. Apple Maps, 3. Waze');
    
    for (String url in navigationUrls) {
      try {
        final Uri uri = Uri.parse(url);
        
        if (await canLaunchUrl(uri)) {
          print('✅ LocationService._tryOpenDefaultNavigator - Apertura con: $url');
          await launchUrl(
            uri, 
            mode: LaunchMode.externalApplication,
          );
          return; // Successo, esci dal loop
        } else {
          print('⚠️ LocationService._tryOpenDefaultNavigator - Non disponibile: $url');
        }
      } catch (e) {
        print('⚠️ LocationService._tryOpenDefaultNavigator - Errore con $url: $e');
        continue; // Prova il prossimo URL
      }
    }
    
    print('❌ LocationService._tryOpenDefaultNavigator - Nessun navigatore disponibile');
  }
  
  /// Genera URL per preview statica della mappa
  static String generateStaticMapUrl(LocationData location, {int width = 300, int height = 200, int zoom = 15}) {
    final lat = location.latitude;
    final lng = location.longitude;
    
    print('🗺️ LocationService.generateStaticMapUrl - Generando mappa per: $lat, $lng');
    print('🗺️ LocationService.generateStaticMapUrl - Dimensioni: ${width}x$height, Zoom: $zoom');
    
    // Usa MapQuest Open Static Maps - COMPLETAMENTE GRATUITO, no API key required
    // Usa tiles OpenStreetMap
    final mapquestUrl = 'https://open.mapquestapi.com/staticmap/v5/map'
           '?center=$lat,$lng'
           '&zoom=$zoom'
           '&size=${width},${height}'
           '&type=map'
           '&imagetype=png'
           '&scalebar=false'
           '&pois=red_1,$lat,$lng';
    
    print('🗺️ LocationService.generateStaticMapUrl - URL MapQuest Open: $mapquestUrl');
    
    return mapquestUrl;
  }
  
  /// Genera URL per condividere la posizione
  static String generateLocationShareUrl(LocationData location) {
    return 'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
  }
  
  /// Formatta la posizione per la visualizzazione
  static String formatLocationForDisplay(LocationData location) {
    return '📍 Posizione\n'
           'Lat: ${location.latitude.toStringAsFixed(6)}\n'
           'Lng: ${location.longitude.toStringAsFixed(6)}\n'
           'Precisione: ${location.accuracy.toStringAsFixed(0)}m';
  }
}

/// Modello dati per una posizione geografica
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
  
  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
  
  /// Converte in JSON per l'invio al server
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
  };
  
  /// Crea da JSON ricevuto dal server
  factory LocationData.fromJson(Map<String, dynamic> json) {
    // Fallback a coordinate valide (Roma) se non presenti o invalide
    final lat = json['latitude']?.toDouble() ?? 41.9028;
    final lng = json['longitude']?.toDouble() ?? 12.4964;
    
    // Se coordinate sono 0,0 (invalide), usa Roma come fallback
    final finalLat = (lat == 0.0 && lng == 0.0) ? 41.9028 : lat;
    final finalLng = (lat == 0.0 && lng == 0.0) ? 12.4964 : lng;
    
    return LocationData(
      latitude: finalLat,
      longitude: finalLng,
      accuracy: json['accuracy']?.toDouble() ?? 10.0,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}
