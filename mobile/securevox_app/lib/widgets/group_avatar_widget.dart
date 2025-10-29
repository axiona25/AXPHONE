import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GroupAvatarWidget extends StatelessWidget {
  final List<String> memberAvatars;
  final List<String> memberNames;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const GroupAvatarWidget({
    super.key,
    required this.memberAvatars,
    required this.memberNames,
    this.size = 50,
    this.showBorder = true,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? Colors.white,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: _buildGroupAvatar(),
      ),
    );
  }

  Widget _buildGroupAvatar() {
    if (memberAvatars.isEmpty || memberNames.isEmpty) {
      return _buildDefaultGroupIcon();
    }

    final displayMembers = memberAvatars.take(4).toList();
    final displayNames = memberNames.take(4).toList();

    switch (displayMembers.length) {
      case 1:
        return _buildSingleMember(displayMembers[0], displayNames[0]);
      case 2:
        return _buildTwoMembers(displayMembers, displayNames);
      case 3:
        return _buildThreeMembers(displayMembers, displayNames);
      case 4:
      default:
        return _buildFourMembers(displayMembers, displayNames);
    }
  }

  Widget _buildDefaultGroupIcon() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.primaryGradient,
      ),
      child: const Center(
        child: Icon(
          Icons.group,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildSingleMember(String avatarUrl, String name) {
    if (avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildInitialsAvatar(name);
        },
      );
    }
    return _buildInitialsAvatar(name);
  }

  Widget _buildTwoMembers(List<String> avatars, List<String> names) {
    return Row(
      children: [
        Expanded(
          child: _buildMemberAvatar(
            avatars[0],
            names[0],
            const BorderRadius.only(
              topLeft: Radius.circular(25),
              bottomLeft: Radius.circular(25),
            ),
          ),
        ),
        Expanded(
          child: _buildMemberAvatar(
            avatars[1],
            names[1],
            const BorderRadius.only(
              topRight: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThreeMembers(List<String> avatars, List<String> names) {
    return Column(
      children: [
        // Prima riga: un membro che occupa metà
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildMemberAvatar(
                  avatars[0],
                  names[0],
                  const BorderRadius.only(
                    topLeft: Radius.circular(25),
                    bottomLeft: Radius.circular(12.5),
                  ),
                ),
              ),
              Expanded(
                child: _buildMemberAvatar(
                  avatars[1],
                  names[1],
                  const BorderRadius.only(
                    topRight: Radius.circular(25),
                    bottomRight: Radius.circular(12.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Seconda riga: un membro che occupa metà
        Expanded(
          child: _buildMemberAvatar(
            avatars[2],
            names[2],
            const BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFourMembers(List<String> avatars, List<String> names) {
    return Column(
      children: [
        // Prima riga: due membri
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildMemberAvatar(
                  avatars[0],
                  names[0],
                  const BorderRadius.only(
                    topLeft: Radius.circular(25),
                  ),
                ),
              ),
              Expanded(
                child: _buildMemberAvatar(
                  avatars[1],
                  names[1],
                  const BorderRadius.only(
                    topRight: Radius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Seconda riga: due membri
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildMemberAvatar(
                  avatars[2],
                  names[2],
                  const BorderRadius.only(
                    bottomLeft: Radius.circular(25),
                  ),
                ),
              ),
              Expanded(
                child: _buildMemberAvatar(
                  avatars[3],
                  names[3],
                  const BorderRadius.only(
                    bottomRight: Radius.circular(25),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemberAvatar(String avatarUrl, String name, BorderRadius borderRadius) {
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsContainer(name, borderRadius);
          },
        ),
      );
    }
    return _buildInitialsContainer(name, borderRadius);
  }

  Widget _buildInitialsContainer(String name, BorderRadius borderRadius) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: _getMemberGradient(name),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar(String name) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _getMemberGradient(name),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    
    final words = name.trim().split(' ');
    if (words.length >= 2) {
      // Se ci sono più nomi, prendi la prima lettera di ognuno (max 2)
      final initials = words.take(2).map((word) => word.isNotEmpty ? word[0] : '').join('');
      return initials.toUpperCase();
    } else {
      // Se c'è solo un nome, prendi le prime due lettere
      final singleName = words[0];
      return singleName.length >= 2 
          ? singleName.substring(0, 2).toUpperCase()
          : singleName[0].toUpperCase();
    }
  }

  LinearGradient _getMemberGradient(String name) {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFfa709a), Color(0xFFfee140)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFa8edea), Color(0xFFfed6e3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFff9a9e), Color(0xFFfecfef)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFffecd2), Color(0xFFfcb69f)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    
    final hash = name.hashCode;
    return gradients[hash.abs() % gradients.length];
  }
}

/// Widget semplificato per avatar di gruppo con dati mock
class MockGroupAvatarWidget extends StatelessWidget {
  final double size;
  final bool showBorder;

  const MockGroupAvatarWidget({
    super.key,
    this.size = 50,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    // Dati mock per il gruppo
    final mockAvatars = [
      '', // Nessuna foto - mostrerà iniziali
      '', // Nessuna foto - mostrerà iniziali
      '', // Nessuna foto - mostrerà iniziali
      '', // Nessuna foto - mostrerà iniziali
    ];

    final mockNames = [
      'Alex',
      'Sara',
      'Marco',
      'Lisa',
    ];

    return GroupAvatarWidget(
      memberAvatars: mockAvatars,
      memberNames: mockNames,
      size: size,
      showBorder: showBorder,
    );
  }
}
