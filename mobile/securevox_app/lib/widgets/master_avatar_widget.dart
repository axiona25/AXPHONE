import 'package:flutter/material.dart';
import '../services/master_avatar_service.dart';
import '../models/user_model.dart';

/// Widget helper per il MasterAvatarService
/// Questo è l'UNICO widget avatar che deve essere usato nell'app
/// Garantisce consistenza totale su tutte le schermate
class MasterAvatarWidget extends StatelessWidget {
  final String userId;
  final String userName;
  final String? profileImageUrl;
  final double size;
  final bool showOnlineIndicator;

  const MasterAvatarWidget({
    super.key,
    required this.userId,
    required this.userName,
    this.profileImageUrl,
    this.size = 48.0,
    this.showOnlineIndicator = false,
  });

  /// Constructor per UserModel
  MasterAvatarWidget.fromUser({
    super.key,
    required UserModel user,
    this.size = 48.0,
    this.showOnlineIndicator = false,
  }) : userId = user.id,
       userName = user.name,
       profileImageUrl = user.profileImage;

  /// Constructor per chat (usa lo stesso sistema)
  const MasterAvatarWidget.fromChat({
    super.key,
    required String chatId,
    required String chatName,
    String? avatarUrl,
    this.size = 48.0,
    this.showOnlineIndicator = false,
  }) : userId = chatId,
       userName = chatName,
       profileImageUrl = avatarUrl;

  @override
  Widget build(BuildContext context) {
    return MasterAvatarService().buildUserAvatar(
      userId: userId,
      userName: userName,
      profileImageUrl: profileImageUrl,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
    );
  }
}

/// Extension per facilitare l'uso con UserModel
extension UserModelMasterAvatar on UserModel {
  Widget buildMasterAvatar({
    double size = 48.0,
    bool showOnlineIndicator = false,
  }) {
    return MasterAvatarWidget.fromUser(
      user: this,
      size: size,
      showOnlineIndicator: showOnlineIndicator,
    );
  }
}
