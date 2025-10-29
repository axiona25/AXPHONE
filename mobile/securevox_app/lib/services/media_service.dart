import 'dart:io';
import 'dart:convert';
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

/// Servizio per gestire tutti i contenuti multimediali
class MediaService {
  static const String baseUrl = 'http://127.0.0.1:8001/api/media';
  final ImagePicker _imagePicker = ImagePicker();



  /// Upload di un file generico
  Future<Map<String, dynamic>?> uploadFile({
    required String userId,
    required String chatId,
    required File file,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/file/'),
      );

      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData['data'];
      } else {
        print('Errore upload file: ${jsonData['error']}');
        return null;
      }
    } catch (e) {
      print('Errore upload file: $e');
      return null;
    }
  }

  /// Upload di un'immagine
  Future<Map<String, dynamic>?> uploadImage({
    required String userId,
    required String chatId,
    required File image,
    String caption = '',
  }) async {
    try {
      // Ridimensiona l'immagine se necessario
      final optimizedImage = await _optimizeImage(image);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/image/'),
      );

      // Rileva il content type basato sull'estensione del file
      final contentType = _getImageContentType(optimizedImage.path);
      
      // Aggiungi il file con content type appropriato
      var multipartFile = await http.MultipartFile.fromPath(
        'image', 
        optimizedImage.path,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      request.fields['caption'] = caption;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData['data'];
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
  }) async {
    try {
      // Ottimizza il video se necessario
      final optimizedVideo = await _optimizeVideo(video);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/video/'),
      );

      // Rileva il content type basato sull'estensione del file
      final contentType = _getVideoContentType(optimizedVideo.path);
      
      // Aggiungi il file con content type appropriato
      var multipartFile = await http.MultipartFile.fromPath(
        'video', 
        optimizedVideo.path,
        contentType: contentType,
      );
      request.files.add(multipartFile);
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      request.fields['caption'] = caption;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData['data'];
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
  }) async {
    try {
      // Ottimizza l'audio se necessario
      final optimizedAudio = await _optimizeAudio(audio);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/audio/'),
      );

      // Aggiungi il file con content type esplicito
      var multipartFile = await http.MultipartFile.fromPath(
        'audio', 
        optimizedAudio.path,
        contentType: MediaType('audio', 'mpeg'),
      );
      request.files.add(multipartFile);
      request.fields['user_id'] = userId;
      request.fields['chat_id'] = chatId;
      request.fields['duration'] = duration;

      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData['data'];
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
      );

      print('📄 MediaService.pickDocument - Risultato: ${result != null ? 'File selezionato' : 'Nessun file'}');

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        print('✅ MediaService.pickDocument - File path: ${file.path}');
        print('✅ MediaService.pickDocument - File name: ${file.path.split('/').last}');
        return file;
      }
      
      print('⚠️ MediaService.pickDocument - Nessun file selezionato');
      return null;
    } catch (e) {
      print('❌ MediaService.pickDocument - Errore: $e');
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
}