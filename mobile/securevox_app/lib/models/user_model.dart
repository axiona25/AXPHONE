class UserModel {
  final String id;
  final String name;
  final String email;
  final String password; // In produzione dovrebbe essere hashata
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  
  // Profilo utente (opzionale)
  final String? profileImage;
  final String? bio;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? location;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.profileImage,
    this.bio,
    this.phone,
    this.dateOfBirth,
    this.location,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '', // Gestisce null, int e String
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
      isActive: json['isActive'] as bool? ?? true,
      profileImage: json['profileImage'] as String?,
      bio: json['bio'] as String?,
      phone: json['phone'] as String?,
      dateOfBirth: json['dateOfBirth'] != null 
          ? DateTime.parse(json['dateOfBirth'] as String)
          : null,
      location: json['location'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isActive': isActive,
      'profileImage': profileImage,
      'bio': bio,
      'phone': phone,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'location': location,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? profileImage,
    String? bio,
    String? phone,
    DateTime? dateOfBirth,
    String? location,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      profileImage: profileImage ?? this.profileImage,
      bio: bio ?? this.bio,
      phone: phone ?? this.phone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      location: location ?? this.location,
    );
  }

  // Metodo per verificare se l'utente ha un profilo completo
  bool get hasCompleteProfile {
    return profileImage != null && 
           bio != null && 
           phone != null && 
           dateOfBirth != null && 
           location != null;
  }

  // Metodo per ottenere le iniziali del nome
  String get initials {
    if (name.isEmpty) return 'U';
    
    final names = name.trim().split(' ');
    if (names.length >= 2) {
      // Se ci sono più nomi, prendi la prima lettera di ognuno (max 2)
      final initials = names.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
      return initials.toUpperCase();
    } else {
      // Se c'è solo un nome, prendi le prime due lettere
      final singleName = names[0];
      return singleName.length >= 2 
          ? singleName.substring(0, 2).toUpperCase()
          : singleName[0].toUpperCase();
    }
  }
}
