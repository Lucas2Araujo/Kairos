import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';
import '../../gamification/monthly_streak_view.dart';

/// Banner de Gamificação da Tela Inicial (Híbrido Dinâmico: pills minimalistas + expansão semanal)
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
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final service = GamificationService();
    if (!service.isInitialized) {
      service.init();
    }
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
        final streakLabel = streak == 0
            ? '0 dias seguidos'
            : streak == 1
                ? '1 dia seguido'
                : '$streak dias seguidos';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de botões minimalistas (Pills compactas)
              Row(
                children: [
                  // Pill da Ofensiva (Fogo)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.deepOrange.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.deepOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            streakLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pill de XP (Raio)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => MonthlyStreakView.show(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${service.totalXp} XP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Botão para ver Calendário do Mês / Conquistas
                  IconButton(
                    icon: const Icon(Icons.calendar_month_rounded, size: 20),
                    tooltip: 'Ver mês da ofensiva & conquistas',
                    onPressed: () => MonthlyStreakView.show(context),
                  ),
                ],
              ),

              // Painel expansível (Card semanal da Imagem 3)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildExpandedWeeklyCard(context, theme, effectiveGlass, service),
                ),
                crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedWeeklyCard(
    BuildContext context,
    ThemeData theme,
    bool effectiveGlass,
    GamificationService service,
  ) {
    const dayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final streak = service.currentStreak;
    final streakTitle = streak == 0
        ? 'Comece sua sequência!'
        : streak == 1
            ? '1 dia de sequência!'
            : '$streak dias de sequência!';

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.local_fire_department,
              color: Colors.deepOrange,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              streakTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => MonthlyStreakView.show(context),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('Ver Mês', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 7 indicadores circulares compactos (D S T Q Q S S)
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDone
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 26,
                  height: 26,
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
                          size: 15,
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
        child: cardContent,
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: cardContent,
      ),
    );
  }
}
