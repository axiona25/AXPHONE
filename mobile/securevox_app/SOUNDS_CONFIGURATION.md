# Configurazione Suoni SecureVOX

## Suoni di Sistema per Chiamate

SecureVOX utilizza suoni specifici per diversi tipi di chiamate per migliorare l'esperienza utente.

### Suoni Richiesti

#### Android (cartella `android/app/src/main/res/raw/`)
- `audio_call_ring.wav` - Suono per chiamate audio
- `video_call_ring.wav` - Suono per videochiamate  
- `group_call_ring.wav` - Suono per chiamate di gruppo

#### iOS (cartella `ios/Runner/Sounds/`)
- `audio_call_ring.wav` - Suono per chiamate audio
- `video_call_ring.wav` - Suono per videochiamate
- `group_call_ring.wav` - Suono per chiamate di gruppo

### Specifiche Tecniche

#### Formato Audio
- **Formato**: WAV
- **Frequenza**: 44.1 kHz
- **Bitrate**: 16-bit
- **Durata**: 2-4 secondi (loop automatico)
- **Canali**: Mono o Stereo

#### Caratteristiche Suoni

1. **Chiamate Audio** (`audio_call_ring.wav`)
   - Tono classico di chiamata
   - Frequenza media (800-1200 Hz)
   - Pattern: bip-bip-pausa

2. **Videochiamate** (`video_call_ring.wav`)
   - Tono più moderno e distintivo
   - Frequenza leggermente più alta (1000-1400 Hz)
   - Pattern: bip-bip-bip-pausa

3. **Chiamate di Gruppo** (`group_call_ring.wav`)
   - Tono distintivo per gruppi
   - Frequenza variabile (600-1600 Hz)
   - Pattern: bip-bip-bip-bip-pausa

### Fallback

Se i suoni personalizzati non sono disponibili, l'app utilizzerà automaticamente:
- **Android**: Suono predefinito del sistema per le chiamate
- **iOS**: Suono predefinito del sistema per le chiamate

### Configurazione Attuale

Il sistema è già configurato per utilizzare questi suoni:

```dart
// Android
sound: RawResourceAndroidNotificationSound('audio_call_ring')
sound: RawResourceAndroidNotificationSound('video_call_ring')
sound: RawResourceAndroidNotificationSound('group_call_ring')

// iOS
sound: 'audio_call_ring.wav'
sound: 'video_call_ring.wav'
sound: 'group_call_ring.wav'
```

### Canali di Notifica

L'app crea canali separati per ogni tipo di chiamata:

1. **securevox_audio_calls** - Chiamate audio
2. **securevox_video_calls** - Videochiamate
3. **securevox_group_calls** - Chiamate di gruppo
4. **securevox_messages** - Messaggi

### Test

Per testare i suoni:

1. Avvia l'app
2. Effettua una chiamata da un altro dispositivo
3. Verifica che il suono corretto venga riprodotto
4. Testa tutti i tipi di chiamata (audio, video, gruppo)

### Note di Sviluppo

- I suoni vengono riprodotti automaticamente quando l'app è in background
- Il sistema gestisce automaticamente il loop dei suoni
- I suoni si fermano quando l'utente risponde o rifiuta la chiamata
- Su iOS, i suoni rispettano le impostazioni "Non disturbare" dell'utente
