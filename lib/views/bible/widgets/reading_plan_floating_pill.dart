import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../services/reading_plan_service.dart';
import '../../../services/theme_service.dart';

/// Pílula flutuante superior colapsável no BibleReaderView para acompanhamento do Plano de Leitura
class ReadingPlanFloatingPill extends StatefulWidget {
  final BibleController controller;

  const ReadingPlanFloatingPill({
    super.key,
    required this.controller,
  });

  @override
  State<ReadingPlanFloatingPill> createState() => _ReadingPlanFloatingPillState();
}

class _ReadingPlanFloatingPillState extends State<ReadingPlanFloatingPill>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _celebrationAnimController;

  @override
  void initState() {
    super.initState();
    _celebrationAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
  }

  @override
  void dispose() {
    _celebrationAnimController.dispose();
    super.dispose();
  }

  void _triggerCelebration(BuildContext context) {
    _celebrationAnimController.forward(from: 0.0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.opacity_rounded, color: Colors.amber, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Leitura do dia concluída! +40 gotas de azeite na sua lamparina! 💧✨',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.grey.shade900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isGlass = themeService.isAnyGlass;
    final planService = ReadingPlanService();

    return ListenableBuilder(
      listenable: planService,
      builder: (context, _) {
        final primary = planService.primaryPlan;
        if (primary == null) return const SizedBox.shrink();

        final plan = primary.plan;
        final todayStatus = planService.getTodayStatus(plan.id);
        if (todayStatus == null) return const SizedBox.shrink();

        // Se o dia já foi concluído e a pílula está recolhida, ela pode ficar ultra discreta
        final isDayCompleted = todayStatus.isDayCompleted;
        final compChapters = todayStatus.completedChapters;
        final totalChapters = todayStatus.totalChapters;
        final currentDay = todayStatus.currentDayIndex;

        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Material(
                    elevation: 6,
                    shadowColor: Colors.black.withValues(alpha: 0.15),
                    color: isGlass
                        ? theme.colorScheme.surface.withValues(alpha: 0.85)
                        : theme.colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDayCompleted
                            ? Colors.green.withValues(alpha: 0.4)
                            : plan.accentColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Linha da pílula recolhida
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDayCompleted ? Icons.check_circle_rounded : plan.icon,
                                  color: isDayCompleted ? Colors.green : plan.accentColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${plan.title} • Dia $currentDay ($compChapters/$totalChapters)',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDayCompleted
                                          ? Colors.green.shade800
                                          : theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  _isExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),

                            // Conteúdo expandido (mini-card de capítulos)
                            if (_isExpanded) ...[
                              const Divider(height: 16),
                              if (todayStatus.day != null &&
                                  todayStatus.day!.chapters.isNotEmpty) ...[
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: todayStatus.day!.chapters.map((ch) {
                                    final chKey = '${ch.bookId}:${ch.chapter}';
                                    final isDone =
                                        planService.isChapterCompleted(plan.id, chKey);

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        planService.toggleChapterCompletion(
                                          plan.id,
                                          currentDay,
                                          chKey,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: isDone
                                              ? Colors.green.withValues(alpha: 0.15)
                                              : theme.colorScheme.surfaceContainerHighest
                                                  .withValues(alpha: 0.5),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isDone
                                                ? Colors.green.withValues(alpha: 0.45)
                                                : theme.colorScheme.outlineVariant
                                                    .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isDone
                                                  ? Icons.check_box_rounded
                                                  : Icons.check_box_outline_blank_rounded,
                                              size: 15,
                                              color: isDone
                                                  ? Colors.green
                                                  : theme.colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              ch.shortRef,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isDone
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isDone
                                                    ? Colors.green.shade800
                                                    : theme.colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Ações rápidas
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Pular para próximo capítulo pendente
                                  TextButton.icon(
                                    onPressed: () {
                                      final day = todayStatus.day;
                                      if (day == null || day.chapters.isEmpty) return;
                                      final next = day.chapters.firstWhere(
                                        (c) => !planService.isChapterCompleted(
                                            plan.id, '${c.bookId}:${c.chapter}'),
                                        orElse: () => day.chapters.first,
                                      );
                                      widget.controller
                                          .jumpToVerse(next.bookId, next.chapter, 1);
                                      setState(() {
                                        _isExpanded = false;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                                    label: const Text('Ir para pendente',
                                        style: TextStyle(fontSize: 11.5)),
                                  ),

                                  // Concluir leitura do dia
                                  if (!isDayCompleted)
                                    FilledButton.icon(
                                      onPressed: () {
                                        planService.completeDay(plan.id, currentDay);
                                        _triggerCelebration(context);
                                        setState(() {
                                          _isExpanded = false;
                                        });
                                      },
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        backgroundColor: Colors.green.shade700,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 0),
                                      ),
                                      icon: const Icon(Icons.check_circle_rounded, size: 14),
                                      label: const Text('Concluir Dia',
                                          style: TextStyle(fontSize: 11.5)),
                                    )
                                  else
                                    const Row(
                                      children: [
                                        Icon(Icons.done_all_rounded,
                                            size: 15, color: Colors.green),
                                        SizedBox(width: 4),
                                        Text('Dia Concluído! ✨',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green)),
                                      ],
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Efeito visual comemorativo de gotas de azeite / confetes flutuantes
            AnimatedBuilder(
              animation: _celebrationAnimController,
              builder: (context, _) {
                final progress = _celebrationAnimController.value;
                if (progress == 0.0 || progress == 1.0) return const SizedBox.shrink();

                return IgnorePointer(
                  child: CustomPaint(
                    size: const Size(double.infinity, 200),
                    painter: _OilDropsCelebrationPainter(progress: progress),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// CustomPainter para desenhar partículas festivas douradas de gotas de azeite
class _OilDropsCelebrationPainter extends CustomPainter {
  final double progress;
  static final math.Random _rnd = math.Random(42);
  static final List<({double angle, double dist, Color color, double radius})>
      _particles = List.generate(24, (i) {
    final angle = _rnd.nextDouble() * 2 * math.pi;
    final dist = 40.0 + _rnd.nextDouble() * 120.0;
    final colors = [
      const Color(0xFFFFD54F), // Âmbar claro
      const Color(0xFFFFB300), // Ouro
      const Color(0xFFFFA000), // Âmbar escuro
      const Color(0xFF81C784), // Verde oliva
    ];
    final color = colors[i % colors.length];
    final radius = 3.0 + _rnd.nextDouble() * 4.0;
    return (angle: angle, dist: dist, color: color, radius: radius);
  });

  _OilDropsCelebrationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 40);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in _particles) {
      final currentDist = p.dist * math.sin(progress * math.pi);
      final x = center.dx + currentDist * math.cos(p.angle);
      final y = center.dy + currentDist * math.sin(p.angle) + (progress * 60);
      final alpha = (1.0 - progress).clamp(0.0, 1.0);

      paint.color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), p.radius * (1.0 - progress * 0.3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OilDropsCelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
