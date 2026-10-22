import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';

/// Banner de Gamificação da Tela Inicial (estilo Flet / SelecaoView)
/// Exibe ofensiva de leitura (streak), total de XP e 7 círculos representando os dias da semana.
class GamificationBanner extends StatefulWidget {
  final bool? isGlass;

  const GamificationBanner({
    super.key,
    this.isGlass,
  });

  @override
  State<GamificationBanner> createState() => _GamificationBannerState();
}

class _GamificationBannerState extends State<GamificationBanner> {
  @override
  void initState() {
    super.initState();
    final service = GamificationService();
    if (!service.isInitialized) {
      service.init();
    }
  }

  void _showInfoDialog(BuildContext context, GamificationService service) {
    final theme = Theme.of(context);
    final isGlass = widget.isGlass ?? ThemeService().isAnyGlass;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isGlass ? theme.colorScheme.surface.withValues(alpha: 0.95) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 26),
              SizedBox(width: 8),
              Text(
                'Ofensiva & XP Kairós',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mantenha o hábito diário de comunhão com a Palavra:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 14),
              _buildDialogTip(
                icon: Icons.local_fire_department,
                color: Colors.orangeAccent,
                title: 'Ofensiva Diária (Streak)',
                subtitle:
                    'Leia a Meditação Diária ou um capítulo da Bíblia todos os dias para acumular dias seguidos de ofensiva.',
              ),
              const SizedBox(height: 12),
              _buildDialogTip(
                icon: Icons.bolt,
                color: Colors.amberAccent,
                title: 'Pontos de Experiência (XP)',
                subtitle:
                    'Receba +10 XP na primeira leitura do dia e pontos adicionais ao realizar estudos e quizzes bíblicos.',
              ),
              const SizedBox(height: 12),
              _buildDialogTip(
                icon: Icons.calendar_month,
                color: theme.colorScheme.primary,
                title: 'Constância Semanal',
                subtitle:
                    'Os 7 círculos mostram seus dias de estudo na semana (D S T Q Q S S). Cultive uma rotina espiritual viva!',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogTip({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final effectiveGlass = widget.isGlass ?? themeService.isAnyGlass;
    final service = GamificationService();

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final streak = service.currentStreak;
        final streakText = streak == 0
            ? 'Comece sua sequência!'
            : streak == 1
                ? '1 dia seguido'
                : '$streak dias seguidos';

        const dayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

        final bannerContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Linha Superior: Fogo + Streak, Raio + XP, Ícone Info
            Row(
              children: [
                // Ícone de fogo + texto
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orangeAccent,
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  streakText,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),

                // Ícone de raio + XP
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: Colors.amberAccent,
                        size: 17,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${service.totalXp} XP',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Linha Inferior: 7 indicadores circulares compactos (D S T Q Q S S)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isDone = index < service.weeklyActivity.length &&
                    service.weeklyActivity[index] == true;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dayLabels[index],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDone
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? theme.colorScheme.primary : Colors.transparent,
                        border: isDone
                            ? null
                            : Border.all(
                                color: theme.colorScheme.outline.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                      ),
                      child: isDone
                          ? Icon(
                              Icons.check,
                              size: 14,
                              color: theme.colorScheme.onPrimary,
                            )
                          : null,
                    ),
                  ],
                );
              }),
            ),
          ],
        );

        if (effectiveGlass) {
          return GlassSurface(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => _showInfoDialog(context, service),
            child: bannerContent,
          );
        }

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showInfoDialog(context, service),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: bannerContent,
            ),
          ),
        );
      },
    );
  }
}
