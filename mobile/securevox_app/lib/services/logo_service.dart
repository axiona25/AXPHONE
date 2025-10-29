import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/logo_model.dart';

class LogoService {
  static const String _logosKey = 'social_logos';
  
  // Inizializza i loghi predefiniti
  static Future<void> initializeDefaultLogos() async {
    final prefs = await SharedPreferences.getInstance();
    final existingLogos = prefs.getString(_logosKey);
    
    if (existingLogos == null) {
      final defaultLogos = [
        LogoModel(
          id: 'facebook_logo',
          name: 'Facebook Logo',
          assetPath: 'assets/icons/Facebook Logo.png',
          platform: 'facebook',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        LogoModel(
          id: 'google_logo',
          name: 'Google Logo',
          assetPath: 'assets/icons/Google Logo.png',
          platform: 'google',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        LogoModel(
          id: 'apple_logo',
          name: 'Apple Logo',
          assetPath: 'assets/icons/Apple Logo.png',
          platform: 'apple',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      
      await _saveLogos(defaultLogos);
    }
  }
  
  // Salva i loghi nel database locale
  static Future<void> _saveLogos(List<LogoModel> logos) async {
    final prefs = await SharedPreferences.getInstance();
    final logosJson = logos.map((logo) => logo.toJson()).toList();
    await prefs.setString(_logosKey, jsonEncode(logosJson));
  }
  
  // Carica tutti i loghi dal database
  static Future<List<LogoModel>> getAllLogos() async {
    final prefs = await SharedPreferences.getInstance();
    final logosJson = prefs.getString(_logosKey);
    
    if (logosJson == null) {
      await initializeDefaultLogos();
      return getAllLogos();
    }
    
    final List<dynamic> logosList = jsonDecode(logosJson);
    return logosList.map((json) => LogoModel.fromJson(json)).toList();
  }
  
  // Ottieni un logo specifico per piattaforma
  static Future<LogoModel?> getLogoByPlatform(String platform) async {
    final logos = await getAllLogos();
    try {
      return logos.firstWhere((logo) => logo.platform == platform);
    } catch (e) {
      return null;
    }
  }
  
  // Aggiorna un logo esistente
  static Future<void> updateLogo(LogoModel logo) async {
    final logos = await getAllLogos();
    final index = logos.indexWhere((l) => l.id == logo.id);
    
    if (index != -1) {
      logos[index] = logo.copyWith(updatedAt: DateTime.now());
      await _saveLogos(logos);
    }
  }
  
  // Aggiungi un nuovo logo
  static Future<void> addLogo(LogoModel logo) async {
    final logos = await getAllLogos();
    logos.add(logo);
    await _saveLogos(logos);
  }
  
  // Rimuovi un logo
  static Future<void> removeLogo(String logoId) async {
    final logos = await getAllLogos();
    logos.removeWhere((logo) => logo.id == logoId);
    await _saveLogos(logos);
  }
}
