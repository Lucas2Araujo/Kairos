import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../models/reading_plan_models.dart';
import '../../services/reading_plan_service.dart';
import '../../services/theme_service.dart';

/// Tela completa de Catálogo e Gerenciamento de Planos de Leitura Bíblica
class ReadingPlansView extends StatefulWidget {
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const ReadingPlansView({
    super.key,
    this.bibleController,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    BibleController? bibleController,
    void Function(int tabIndex)? onNavigateToTab,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReadingPlansView(
          bibleController: bibleController,
          onNavigateToTab: onNavigateToTab,
        ),
      ),
    );
  }

  /// Diálogo discreto para começar o plano de um dia específico ou calibrar o dia atual
  static void showJumpToDayDialog(BuildContext context, ReadingPlan plan) {
    final planService = ReadingPlanService();
    final prog = planService.getProgress(plan.id);
    final currentDay = prog?.calculateCurrentDay(plan.daysCount) ?? 1;

    final controller = TextEditingController(text: currentDay.toString());
    bool markPrevious = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit_calendar_rounded, color: plan.accentColor),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Definir Dia Atual',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Comece o plano "${plan.title}" da metade ou calibre seu dia atual.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Dia de Leitura (1 a ${plan.daysCount})',
                        hintText: 'Ex: 600',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.today_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: markPrevious,
                      activeColor: plan.accentColor,
                      title: const Text(
                        'Marcar dias anteriores como lidos',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Mantém seu percentual e histórico de progresso coerentes.',
                        style: TextStyle(fontSize: 11),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          markPrevious = val ?? true;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  final targetDay = int.tryParse(text);
                  if (targetDay == null || targetDay < 1 || targetDay > plan.daysCount) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Informe um dia válido entre 1 e ${plan.daysCount}.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.of(ctx).pop();
                  await planService.jumpToDay(
                    plan.id,
                    targetDay,
                    markPreviousAsCompleted: markPrevious,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Plano "${plan.title}" ajustado para o Dia $targetDay!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  State<ReadingPlansView> createState() => _ReadingPlansViewState();
}

class _ReadingPlansViewState extends State<ReadingPlansView> {
  @override
  void initState() {
    super.initState();
    final service = ReadingPlanService();
    if (!service.isInitialized) {
      service.init();
    }
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
        final activePlans = planService.activePlans;
        final allPlans = planService.allPlans;

        return Scaffold(
          backgroundColor: isGlass ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
            title: const Text(
              'Planos de Leitura',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Seção de Planos em Andamento (se houver)
                    if (activePlans.isNotEmpty) ...[
                      Text(
                        'Em Andamento',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...activePlans.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildActivePlanCard(context, item.plan, item.progress),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Seção de Catálogo Completo
                    Text(
                      'Explorar Planos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...allPlans.map((plan) {
                      final prog = planService.getProgress(plan.id);
                      final isActive = prog?.isActive ?? false;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildCatalogPlanCard(context, plan, prog, isActive),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivePlanCard(
    BuildContext context,
    ReadingPlan plan,
    UserPlanProgress progress,
  ) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isGlass = themeService.isAnyGlass;
    final planService = ReadingPlanService();
    final todayStatus = planService.getTodayStatus(plan.id);

    final currentDay = todayStatus?.currentDayIndex ?? 1;
    final readingSummary = todayStatus?.day?.readingSummary ?? 'Leitura do dia';
    final progressPct = progress.getProgressPercentage(plan.daysCount);

    final cardContent = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: plan.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(plan.icon, color: plan.accentColor, size: 24),
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
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (progress.isPrimary) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'PRINCIPAL',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dia $currentDay de ${plan.daysCount} • $readingSummary',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressPct,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(plan.accentColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!progress.isPrimary)
                TextButton(
                  onPressed: () => planService.setPrimaryPlan(plan.id),
                  child: const Text('Tornar Principal'),
                ),
              OutlinedButton.icon(
                onPressed: () => _showPlanDetailsSheet(context, plan, progress),
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Detalhes'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _startReading(context, plan, todayStatus?.day),
                style: FilledButton.styleFrom(backgroundColor: plan.accentColor),
                icon: const Icon(Icons.menu_book, size: 16),
                label: const Text('Ler Agora'),
              ),
            ],
          ),
        ],
      ),
    );

    if (isGlass) {
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
          color: progress.isPrimary
              ? plan.accentColor.withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.1),
          width: progress.isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: cardContent,
    );
  }

  Widget _buildCatalogPlanCard(
    BuildContext context,
    ReadingPlan plan,
    UserPlanProgress? progress,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isGlass = themeService.isAnyGlass;
    final planService = ReadingPlanService();

    final cardContent = Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: plan.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(plan.icon, color: plan.accentColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${plan.daysCount} dias',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  plan.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => _showPlanDetailsSheet(context, plan, progress),
                      child: const Text('Ver Roteiro'),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                      tooltip: 'Começar de outro dia...',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ReadingPlansView.showJumpToDayDialog(context, plan),
                    ),
                    const SizedBox(width: 4),
                    if (!isActive)
                      FilledButton(
                        onPressed: () async {
                          await planService.activatePlan(plan.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Plano "${plan.title}" iniciado com sucesso!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: const Text('Iniciar Plano'),
                      )
                    else
                      OutlinedButton(
                        onPressed: () => planService.deactivatePlan(plan.id),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        child: const Text('Pausar Plano'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (isGlass) {
      return GlassSurface(
        borderRadius: 16,
        child: cardContent,
      );
    }

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: cardContent,
    );
  }

  void _startReading(BuildContext context, ReadingPlan plan, ReadingPlanDay? day) {
    if (day == null || day.chapters.isEmpty) return;

    final firstPending = day.chapters.first;
    if (widget.bibleController != null) {
      widget.bibleController!.jumpToVerse(firstPending.bookId, firstPending.chapter, 1);
    }

    if (widget.onNavigateToTab != null) {
      Navigator.of(context).pop();
      widget.onNavigateToTab!(1); // Tab 1 = BibleReaderView
    }
  }

  void _showPlanDetailsSheet(
    BuildContext context,
    ReadingPlan plan,
    UserPlanProgress? progress,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanDetailsBottomSheet(
        plan: plan,
        initialProgress: progress,
        onStartReading: (day) => _startReading(context, plan, day),
      ),
    );
  }
}

class _PlanDetailsBottomSheet extends StatefulWidget {
  final ReadingPlan plan;
  final UserPlanProgress? initialProgress;
  final void Function(ReadingPlanDay day) onStartReading;

  const _PlanDetailsBottomSheet({
    required this.plan,
    required this.initialProgress,
    required this.onStartReading,
  });

  @override
  State<_PlanDetailsBottomSheet> createState() => _PlanDetailsBottomSheetState();
}

class _PlanDetailsBottomSheetState extends State<_PlanDetailsBottomSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final planService = ReadingPlanService();

    return ListenableBuilder(
      listenable: planService,
      builder: (context, _) {
        final prog = planService.getProgress(widget.plan.id) ?? widget.initialProgress;
        final isActive = prog?.isActive ?? false;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: widget.plan.accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(widget.plan.icon, color: widget.plan.accentColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plan.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                '${widget.plan.daysCount} dias • ${widget.plan.category}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isActive)
                          FilledButton(
                            onPressed: () => planService.activatePlan(widget.plan.id),
                            child: const Text('Iniciar'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => planService.deactivatePlan(widget.plan.id),
                            child: const Text('Pausar'),
                          ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                          tooltip: 'Definir dia atual...',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => ReadingPlansView.showJumpToDayDialog(context, widget.plan),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: widget.plan.days.length,
                      itemBuilder: (context, index) {
                        final day = widget.plan.days[index];
                        final isCompleted = prog?.completedDays.contains(day.dayIndex) ?? false;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          onLongPress: () {
                            ReadingPlansView.showJumpToDayDialog(context, widget.plan);
                          },
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isCompleted
                                ? Colors.green.withValues(alpha: 0.2)
                                : theme.colorScheme.surfaceContainerHighest,
                            child: isCompleted
                                ? const Icon(Icons.check, size: 16, color: Colors.green)
                                : Text(
                                    '${day.dayIndex}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                          ),
                          title: Text(
                            day.readingSummary,
                            style: TextStyle(
                              fontWeight: isCompleted ? FontWeight.normal : FontWeight.w600,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          subtitle: Text(
                            day.title,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 14),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onStartReading(day);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

