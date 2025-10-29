class LogoModel {
  final String id;
  final String name;
  final String assetPath;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;

  LogoModel({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LogoModel.fromJson(Map<String, dynamic> json) {
    return LogoModel(
      id: json['id'] as String,
      name: json['name'] as String,
      assetPath: json['assetPath'] as String,
      platform: json['platform'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'assetPath': assetPath,
      'platform': platform,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  LogoModel copyWith({
    String? id,
    String? name,
    String? assetPath,
    String? platform,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LogoModel(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
