import 'package:flutter/material.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';
import '../profile/avatar_builder_modal.dart';

class MonthlyStreakView extends StatefulWidget {
  const MonthlyStreakView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MonthlyStreakView()),
    );
  }

  @override
  State<MonthlyStreakView> createState() => _MonthlyStreakViewState();
}

class _MonthlyStreakViewState extends State<MonthlyStreakView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _currentMonth = DateTime.now();
  AchievementCategory? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _monthNames = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isGlass = themeService.isAnyGlass;
    final service = GamificationService();

    return ListenableBuilder(
      listenable: Listenable.merge([service, themeService]),
      builder: (context, _) {
        final hasGlobalBg = themeService.hasGlobalBackgroundShell;
        return Scaffold(
          backgroundColor: hasGlobalBg ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: themeService.isAscii
                ? theme.colorScheme.surface
                : (themeService.isWin95
                    ? const Color(0xFF000080)
                    : (isGlass ? Colors.transparent : null)),
            foregroundColor: themeService.isWin95 ? Colors.white : null,
            elevation: 0,
            scrolledUnderElevation: 0,
            shape: themeService.isAscii
                ? Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 1.5))
                : (themeService.isHoloRetro
                    ? const Border(bottom: BorderSide(color: Color(0xFF33B5E5), width: 2))
                    : null),
            title: const Text(
              'Ofensiva & Conquistas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                tooltip: 'Personalizar Avatar',
                icon: const Icon(Icons.face_retouching_natural_rounded),
                onPressed: () => AvatarBuilderModal.show(context),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Mês'),
                Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Conquistas'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildMonthTab(context, theme, service),
              _buildTrophiesTab(context, theme, service),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonthTab(BuildContext context, ThemeData theme, GamificationService service) {
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final totalDaysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7;

    int activeDaysCount = 0;
    for (int d = 1; d <= totalDaysInMonth; d++) {
      final dateStr =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      if (service.activityDates.contains(dateStr)) {
        activeDaysCount++;
      }
    }

    final today = DateTime.now();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        final summaryCards = [
          _buildSummaryCard(
            theme: theme,
            icon: Icons.local_fire_department_rounded,
            pixelIcon: SnesPixelIconType.lamp,
            iconColor: Colors.deepOrange,
            title: '${service.currentStreak} dias',
            subtitle: 'Ofensiva Atual',
            horizontal: isWide,
          ),
          _buildSummaryCard(
            theme: theme,
            icon: Icons.bolt_rounded,
            pixelIcon: SnesPixelIconType.bolt,
            iconColor: Colors.amber,
            title: '${service.totalXp} XP',
            subtitle: 'Total Acumulado',
            horizontal: isWide,
          ),
          _buildSummaryCard(
            theme: theme,
            icon: Icons.task_alt_rounded,
            pixelIcon: SnesPixelIconType.calendar,
            iconColor: Colors.green,
            title: '$activeDaysCount/$totalDaysInMonth',
            subtitle: 'Dias no Mês',
            horizontal: isWide,
          ),
        ];

        final calendarCard = _buildCalendarCard(
          theme,
          service,
          year: year,
          month: month,
          totalDaysInMonth: totalDaysInMonth,
          firstWeekday: firstWeekday,
          today: today,
        );

        if (isWide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summaryCards[0],
                          const SizedBox(height: 12),
                          summaryCards[1],
                          const SizedBox(height: 12),
                          summaryCards[2],
                          const SizedBox(height: 16),
                          _buildStreakLegendCard(theme),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 6,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: calendarCard,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: summaryCards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: summaryCards[1]),
                      const SizedBox(width: 12),
                      Expanded(child: summaryCards[2]),
                    ],
                  ),
                  const SizedBox(height: 20),
                  calendarCard,
                  const SizedBox(height: 16),
                  _buildStreakLegendCard(theme),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakLegendCard(ThemeData theme) {
    final ts = ThemeService();
    final isAscii = ts.isAscii;
    final isSquareRetro = isAscii || ts.isWin95 || ts.isHoloRetro;

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isAscii ? 'CRITERIOS DA OFENSIVA' : 'Critérios da Ofensiva',
          style: TextStyle(
            fontFamily: isAscii ? 'RetroPixel' : null,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: isSquareRetro ? BoxShape.rectangle : BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Chama Cheia: 100 gotas no dia (1.5x azeite)',
                style: TextStyle(
                  fontFamily: isAscii ? 'RetroPixel' : null,
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                shape: isSquareRetro ? BoxShape.rectangle : BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Meia Chama: 1+ missão cumprida mantém o pavio aceso',
                style: TextStyle(
                  fontFamily: isAscii ? 'RetroPixel' : null,
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    if (isAscii) {
      return AsciiBoxSurface(
        padding: const EdgeInsets.all(14),
        child: inner,
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(16),
        border: Border.all(
          color: ts.isHoloRetro
              ? const Color(0xFF33B5E5).withValues(alpha: 0.55)
              : theme.dividerColor.withValues(alpha: 0.14),
        ),
      ),
      child: inner,
    );
  }

  Widget _buildCalendarCard(
    ThemeData theme,
    GamificationService service, {
    required int year,
    required int month,
    required int totalDaysInMonth,
    required int firstWeekday,
    required DateTime today,
  }) {
    final ts = ThemeService();
    final isAscii = ts.isAscii;
    final isSquareRetro = isAscii || ts.isWin95 || ts.isHoloRetro;

    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Mês anterior',
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                });
              },
            ),
            Text(
              '${_monthNames[month - 1]} $year',
              style: theme.textTheme.titleMedium?.copyWith(
                fontFamily: isAscii ? 'RetroPixel' : null,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Próximo mês',
              onPressed: () {
                setState(() {
                  _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _WeekdayLabel('D'),
            _WeekdayLabel('S'),
            _WeekdayLabel('T'),
            _WeekdayLabel('Q'),
            _WeekdayLabel('Q'),
            _WeekdayLabel('S'),
            _WeekdayLabel('S'),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: firstWeekday + totalDaysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            mainAxisExtent: 46,
          ),
          itemBuilder: (context, index) {
            if (index < firstWeekday) {
              return const SizedBox.shrink();
            }
            final dayNumber = index - firstWeekday + 1;
            final dateStr =
                '$year-${month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
            final isActive = service.activityDates.contains(dateStr);
            final isToday =
                today.year == year && today.month == month && today.day == dayNumber;

            return Center(
              child: SizedBox(
                width: 42,
                height: 42,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: isSquareRetro ? BoxShape.rectangle : BoxShape.circle,
                    color: isActive
                        ? theme.colorScheme.primary
                        : isToday
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : theme.colorScheme.surfaceContainerLow,
                    border: isToday
                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                        : (isAscii
                            ? Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                width: 1,
                              )
                            : null),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontFamily: isAscii ? 'RetroPixel' : null,
                            fontSize: 13,
                            fontWeight:
                                isActive || isToday ? FontWeight.bold : FontWeight.normal,
                            color: isActive
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (isActive)
                          Icon(
                            Icons.local_fire_department,
                            size: 10,
                            color: theme.colorScheme.onPrimary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );

    if (isAscii) {
      return AsciiBoxSurface(
        label: '${_monthNames[month - 1].toUpperCase()} $year',
        doubleBorder: true,
        padding: const EdgeInsets.all(14),
        child: inner,
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(18),
        border: Border.all(
          color: ts.isHoloRetro
              ? const Color(0xFF33B5E5).withValues(alpha: 0.6)
              : theme.dividerColor.withValues(alpha: 0.14),
        ),
      ),
      child: inner,
    );
  }

  Widget _buildSummaryCard({
    required ThemeData theme,
    required IconData icon,
    required SnesPixelIconType pixelIcon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool horizontal = false,
  }) {
    final ts = ThemeService();
    final isAscii = ts.isAscii;
    final isSquareRetro = isAscii || ts.isWin95 || ts.isHoloRetro;

    final Widget iconWidget = isAscii
        ? SnesPixelIcon(type: pixelIcon, size: 22, color: theme.colorScheme.primary)
        : Icon(icon, color: iconColor, size: 24);

    final Widget body = horizontal
        ? Row(
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: isAscii ? 'RetroPixel' : null,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: isAscii ? 'RetroPixel' : null,
                        fontSize: 11.5,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            children: [
              iconWidget,
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: isAscii ? 'RetroPixel' : null,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: isAscii ? 'RetroPixel' : null,
                  fontSize: 11,
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );

    if (isAscii) {
      return AsciiBoxSurface(
        padding: EdgeInsets.symmetric(
          vertical: horizontal ? 12 : 14,
          horizontal: horizontal ? 14 : 8,
        ),
        child: body,
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: horizontal ? 12 : 14,
        horizontal: horizontal ? 14 : 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(16),
        border: Border.all(
          color: ts.isHoloRetro
              ? const Color(0xFF33B5E5).withValues(alpha: 0.5)
              : theme.dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: body,
    );
  }

  Widget _buildTrophiesTab(BuildContext context, ThemeData theme, GamificationService service) {
    final all = service.allAchievements;
    final unlockedTotal = all.where((a) => a.isUnlocked).length;
    final filtered = _selectedCategory == null
        ? all
        : all.where((a) => a.category == _selectedCategory).toList();

    Widget buildAchievementCard(AchievementDefinition t) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.isUnlocked
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.6),
          borderRadius: ThemeService().isAscii ? BorderRadius.zero : BorderRadius.circular(16),
          border: Border.all(
            color: t.isUnlocked
                ? t.color.withValues(alpha: 0.35)
                : theme.dividerColor.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: ThemeService().isAscii ? BoxShape.rectangle : BoxShape.circle,
                color: t.isUnlocked
                    ? t.color.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.14),
              ),
              child: Icon(
                t.icon,
                color: t.isUnlocked ? t.color : Colors.grey,
                size: 25,
              ),
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
                          t.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.5,
                            color: t.isUnlocked
                                ? theme.colorScheme.onSurface
                                : Colors.grey,
                          ),
                        ),
                      ),
                      Text(
                        '${t.current}/${t.target}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: t.isUnlocked
                              ? t.color
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.isUnlocked
                          ? theme.textTheme.bodySmall?.color
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: t.progress,
                      minHeight: 5,
                      backgroundColor: theme.dividerColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        t.isUnlocked ? t.color : theme.colorScheme.primary.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  if (t.rewardLabel != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.isUnlocked
                            ? Colors.amber.withValues(alpha: 0.16)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        t.isUnlocked
                            ? '🎁 Recompensa liberada: ${t.rewardLabel}'
                            : '🎁 Desbloqueia: ${t.rewardLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: t.isUnlocked
                              ? Colors.amber.shade800
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (t.isUnlocked)
              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
            else
              const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Column(
          children: [
            // Resumo de progresso geral + botão rápido de Avatar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: ThemeService().isAscii
                      ? BorderRadius.zero
                      : BorderRadius.circular(18),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    AvatarCustomWidget(config: service.avatarConfig, size: 52),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unlockedTotal de ${all.length} conquistas desbloqueadas',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: all.isEmpty ? 0 : unlockedTotal / all.length,
                              minHeight: 7,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => AvatarBuilderModal.show(context),
                      child: const Text('Equipar'),
                    ),
                  ],
                ),
              ),
            ),

            // Filtro por Categoria
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Todas'),
                      selected: _selectedCategory == null,
                      onSelected: (_) => setState(() => _selectedCategory = null),
                    ),
                  ),
                  ...AchievementCategory.values.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(cat.icon, size: 15),
                        label: Text(cat.label),
                        selected: _selectedCategory == cat,
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Lista / Grade responsiva de Conquistas
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 760) {
                    final rowCount = (filtered.length / 2).ceil();
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: rowCount,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, rowIdx) {
                        final firstIdx = rowIdx * 2;
                        final secondIdx = firstIdx + 1;
                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: buildAchievementCard(filtered[firstIdx])),
                              const SizedBox(width: 12),
                              Expanded(
                                child: secondIdx < filtered.length
                                    ? buildAchievementCard(filtered[secondIdx])
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => buildAchievementCard(filtered[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
