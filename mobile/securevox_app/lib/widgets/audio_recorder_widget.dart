import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/media_service.dart';

/// Widget per la registrazione audio
class AudioRecorderWidget extends StatefulWidget {
  final Function(File audioFile, String duration)? onRecordingComplete;
  final VoidCallback? onCancel;

  const AudioRecorderWidget({
    Key? key,
    this.onRecordingComplete,
    this.onCancel,
  }) : super(key: key);

  @override
  State<AudioRecorderWidget> createState() => _AudioRecorderWidgetState();
}

class _AudioRecorderWidgetState extends State<AudioRecorderWidget>
    with TickerProviderStateMixin {
  final MediaService _mediaService = MediaService();
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isRecording = false;
  int _recordingDuration = 0;
  late Stream<int> _timerStream;
  
  // NUOVO: Stato per anteprima audio
  File? _recordedAudio;
  bool _showPreview = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    print('🎤 AudioRecorderWidget._startRecording - PULSANTE CLICCATO!');
    
    final success = await _mediaService.startRecording();
    print('🎤 AudioRecorderWidget._startRecording - MediaService result: $success');
    
    if (success) {
      print('🎤 AudioRecorderWidget._startRecording - Avvio registrazione UI...');
      setState(() {
        _isRecording = true;
        _recordingDuration = 0;
      });
      _animationController.repeat(reverse: true);
      _startTimer();
      print('✅ AudioRecorderWidget._startRecording - Registrazione avviata');
    } else {
      print('❌ AudioRecorderWidget._startRecording - Registrazione fallita');
    }
  }

  Future<void> _stopRecording() async {
    print('🎤 AudioRecorderWidget._stopRecording - STOP CLICCATO!');
    
    final audioFile = await _mediaService.stopRecording();
    print('🎤 AudioRecorderWidget._stopRecording - AudioFile ricevuto: ${audioFile?.path}');
    
    if (audioFile != null) {
      print('🎤 AudioRecorderWidget._stopRecording - Impostando stato anteprima...');
      setState(() {
        _isRecording = false;
        _recordedAudio = audioFile;
        _showPreview = true; // NUOVO: Mostra anteprima invece di chiamare callback
      });
      _animationController.stop();
      _animationController.reset();
      
      print('🎤 AudioRecorderWidget._stopRecording - Stato aggiornato: _showPreview=$_showPreview');
    } else {
      print('❌ AudioRecorderWidget._stopRecording - AudioFile è null, tornando al microfono');
      setState(() {
        _isRecording = false;
      });
      _animationController.stop();
      _animationController.reset();
    }
  }

  Future<void> _cancelRecording() async {
    await _mediaService.cancelRecording();
    setState(() {
      _isRecording = false;
    });
    _animationController.stop();
    _animationController.reset();
    widget.onCancel?.call();
  }
  
  // NUOVO: Metodi per gestire anteprima audio
  void _sendAudio() {
    if (_recordedAudio != null) {
      final duration = _formatDuration(_recordingDuration);
      widget.onRecordingComplete?.call(_recordedAudio!, duration);
    }
  }
  
  void _cancelPreview() {
    setState(() {
      _recordedAudio = null;
      _showPreview = false;
      _isPlaying = false;
      _recordingDuration = 0;
    });
  }
  
  void _togglePlayback() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    // TODO: Implementare playback reale del file audio
    print('🎤 AudioRecorderWidget._togglePlayback - Play/Pause: $_isPlaying');
  }

  void _startTimer() {
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i + 1);
    _timerStream.listen((duration) {
      if (_isRecording) {
        setState(() {
          _recordingDuration = duration;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    print('🎤 AudioRecorderWidget.build - _showPreview: $_showPreview, _isRecording: $_isRecording');
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // NUOVO: Gestione tre stati - iniziale, registrazione, anteprima
          if (_showPreview) ...[
            _buildAudioPreview(),
          ] else ...[
            _buildRecordingInterface(),
          ],
        ],
      ),
    );
  }
  
  // NUOVO: Interfaccia di registrazione (stato iniziale + registrazione)
  Widget _buildRecordingInterface() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
          
          const SizedBox(height: 20),
          
          // Indicatore di registrazione
          if (_isRecording) ...[
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Registrazione in corso...',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _formatDuration(_recordingDuration),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
          ] else ...[
            // Pulsante microfono cliccabile
            GestureDetector(
              onTap: _startRecording,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  color: AppTheme.primaryColor,
                  size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Tocca per iniziare la registrazione',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 30),
          ],
          
          // Pulsanti di controllo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (!_isRecording) ...[
                // Pulsante inizia registrazione
                GestureDetector(
                  onTap: _startRecording,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ] else ...[
                // Pulsante ferma registrazione
                GestureDetector(
                  onTap: _stopRecording,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.stop,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
              
              // Pulsante cancella
              GestureDetector(
                onTap: _cancelRecording,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.grey,
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
        ],
      );
    }
  
  // NUOVO: Widget per anteprima audio
  Widget _buildAudioPreview() {
    print('🎤 AudioRecorderWidget._buildAudioPreview - COSTRUENDO ANTEPRIMA AUDIO');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        
        // Titolo
        const Text(
          'Anteprima Audio',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Player audio
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              // Pulsante play/pause
              GestureDetector(
                onTap: _togglePlayback,
                child: Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ),
              
              const SizedBox(width: 15),
              
              // Info audio
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Messaggio Audio',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Durata: ${_formatDuration(_recordingDuration)}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Icona audio
              Icon(
                Icons.audiotrack,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 30),
        
        // Pulsanti azione
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Pulsante cancella
            GestureDetector(
              onTap: _cancelPreview,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete,
                  color: Colors.red[600],
                  size: 25,
                ),
              ),
            ),
            
            // Pulsante invia
            GestureDetector(
              onTap: _sendAudio,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 25,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 30),
      ],
    );
  }
}

/// Handler per mostrare il widget di registrazione audio
class AudioRecorderHandler {
  static void showAudioRecorder(BuildContext context, {
    Function(File audioFile, String duration)? onRecordingComplete,
    VoidCallback? onCancel,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => AudioRecorderWidget(
        onRecordingComplete: (audioFile, duration) {
          Navigator.pop(context);
          onRecordingComplete?.call(audioFile, duration);
        },
        onCancel: () {
          Navigator.pop(context);
          onCancel?.call();
        },
      ),
    );
  }
}
