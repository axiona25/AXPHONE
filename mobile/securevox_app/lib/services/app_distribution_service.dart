// 📱 SecureVOX App Distribution Service
// Servizio per integrare l'app mobile con il sistema di distribuzione

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDistributionService {
  static const String baseUrl = 'https://securevox.it/app-distribution/api';
  
  // Verifica se ci sono aggiornamenti disponibili
  static Future<AppUpdateInfo?> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      final response = await http.get(
        Uri.parse('$baseUrl/builds/?platform=$platform&is_active=true'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final builds = data['results'] as List;
        
        if (builds.isNotEmpty) {
          final latestBuild = builds.first;
          final currentVersion = packageInfo.version;
          final latestVersion = latestBuild['version'];
          
          // Confronta versioni (implementazione semplice)
          if (_isNewerVersion(currentVersion, latestVersion)) {
            return AppUpdateInfo.fromJson(latestBuild);
          }
        }
      }
    } catch (e) {
      print('Errore nel controllo aggiornamenti: $e');
    }
    
    return null;
  }
  
  // Scarica e installa aggiornamento
  static Future<bool> downloadUpdate(AppUpdateInfo updateInfo) async {
    try {
      if (Platform.isIOS) {
        // Per iOS, apri il link di installazione
        final installUrl = updateInfo.installUrl;
        if (installUrl != null && await canLaunchUrl(Uri.parse(installUrl))) {
          return await launchUrl(
            Uri.parse(installUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        // Per Android, scarica l'APK
        final downloadUrl = '${baseUrl.replaceAll('/api', '')}/build/${updateInfo.id}/download/';
        if (await canLaunchUrl(Uri.parse(downloadUrl))) {
          return await launchUrl(
            Uri.parse(downloadUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      }
    } catch (e) {
      print('Errore nel download aggiornamento: $e');
    }
    
    return false;
  }
  
  // Invia feedback per la build corrente
  static Future<bool> sendFeedback(int rating, String comment) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      
      // Trova la build corrente
      final buildsResponse = await http.get(
        Uri.parse('$baseUrl/builds/?platform=$platform&version=${packageInfo.version}'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (buildsResponse.statusCode == 200) {
        final data = json.decode(buildsResponse.body);
        final builds = data['results'] as List;
        
        if (builds.isNotEmpty) {
          final buildId = builds.first['id'];
          
          final feedbackResponse = await http.post(
            Uri.parse('$baseUrl/feedback/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'app_build': buildId,
              'rating': rating,
              'comment': comment,
              'device_info': {
                'platform': Platform.operatingSystem,
                'version': Platform.operatingSystemVersion,
                'app_version': packageInfo.version,
              }
            }),
          );
          
          return feedbackResponse.statusCode == 201;
        }
      }
    } catch (e) {
      print('Errore nell\'invio feedback: $e');
    }
    
    return false;
  }
  
  // Confronta versioni (implementazione semplice)
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();
    
    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;
      
      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }
    
    return false;
  }
  
  // Apri pagina distribuzione nel browser
  static Future<void> openDistributionPage() async {
    const url = 'https://securevox.it/app-distribution/';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    }
  }
}

class AppUpdateInfo {
  final String id;
  final String name;
  final String version;
  final String buildNumber;
  final String platform;
  final String description;
  final String? releaseNotes;
  final String? installUrl;
  final double fileSizeMb;
  final bool isBeta;
  
  AppUpdateInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.buildNumber,
    required this.platform,
    required this.description,
    this.releaseNotes,
    this.installUrl,
    required this.fileSizeMb,
    required this.isBeta,
  });
  
  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      id: json['id'],
      name: json['name'],
      version: json['version'],
      buildNumber: json['build_number'],
      platform: json['platform'],
      description: json['description'] ?? '',
      releaseNotes: json['release_notes'],
      installUrl: json['install_url'],
      fileSizeMb: (json['file_size_mb'] ?? 0).toDouble(),
      isBeta: json['is_beta'] ?? false,
    );
  }
}
