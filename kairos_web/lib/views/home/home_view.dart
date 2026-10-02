import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../services/theme_service.dart';

class HomeView extends StatelessWidget {
  final BibleController bibleController;
  final HymnController hymnController;
  final DevotionalController devotionalController;
  final void Function(int tabIndex) onNavigateToTab;

  const HomeView({
    super.key,
    required this.bibleController,
    required this.hymnController,
    required this.devotionalController,
    required this.onNavigateToTab,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Bom dia!';
    } else if (hour >= 12 && hour < 18) {
      return 'Boa tarde!';
    } else {
      return 'Boa noite!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final multiplier = themeService.fontSizeMultiplier;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.auto_stories, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Kairós',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Saudação Inicial
                Text(
                  _getGreeting(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 24 * multiplier,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bem-vindo ao seu espaço de adoração, comunhão e estudo da Palavra.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 24),

                // Card: Versículo do Dia
                Card(
                  elevation: 0,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Versículo do Dia',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          '“Lâmpada para os meus pés é tua palavra e luz, para o meu caminho.”',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            fontSize: 16 * multiplier,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ActionChip(
                            avatar: const Icon(Icons.menu_book, size: 14),
                            label: const Text(
                              'Salmos 119:105',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            onPressed: () {
                              bibleController.jumpToVerse('Salmos', 119, 105);
                              onNavigateToTab(1); // Vai para a Bíblia
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Atalhos Rápidos (Grid / Linhas)
                Text(
                  'Acesso Rápido',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.menu_book,
                        title: 'Bíblia Sagrada',
                        subtitle: 'Estudo com notas',
                        color: Colors.blueAccent,
                        onTap: () => onNavigateToTab(1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.music_note,
                        title: 'Hinário',
                        subtitle: '600+ hinos com áudio',
                        color: Colors.deepOrangeAccent,
                        onTap: () => onNavigateToTab(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.volunteer_activism,
                        title: 'Meditação Diária',
                        subtitle: 'Reflexões matinais',
                        color: Colors.purpleAccent,
                        onTap: () => onNavigateToTab(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        context,
                        icon: Icons.school,
                        title: 'Escola Sabatina',
                        subtitle: 'Lições da semana',
                        color: Colors.teal,
                        onTap: () => onNavigateToTab(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Card de Destaque da Meditação de Hoje
                AnimatedBuilder(
                  animation: devotionalController,
                  builder: (context, _) {
                    final devo = devotionalController.currentDevotional;
                    if (devo == null) return const SizedBox.shrink();

                    return Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => onNavigateToTab(3),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.today, color: theme.colorScheme.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Meditação de Hoje',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                devo.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '“${devo.verseText}” — ${devo.verseReference}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
