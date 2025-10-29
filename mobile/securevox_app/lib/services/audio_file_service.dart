import 'dart:io';
// import 'package:file_picker/file_picker.dart';  // Temporaneamente disabilitato
import 'package:path/path.dart' as path;

/// Servizio per gestire la selezione di file audio dal dispositivo
class AudioFileService {
  
  /// Estensioni audio supportate
  static const List<String> supportedExtensions = [
    'mp3',
    'wav', 
    'wave',
    'm4a',
    'aac',
    'flac',
    'ogg',
    'wma'
  ];
  
  /// Seleziona un file audio dal dispositivo
  static Future<AudioFileData?> pickAudioFile() async {
    // FilePicker temporaneamente disabilitato
    print('🎵 AudioFileService.pickAudioFile - FilePicker disabilitato');
    return null;
    
    /*
    try {
      print('🎵 AudioFileService.pickAudioFile - INIZIO selezione file audio');
      
      // Apri il file picker filtrato per file audio
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
        allowMultiple: false,
      );
      
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName = result.files.single.name;
        final fileSize = result.files.single.size;
        final fileExtension = path.extension(fileName).toLowerCase().replaceFirst('.', '');
        
        print('🎵 AudioFileService.pickAudioFile - File selezionato:');
        print('   Nome: $fileName');
        print('   Dimensione: ${_formatFileSize(fileSize)}');
        print('   Estensione: $fileExtension');
        print('   Percorso: ${file.path}');
        
        // Verifica che l'estensione sia supportata
        if (!supportedExtensions.contains(fileExtension)) {
          print('❌ AudioFileService.pickAudioFile - Estensione non supportata: $fileExtension');
          return null;
        }
        
        // Verifica che il file esista
        if (!await file.exists()) {
          print('❌ AudioFileService.pickAudioFile - File non trovato: ${file.path}');
          return null;
        }
        
        // Ottieni la durata del file audio (se possibile)
        final duration = await _getAudioDuration(file);
        
        final audioData = AudioFileData(
          file: file,
          fileName: fileName,
          fileSize: fileSize,
          fileExtension: fileExtension,
          duration: duration,
        );
        
        print('✅ AudioFileService.pickAudioFile - File audio pronto per l\'invio');
        return audioData;
        
      } else {
        print('📞 AudioFileService.pickAudioFile - Nessun file selezionato');
        return null;
      }
      
    } catch (e) {
      print('❌ AudioFileService.pickAudioFile - Errore selezione file audio: $e');
      return null;
    }
    */
  }
  
  /// Ottiene la durata di un file audio (implementazione base)
  static Future<String> _getAudioDuration(File audioFile) async {
    try {
      // TODO: Implementare lettura durata reale con libreria audio
      // Per ora ritorna una durata fittizia basata sulla dimensione del file
      final fileSizeKB = await audioFile.length() / 1024;
      final estimatedSeconds = (fileSizeKB / 100).round(); // Stima approssimativa
      
      final minutes = estimatedSeconds ~/ 60;
      final seconds = estimatedSeconds % 60;
      
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } catch (e) {
      print('⚠️ AudioFileService._getAudioDuration - Errore calcolo durata: $e');
      return '00:00';
    }
  }
  
  /// Formatta la dimensione del file in formato leggibile
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
  
  /// Verifica se un file è un audio supportato
  static bool isAudioFile(String fileName) {
    final extension = path.extension(fileName).toLowerCase().replaceFirst('.', '');
    return supportedExtensions.contains(extension);
  }
  
  /// Formatta i dati audio per la visualizzazione in chat
  static String formatAudioForDisplay(AudioFileData audioData) {
    return '🎵 ${audioData.fileName}\n'
           '⏱️ ${audioData.duration}\n'
           '📦 ${_formatFileSize(audioData.fileSize)}';
  }
}

/// Modello dati per un file audio
class AudioFileData {
  final File file;
  final String fileName;
  final int fileSize;
  final String fileExtension;
  final String duration;
  
  AudioFileData({
    required this.file,
    required this.fileName,
    required this.fileSize,
    required this.fileExtension,
    required this.duration,
  });
  
  /// Converte in JSON per l'invio al server
  Map<String, dynamic> toJson() => {
    'file_name': fileName,
    'file_size': fileSize,
    'file_extension': fileExtension,
    'duration': duration,
  };
  
  /// Crea da JSON ricevuto dal server
  factory AudioFileData.fromJson(Map<String, dynamic> json, File file) => AudioFileData(
    file: file,
    fileName: json['file_name'] ?? '',
    fileSize: json['file_size'] ?? 0,
    fileExtension: json['file_extension'] ?? '',
    duration: json['duration'] ?? '00:00',
  );
}
