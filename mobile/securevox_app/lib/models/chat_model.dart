class ChatModel {
  final String id;
  final String name;
  final String lastMessage;
  final DateTime timestamp;
  final String avatarUrl;
  final bool isOnline;
  final int unreadCount;
  final bool isGroup;
  final List<String>? groupMembers;
  final String? userId; // ID dell'utente per chat individuali
  final List<String> participants; // Lista dei partecipanti alla chat
  
  // NUOVO: Campi per sistema di gestazione
  final bool isInGestation; // True se la chat è in periodo di gestazione
  final bool isReadOnly; // True se la chat è in sola lettura
  final String? deletionRequestedBy; // ID utente che ha richiesto eliminazione
  final String? deletionRequestedByName; // Nome utente che ha richiesto eliminazione
  final DateTime? deletionRequestedAt; // Quando è stata richiesta l'eliminazione
  final DateTime? gestationExpiresAt; // Quando scade il periodo di gestazione
  final bool gestationNotificationShown; // True se la notifica è già stata mostrata

  const ChatModel({
    required this.id,
    required this.name,
    required this.lastMessage,
    required this.timestamp,
    required this.avatarUrl,
    required this.isOnline,
    required this.unreadCount,
    required this.isGroup,
    this.groupMembers,
    this.userId,
    this.participants = const [],
    // NUOVO: Campi gestazione
    this.isInGestation = false,
    this.isReadOnly = false,
    this.deletionRequestedBy,
    this.deletionRequestedByName,
    this.deletionRequestedAt,
    this.gestationExpiresAt,
    this.gestationNotificationShown = false,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      lastMessage: json['lastMessage'] ?? '',
      timestamp: json['timestamp'] != null 
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
      avatarUrl: json['avatarUrl'] ?? '',
      isOnline: json['isOnline'] ?? false,
      unreadCount: json['unreadCount'] ?? 0,
      isGroup: json['isGroup'] ?? false,
      groupMembers: json['groupMembers']?.cast<String>(),
      userId: json['userId'],
      participants: json['participants']?.cast<String>() ?? [],
      // NUOVO: Parsing campi gestazione
      isInGestation: json['is_in_gestation'] ?? false,
      isReadOnly: json['is_read_only'] ?? false,
      deletionRequestedBy: json['deletion_requested_by'],
      deletionRequestedByName: json['deletion_requested_by_name'],
      deletionRequestedAt: json['deletion_requested_at'] != null 
        ? DateTime.parse(json['deletion_requested_at'] as String)
        : null,
      gestationExpiresAt: json['gestation_expires_at'] != null 
        ? DateTime.parse(json['gestation_expires_at'] as String)
        : null,
      gestationNotificationShown: json['gestation_notification_shown'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lastMessage': lastMessage,
      'timestamp': timestamp.toIso8601String(),
      'avatarUrl': avatarUrl,
      'isOnline': isOnline,
      'unreadCount': unreadCount,
      'isGroup': isGroup,
      'groupMembers': groupMembers,
      'userId': userId,
      'participants': participants,
      // NUOVO: Campi gestazione
      'is_in_gestation': isInGestation,
      'is_read_only': isReadOnly,
      'deletion_requested_by': deletionRequestedBy,
      'deletion_requested_by_name': deletionRequestedByName,
      'deletion_requested_at': deletionRequestedAt?.toIso8601String(),
      'gestation_expires_at': gestationExpiresAt?.toIso8601String(),
      'gestation_notification_shown': gestationNotificationShown,
    };
  }

  ChatModel copyWith({
    String? id,
    String? name,
    String? lastMessage,
    DateTime? timestamp,
    String? avatarUrl,
    bool? isOnline,
    int? unreadCount,
    bool? isGroup,
    List<String>? groupMembers,
    String? userId,
    List<String>? participants,
    bool? isInGestation,
    bool? isReadOnly,
    String? deletionRequestedBy,
    String? deletionRequestedByName,
    DateTime? deletionRequestedAt,
    DateTime? gestationExpiresAt,
    bool? gestationNotificationShown,
  }) {
    return ChatModel(
      id: id ?? this.id,
      name: name ?? this.name,
      lastMessage: lastMessage ?? this.lastMessage,
      timestamp: timestamp ?? this.timestamp,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isOnline: isOnline ?? this.isOnline,
      unreadCount: unreadCount ?? this.unreadCount,
      isGroup: isGroup ?? this.isGroup,
      groupMembers: groupMembers ?? this.groupMembers,
      userId: userId ?? this.userId,
      participants: participants ?? this.participants,
      // NUOVO: Campi gestazione
      isInGestation: isInGestation ?? this.isInGestation,
      isReadOnly: isReadOnly ?? this.isReadOnly,
      deletionRequestedBy: deletionRequestedBy ?? this.deletionRequestedBy,
      deletionRequestedByName: deletionRequestedByName ?? this.deletionRequestedByName,
      deletionRequestedAt: deletionRequestedAt ?? this.deletionRequestedAt,
      gestationExpiresAt: gestationExpiresAt ?? this.gestationExpiresAt,
      gestationNotificationShown: gestationNotificationShown ?? this.gestationNotificationShown,
    );
  }
}
