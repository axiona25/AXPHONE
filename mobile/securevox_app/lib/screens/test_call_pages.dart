import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';

class TestCallPagesScreen extends StatelessWidget {
  const TestCallPagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final users = UserService.getRegisteredUsers();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Test Pagine Chiamata',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seleziona un utente per testare le pagine di chiamata:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            
            // Lista utenti per test
            Expanded(
              child: FutureBuilder<List<UserModel>>(
                future: users,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  final userList = snapshot.data ?? [];
                  return ListView.builder(
                    itemCount: userList.length,
                    itemBuilder: (context, index) {
                      final user = userList[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: AppTheme.surfaceColor,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                            ? NetworkImage(user.profileImage!)
                            : null,
                        child: user.profileImage == null || user.profileImage!.isEmpty
                            ? Text(
                                user.initials,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      title: Text(
                        user.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        user.email,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.grey[400],
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _handleMenuSelection(context, user.id, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'incoming_audio',
                            child: Text('Chiamata Audio in Arrivo'),
                          ),
                          const PopupMenuItem(
                            value: 'incoming_video',
                            child: Text('Chiamata Video in Arrivo'),
                          ),
                          const PopupMenuItem(
                            value: 'audio_call',
                            child: Text('Chiamata Audio Attiva'),
                          ),
                          const PopupMenuItem(
                            value: 'video_call',
                            child: Text('Chiamata Video Attiva'),
                          ),
                        ],
                        child: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                    },
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Pulsanti per test chiamate di gruppo
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _testGroupAudioCall(context),
                    icon: const Icon(Icons.group),
                    label: const Text('Test Audio Gruppo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _testGroupVideoCall(context),
                    icon: const Icon(Icons.videocam),
                    label: const Text('Test Video Gruppo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleMenuSelection(BuildContext context, String userId, String action) {
    switch (action) {
      case 'incoming_audio':
        context.go('/incoming-call/$userId?video=false');
        break;
      case 'incoming_video':
        context.go('/incoming-call/$userId?video=true');
        break;
      case 'audio_call':
        context.go('/audio-call/$userId');
        break;
      case 'video_call':
        context.go('/video-call/$userId');
        break;
    }
  }

  void _testGroupAudioCall(BuildContext context) async {
    final users = await UserService.getRegisteredUsers();
    final userIds = users.take(3).map((user) => user.id).join(',');
    context.go('/group-audio-call?users=$userIds');
  }

  void _testGroupVideoCall(BuildContext context) async {
    final users = await UserService.getRegisteredUsers();
    final userIds = users.take(3).map((user) => user.id).join(',');
    context.go('/group-video-call?users=$userIds');
  }
}
