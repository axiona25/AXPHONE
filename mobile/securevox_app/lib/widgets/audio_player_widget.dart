import 'package:flutter/material.dart';
// import 'package:audioplayers/audioplayers.dart'; // Temporaneamente disabilitato

/// Widget per riprodurre file audio nella chat
/// TEMPORANEAMENTE DISABILITATO - Audio player non disponibile
class AudioPlayerWidget extends StatefulWidget {
  final String audioUrl;
  final String duration;
  final bool isMe;

  const AudioPlayerWidget({
    Key? key,
    required this.audioUrl,
    required this.duration,
    required this.isMe,
  }) : super(key: key);

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  // Widget temporaneo per audio player disabilitato
  @override
  void initState() {
    super.initState();
    // Audio player temporaneamente disabilitato
  }

  @override
  void dispose() {
    // Nessuna risorsa da liberare
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Widget temporaneo per audio player disabilitato
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isMe 
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isMe 
              ? Theme.of(context).primaryColor.withOpacity(0.3)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.audiotrack,
            color: widget.isMe 
                ? Theme.of(context).primaryColor
                : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Audio temporaneamente non disponibile',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: widget.isMe 
                  ? Theme.of(context).primaryColor
                  : Colors.grey[700],
            ),
          ),
          const Spacer(),
          Text(
            widget.duration,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
