import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../profile/profile_dialog.dart';
import '../search/global_search_view.dart';
import '../settings/settings_dialog.dart';
import 'widgets/daily_verse_card.dart';
import 'widgets/gamification_banner.dart';

class HomeView extends StatelessWidget {
  final BibleController bibleController;
  final HymnController hymnController;
  final DevotionalController devotionalController;
  final SabbathSchoolController? sabbathSchoolController;
  final void Function(int tabIndex) onNavigateToTab;

  const HomeView({
    super.key,
    required this.bibleController,
    required this.hymnController,
    required this.devotionalController,
    this.sabbathSchoolController,
    required this.onNavigateToTab,
  });

  /// Retorna título e subtítulo da acolhida dinâmica conforme o período do dia e o usuário logado
  (String title, String subtitle) _getGreeting() {
    final now = DateTime.now();
    final hour = now.hour;
    final user = AuthService().currentUser;
    final name = (user?.displayName != null && user!.displayName.trim().isNotEmpty)
        ? ', ${user.displayName.trim()}'
        : '';

    final seed = now.day + now.hour;

    if (hour >= 5 && hour < 12) {
      // Manhã (5h - 11h59)
      const subtitles = [
        'Que a Palavra ilumine seu caminho hoje.',
        'Hora de começar o dia com inspiração e fé.',
        'Uma manhã com a Palavra renova o coração.',
      ];
      return ('Bom dia$name! ☀️', subtitles[seed % subtitles.length]);
    } else if (hour >= 12 && hour < 18) {
      // Tarde (12h - 17h59)
      const subtitles = [
        'Que tal uma pausa para alimentar a alma?',
        'A Palavra é lâmpada para os seus passos.',
        'Renove sua mente com a leitura de hoje.',
      ];
      return ('Boa tarde$name! 🌤️', subtitles[seed % subtitles.length]);
    } else {
      // Noite (18h - 4h59)
      const subtitles = [
        'Encerre o dia refletindo na Palavra de Deus.',
        'Uma leitura antes de descansar traz paz ao coração.',
        'Que a paz do Senhor guarde seus pensamentos.',
      ];
      return ('Boa noite$name! 🌙', subtitles[seed % subtitles.length]);
    }
  }

  /// Formata a categoria devocional para exibição elegante no badge
  static String _formatDevotionalBadge(String category) {
    final cat = category.trim().toLowerCase();
    if (cat.startsWith('jov')) {
      return 'JOVENS';
    } else if (cat.contains('mulher')) {
      return 'MULHER';
    } else if (cat.contains('diario') || cat.contains('adult')) {
      return 'ADULTOS';
    }
    return category.trim().toUpperCase();
  }

  /// Formata a categoria da lição da escola sabatina para exibição no badge
  static String _formatSabbathSchoolBadge(String? category) {
    final cat = (category ?? '').trim().toLowerCase();
    if (cat.startsWith('jov')) {
      return 'JOVENS';
    }
    return 'ADULTOS';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: Listenable.merge([themeService, AuthService()]),
      builder: (context, _) {
        final isGlass = themeService.isAnyGlass;
        final multiplier = themeService.fontSizeMultiplier;
        final greeting = _getGreeting();

        return Scaffold(
          backgroundColor: isGlass ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
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
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Busca Global',
                onPressed: () {
                  GlobalSearchView.show(
                    context,
                    bibleController: bibleController,
                    hymnController: hymnController,
                    devotionalController: devotionalController,
                    sabbathSchoolController:
                        sabbathSchoolController ?? SabbathSchoolController(),
                    onNavigateToTab: onNavigateToTab,
                  );
                },
              ),
              IconButton(
                tooltip: 'Perfil e Conta',
                onPressed: () => ProfileDialog.show(context),
                icon: AnimatedBuilder(
                  animation: AuthService(),
                  builder: (context, _) {
                    final auth = AuthService();
                    final user = auth.currentUser;
                    if (auth.isAuthenticated) {
                      if (user != null && user.avatarUrl.isNotEmpty) {
                        return CircleAvatar(
                          radius: 13,
                          backgroundImage: NetworkImage(user.avatarUrl),
                          onBackgroundImageError: (_, __) {},
                        );
                      }
                      return const Icon(Icons.account_circle);
                    }
                    return const Icon(Icons.account_circle_outlined);
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Configurações e Temas',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Saudação + Subtítulo dinâmico
                    Text(
                      greeting.$1,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24 * multiplier,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greeting.$2,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                        fontSize: 14 * multiplier,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Banner de Gamificação
                    GamificationBanner(isGlass: isGlass),
                    const SizedBox(height: 20),

                    // 3. Card Editorial do Versículo do Dia
                    DailyVerseCard(
                      bibleController: bibleController,
                      onNavigateToTab: onNavigateToTab,
                      devotionalController: devotionalController,
                      isGlass: isGlass,
                    ),
                    const SizedBox(height: 24),

                    // 4. Acesso Rápido
                    Text(
                      'Acesso Rápido',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16 * multiplier,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListenableBuilder(
                            listenable: bibleController,
                            builder: (context, _) {
                              final version = bibleController.activeVersion.trim().isNotEmpty
                                  ? bibleController.activeVersion.trim().toUpperCase()
                                  : 'ARA';
                              return _buildActionTile(
                                context,
                                icon: Icons.menu_book,
                                title: 'Bíblia',
                                subtitle: 'Estudo com notas',
                                badgeText: version,
                                color: theme.colorScheme.primary,
                                onTap: () => onNavigateToTab(1),
                                isGlass: isGlass,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActionTile(
                            context,
                            icon: Icons.music_note,
                            title: 'Hinários',
                            subtitle: 'Letras e áudios',
                            badgeText: '2022/96',
                            color: theme.colorScheme.secondary,
                            onTap: () => onNavigateToTab(2),
                            isGlass: isGlass,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              devotionalController,
                              themeService,
                            ]),
                            builder: (context, _) {
                              final rawCat = devotionalController.selectedCategory.isNotEmpty
                                  ? devotionalController.selectedCategory
                                  : themeService.defaultDevotionalCategory;
                              final badge = _formatDevotionalBadge(rawCat);
                              return _buildActionTile(
                                context,
                                icon: Icons.volunteer_activism,
                                title: 'Meditação',
                                subtitle: 'Devocional de hoje',
                                badgeText: badge,
                                color: theme.colorScheme.tertiary,
                                onTap: () => onNavigateToTab(3),
                                isGlass: isGlass,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: Listenable.merge([
                              if (sabbathSchoolController != null) sabbathSchoolController!,
                              themeService,
                            ]),
                            builder: (context, _) {
                              final rawCat = sabbathSchoolController?.quarterlyType ??
                                  themeService.defaultSabbathSchoolCategory;
                              final badge = _formatSabbathSchoolBadge(rawCat);
                              return _buildActionTile(
                                context,
                                icon: Icons.school,
                                title: 'Escola Sabatina',
                                subtitle: 'Lição da semana',
                                badgeText: badge,
                                color: theme.colorScheme.primary,
                                onTap: () => onNavigateToTab(4),
                                isGlass: isGlass,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isGlass,
    String? badgeText,
  }) {
    final theme = Theme.of(context);

    final content = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ),
      ),
    );

    if (isGlass) {
      return GlassSurface(
        borderRadius: 16,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: content,
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: content,
    );
  }
}
