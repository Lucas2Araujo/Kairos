import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';

class WelcomeDialog extends StatefulWidget {
  const WelcomeDialog({super.key});

  static Future<void> show(BuildContext context, {bool force = false}) async {
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool('onboarding_completed') ?? false;
      if (completed) return;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const WelcomeDialog(),
    );
  }

  @override
  State<WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<WelcomeDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        final isDark = theme.brightness == Brightness.dark;
        final isGlass = themeService.isAnyGlass;

        Widget content = Dialog(
          backgroundColor: isGlass
              ? (isDark ? const Color(0xCC1E1E1E) : const Color(0xEBFFFFFF))
              : theme.colorScheme.surface,
          elevation: isGlass ? 0 : 6,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: isGlass
                ? BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.6),
                    width: 1.2,
                  )
                : BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 480,
              maxHeight: 620,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                children: [
                  // PageView com as 3 etapas
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (idx) {
                        setState(() => _currentPage = idx);
                      },
                      children: [
                        _buildPage1Welcome(context, theme),
                        _buildPage2Themes(context, theme, themeService),
                        _buildPage3Ready(context, theme),
                      ],
                    ),
                  ),

                  // Barra Inferior com Indicador e Controles
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botão Esquerdo: "Pular" ou "Voltar"
                        if (_currentPage == 0)
                          TextButton(
                            onPressed: _finishOnboarding,
                            child: const Text('Pular'),
                          )
                        else
                          TextButton.icon(
                            onPressed: _previousPage,
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Voltar'),
                          ),

                        // Indicador de 3 pontos
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (index) {
                            final isActive = index == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.dividerColor.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        // Botão Direito: "Avançar" ou "Concluir"
                        if (_currentPage < 2)
                          FilledButton.tonal(
                            onPressed: _nextPage,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Avançar'),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_rounded, size: 16),
                              ],
                            ),
                          )
                        else
                          FilledButton(
                            onPressed: _finishOnboarding,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Concluir'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        final blur = (isGlass && themeService.glassBlurEnabled)
            ? (themeService.isAppleGlass ? 24.0 : 16.0)
            : 0.0;

        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: content,
        );
      },
    );
  }

  // Página 1: Apresentação Geral do Kairós
  Widget _buildPage1Welcome(BuildContext context, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_stories,
              size: 42,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Bem-vindo ao Kairós',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Seu ecossistema completo para adoração, comunhão e estudo da Palavra.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
              height: 1.3,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            theme,
            icon: Icons.menu_book_rounded,
            iconColor: Colors.blueAccent,
            title: 'Bíblia Sagrada',
            description: 'Comentários, referências cruzadas e notas de rodapé.',
          ),
          const SizedBox(height: 8),
          _buildFeatureCard(
            context,
            theme,
            icon: Icons.music_note_rounded,
            iconColor: Colors.purpleAccent,
            title: 'Hinário Adventista',
            description: 'Áudios oficiais, instrumentais e comparativo histórico (1996 vs 2022).',
          ),
          const SizedBox(height: 8),
          _buildFeatureCard(
            context,
            theme,
            icon: Icons.wb_sunny_rounded,
            iconColor: Colors.orangeAccent,
            title: 'Meditações Diárias',
            description: 'Inspiração matinal para renovar seu dia.',
          ),
          const SizedBox(height: 8),
          _buildFeatureCard(
            context,
            theme,
            icon: Icons.school_rounded,
            iconColor: Colors.tealAccent.shade700,
            title: 'Escola Sabatina',
            description: 'Lições trimestrais, mapas mentais e Desafio Diário (Quiz).',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Página 2: Escolha seu Estilo Visual
  Widget _buildPage2Themes(
    BuildContext context,
    ThemeData theme,
    ThemeService themeService,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.palette_outlined,
              size: 40,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Personalize sua Experiência',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Escolha o estilo de interface que mais combina com seu momento de leitura.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
              height: 1.3,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildThemeCard(
            context,
            theme,
            themeService,
            style: AppThemeStyle.materialYou,
            icon: Icons.color_lens_outlined,
            title: 'Material You',
            subtitle: 'Cores dinâmicas e design limpo padrão Google M3.',
          ),
          const SizedBox(height: 8),
          _buildThemeCard(
            context,
            theme,
            themeService,
            style: AppThemeStyle.liquidGlass,
            icon: Icons.water_drop_outlined,
            title: 'Liquid Glass',
            subtitle: 'Superfícies translúcidas vivas com degradê refinado.',
          ),
          const SizedBox(height: 8),
          _buildThemeCard(
            context,
            theme,
            themeService,
            style: AppThemeStyle.appleGlass,
            icon: Icons.blur_on_rounded,
            title: 'Apple Glass',
            subtitle: 'Estilo moderno visionOS/macOS com orbes orgânicos e reflexo especular.',
          ),
          const SizedBox(height: 8),
          _buildThemeCard(
            context,
            theme,
            themeService,
            style: AppThemeStyle.classicBook,
            icon: Icons.menu_book_outlined,
            title: 'Livro Clássico',
            subtitle: 'Tons sépia acolhedores para leitura prolongada sem cansaço visual.',
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    ThemeData theme,
    ThemeService themeService, {
    required AppThemeStyle style,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = themeService.themeStyle == style;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          themeService.setThemeStyle(style);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.12),
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : theme.dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? theme.colorScheme.primary : theme.iconTheme.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isSelected ? theme.colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Página 3: Tudo Pronto e Login Opcional
  Widget _buildPage3Ready(BuildContext context, ThemeData theme) {
    final auth = AuthService();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pronto para Começar',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              fontSize: 21,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'O Kairós funciona 100% offline. Se desejar sincronizar suas anotações e ofensiva na nuvem, conecte sua conta Google.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
              height: 1.3,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),

          // Card de Login Google
          ListenableBuilder(
            listenable: auth,
            builder: (context, _) {
              if (auth.isAuthenticated) {
                final user = auth.currentUser;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                        backgroundImage: user?.avatarUrl.isNotEmpty == true
                            ? NetworkImage(user!.avatarUrl)
                            : null,
                        child: user?.avatarUrl.isEmpty != false
                            ? const Icon(Icons.person, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Conectado',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Conta Google sincronizada ✅',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => auth.signInWithGoogle(),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text('Conectar com Conta Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Botão Principal de Concluir / Começar a Usar
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _finishOnboarding,
              icon: const Icon(Icons.explore_rounded, size: 18),
              label: const Text(
                'Começar a Usar o Kairós',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
