import 'package:flutter/material.dart';
import '../services/unified_avatar_service.dart';
import '../models/user_model.dart';

/// Widget helper per avatar unificati
/// Semplifica l'uso del UnifiedAvatarService
class UnifiedAvatarWidget extends StatelessWidget {
  final String userId;
  final String userName;
  final String? profileImageUrl;
  final double size;
  final bool showOnlineIndicator;
  final bool isOnline;

  const UnifiedAvatarWidget({
    super.key,
    required this.userId,
    required this.userName,
    this.profileImageUrl,
    this.size = 48.0,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  });

  /// Constructor per UserModel
  const UnifiedAvatarWidget.fromUser({
    super.key,
    required UserModel user,
    this.size = 48.0,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  }) : userId = user.id,
       userName = user.name,
       profileImageUrl = user.profileImage;

  /// Constructor per chat
  const UnifiedAvatarWidget.fromChat({
    super.key,
    required String chatId,
    required String chatName,
    String? avatarUrl,
    this.size = 48.0,
    this.showOnlineIndicator = false,
    this.isOnline = false,
  }) : userId = chatId,
       userName = chatName,
       profileImageUrl = avatarUrl;

  @override
  Widget build(BuildContext context) {
    return UnifiedAvatarService.buildUserAvatar(
      userId: userId,
      userName: userName,
      profileImageUrl: profileImageUrl,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
    );
  }
}

/// Extension per facilitare l'uso con UserModel
extension UserModelAvatar on UserModel {
  Widget buildAvatar({
    double size = 48.0,
    bool showOnlineIndicator = false,
    bool isOnline = false,
  }) {
    return UnifiedAvatarWidget.fromUser(
      user: this,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
      isOnline: isOnline,
    );
  }
}
