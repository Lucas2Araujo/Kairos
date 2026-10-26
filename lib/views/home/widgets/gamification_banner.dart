import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';
import '../../gamification/monthly_streak_view.dart';
import 'kairos_lamp_mascot.dart';

/// Banner de Gamificação da Tela Inicial: Lamparina, Reservatório de Azeite e Ofensiva
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

        final isFull = service.isFullFlameActive;
        final isHalf = service.isHalfStreakActive;
        final flameColor = isFull
            ? Colors.amber.shade700
            : (isHalf ? Colors.deepOrange : Colors.grey);
        final flameBg = isFull
            ? Colors.amber.withValues(alpha: 0.18)
            : (isHalf
                ? Colors.deepOrange.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5));
        final flameBorder = isFull
            ? Colors.amber.withValues(alpha: 0.5)
            : (isHalf
                ? Colors.deepOrange.withValues(alpha: 0.3)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de botões minimalistas (Pills compactas)
              Row(
                children: [
                  // Pill da Ofensiva (Fogo / Chama da Lamparina com Meia Ofensiva vs Completa)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: flameBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: flameBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFull
                                ? Icons.whatshot_rounded
                                : (isHalf
                                    ? Icons.local_fire_department_rounded
                                    : Icons.local_fire_department_outlined),
                            color: flameColor,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            streakLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          if (isFull) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade600,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '1.5x',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 4),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Pill da Lamparina (Azeite: X/100 gotas)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.38),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            service.isLampFull
                                ? Icons.lightbulb_rounded
                                : Icons.opacity_rounded,
                            color: Colors.amber.shade700,
                            size: 17,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${service.todayOilDrops}/100 gotas',
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

              // Painel expansível (Mascote + Missões Diárias + Semana)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _buildExpandedWeeklyCard(context, theme, effectiveGlass, service),
                ),
                crossFadeState:
                    _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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
    final isFull = service.isFullFlameActive;
    final isHalf = service.isHalfStreakActive;

    final streakTitle = isFull
        ? '🔥 Chama Completa Ativa! (1.5x Azeite)'
        : (isHalf
            ? '✨ Meia Ofensiva: Chama Acesa!'
            : (streak > 0
                ? '$streak dias seguidos — Mantenha o pavio aceso!'
                : 'Encha sua Lamparina hoje com azeite!'));

    final cardContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Mascote compacto da Lamparina Kairós
            KairosLampMascotWidget(
              state: service.lampMascotState,
              oilFill: service.lampPercentage,
              size: 52,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    streakTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${service.completedMissionsCount}/4 missões • ${service.todayFocusMinutes}/${service.dailyGoalMinutes} min com Deus',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
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
        const SizedBox(height: 10),

        // Barra de Nível da Lamparina
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      service.isLampFull
                          ? Icons.lightbulb_rounded
                          : Icons.opacity_rounded,
                      color: Colors.amber.shade700,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.isLampFull
                          ? 'Lamparina 100% cheia e brilhando!'
                          : 'Azeite na Lamparina: ${service.todayOilDrops}/100 gotas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${service.totalOilDrops} gotas no total',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: service.lampPercentage,
                minHeight: 7,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  service.isLampFull ? Colors.amber.shade600 : Colors.amber.shade400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 4 Missões Diárias (Tempo com Deus, Palavra Viva, Pão Diário, Quiz da Lição)
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildPillarBadge(
              theme,
              label: '⏳ Tempo (${service.todayFocusMinutes}/${service.dailyGoalMinutes}m)',
              isDone: service.mission1TimeWithGod,
            ),
            _buildPillarBadge(
              theme,
              label: '📖 Palavra Viva',
              isDone: service.mission2LivingWord,
            ),
            _buildPillarBadge(
              theme,
              label: '🌅 Pão Diário',
              isDone: service.mission3DailyBread,
            ),
            _buildPillarBadge(
              theme,
              label: '🧠 Quiz Lição ⭐',
              isDone: service.mission4LessonQuiz,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 7 indicadores circulares compactos da semana (D S T Q Q S S)
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

  Widget _buildPillarBadge(
    ThemeData theme, {
    required String label,
    required bool isDone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? Colors.green.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 13,
            color: isDone ? Colors.green : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
              color: isDone ? Colors.green.shade800 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
