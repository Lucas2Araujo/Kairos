import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../models/reading_plan_models.dart';
import '../../../services/reading_plan_service.dart';
import '../../../services/theme_service.dart';
import '../../plans/reading_plans_view.dart';

/// Card expansivo de Plano de Leitura da Home (estilo ofensiva/gamification)
class ActivePlanBanner extends StatefulWidget {
  final bool? isGlass;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const ActivePlanBanner({
    super.key,
    this.isGlass,
    this.bibleController,
    this.onNavigateToTab,
  });

  @override
  State<ActivePlanBanner> createState() => _ActivePlanBannerState();
}

class _ActivePlanBannerState extends State<ActivePlanBanner> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    final service = ReadingPlanService();
    if (!service.isInitialized) {
      service.init();
    }
  }

  void _onReadPressed(ReadingPlan plan, ReadingPlanDay? day) {
    if (day == null || day.chapters.isEmpty) return;

    final planService = ReadingPlanService();
    // Encontra o primeiro capítulo ainda pendente
    final firstPending = day.chapters.firstWhere(
      (c) => !planService.isChapterCompleted(plan.id, '${c.bookId}:${c.chapter}'),
      orElse: () => day.chapters.first,
    );

    if (widget.bibleController != null) {
      widget.bibleController!.jumpToVerse(firstPending.bookId, firstPending.chapter, 1);
    }

    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(1); // Tab 1 = BibleReaderView
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final effectiveGlass = widget.isGlass ?? themeService.isAnyGlass;
    final planService = ReadingPlanService();

    return ListenableBuilder(
      listenable: planService,
      builder: (context, _) {
        final primary = planService.primaryPlan;
        final activePlans = planService.activePlans;

        if (primary == null) {
          // Nenhum plano ativo: exibe convite elegante para começar um plano
          return _buildEmptyInvitationCard(context, theme, effectiveGlass);
        }

        final plan = primary.plan;
        final progress = primary.progress;
        final todayStatus = planService.getTodayStatus(plan.id);

        final currentDayIndex = todayStatus?.currentDayIndex ?? 1;
        final readingSummary = todayStatus?.day?.readingSummary ?? 'Leitura de hoje';
        final isDayCompleted = todayStatus?.isDayCompleted ?? false;
        final progressPct = progress.getProgressPercentage(plan.daysCount);
        final pctLabel = '${(progressPct * 100).toInt()}%';

        final cardContent = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabeçalho / Modo Recolhido
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: plan.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(plan.icon, color: plan.accentColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  plan.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: plan.accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  pctLabel,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: plan.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dia $currentDayIndex • $readingSummary',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDayCompleted
                                  ? Colors.green.shade700
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: isDayCompleted ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Botão rápido "Ler"
                    FilledButton.tonal(
                      onPressed: () => _onReadPressed(plan, todayStatus?.day),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        backgroundColor: plan.accentColor.withValues(alpha: 0.18),
                        foregroundColor: plan.accentColor,
                      ),
                      child: Text(
                        isDayCompleted ? 'Rever' : 'Ler',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Seta de expansão
                    Icon(
                      _isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),

              // Barra de progresso linear fina
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressPct,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(plan.accentColor),
                ),
              ),

              // Seção Expandida
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Checkboxes dos capítulos de hoje
                      if (todayStatus?.day != null && todayStatus!.day!.chapters.isNotEmpty) ...[
                        Text(
                          'Capítulos de Hoje (Dia $currentDayIndex):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: todayStatus.day!.chapters.map((ch) {
                            final chKey = '${ch.bookId}:${ch.chapter}';
                            final isDone = planService.isChapterCompleted(plan.id, chKey);

                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () {
                                planService.toggleChapterCompletion(
                                  plan.id,
                                  currentDayIndex,
                                  chKey,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDone
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDone
                                        ? Colors.green.withValues(alpha: 0.4)
                                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDone
                                          ? Icons.check_box_rounded
                                          : Icons.check_box_outline_blank_rounded,
                                      size: 16,
                                      color: isDone ? Colors.green : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      ch.shortRef,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: isDone ? FontWeight.bold : FontWeight.w500,
                                        color: isDone ? Colors.green.shade800 : theme.colorScheme.onSurface,
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

                      // Outros planos ativos secundários
                      if (activePlans.length > 1) ...[
                        Text(
                          'Outros planos em andamento:',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: activePlans
                              .where((item) => item.plan.id != plan.id)
                              .map((item) {
                            return ActionChip(
                              avatar: Icon(item.plan.icon, size: 14, color: item.plan.accentColor),
                              label: Text(
                                item.plan.title,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              tooltip: 'Definir como Plano Principal',
                              onPressed: () => planService.setPrimaryPlan(item.plan.id),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Barra de ações do rodapé
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => ReadingPlansView.show(
                              context,
                              bibleController: widget.bibleController,
                              onNavigateToTab: widget.onNavigateToTab,
                            ),
                            icon: const Icon(Icons.apps_rounded, size: 16),
                            label: const Text('Ver Todos os Planos', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                          ),
                          if (!isDayCompleted)
                            FilledButton.icon(
                              onPressed: () {
                                planService.completeDay(plan.id, currentDayIndex);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Dia concluído! +40 gotas de azeite na sua lamparina! 💧✨'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.green.shade700,
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 15),
                              label: const Text('Concluir Dia', style: TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                crossFadeState:
                    _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        );

        if (effectiveGlass) {
          return GlassSurface(
            borderRadius: 16,
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
          child: cardContent,
        );
      },
    );
  }

  Widget _buildEmptyInvitationCard(
    BuildContext context,
    ThemeData theme,
    bool effectiveGlass,
  ) {
    final cardContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.menu_book_rounded, color: theme.colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plano de Estudo Bíblico',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Escolha um plano de leitura e abasteça sua lâmpada!',
                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => ReadingPlansView.show(
              context,
              bibleController: widget.bibleController,
              onNavigateToTab: widget.onNavigateToTab,
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Explorar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );

    if (effectiveGlass) {
      return GlassSurface(
        borderRadius: 16,
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
      child: cardContent,
    );
  }
}

