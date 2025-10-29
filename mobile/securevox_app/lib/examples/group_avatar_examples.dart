import 'package:flutter/material.dart';
import '../widgets/group_avatar_widget.dart';
import '../theme/app_theme.dart';

/// Esempi di utilizzo del GroupAvatarWidget
class GroupAvatarExamples extends StatelessWidget {
  const GroupAvatarExamples({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Avatar Multi-Immagini',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'Gruppi con 2 Membri',
              [
                _buildExample(
                  'Team Marketing',
                  ['Elena', 'Roberto'],
                  ['', ''],
                ),
                _buildExample(
                  'Coppia',
                  ['Marco', 'Lisa'],
                  ['', ''],
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSection(
              'Gruppi con 3 Membri',
              [
                _buildExample(
                  'Famiglia',
                  ['Mamma', 'Papà', 'Marco'],
                  ['', '', ''],
                ),
                _buildExample(
                  'Team Trio',
                  ['Alex', 'Sara', 'Mike'],
                  ['', '', ''],
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSection(
              'Gruppi con 4+ Membri',
              [
                _buildExample(
                  'Team Sviluppo',
                  ['Alex Linderson', 'Sarah Johnson', 'Mike Wilson', 'Emma Davis'],
                  ['', '', '', ''],
                ),
                _buildExample(
                  'Amici Università',
                  ['Luca', 'Giulia', 'Andrea', 'Chiara'],
                  ['', '', '', ''],
                ),
                _buildExample(
                  'Gruppo Grande',
                  ['Alice', 'Bob', 'Charlie', 'Diana', 'Eve'],
                  ['', '', '', '', ''],
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSection(
              'Diverse Dimensioni',
              [
                Row(
                  children: [
                    _buildSizeExample('Piccolo', 30),
                    const SizedBox(width: 20),
                    _buildSizeExample('Medio', 50),
                    const SizedBox(width: 20),
                    _buildSizeExample('Grande', 80),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSection(
              'Con Immagini Realistiche',
              [
                _buildMockExample(
                  'Team Design',
                  ['', ''], // Nessuna foto - mostrerà iniziali
                  ['Alex', 'Sara'],
                ),
                _buildMockExample(
                  'Squadra Vendite',
                  ['', '', ''], // Nessuna foto - mostrerà iniziali
                  ['Marco', 'Giulia', 'Luca'],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    );
  }

  Widget _buildExample(String name, List<String> members, List<String> avatars) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardColor),
      ),
      child: Row(
        children: [
          GroupAvatarWidget(
            memberAvatars: avatars,
            memberNames: members,
            size: 50,
            showBorder: true,
            borderColor: AppTheme.primaryColor,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${members.length} membri',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  members.join(', '),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockExample(String name, List<String> avatars, List<String> members) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardColor),
      ),
      child: Row(
        children: [
          GroupAvatarWidget(
            memberAvatars: avatars,
            memberNames: members,
            size: 60,
            showBorder: true,
            borderColor: AppTheme.primaryColor,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${members.length} membri con foto',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeExample(String label, double size) {
    return Column(
      children: [
        MockGroupAvatarWidget(
          size: size,
          showBorder: true,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          '${size.toInt()}px',
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
