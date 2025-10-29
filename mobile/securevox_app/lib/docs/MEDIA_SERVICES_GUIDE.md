# Guida ai Servizi Multimediali - SecureVOX

## 📱 Panoramica

Il sistema di servizi multimediali di SecureVOX permette di gestire tutti i tipi di contenuti multimediali nelle chat, inclusi:
- **Messaggi di testo**
- **Messaggi audio** (registrazione vocale)
- **Foto** (galleria e fotocamera)
- **Video** (galleria e registrazione live)
- **Allegati** (documenti, file)
- **Posizioni geografiche**
- **Contatti**

## 🏗️ Architettura

### Backend Services (`server/src/api/media_service.py`)
- `upload_file()` - Upload file generici
- `upload_image()` - Upload immagini
- `upload_video()` - Upload video
- `upload_audio()` - Upload messaggi audio
- `save_location()` - Salvataggio posizioni
- `save_contact()` - Salvataggio contatti
- `download_file()` - Download file
- `get_thumbnail()` - Generazione thumbnail

### Frontend Services (`mobile/securevox_app/lib/services/media_service.dart`)
- `MediaService` - Servizio principale per upload/download
- `CameraService` - Gestione fotocamera e galleria
- `AudioRecorderService` - Registrazione audio
- `ContactService` - Gestione contatti
- `LocationService` - Geolocalizzazione
- `FileService` - Selezione file

## 🎯 Funzionalità Implementate

### 1. Icona Allegato (📎)
**Cliccando sull'icona allegato si apre un menu con:**
- 📷 **Foto dalla galleria**
- 🎥 **Video dalla galleria**
- 📄 **Documenti** (docx, xlsx, pptx, pdf, zip)
- 👤 **Contatti dalla rubrica**
- 📍 **Posizione geografica**
- 📷 **Fotocamera** (foto istantanea)
- 🎥 **Registra Video** (registrazione live)
- 🎤 **Audio** (registrazione vocale)

### 2. Icona Fotocamera (📷)
**Cliccando sull'icona fotocamera si apre un menu con:**
- 📸 **Scatta Foto** (foto istantanea)
- 🎥 **Registra Video** (registrazione live)

### 3. Icona Microfono (🎤)
**Cliccando sull'icona microfono si apre:**
- 🎙️ **Registratore Audio** con timer e controlli

## 🔧 Utilizzo

### Nel Chat Detail Screen

```dart
// I servizi sono già integrati nel ChatDetailScreen
// Basta cliccare sulle icone per attivare le funzionalità:

// Icona allegato (📎) - Menu completo
// Icona fotocamera (📷) - Menu fotocamera
// Icona microfono (🎤) - Registratore audio
```

### Esempio di utilizzo manuale

```dart
// Creazione di un messaggio multimediale
final message = MessageFactory.createImageMessage(
  id: '1',
  chatId: 'chat1',
  senderId: 'user1',
  isMe: false,
  imageUrl: 'https://example.com/image.jpg',
  time: '09:25',
);

// Rendering del messaggio
UniversalMessageWidget(message: message)
```

## 📋 Permessi Richiesti

### iOS (ios/Runner/Info.plist)
```xml
<key>NSCameraUsageDescription</key>
<string>L'app ha bisogno dell'accesso alla fotocamera per scattare foto e registrare video</string>
<key>NSMicrophoneUsageDescription</key>
<string>L'app ha bisogno dell'accesso al microfono per registrare messaggi audio</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>L'app ha bisogno dell'accesso alla galleria per selezionare foto e video</string>
<key>NSContactsUsageDescription</key>
<string>L'app ha bisogno dell'accesso ai contatti per condividere informazioni di contatto</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>L'app ha bisogno dell'accesso alla posizione per condividere la tua posizione</string>
```

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_CONTACTS" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## 🚀 Funzionalità Avanzate

### Upload con Progress
```dart
// Il sistema gestisce automaticamente:
// - Validazione dei file
// - Compressione delle immagini
// - Generazione di thumbnail per i video
// - Gestione degli errori
// - Feedback all'utente
```

### Tipi di File Supportati
- **Immagini**: PNG, JPEG, JPG
- **Video**: MP4, AVI, MOV
- **Audio**: MP3, WAV, M4A
- **Documenti**: DOCX, XLSX, PPTX, PDF, ZIP

### Limiti e Sicurezza
- **Dimensione massima file**: 50MB
- **Validazione tipo MIME**
- **Nomi file univoci**
- **Storage sicuro**
- **Controllo permessi**

## 🔄 Flusso di Lavoro

1. **Utente clicca su icona** (allegato/fotocamera/microfono)
2. **Richiesta permessi** (se necessario)
3. **Apertura interfaccia** (galleria/fotocamera/registratore)
4. **Selezione/creazione contenuto**
5. **Upload al backend**
6. **Creazione messaggio**
7. **Visualizzazione nella chat**

## 🎨 Personalizzazione

### Widget Standardizzati
Tutti i messaggi utilizzano widget standardizzati che garantiscono:
- **Consistenza visiva**
- **Allineamento perfetto**
- **Stile uniforme**
- **Responsività**

### Temi e Colori
```dart
// I widget utilizzano automaticamente:
// - AppTheme.primaryColor per i colori principali
// - Font Poppins per la tipografia
// - Stile coerente con il progetto
```

## 🐛 Debug e Logging

Il sistema include logging dettagliato per:
- Upload/download file
- Errori di permessi
- Problemi di rete
- Validazione file

```dart
// I log sono visibili nella console durante lo sviluppo
print('Upload completato: ${result['metadata']}');
print('Errore upload: $e');
```

## 📚 Esempi Pratici

### Creare un messaggio di test
```dart
// Utilizza TestMessageCreator per creare messaggi di esempio
final testMessages = TestMessageCreator.createTestMessages();
```

### Gestire errori di upload
```dart
try {
  final result = await _mediaService.uploadImage(...);
  if (result != null) {
    // Successo
  } else {
    // Errore gestito dal servizio
  }
} catch (e) {
  // Errore di rete o sistema
  print('Errore: $e');
}
```

## 🔮 Prossimi Sviluppi

- [ ] **Compressione automatica** delle immagini
- [ ] **Upload in background** per file grandi
- [ ] **Preview** dei file prima dell'invio
- [ ] **Modifica** foto e video
- [ ] **Stickers** e GIF
- [ ] **Condivisione** da altre app

---

**Nota**: Tutti i servizi sono completamente integrati e pronti all'uso. Il sistema gestisce automaticamente permessi, validazioni e feedback all'utente.
