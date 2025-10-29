import '../models/call_model.dart';
class CallModel {
  final String id;
  final String contactName;
  final String contactAvatar;
  final String? contactId; // ID dell'utente per avatar consistenti
  final String? callerId; // ID del chiamante
  final String? calleeId; // ID del ricevente
  final DateTime timestamp;
  final CallType type;
  final CallDirection direction;
  final CallStatus status;
  final Duration duration;
  final String? phoneNumber;

  CallModel({
    required this.id,
    required this.contactName,
    required this.contactAvatar,
    this.contactId,
    this.callerId,
    this.calleeId,
    required this.timestamp,
    required this.type,
    required this.direction,
    required this.status,
    required this.duration,
    this.phoneNumber,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'],
      contactName: json['contactName'],
      contactAvatar: json['contactAvatar'] ?? '',
      contactId: json['contactId'],
      callerId: json['callerId'],
      calleeId: json['calleeId'],
      timestamp: DateTime.parse(json['timestamp']),
      type: CallType.values.firstWhere((e) => e.name == json['type']),
      direction: CallDirection.values.firstWhere((e) => e.name == json['direction']),
      status: CallStatus.values.firstWhere((e) => e.name == json['status']),
      duration: Duration(seconds: json['duration'] ?? 0),
      phoneNumber: json['phoneNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactName': contactName,
      'contactAvatar': contactAvatar,
      'contactId': contactId,
      'callerId': callerId,
      'calleeId': calleeId,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'direction': direction.name,
      'status': status.name,
      'duration': duration.inSeconds,
      'phoneNumber': phoneNumber,
    };
  }
}

enum CallType {
  audio,
  video,
}

enum CallDirection {
  incoming,  // Ricevuta
  outgoing,  // Effettuata
  missed,    // Persa
}

enum CallStatus {
  completed, // Completata
  missed,    // Persa
  declined,  // Rifiutata
  cancelled, // Cancellata
  ringing,   // In corso/Squillante
  answered,  // Risposta
  ended,     // Terminata
}
