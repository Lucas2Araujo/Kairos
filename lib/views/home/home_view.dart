import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../services/auth_service.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';
import '../classroom/classroom_view.dart';
import '../plans/reading_plans_view.dart';
import '../profile/profile_dialog.dart';
import '../search/global_search_view.dart';
import '../settings/settings_dialog.dart';
import 'widgets/daily_missions_bottom_sheet.dart';
import 'widgets/daily_verse_card.dart';

class HomeView extends StatefulWidget {
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

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _block1Anim;
  late final Animation<double> _block2Anim;
  late final Animation<double> _block3Anim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _block1Anim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOutCubic),
    );
    _block2Anim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.20, 0.75, curve: Curves.easeOutCubic),
    );
    _block3Anim = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

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
        'Que tal passar um tempo com Deus nessa manhã?',
        'Que a Palavra ilumine seus passos hoje.',
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

  /// Formata a categoria da lição da escola sabatina para exibição no badge
  static String _formatSabbathSchoolBadge(String? category) {
    final cat = (category ?? '').trim().toLowerCase();
    if (cat.startsWith('jov')) {
      return 'JOVENS';
    }
    return 'ADULTOS';
  }

  void _openGlobalSearch(BuildContext context) {
    GlobalSearchView.show(
      context,
      bibleController: widget.bibleController,
      hymnController: widget.hymnController,
      devotionalController: widget.devotionalController,
      sabbathSchoolController:
          widget.sabbathSchoolController ?? SabbathSchoolController(),
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: Listenable.merge([themeService, AuthService(), GamificationService()]),
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
            // A. Top Bar: Extremo superior esquerdo: Avatar/ícone de Perfil circular
            leading: IconButton(
              tooltip: 'Perfil e Conta',
              onPressed: () => ProfileDialog.show(context),
              icon: AnimatedBuilder(
                animation: AuthService(),
                builder: (context, _) {
                  final auth = AuthService();
                  final user = auth.currentUser;
                  if (auth.isAuthenticated && user != null && user.avatarUrl.isNotEmpty) {
                    return CircleAvatar(
                      radius: 14,
                      backgroundImage: NetworkImage(user.avatarUrl),
                      onBackgroundImageError: (_, __) {},
                    );
                  }
                  return CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    child: Icon(
                      auth.isAuthenticated ? Icons.person : Icons.person_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                  );
                },
              ),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Kairós',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ],
            ),
            // A. Top Bar: Extremo superior direito: Ícone de busca (opcional) + Configurações
            actions: [
              if (themeService.homeSearchPlacement == HomeSearchPlacement.topBarIcon)
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Busca Global',
                  onPressed: () => _openGlobalSearch(context),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // B. Header de Boas-Vindas & Gamificação (Parábola das Dez Virgens)
                    _buildAnimatedSection(
                      animation: _block1Anim,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Lado Esquerdo: Saudação contextual + Subtítulo devocional rotativo
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  greeting.$1,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22 * multiplier,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  greeting.$2,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.textTheme.bodySmall?.color,
                                    fontSize: 13 * multiplier,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Lado Direito: Lamparina & Gotas de Azeite (XP)
                          _buildGamificationHeaderPill(context, theme, isGlass),
                        ],
                      ),
                    ),

                    // C. Barra de Busca Global (Cápsula no corpo da tela)
                    if (themeService.homeSearchPlacement == HomeSearchPlacement.capsuleBody) ...[
                      const SizedBox(height: 16),
                      _buildAnimatedSection(
                        animation: _block1Anim,
                        child: _buildSearchCapsule(context, theme, isGlass),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // D. Banner Dinâmico: Meditação Diária & Pôr do Sol
                    _buildAnimatedSection(
                      animation: _block2Anim,
                      child: DailyVerseCard(
                        bibleController: widget.bibleController,
                        onNavigateToTab: widget.onNavigateToTab,
                        devotionalController: widget.devotionalController,
                        isGlass: isGlass,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // E. Grid de Ações / Módulos Principais (3 Linhas x 2 Colunas)
                    _buildAnimatedSection(
                      animation: _block3Anim,
                      child: _buildActionGrid(context, theme, isGlass, themeService, multiplier),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Pílula compacta de Gamificação no Header (Lamparina/Ofensiva + Gotas de Azeite)
  Widget _buildGamificationHeaderPill(BuildContext context, ThemeData theme, bool isGlass) {
    final service = GamificationService();
    final streak = service.currentStreak;
    final isFull = service.isFullFlameActive;
    final isHalf = service.isHalfStreakActive;
    final isLit = isFull || isHalf;

    final flameColor = isLit ? Colors.amber.shade700 : Colors.grey;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => DailyMissionsBottomSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLit
              ? Colors.amber.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLit
                ? Colors.amber.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lamparina / Fogo da Ofensiva
            Icon(
              isLit ? Icons.local_fire_department_rounded : Icons.local_fire_department_outlined,
              color: flameColor,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),

            // Linha divisora discreta
            Container(
              width: 1,
              height: 14,
              color: theme.dividerColor.withValues(alpha: 0.25),
            ),
            const SizedBox(width: 8),

            // Gota de Azeite (XP)
            Icon(
              service.isLampFull ? Icons.lightbulb_rounded : Icons.opacity_rounded,
              color: Colors.amber.shade700,
              size: 16,
            ),
            const SizedBox(width: 4),
            Text(
              '${service.todayOilDrops}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Campo de busca em formato cápsula/pílula no corpo da Home
  Widget _buildSearchCapsule(BuildContext context, ThemeData theme, bool isGlass) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => _openGlobalSearch(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: isGlass ? 0.3 : 0.6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pesquisar na Bíblia, hinários, lições...',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Grid de Módulos Principais (3 Linhas x 2 Colunas)
  Widget _buildActionGrid(
    BuildContext context,
    ThemeData theme,
    bool isGlass,
    ThemeService themeService,
    double multiplier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Módulos Principais',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 16 * multiplier,
          ),
        ),
        const SizedBox(height: 12),

        // Linha 1: 1. Bíblia Sagrada & 2. Planos de Leitura
        Row(
          children: [
            Expanded(
              child: ListenableBuilder(
                listenable: widget.bibleController,
                builder: (context, _) {
                  final version = widget.bibleController.activeVersion.trim().isNotEmpty
                      ? widget.bibleController.activeVersion.trim().toUpperCase()
                      : 'ARA';
                  final lastRead = widget.bibleController.lastReadReference;
                  return _buildActionTile(
                    context,
                    icon: Icons.menu_book_rounded,
                    title: 'Bíblia Sagrada',
                    subtitle: 'Continuar: $lastRead',
                    badgeText: version,
                    color: theme.colorScheme.primary,
                    onTap: () => widget.onNavigateToTab(1),
                    isGlass: isGlass,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.auto_stories_rounded,
                title: 'Planos de Leitura',
                subtitle: 'Jornadas & Metas',
                badgeText: 'ESTUDO',
                color: Colors.indigoAccent,
                onTap: () => ReadingPlansView.show(
                  context,
                  bibleController: widget.bibleController,
                  onNavigateToTab: widget.onNavigateToTab,
                ),
                isGlass: isGlass,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Linha 2: 3. Hinários & 4. Escola Sabatina
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.music_note_rounded,
                title: 'Hinários',
                subtitle: 'Letras e áudios',
                badgeText: '2022 / 1996',
                color: theme.colorScheme.secondary,
                onTap: () => widget.onNavigateToTab(2),
                isGlass: isGlass,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  if (widget.sabbathSchoolController != null) widget.sabbathSchoolController!,
                  themeService,
                ]),
                builder: (context, _) {
                  final rawCat = widget.sabbathSchoolController?.quarterlyType ??
                      themeService.defaultSabbathSchoolCategory;
                  final badge = _formatSabbathSchoolBadge(rawCat);
                  return _buildActionTile(
                    context,
                    icon: Icons.school_rounded,
                    title: 'Escola Sabatina',
                    subtitle: 'Estudo diário da lição',
                    badgeText: badge,
                    color: theme.colorScheme.primary,
                    onTap: () => widget.onNavigateToTab(4),
                    isGlass: isGlass,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Linha 3: 5. Encontre uma Igreja & 6. Turmas / Classes
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.church_rounded,
                title: 'Encontre uma Igreja',
                subtitle: 'Templos próximos',
                badgeText: 'MAPA',
                color: Colors.teal,
                onTap: () async {
                  final uri = Uri.parse('https://igrejas.adventistas.org/');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                isGlass: isGlass,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                context,
                icon: Icons.groups_rounded,
                title: 'Turmas / Classes',
                subtitle: 'Comunidade & estudos',
                badgeText: 'CLASSE',
                color: Colors.deepPurpleAccent,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ClassroomView(),
                    ),
                  );
                },
                isGlass: isGlass,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedSection({
    required Animation<double> animation,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - animation.value) * 12),
            child: child,
          ),
        );
      },
      child: child,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
