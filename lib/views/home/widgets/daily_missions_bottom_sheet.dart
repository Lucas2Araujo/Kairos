import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';
import '../../gamification/monthly_streak_view.dart';
import 'kairos_lamp_mascot.dart';

/// Modal Bottom Sheet expansível de Missões Diárias e Reservatório de Azeite
/// (Inspirado na Parábola das Dez Virgens)
class DailyMissionsBottomSheet extends StatelessWidget {
  const DailyMissionsBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DailyMissionsBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isDark = theme.brightness == Brightness.dark;
    final isGlass = themeService.isAnyGlass;
    final service = GamificationService();

    const dayLabels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    return Container(
      decoration: BoxDecoration(
        color: isGlass
            ? (isDark ? const Color(0xEB1E1E1E) : const Color(0xF5FFFFFF))
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra indicadora de arraste
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Cabeçalho com Mascote e Título
              ListenableBuilder(
                listenable: service,
                builder: (context, _) {
                  final streak = service.currentStreak;
                  final isFull = service.isFullFlameActive;
                  final isHalf = service.isHalfStreakActive;

                  final streakTitle = isFull
                      ? '🔥 Chama Completa Ativa! (1.5x Azeite)'
                      : (isHalf
                          ? '✨ Meia Ofensiva: Chama Acesa!'
                          : (streak > 0
                              ? '$streak dias seguidos — Pavio aceso!'
                              : 'Encha sua Lamparina com azeite!'));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          KairosLampMascotWidget(
                            state: service.lampMascotState,
                            oilFill: service.lampPercentage,
                            size: 56,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reserva de Azeite & Missões',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  streakTitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isFull
                                        ? Colors.amber.shade700
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Barra de Nível da Lamparina
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
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
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      service.isLampFull
                                          ? 'Lamparina 100% cheia!'
                                          : '${service.todayOilDrops}/100 gotas hoje',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${service.totalOilDrops} gotas totais',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: service.lampPercentage,
                                minHeight: 8,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  service.isLampFull
                                      ? Colors.amber.shade600
                                      : Colors.amber.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Seção de Missões Diárias
                      Text(
                        'Missões de Hoje (${service.completedMissionsCount}/4 cumpridas)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildMissionItem(
                        theme,
                        title: 'Tempo com Deus',
                        subtitle:
                            'Fique pelo menos ${service.dailyGoalMinutes} min lendo ou orando (${service.todayFocusMinutes}/${service.dailyGoalMinutes}m)',
                        icon: Icons.hourglass_top_rounded,
                        isDone: service.mission1TimeWithGod,
                      ),
                      _buildMissionItem(
                        theme,
                        title: 'Palavra Viva',
                        subtitle: 'Leia ao menos 1 capítulo da Bíblia Sagrada',
                        icon: Icons.menu_book_rounded,
                        isDone: service.mission2LivingWord,
                      ),
                      _buildMissionItem(
                        theme,
                        title: 'Pão Diário',
                        subtitle: 'Complete a leitura da meditação diária',
                        icon: Icons.wb_sunny_rounded,
                        isDone: service.mission3DailyBread,
                      ),
                      _buildMissionItem(
                        theme,
                        title: 'Quiz da Lição ⭐',
                        subtitle: 'Responda as perguntas rápidas da Escola Sabatina',
                        icon: Icons.bolt_rounded,
                        isDone: service.mission4LessonQuiz,
                      ),
                      const SizedBox(height: 16),

                      // Indicadores compactos da semana
                      const Text(
                        'Ofensiva da Semana',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
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
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDone
                                      ? theme.colorScheme.primary
                                      : Colors.transparent,
                                  border: isDone
                                      ? null
                                      : Border.all(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.35),
                                          width: 1.2,
                                        ),
                                ),
                                child: isDone
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: theme.colorScheme.onPrimary,
                                      )
                                    : null,
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Botão para ver o Mês e Conquistas
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: const Text('Ver Calendário do Mês & Conquistas'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          MonthlyStreakView.show(context);
                        },
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionItem(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDone,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDone
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDone
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDone
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              isDone ? Icons.check : icon,
              size: 16,
              color: isDone
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
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
                    color: isDone ? theme.colorScheme.primary : null,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isDone)
            const Text(
              '+25 gotas',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Colors.amber,
              ),
            ),
        ],
      ),
    );
  }
}
