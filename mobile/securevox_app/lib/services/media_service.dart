import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:contacts_service/contacts_service.dart'; // Temporaneamente disabilitato
// import 'package:geolocator/geolocator.dart'; // Temporaneamente disabilitato per problemi iOS
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:image/image.dart' as img;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'e2e_manager.dart';

/// Servizio per gestire tutti i contenuti multimediali
class MediaService {
  static const String baseUrl = 'http://127.0.0.1:8001/api/media';
  final ImagePicker _imagePicker = ImagePicker();

  // 🗂️ Mappa locale videoUrl -> local_file_name per il mittente
  static const String _videoLocalMapFile = 'video_local_cache.json';

  Future<void> saveLocalVideoCacheMapping(String videoUrl, String localFileName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_videoLocalMapFile');
      Map<String, dynamic> map = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) map = json.decode(content) as Map<String, dynamic>;
      }
      // 🔐 CRITICO: Aggiorna sempre il mapping anche se esiste già
      // Questo assicura che quando si invia un nuovo video con lo stesso URL,
      // il mapping punti al nuovo file locale (con nuovi IV/MAC)
      map[videoUrl] = localFileName;
      await file.writeAsString(json.encode(map));
      print('💾 MediaService.saveLocalVideoCacheMapping - Salvato/Aggiornato mapping per $videoUrl → $localFileName');
      print('   🔄 Mapping aggiornato per gestire nuovi video con stesso URL');
    } catch (e) {
      print('❌ MediaService.saveLocalVideoCacheMapping - Errore: $e');
    }
  }

  Future<String?> getLocalVideoFileNameByUrl(String videoUrl) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_videoLocalMapFile');
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      if (content.isEmpty) return null;
      final map = json.decode(content) as Map<String, dynamic>;
      return map[videoUrl]?.toString();
    } catch (e) {
      print('❌ MediaService.getLocalVideoFileNameByUrl - Errore: $e');
      return null;
    }
  }

  /// 🔐 CORREZIONE BUG: Invalida il mapping video quando cambia lo stato di crittografia
  /// Questo previene che video vecchi vengano caricati usando il mapping errato
  Future<void> clearVideoCacheMapping() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/$_videoLocalMapFile');
      if (await file.exists()) {
        await file.writeAsString('{}');
        print('🗑️ MediaService.clearVideoCacheMapping - Mapping video invalidato');
      }
    } catch (e) {
      print('❌ MediaService.clearVideoCacheMapping - Errore: $e');
    }
  }

  /// 🔐 Helper per cifrare un file prima dell'upload
  Future<Map<String, dynamic>?> _encryptFileIfNeeded({
    required File file,
    required String? recipientId,
    required bool shouldEncrypt,
  }) async {
    if (!shouldEncrypt || recipientId == null || !E2EManager.isEnabled) {
      return null;
    }

    try {
      print('🔐 MediaService._encryptFileIfNeeded - Cifratura file per destinatario $recipientId');
      
      // Leggi il file come bytes
      final fileBytes = await file.readAsBytes();
      print('🔐 File letto: ${fileBytes.length} bytes');
      
      // 🆕 SALVA L'IMMAGINE ORIGINALE IN CACHE PER IL MITTENTE
      print('🔐 DEBUG - INIZIO salvataggio immagine originale in cache locale');
      final appDir = await getApplicationDocumentsDirectory();
      print('🔐 DEBUG - App directory: ${appDir.path}');
      
      final cacheDir = Directory('${appDir.path}/image_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
        print('🔐 DEBUG - Cache directory creata: ${cacheDir.path}');
      } else {
        print('🔐 DEBUG - Cache directory già esistente: ${cacheDir.path}');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // 🔐 CORREZIONE: Estrai nome REALE e estensione del file originale
      final realFileName = file.path.split('/').last; // Es: "PIanificazione Budget 2026_PA.xlsx"
      final realFileExtension = realFileName.contains('.') 
          ? realFileName.split('.').last.toLowerCase() 
          : '';
      
      print('📄 MediaService._encryptFileIfNeeded - File originale:');
      print('   📄 Nome: $realFileName');
      print('   📄 Estensione: $realFileExtension');
      
      final originalFileName = '${timestamp}_original${file.path.substring(file.path.lastIndexOf('.'))}';
      final cachedOriginalFile = File('${cacheDir.path}/$originalFileName');
      await cachedOriginalFile.writeAsBytes(fileBytes);
      
      print('💾 MediaService - File originale salvato in cache');
      print('   📁 Path: ${cachedOriginalFile.path}');
      print('   📊 Dimensione: ${fileBytes.length} bytes');
      print('   ✅ File esiste: ${await cachedOriginalFile.exists()}');
      
      // Cifra i bytes
      print('🔐 DEBUG - Inizio cifratura file...');
      final encrypted = await E2EManager.encryptFileBytes(recipientId, fileBytes);
      
      if (encrypted != null) {
        print('🔐 DEBUG - File cifrato con successo!');
        final ivStr = encrypted['iv']?.toString() ?? '';
        final macStr = encrypted['mac']?.toString() ?? '';
        print('   🔑 IV: ${ivStr.length > 20 ? ivStr.substring(0, 20) : ivStr}...');
        print('   🔑 MAC: ${macStr.length > 20 ? macStr.substring(0, 20) : macStr}...');
        print('   📊 Original size: ${encrypted['original_size']}');
        
        // Salva i bytes cifrati in un file temporaneo
        final tempDir = await getTemporaryDirectory();
        final encryptedFileName = '${timestamp}_encrypted.bin';
        final encryptedFile = File('${tempDir.path}/$encryptedFileName');
        
        // Decodifica il ciphertext da base64 e scrivi nel file
        final ciphertextBytes = base64.decode(encrypted['ciphertext'] as String);
        await encryptedFile.writeAsBytes(ciphertextBytes);
        
        print('🔐 MediaService._encryptFileIfNeeded - ✅ File cifrato temporaneo creato');
        print('   📁 Path cifrato: ${encryptedFile.path}');
        print('   📊 Dimensione cifrata: ${ciphertextBytes.length} bytes');
        
        final metadata = {
          'iv': encrypted['iv'],
          'mac': encrypted['mac'],
          'encrypted': true,
          'original_size': encrypted['original_size'],
          'local_file_name': originalFileName, // 🆕 Per mittente: cache locale
          'original_file_name': realFileName,  // 🔐 CORREZIONE: Nome REALE per destinatario
          'original_file_extension': realFileExtension, // 🔐 CORREZIONE: Estensione REALE
        };
        
        print('🔐 DEBUG - METADATA COMPLETI DA RITORNARE:');
        print('   📦 ${metadata.toString()}');
        print('   📦 local_file_name: $originalFileName');
        print('   📦 original_file_name: $realFileName');
        print('   📦 original_file_extension: $realFileExtension');
        
        return {
          'file': encryptedFile,
          'metadata': metadata,
        };
      } else {
        print('❌ DEBUG - Cifratura fallita! encrypted è null');
      }
    } catch (e) {
      print('❌ MediaService._encryptFileIfNeeded - Errore: $e');
    }
    
    return null;
  }



  /// Upload di un file generico
  Future<Map<String, dynamic>?> uploadFile({
    required String userId,
    required String chatId,
    required File file,
    String? recipientId, // 🆕 Per cifratura E2E
    bool shouldEncrypt = false, // 🆕 Flag per abilitare cifratura
  }) async {
    try {
      File fileToUpload = file;
      Map<String, dynamic>? encryptionMetadata;

      // 🔐 CIFRATURA E2E
      final encryptionResult = await _encryptFileIfNeeded(
        file: file,
        recipientId: recipientId,
        shouldEncrypt: shouldEncrypt,
      );
      
      if (encryptionResult != null) {
        fileToUpload = encryptionResult['file'] as File;
        encryptionMetadata = encryptionResult['metadata'] as Map<String, dynamic>;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/file/'),
      );

      request.files.add(await http.MultipartFile.fromPath(
        'file', 
        fileToUpload.path,
        contentType: encryptionMetadata != null 
            ? MediaType('application', 'octet-stream')
            : null,
      ));
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      
      // 🔐 CORREZIONE: Passa il nome originale del file e metadati di cifratura per file cifrati
      if (encryptionMetadata != null) {
        if (encryptionMetadata['original_file_name'] != null) {
          request.fields['original_file_name'] = encryptionMetadata['original_file_name'];
        }
        // 🔐 CRITICO: Passa iv, mac e altri metadati di cifratura durante l'upload
        if (encryptionMetadata['iv'] != null) {
          request.fields['iv'] = encryptionMetadata['iv'];
        }
        if (encryptionMetadata['mac'] != null) {
          request.fields['mac'] = encryptionMetadata['mac'];
        }
        if (encryptionMetadata['encrypted'] != null) {
          request.fields['encrypted'] = encryptionMetadata['encrypted'].toString();
        }
        if (encryptionMetadata['original_size'] != null) {
          request.fields['original_size'] = encryptionMetadata['original_size'].toString();
        }
        if (encryptionMetadata['local_file_name'] != null) {
          request.fields['local_file_name'] = encryptionMetadata['local_file_name'];
        }
        if (encryptionMetadata['original_file_extension'] != null) {
          request.fields['original_file_extension'] = encryptionMetadata['original_file_extension'];
        }
        print('🔐 MediaService.uploadFile - Invio metadati cifratura: iv=${encryptionMetadata['iv'] != null}, mac=${encryptionMetadata['mac'] != null}');
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final result = jsonData['data'] as Map<String, dynamic>;
        
        // 🔐 Aggiungi metadata cifratura se presente (client-side)
        if (encryptionMetadata != null) {
          result['encryption'] = encryptionMetadata;
          print('🔐 MediaService.uploadFile - Metadata cifratura aggiunti al risultato');
        }
        
        // 🔐 CORREZIONE: SEMPRE estrai metadata E2E dal backend se encrypted=true
        if (result['metadata'] != null && result['metadata']['encrypted'] == true) {
          final backendMetadata = result['metadata'] as Map<String, dynamic>;
          if (result['encryption'] == null) {
            result['encryption'] = {};
          }
          // Fondo metadata backend in encryption (sovrascrive quelli client se duplicati)
          result['encryption'] = {
            ...result['encryption'],
            'iv': backendMetadata['iv'],
            'mac': backendMetadata['mac'],
            'encrypted': backendMetadata['encrypted'],
            'original_size': backendMetadata['original_size'],
            if (backendMetadata['local_file_name'] != null) 'local_file_name': backendMetadata['local_file_name'],
            if (backendMetadata['original_file_extension'] != null) 'original_file_extension': backendMetadata['original_file_extension'],
          };
          print('🔐 MediaService.uploadFile - Metadata E2E estesi dal backend');
        }
        
        // 🧹 Rimuovi file temporaneo
        if (encryptionMetadata != null && fileToUpload.existsSync()) {
          await fileToUpload.delete();
        }
        
        print('✅ MediaService.uploadFile - Upload completato: ${result['fileId']}');
        return result;
      } else {
        // 🆕 CORREZIONE: Mostra dettagli errore dal server
        final errorMsg = jsonData['error'] ?? 'Errore sconosciuto';
        final errorDetails = jsonData['details'] ?? '';
        print('❌ MediaService.uploadFile - Errore upload file:');
        print('   Status Code: ${response.statusCode}');
        print('   Messaggio: $errorMsg');
        print('   Dettagli: $errorDetails');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ MediaService.uploadFile - Exception: $e');
      print('   Stack Trace: $stackTrace');
      return null;
    }
  }

  /// Upload di un'immagine
  Future<Map<String, dynamic>?> uploadImage({
    required String userId,
    required String chatId,
    required File image,
    String caption = '',
    String? recipientId, // 🆕 Per cifratura E2E
    bool shouldEncrypt = false, // 🆕 Flag per abilitare cifratura
  }) async {
    try {
      // Ridimensiona l'immagine se necessario
      final optimizedImage = await _optimizeImage(image);
      
      File fileToUpload = optimizedImage;
      Map<String, dynamic>? encryptionMetadata;

      // 🔐 CIFRATURA E2E: Se abilitata, cifra il file prima di caricarlo
      final encryptionResult = await _encryptFileIfNeeded(
        file: optimizedImage,
        recipientId: recipientId,
        shouldEncrypt: shouldEncrypt,
      );
      
      if (encryptionResult != null) {
        fileToUpload = encryptionResult['file'] as File;
        encryptionMetadata = encryptionResult['metadata'] as Map<String, dynamic>;
      }
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/image/'),
      );

      // Rileva il content type basato sull'estensione del file
      final contentType = shouldEncrypt && encryptionMetadata != null 
          ? MediaType('application', 'octet-stream') // File cifrato = binario generico
          : _getImageContentType(fileToUpload.path);
      
      // Aggiungi il file con content type appropriato
      var multipartFile = await http.MultipartFile.fromPath(
        'image', 
        fileToUpload.path,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      request.fields['caption'] = caption;
      
      // 🔐 CORREZIONE: Passa il nome originale del file e metadati di cifratura per immagini cifrate
      if (encryptionMetadata != null) {
        if (encryptionMetadata['original_file_name'] != null) {
          request.fields['original_file_name'] = encryptionMetadata['original_file_name'];
        }
        // 🔐 CRITICO: Passa iv, mac e altri metadati di cifratura durante l'upload
        if (encryptionMetadata['iv'] != null) {
          request.fields['iv'] = encryptionMetadata['iv'];
        }
        if (encryptionMetadata['mac'] != null) {
          request.fields['mac'] = encryptionMetadata['mac'];
        }
        if (encryptionMetadata['encrypted'] != null) {
          request.fields['encrypted'] = encryptionMetadata['encrypted'].toString();
        }
        if (encryptionMetadata['original_size'] != null) {
          request.fields['original_size'] = encryptionMetadata['original_size'].toString();
        }
        if (encryptionMetadata['local_file_name'] != null) {
          request.fields['local_file_name'] = encryptionMetadata['local_file_name'];
        }
        if (encryptionMetadata['original_file_extension'] != null) {
          request.fields['original_file_extension'] = encryptionMetadata['original_file_extension'];
        }
        print('🔐 MediaService.uploadImage - Invio metadati cifratura: iv=${encryptionMetadata['iv'] != null}, mac=${encryptionMetadata['mac'] != null}');
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final result = jsonData['data'] as Map<String, dynamic>;
        
        // 🔐 Aggiungi metadata cifratura se presente (client-side)
        if (encryptionMetadata != null) {
          result['encryption'] = encryptionMetadata;
          print('🔐 MediaService.uploadImage - Metadata cifratura aggiunti al risultato');
        } else if (result['metadata'] != null && result['metadata']['encrypted'] == true) {
          // 🔐 CORREZIONE: Estrai metadata E2E dal backend se non presenti lato client
          final backendEncryption = Map<String, dynamic>.from(result['metadata']);
          result['encryption'] = backendEncryption;
          print('🔐 MediaService.uploadImage - Metadata E2E estratti dal backend');
        }
        
        // 🧹 Rimuovi file temporaneo cifrato
        if (shouldEncrypt && encryptionMetadata != null && fileToUpload.existsSync()) {
          await fileToUpload.delete();
          print('🧹 MediaService.uploadImage - File temporaneo cifrato eliminato');
        }
        
        return result;
      } else {
        print('Errore upload immagine: ${jsonData['error']}');
        return null;
      }
    } catch (e) {
      print('Errore upload immagine: $e');
      return null;
    }
  }

  /// Upload di un video
  Future<Map<String, dynamic>?> uploadVideo({
    required String userId,
    required String chatId,
    required File video,
    String caption = '',
    String? recipientId, // 🆕 Per cifratura E2E
    bool shouldEncrypt = false, // 🆕 Flag per abilitare cifratura
  }) async {
    try {
      // Ottimizza il video se necessario
      final optimizedVideo = await _optimizeVideo(video);
      
      File fileToUpload = optimizedVideo;
      Map<String, dynamic>? encryptionMetadata;

      // 🔐 CIFRATURA E2E
      final encryptionResult = await _encryptFileIfNeeded(
        file: optimizedVideo,
        recipientId: recipientId,
        shouldEncrypt: shouldEncrypt,
      );
      
      if (encryptionResult != null) {
        fileToUpload = encryptionResult['file'] as File;
        encryptionMetadata = encryptionResult['metadata'] as Map<String, dynamic>;
      }
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/video/'),
      );

      // Rileva il content type
      final contentType = encryptionMetadata != null 
          ? MediaType('application', 'octet-stream')
          : _getVideoContentType(fileToUpload.path);
      
      var multipartFile = await http.MultipartFile.fromPath(
        'video', 
        fileToUpload.path,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      request.fields['caption'] = caption;
      
      // 🔐 CORREZIONE: Passa il nome originale del file e metadati di cifratura per video cifrati
      if (encryptionMetadata != null) {
        if (encryptionMetadata['original_file_name'] != null) {
          request.fields['original_file_name'] = encryptionMetadata['original_file_name'];
        }
        // 🔐 CRITICO: Passa iv, mac e altri metadati di cifratura durante l'upload
        if (encryptionMetadata['iv'] != null) {
          request.fields['iv'] = encryptionMetadata['iv'];
        }
        if (encryptionMetadata['mac'] != null) {
          request.fields['mac'] = encryptionMetadata['mac'];
        }
        if (encryptionMetadata['encrypted'] != null) {
          request.fields['encrypted'] = encryptionMetadata['encrypted'].toString();
        }
        if (encryptionMetadata['original_size'] != null) {
          request.fields['original_size'] = encryptionMetadata['original_size'].toString();
        }
        if (encryptionMetadata['local_file_name'] != null) {
          request.fields['local_file_name'] = encryptionMetadata['local_file_name'];
        }
        if (encryptionMetadata['original_file_extension'] != null) {
          request.fields['original_file_extension'] = encryptionMetadata['original_file_extension'];
        }
        print('🔐 MediaService.uploadVideo - Invio metadati cifratura: iv=${encryptionMetadata['iv'] != null}, mac=${encryptionMetadata['mac'] != null}');
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final result = jsonData['data'] as Map<String, dynamic>;
        
        // 🔐 Aggiungi metadata cifratura
        if (encryptionMetadata != null) {
          result['encryption'] = encryptionMetadata;
        }
        
        // 🧹 Rimuovi file temporaneo
        if (encryptionMetadata != null && fileToUpload.existsSync()) {
          await fileToUpload.delete();
        }
        
        return result;
      } else {
        print('Errore upload video: ${jsonData['error']}');
        return null;
      }
    } catch (e) {
      print('Errore upload video: $e');
      return null;
    }
  }

  /// Upload di un audio
  Future<Map<String, dynamic>?> uploadAudio({
    required String userId,
    required String chatId,
    required File audio,
    String duration = '00:00',
    String? recipientId, // 🆕 Per cifratura E2E
    bool shouldEncrypt = false, // 🆕 Flag per abilitare cifratura
  }) async {
    try {
      // Ottimizza l'audio se necessario
      final optimizedAudio = await _optimizeAudio(audio);
      
      File fileToUpload = optimizedAudio;
      Map<String, dynamic>? encryptionMetadata;

      // 🔐 CIFRATURA E2E
      final encryptionResult = await _encryptFileIfNeeded(
        file: optimizedAudio,
        recipientId: recipientId,
        shouldEncrypt: shouldEncrypt,
      );
      
      if (encryptionResult != null) {
        fileToUpload = encryptionResult['file'] as File;
        encryptionMetadata = encryptionResult['metadata'] as Map<String, dynamic>;
      }
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/audio/'),
      );

      // Aggiungi il file con content type appropriato
      final contentType = encryptionMetadata != null 
          ? MediaType('application', 'octet-stream') // File cifrato = binario generico
          : MediaType('audio', 'mpeg');
      
      var multipartFile = await http.MultipartFile.fromPath(
        'audio', 
        fileToUpload.path,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      request.fields['duration'] = duration;
      
      // 🔐 CORREZIONE: Passa il nome originale del file e metadati di cifratura per audio cifrati
      if (encryptionMetadata != null) {
        if (encryptionMetadata['original_file_name'] != null) {
          request.fields['original_file_name'] = encryptionMetadata['original_file_name'];
        }
        // 🔐 CRITICO: Passa iv, mac e altri metadati di cifratura durante l'upload
        if (encryptionMetadata['iv'] != null) {
          request.fields['iv'] = encryptionMetadata['iv'];
        }
        if (encryptionMetadata['mac'] != null) {
          request.fields['mac'] = encryptionMetadata['mac'];
        }
        if (encryptionMetadata['encrypted'] != null) {
          request.fields['encrypted'] = encryptionMetadata['encrypted'].toString();
        }
        if (encryptionMetadata['original_size'] != null) {
          request.fields['original_size'] = encryptionMetadata['original_size'].toString();
        }
        if (encryptionMetadata['local_file_name'] != null) {
          request.fields['local_file_name'] = encryptionMetadata['local_file_name'];
        }
        if (encryptionMetadata['original_file_extension'] != null) {
          request.fields['original_file_extension'] = encryptionMetadata['original_file_extension'];
        }
        print('🔐 MediaService.uploadAudio - Invio metadati cifratura: iv=${encryptionMetadata['iv'] != null}, mac=${encryptionMetadata['mac'] != null}');
      }

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final result = jsonData['data'] as Map<String, dynamic>;
        
        // 🔐 Aggiungi metadata cifratura se presente
        if (encryptionMetadata != null) {
          result['encryption'] = encryptionMetadata;
        }
        
        // 🧹 Rimuovi file temporaneo cifrato
        if (shouldEncrypt && encryptionMetadata != null && fileToUpload.existsSync()) {
          await fileToUpload.delete();
          print('🧹 MediaService.uploadAudio - File temporaneo cifrato eliminato');
        }
        
        return result;
      } else {
        print('Errore upload audio: ${jsonData['error']}');
        return null;
      }
    } catch (e) {
      print('Errore upload audio: $e');
      return null;
    }
  }

  /// Salva posizione geografica
  Future<Map<String, dynamic>?> saveLocation({
    required String userId,
    required String chatId,
    required double latitude,
    required double longitude,
    String address = '',
    String city = '',
    String country = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/save/location/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'chat_id': chatId,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'city': city,
          'country': country,
        }),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        var jsonData = json.decode(response.body);
        print('Errore salvataggio posizione: ${jsonData['error']}');
        return null;
      }
    } catch (e) {
      print('Errore salvataggio posizione: $e');
      return null;
    }
  }

  /// Salva contatto
  Future<Map<String, dynamic>?> saveContact({
    required String userId,
    required String chatId,
    required String name,
    required String phone,
    String email = '',
    String organization = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/save/contact/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'chat_id': chatId,
          'name': name,
          'phone': phone,
          'email': email,
          'organization': organization,
        }),
      );

      if (response.statusCode == 200) {
        var jsonData = json.decode(response.body);
        return jsonData['data'];
      } else {
        var jsonData = json.decode(response.body);
        print('Errore salvataggio contatto: ${jsonData['error']}');
        return null;
      }
    } catch (e) {
      print('Errore salvataggio contatto: $e');
      return null;
    }
  }

  /// Scarica un file
  Future<File?> downloadFile(String fileUrl, String fileName) async {
    try {
      final response = await http.get(Uri.parse(fileUrl));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      return null;
    } catch (e) {
      print('Errore download file: $e');
      return null;
    }
  }

  /// Seleziona foto dalla galleria
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Errore selezione immagine: $e');
      return null;
    }
  }

  /// Seleziona video dalla galleria
  Future<File?> pickVideoFromGallery() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );

      if (video != null) {
        return File(video.path);
      }
      return null;
    } catch (e) {
      print('Errore selezione video: $e');
      return null;
    }
  }

  /// Seleziona contatto - Temporaneamente disabilitato
  Future<dynamic> pickContact() async {
    try {
      // final Contact? contact = await ContactsService.openDeviceContactPicker();
      // return contact;
      print('Selezione contatti temporaneamente disabilitata per test Android');
      return null;
    } catch (e) {
      print('Errore selezione contatto: $e');
      return null;
    }
  }

  /// Ottieni posizione corrente
  Future<dynamic> getCurrentPosition() async {
    try {
      // Richiedi permessi
      var status = await Permission.location.request();
      if (status != PermissionStatus.granted) {
        return null;
      }

      // return await Geolocator.getCurrentPosition( // Temporaneamente disabilitato per problemi iOS
      //   desiredAccuracy: LocationAccuracy.high,
      // );
      return null; // Temporaneamente disabilitato per problemi iOS
    } catch (e) {
      print('Errore recupero posizione: $e');
      return null;
    }
  }

  /// Ottieni indirizzo da coordinate
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      // Qui implementeresti la geocoding inversa
      // Per ora restituiamo un indirizzo mock
      return 'Via Roma, 123, Milano, Italia';
    } catch (e) {
      print('Errore geocoding inversa: $e');
      return 'Posizione sconosciuta';
    }
  }

  /// Seleziona file di documenti
  Future<File?> pickDocument() async {
    try {
      print('📄 MediaService.pickDocument - Apertura file picker...');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'],
        allowMultiple: false,
        withData: true,  // 🆕 IMPORTANTE per iOS: carica i bytes
      );

      print('📄 MediaService.pickDocument - Risultato: ${result != null ? 'File selezionato' : 'Nessun file'}');

      if (result != null) {
        final platformFile = result.files.single;
        
        // 🆕 CORREZIONE iOS: Controlla prima path, poi usa bytes
        if (platformFile.path != null) {
          // Android o file locale iOS: usa path diretto
          final file = File(platformFile.path!);
          print('✅ MediaService.pickDocument - File path: ${file.path}');
          print('✅ MediaService.pickDocument - File name: ${file.path.split('/').last}');
          return file;
        } else if (platformFile.bytes != null) {
          // 🆕 iOS iCloud/protetto: crea file temporaneo dai bytes
          print('📱 MediaService.pickDocument - iOS: path null, usando bytes...');
          print('📱 MediaService.pickDocument - Bytes length: ${platformFile.bytes!.length}');
          print('📱 MediaService.pickDocument - File name: ${platformFile.name}');
          
          // Crea file temporaneo nella directory temporanea dell'app
          final tempDir = await getTemporaryDirectory();
          final fileName = platformFile.name;
          final tempFile = File('${tempDir.path}/$fileName');
          
          // Scrivi i bytes nel file temporaneo
          await tempFile.writeAsBytes(platformFile.bytes!);
          
          print('✅ MediaService.pickDocument - File temporaneo creato: ${tempFile.path}');
          print('✅ MediaService.pickDocument - File size: ${await tempFile.length()} bytes');
          
          return tempFile;
        } else {
          print('❌ MediaService.pickDocument - Né path né bytes disponibili');
          return null;
        }
      }
      
      print('⚠️ MediaService.pickDocument - Nessun file selezionato');
      return null;
    } catch (e) {
      print('❌ MediaService.pickDocument - Errore: $e');
      print('❌ MediaService.pickDocument - Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Rileva il content type per le immagini basato sull'estensione
  MediaType _getImageContentType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'tiff':
      case 'tif':
        return MediaType('image', 'tiff');
      default:
        return MediaType('image', 'jpeg'); // Default fallback
    }
  }

  /// Rileva il content type per i video basato sull'estensione
  MediaType _getVideoContentType(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'mpeg':
      case 'mpg':
        return MediaType('video', 'mpeg');
      case 'mkv':
        return MediaType('video', 'x-matroska');
      default:
        return MediaType('video', 'mp4'); // Default fallback
    }
  }

  /// Ottimizza un'immagine ridimensionandola se necessario
  Future<File> _optimizeImage(File imageFile) async {
    try {
      // Controlla la dimensione del file
      final fileSize = await imageFile.length();
      final maxSize = 5 * 1024 * 1024; // 5MB
      
      if (fileSize <= maxSize) {
        return imageFile; // File già ottimizzato
      }

      // Carica l'immagine
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        return imageFile; // Fallback se non riesce a decodificare
      }

      // Calcola le nuove dimensioni mantenendo l'aspect ratio
      final maxWidth = 1920; // Max width per chat
      final maxHeight = 1080; // Max height per chat
      
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > maxWidth || image.height > maxHeight) {
        final aspectRatio = image.width / image.height;
        
        if (image.width > image.height) {
          newWidth = maxWidth;
          newHeight = (maxWidth / aspectRatio).round();
        } else {
          newHeight = maxHeight;
          newWidth = (maxHeight * aspectRatio).round();
        }
      }

      // Ridimensiona l'immagine
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.average,
      );

      // Salva l'immagine ottimizzata
      final optimizedBytes = img.encodeJpg(resizedImage, quality: 85);
      final tempDir = await Directory.systemTemp.createTemp();
      final optimizedFile = File('${tempDir.path}/optimized_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await optimizedFile.writeAsBytes(optimizedBytes);

      print('🖼️ Immagine ottimizzata: ${fileSize ~/ 1024}KB -> ${optimizedBytes.length ~/ 1024}KB');
      return optimizedFile;
    } catch (e) {
      print('Errore ottimizzazione immagine: $e');
      return imageFile; // Fallback al file originale
    }
  }

  /// Ottimizza un video ridimensionandolo se necessario
  Future<File> _optimizeVideo(File videoFile) async {
    try {
      // Controlla la dimensione del file
      final fileSize = await videoFile.length();
      final maxSize = 50 * 1024 * 1024; // 50MB
      
      if (fileSize <= maxSize) {
        return videoFile; // File già ottimizzato
      }

      // Per ora, per semplicità, restituiamo il file originale
      // In un'implementazione completa, useresti FFmpeg per la compressione video
      print('🎥 Video grande rilevato: ${fileSize ~/ (1024 * 1024)}MB (ottimizzazione non implementata)');
      return videoFile;
    } catch (e) {
      print('Errore ottimizzazione video: $e');
      return videoFile; // Fallback al file originale
    }
  }

  /// Ottimizza un file audio ridimensionandolo se necessario
  Future<File> _optimizeAudio(File audioFile) async {
    try {
      // Controlla la dimensione del file
      final fileSize = await audioFile.length();
      final maxSize = 10 * 1024 * 1024; // 10MB
      
      if (fileSize <= maxSize) {
        return audioFile; // File già ottimizzato
      }

      // Per ora, per semplicità, restituiamo il file originale
      // In un'implementazione completa, useresti FFmpeg per la compressione audio
      print('🎵 Audio grande rilevato: ${fileSize ~/ (1024 * 1024)}MB (ottimizzazione non implementata)');
      return audioFile;
    } catch (e) {
      print('Errore ottimizzazione audio: $e');
      return audioFile; // Fallback al file originale
    }
  }

  /// Scatta foto dalla fotocamera
  Future<File?> pickImageFromCamera() async {
    print('📷 MediaService.pickImageFromCamera - INIZIO scatto foto');
    try {
      // Richiedi permessi
      var status = await Permission.camera.request();
      print('📷 MediaService.pickImageFromCamera - Stato permessi fotocamera: $status');
      if (status != PermissionStatus.granted) {
        print('❌ MediaService.pickImageFromCamera - Permessi fotocamera negati');
        return null;
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null) {
        return File(photo.path);
      }
      return null;
    } catch (e) {
      print('Errore scatto foto: $e');
      return null;
    }
  }

  /// Registra video dalla fotocamera
  Future<File?> pickVideoFromCamera() async {
    print('🎥 MediaService.pickVideoFromCamera - INIZIO registrazione video');
    try {
      // Richiedi permessi
      var cameraStatus = await Permission.camera.request();
      var microphoneStatus = await Permission.microphone.request();
      print('🎥 MediaService.pickVideoFromCamera - Permessi fotocamera: $cameraStatus, microfono: $microphoneStatus');
      
      if (cameraStatus != PermissionStatus.granted || 
          microphoneStatus != PermissionStatus.granted) {
        print('❌ MediaService.pickVideoFromCamera - Permessi negati');
        return null;
      }

      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
      );

      if (video != null) {
        return File(video.path);
      }
      return null;
    } catch (e) {
      print('Errore registrazione video: $e');
      return null;
    }
  }

  // Audio recording methods
  // final Record _audioRecorder = Record(); // API cambiata nella versione 6.x

  /// Inizia la registrazione audio
  Future<bool> startRecording() async {
    try {
      print('🎤 MediaService.startRecording - Inizio registrazione audio');
      
      // Controlla permessi attuali
      var currentStatus = await Permission.microphone.status;
      print('🎤 MediaService.startRecording - Stato permessi attuale: $currentStatus');
      
      // MODALITÀ SIMULAZIONE: Se i permessi sono negati, simula la registrazione
      if (currentStatus == PermissionStatus.permanentlyDenied || currentStatus == PermissionStatus.denied) {
        print('🎤 MediaService.startRecording - MODALITÀ SIMULAZIONE: Permessi negati ($currentStatus)');
        print('✅ MediaService.startRecording - Simulando registrazione per test...');
        return true; // Simula successo
      }
      
      // Richiedi permessi se non concessi
      if (currentStatus != PermissionStatus.granted) {
        print('🎤 MediaService.startRecording - Richiedendo permessi microfono...');
        var status = await Permission.microphone.request();
        print('🎤 MediaService.startRecording - Risposta permessi: $status');
        
        if (status != PermissionStatus.granted) {
          print('❌ MediaService.startRecording - Permessi microfono negati: $status');
          // FALLBACK: Attiva modalità simulazione
          print('🎤 MediaService.startRecording - MODALITÀ SIMULAZIONE: Attivata per test');
          return true; // Simula successo per test
        }
      }

      // Verifica se la registrazione è supportata
      // if (await _audioRecorder.hasPermission()) { // API cambiata nella versione 6.x
        // Ottieni directory temporanea per salvare il file
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // Inizia la registrazione
        // await _audioRecorder.start( // API cambiata nella versione 6.x
        //   path: filePath,
        //   encoder: AudioEncoder.aacLc,
        //   bitRate: 128000,
        //   samplingRate: 44100,
        // );
        
        print('✅ MediaService.startRecording - Registrazione audio iniziata (simulazione): $filePath');
        return true;
      // } else {
      //   print('❌ MediaService.startRecording - Permessi microfono non disponibili');
      //   return false;
      // }
    } catch (e) {
      print('❌ MediaService.startRecording - Errore avvio registrazione: $e');
      return false;
    }
  }

  /// Ferma la registrazione audio
  Future<File?> stopRecording() async {
    print('🎤 MediaService.stopRecording - Arresto registrazione audio');
    
    // CONTROLLA SUBITO se siamo in modalità simulazione
    var currentStatus = await Permission.microphone.status;
    print('🎤 MediaService.stopRecording - Stato permessi: $currentStatus');
    
    if (currentStatus == PermissionStatus.permanentlyDenied || currentStatus == PermissionStatus.denied) {
      print('🎤 MediaService.stopRecording - MODALITÀ SIMULAZIONE: Creando file audio fittizio...');
      
      try {
        // Crea un file audio fittizio per test
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/simulated_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
        
        // Scrive contenuto fittizio (simulazione)
        await tempFile.writeAsString('SIMULATED_AUDIO_DATA');
        print('✅ MediaService.stopRecording - File audio simulato creato: ${tempFile.path}');
        return tempFile;
      } catch (e) {
        print('❌ MediaService.stopRecording - Errore creazione file simulato: $e');
        return null;
      }
    }
    
    // SOLO se non siamo in simulazione, prova la registrazione reale
    try {
      print('🎤 MediaService.stopRecording - Tentativo registrazione reale...');
      // final path = await _audioRecorder.stop(); // API cambiata nella versione 6.x
      
      // Simulazione per ora
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/simulated_audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
      await tempFile.writeAsString('SIMULATED_AUDIO_DATA');
      print('✅ MediaService.stopRecording - File audio simulato creato: ${tempFile.path}');
      return tempFile;
      
      // if (path != null) {
      //   final audioFile = File(path);
      //   if (await audioFile.exists()) {
      //     print('✅ MediaService.stopRecording - File audio salvato: $path');
      //     return audioFile;
      //   } else {
      //     print('❌ MediaService.stopRecording - File audio non trovato: $path');
      //     return null;
      //   }
      // } else {
      //   print('❌ MediaService.stopRecording - Nessun percorso file ricevuto');
      //   return null;
      // }
    } catch (e) {
      print('❌ MediaService.stopRecording - Errore stop registrazione: $e');
      return null;
    }
  }

  /// Cancella la registrazione audio
  Future<void> cancelRecording() async {
    try {
      print('🎤 MediaService.cancelRecording - Cancellazione registrazione audio');
      
      // Controlla se siamo in modalità simulazione
      var currentStatus = await Permission.microphone.status;
      if (currentStatus == PermissionStatus.permanentlyDenied || currentStatus == PermissionStatus.denied) {
        print('🎤 MediaService.cancelRecording - MODALITÀ SIMULAZIONE: Cancellazione simulata');
        print('✅ MediaService.cancelRecording - Registrazione simulata cancellata');
        return;
      }
      
      // Cancellazione reale
      // await _audioRecorder.stop(); // API cambiata nella versione 6.x
      
      print('✅ MediaService.cancelRecording - Registrazione cancellata');
    } catch (e) {
      print('❌ MediaService.cancelRecording - Errore cancellazione registrazione: $e');
    }
  }

  /// 🔐 Scarica file da URL (cifrato o in chiaro)
  Future<Uint8List?> downloadFileBytes(String url) async {
    try {
      print('⬇️ MediaService.downloadFileBytes - Download da: $url');
      
      final request = http.Request('GET', Uri.parse(url));
      // 🔐 IMPORTANTE: NON aggiungere header Range per evitare Partial Content
      // Il server potrebbe servire 206 se rileva Range header, quindi evitiamolo
      request.headers['Accept'] = '*/*';
      request.headers['Connection'] = 'close'; // Evita connection pooling che potrebbe causare problemi
      
      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        final bytes = await streamedResponse.stream.toList();
        final totalBytes = bytes.fold<int>(0, (sum, chunk) => sum + chunk.length);
        final result = Uint8List(totalBytes);
        int offset = 0;
        for (final chunk in bytes) {
          result.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }
        
        print('✅ MediaService.downloadFileBytes - Download completato: ${result.length} bytes');
        print('   📦 Content-Type: ${streamedResponse.headers['content-type']}');
        print('   📦 Content-Length: ${streamedResponse.headers['content-length']}');
        print('   📦 Accept-Ranges: ${streamedResponse.headers['accept-ranges']}');
        
        return result;
      } else if (streamedResponse.statusCode == 206) {
        // 🔐 Gestisci Partial Content (Range Request)
        print('⚠️ MediaService.downloadFileBytes - Ricevuto 206 Partial Content');
        print('   📦 Content-Range: ${streamedResponse.headers['content-range']}');
        
        // Per video, potrebbe essere necessario scaricare tutto il file senza range
        // Rifai la richiesta senza Range header
        final fullRequest = http.Request('GET', Uri.parse(url));
        final fullResponse = await fullRequest.send();
        
        if (fullResponse.statusCode == 200) {
          final bytes = await fullResponse.stream.toList();
          final totalBytes = bytes.fold<int>(0, (sum, chunk) => sum + chunk.length);
          final result = Uint8List(totalBytes);
          int offset = 0;
          for (final chunk in bytes) {
            result.setRange(offset, offset + chunk.length, chunk);
            offset += chunk.length;
          }
          
          print('✅ MediaService.downloadFileBytes - Download completo dopo retry: ${result.length} bytes');
          return result;
        }
      } else {
        print('❌ MediaService.downloadFileBytes - Errore HTTP: ${streamedResponse.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ MediaService.downloadFileBytes - Errore: $e');
      print('   StackTrace: $stackTrace');
      return null;
    }
    return null;
  }

  /// 🔐 Scarica E decifra file cifrato
  Future<Uint8List?> downloadAndDecryptFile({
    required String url,
    required String senderId,
    required Map<String, dynamic> encryptionMetadata,
  }) async {
    try {
      print('🔐 MediaService.downloadAndDecryptFile - Download file cifrato...');
      
      // 1. Scarica bytes cifrati
      final encryptedBytes = await downloadFileBytes(url);
      if (encryptedBytes == null) {
        throw Exception('Download fallito');
      }
      
      print('🔐 MediaService.downloadAndDecryptFile - File scaricato: ${encryptedBytes.length} bytes');
      
      // 2. Prepara dati per decifratura
      print('🔐 MediaService.downloadAndDecryptFile - Preparazione dati per decifratura...');
      print('   📦 encryptionMetadata keys: ${encryptionMetadata.keys.toList()}');
      print('   📦 iv type: ${encryptionMetadata['iv'].runtimeType}, value: ${encryptionMetadata['iv']}');
      print('   📦 mac type: ${encryptionMetadata['mac'].runtimeType}, value: ${encryptionMetadata['mac']}');
      
      // Verifica che IV e MAC siano stringhe base64 valide
      final ivStr = encryptionMetadata['iv'] as String?;
      final macStr = encryptionMetadata['mac'] as String?;
      
      if (ivStr == null || macStr == null) {
        throw Exception('IV o MAC mancanti nei metadata');
      }
      
      // Assicurati che siano già in base64 (non decodificarli di nuovo)
      final encryptedData = {
        'ciphertext': base64.encode(encryptedBytes),
        'iv': ivStr,  // Già in base64
        'mac': macStr,  // Già in base64
      };
      
      print('🔐 MediaService.downloadAndDecryptFile - Dati preparati:');
      print('   📦 encryptedBytes scaricati: ${encryptedBytes.length} bytes');
      print('   📦 ciphertext length (base64): ${(encryptedData['ciphertext'] as String).length}');
      print('   📦 ciphertext first 50 chars: ${(encryptedData['ciphertext'] as String).substring(0, (encryptedData['ciphertext'] as String).length > 50 ? 50 : (encryptedData['ciphertext'] as String).length)}...');
      print('   📦 ciphertext last 50 chars: ...${(encryptedData['ciphertext'] as String).substring((encryptedData['ciphertext'] as String).length > 50 ? (encryptedData['ciphertext'] as String).length - 50 : 0)}');
      print('   📦 iv (base64): ${ivStr.length > 30 ? ivStr.substring(0, 30) + "..." : ivStr}');
      print('   📦 mac (base64): ${macStr.length > 30 ? macStr.substring(0, 30) + "..." : macStr}');
      
      // 🔍 VERIFICA: Decodifica il ciphertext per vedere se corrisponde ai bytes scaricati
      try {
        final decodedCiphertext = base64.decode(encryptedData['ciphertext'] as String);
        print('   🔍 Decoded ciphertext: ${decodedCiphertext.length} bytes');
        print('   🔍 encryptedBytes == decodedCiphertext: ${encryptedBytes.length == decodedCiphertext.length}');
        if (encryptedBytes.length == decodedCiphertext.length) {
          bool bytesMatch = true;
          for (int i = 0; i < encryptedBytes.length && i < 100; i++) {
            if (encryptedBytes[i] != decodedCiphertext[i]) {
              bytesMatch = false;
              print('   ❌ Bytes differiscono alla posizione $i: ${encryptedBytes[i]} vs ${decodedCiphertext[i]}');
              break;
            }
          }
          if (bytesMatch) {
            print('   ✅ Primi 100 bytes corrispondono!');
          }
        }
      } catch (e) {
        print('   ⚠️ Errore verifica bytes: $e');
      }
      
      // 3. Decifra
      print('🔐 MediaService.downloadAndDecryptFile - Avvio decifratura...');
      final decryptedBytes = await E2EManager.decryptFileBytes(
        senderId,
        encryptedData,
      );
      
      if (decryptedBytes == null) {
        throw Exception('Decifratura fallita');
      }
      
      print('✅ MediaService.downloadAndDecryptFile - File decifrato: ${decryptedBytes.length} bytes');
      return decryptedBytes;
      
    } catch (e) {
      print('❌ MediaService.downloadAndDecryptFile - Errore: $e');
      return null;
    }
  }

  /// 🔐 Helper: Verifica se un allegato è cifrato
  static bool isAttachmentEncrypted(Map<String, dynamic>? metadata) {
    if (metadata == null) return false;
    
    // Controlla se esiste il campo 'encryption' con i metadata E2E
    if (metadata.containsKey('encryption')) {
      final encryption = metadata['encryption'] as Map<String, dynamic>?;
      return encryption?['encrypted'] == true;
    }
    
    // Fallback: controlla direttamente nei metadata
    return metadata['encrypted'] == true && 
           metadata.containsKey('iv') && 
           metadata.containsKey('mac');
  }

  /// 🔐 Helper: Estrai encryption metadata da metadata allegato
  static Map<String, dynamic>? getEncryptionMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) {
      print('🔐 MediaService.getEncryptionMetadata - metadata è NULL');
      return null;
    }
    
    print('🔐 MediaService.getEncryptionMetadata - Cerca metadata in: ${metadata.keys.toList()}');
    
    // Caso 1: Metadata dentro campo 'encryption'
    if (metadata.containsKey('encryption')) {
      final encryption = metadata['encryption'] as Map<String, dynamic>?;
      print('   ✅ Trovati in metadata["encryption"]: ${encryption?.keys.toList()}');
      if (encryption != null && encryption['iv'] != null && encryption['mac'] != null) {
        return encryption;
      }
    }
    
    // Caso 2: Metadata direttamente nel root
    if (metadata['encrypted'] == true || metadata.containsKey('iv')) {
      print('   ✅ Trovati direttamente nel root');
      if (metadata['iv'] != null && metadata['mac'] != null) {
        return {
          'iv': metadata['iv'],
          'mac': metadata['mac'],
          'encrypted': metadata['encrypted'] ?? true,
          if (metadata['original_size'] != null) 'original_size': metadata['original_size'],
          if (metadata['original_file_name'] != null) 'original_file_name': metadata['original_file_name'],
          if (metadata['original_file_extension'] != null) 'original_file_extension': metadata['original_file_extension'],
          if (metadata['local_file_name'] != null) 'local_file_name': metadata['local_file_name'],
        };
      }
    }
    
    // Caso 3: Cerca in nested metadata (per messaggi real-time)
    if (metadata.containsKey('metadata') && metadata['metadata'] is Map) {
      final nestedMeta = metadata['metadata'] as Map<String, dynamic>;
      print('   🔍 Cerca in metadata["metadata"]: ${nestedMeta.keys.toList()}');
      
      if (nestedMeta.containsKey('encryption')) {
        final enc = nestedMeta['encryption'] as Map<String, dynamic>?;
        if (enc != null && enc['iv'] != null && enc['mac'] != null) {
          print('   ✅ Trovati in metadata["metadata"]["encryption"]');
          return enc;
        }
      }
      
      if (nestedMeta['iv'] != null && nestedMeta['mac'] != null) {
        print('   ✅ Trovati in metadata["metadata"] (root)');
        return {
          'iv': nestedMeta['iv'],
          'mac': nestedMeta['mac'],
          'encrypted': nestedMeta['encrypted'] ?? true,
        };
      }
    }
    
    print('   ❌ Nessun encryption metadata trovato!');
    return null;
  }
}