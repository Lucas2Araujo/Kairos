import 'package:flutter/material.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';

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
      listenable: service,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isGlass ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
            title: const Text(
              'Ofensiva & Conquistas',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // Dom = 0

    // Calcula dias ativos no mês corrente
    int activeDaysCount = 0;
    for (int d = 1; d <= totalDaysInMonth; d++) {
      final dateStr =
          '$year-${month.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
      if (service.activityDates.contains(dateStr)) {
        activeDaysCount++;
      }
    }

    final today = DateTime.now();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resumo no topo
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  theme: theme,
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.deepOrange,
                  title: '${service.currentStreak} dias',
                  subtitle: 'Ofensiva Atual',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  theme: theme,
                  icon: Icons.bolt_rounded,
                  iconColor: Colors.amber,
                  title: '${service.totalXp} XP',
                  subtitle: 'Total Acumulado',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  theme: theme,
                  icon: Icons.task_alt_rounded,
                  iconColor: Colors.green,
                  title: '$activeDaysCount/$totalDaysInMonth',
                  subtitle: 'Dias no Mês',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Seletor de Mês
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                  });
                },
              ),
              Text(
                '${_monthNames[month - 1]} $year',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Cabeçalho dos dias da semana
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

          // Grid do Calendário
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + totalDaysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - firstWeekday + 1;
              final dateStr =
                  '$year-${month.toString().padLeft(2, '0')}-${dayNumber.toString().padLeft(2, '0')}';
              final isActive = service.activityDates.contains(dateStr);
              final isToday = today.year == year && today.month == month && today.day == dayNumber;

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? theme.colorScheme.primary
                      : isToday
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                          : theme.colorScheme.surfaceContainerLow,
                  border: isToday
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive || isToday ? FontWeight.bold : FontWeight.normal,
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
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required ThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTrophiesTab(BuildContext context, ThemeData theme, GamificationService service) {
    final streak = service.currentStreak;
    final xp = service.totalXp;

    final trophies = [
      _Trophy(
        title: 'Primeiro Passo',
        description: 'Faça sua primeira leitura devocional ou estudo.',
        icon: Icons.flag_rounded,
        color: Colors.amber,
        isUnlocked: service.activityDates.isNotEmpty || streak >= 1,
      ),
      _Trophy(
        title: 'Tríplice Aliança',
        description: 'Mantenha 3 dias consecutivos de ofensiva.',
        icon: Icons.local_fire_department_rounded,
        color: Colors.deepOrange,
        isUnlocked: streak >= 3,
      ),
      _Trophy(
        title: 'Semana de Vitória',
        description: 'Alcance 7 dias consecutivos de ofensiva.',
        icon: Icons.workspace_premium_rounded,
        color: Colors.purpleAccent,
        isUnlocked: streak >= 7,
      ),
      _Trophy(
        title: 'Constância Mensal',
        description: 'Alcance 30 dias de comunhão ininterrupta.',
        icon: Icons.military_tech_rounded,
        color: Colors.teal,
        isUnlocked: streak >= 30,
      ),
      _Trophy(
        title: 'Iniciante do Saber',
        description: 'Acumule seus primeiros 50 XP.',
        icon: Icons.bolt_rounded,
        color: Colors.amberAccent,
        isUnlocked: xp >= 50,
      ),
      _Trophy(
        title: 'Explorador Bíblico',
        description: 'Acumule 200 XP em estudos e quizzes.',
        icon: Icons.auto_stories_rounded,
        color: Colors.blueAccent,
        isUnlocked: xp >= 200,
      ),
      _Trophy(
        title: 'Mestre da Palavra',
        description: 'Atinja o marco memorável de 500 XP.',
        icon: Icons.diamond_rounded,
        color: Colors.indigoAccent,
        isUnlocked: xp >= 500,
      ),
      // Novos Troféus Gamificação 2.0 (Lamparina & Azeite)
      _Trophy(
        title: 'Sentinela da Manhã',
        description: 'Faça sua meditação ou leitura antes das 8h da manhã.',
        icon: Icons.wb_twilight_rounded,
        color: Colors.orangeAccent,
        isUnlocked: service.trophyMorningSentinel,
      ),
      _Trophy(
        title: 'Virgem Prudente',
        description: 'Mantenha 7 dias de Chama Completa (azeite transbordando).',
        icon: Icons.light_mode_rounded,
        color: Colors.amber,
        isUnlocked: service.trophyPrudentVirgin7Days,
      ),
      _Trophy(
        title: 'Mestre da Escola Sabatina',
        description: 'Conclua o Quiz da Lição em 5 dias.',
        icon: Icons.school_rounded,
        color: Colors.deepPurpleAccent,
        isUnlocked: service.completedQuizzesCount >= 5,
      ),
      _Trophy(
        title: 'Bereano da Palavra',
        description: 'Leia pelo menos 30 capítulos da Bíblia.',
        icon: Icons.menu_book_rounded,
        color: Colors.tealAccent,
        isUnlocked: service.completedChaptersCount >= 30,
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: trophies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final t = trophies[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: t.isUnlocked
                ? theme.colorScheme.surfaceContainerLow
                : theme.colorScheme.surfaceContainerLowest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: t.isUnlocked
                  ? t.color.withValues(alpha: 0.3)
                  : theme.dividerColor.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.isUnlocked ? t.color.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
                ),
                child: Icon(
                  t.icon,
                  color: t.isUnlocked ? t.color : Colors.grey,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: t.isUnlocked ? theme.colorScheme.onSurface : Colors.grey,
                      ),
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
                  ],
                ),
              ),
              if (t.isUnlocked)
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22)
              else
                const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
            ],
          ),
        );
      },
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

class _Trophy {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  const _Trophy({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });
}
