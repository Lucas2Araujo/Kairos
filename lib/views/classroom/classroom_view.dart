import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';
import '../profile/avatar_builder_modal.dart';

enum ClassroomPeriodFilter {
  currentWeek,
  currentMonth,
  currentQuarter,
}

class ClassroomView extends StatefulWidget {
  const ClassroomView({super.key});

  @override
  State<ClassroomView> createState() => _ClassroomViewState();
}

class _ClassroomViewState extends State<ClassroomView> with SingleTickerProviderStateMixin {
  final ClassroomService _service = ClassroomService();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _churchNameController = TextEditingController();
  final TextEditingController _webhookUrlController = TextEditingController();

  ClassroomPeriodFilter _selectedPeriod = ClassroomPeriodFilter.currentWeek;
  TabController? _tabController;
  bool _isSyncingSheets = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _service.loadUserClassroom();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _joinCodeController.dispose();
    _classNameController.dispose();
    _churchNameController.dispose();
    _webhookUrlController.dispose();
    super.dispose();
  }

  (DateTime, DateTime) _getPeriodDateRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ClassroomPeriodFilter.currentWeek:
        // Domingo a Sábado da semana corrente
        final start = now.subtract(Duration(days: now.weekday % 7));
        final end = start.add(const Duration(days: 6));
        return (DateTime(start.year, start.month, start.day), DateTime(end.year, end.month, end.day, 23, 59, 59));
      case ClassroomPeriodFilter.currentMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        return (start, end);
      case ClassroomPeriodFilter.currentQuarter:
        final currentQuarter = ((now.month - 1) ~/ 3) + 1;
        final startMonth = (currentQuarter - 1) * 3 + 1;
        final start = DateTime(now.year, startMonth, 1);
        final end = DateTime(now.year, startMonth + 3, 0, 23, 59, 59);
        return (start, end);
    }
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case ClassroomPeriodFilter.currentWeek:
        return 'Semana Atual';
      case ClassroomPeriodFilter.currentMonth:
        return 'Mês Atual';
      case ClassroomPeriodFilter.currentQuarter:
        return 'Trimestre Atual';
    }
  }

  Future<void> _handleJoinClass() async {
    final code = _joinCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite o código de 6 caracteres da turma.')),
      );
      return;
    }

    try {
      final success = await _service.joinClassroom(code);
      if (!mounted) return;
      if (success) {
        _joinCodeController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bem-vindo à sua nova Classe Jovem / PG!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código de turma não encontrado ou inválido.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showCreateClassDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Criar Nova Turma / PG'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _classNameController,
              decoration: const InputDecoration(
                labelText: 'Nome da Classe / Turma',
                hintText: 'Ex: Classe Jovem Geração Esperança',
                prefixIcon: Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _churchNameController,
              decoration: const InputDecoration(
                labelText: 'Igreja / Congregação',
                hintText: 'Ex: IASD Central',
                prefixIcon: Icon(Icons.church_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final name = _classNameController.text.trim();
              final church = _churchNameController.text.trim();
              if (name.isEmpty || church.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, preencha o nome da turma e da igreja.')),
                );
                return;
              }

              final auth = AuthService();
              if (!auth.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Você precisa estar conectado à sua conta Kairós para criar uma turma.'),
                  ),
                );
                return;
              }

              Navigator.of(ctx).pop();
              try {
                final created = await _service.createClassroom(
                  name: name,
                  churchName: church,
                );

                if (!mounted) return;
                if (created != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.green.shade700,
                      content: Text('Turma criada com sucesso! Código: ${created.code}'),
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red.shade700,
                    content: Text('Erro: ${e.toString().replaceAll('Exception: ', '')}'),
                  ),
                );
              }
            },
            child: const Text('Criar Turma'),
          ),
        ],
      ),
    );
  }

  void _showWebhookConfigDialog() {
    _webhookUrlController.text = _service.currentClassroom?.webhookUrl ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_chart_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Integração Google Sheets'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sincronize automaticamente os dados da sua turma com uma planilha do Google Sheets usando um Web App do Apps Script.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _webhookUrlController,
              decoration: const InputDecoration(
                labelText: 'URL do Webhook (Google Apps Script)',
                hintText: 'https://script.google.com/macros/s/.../exec',
                prefixIcon: Icon(Icons.link_rounded),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar Código do Google Apps Script'),
              onPressed: () {
                _showAppsScriptCodeModal();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              final url = _webhookUrlController.text.trim();
              Navigator.of(ctx).pop();
              final ok = await _service.updateWebhookUrl(url);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL do Webhook salva com sucesso!')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showAppsScriptCodeModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código do Google Apps Script'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Siga estes 3 passos simples para automatizar sua planilha:\n'
                '1. Abra o Google Planilhas > Extensões > Apps Script\n'
                '2. Cole o código abaixo e clique em Implantar > Nova Implantação > App da Web (Quem pode acessar: Qualquer pessoa)\n'
                '3. Copie a URL gerada e cole nas configurações da Turma.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                height: 150,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SingleChildScrollView(
                  child: SelectableText(
                    ClassroomService.googleAppsScriptTemplate,
                    style: TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar Código'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: ClassroomService.googleAppsScriptTemplate));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Código copiado para a área de transferência!')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _exportExcelReport(List<StudentStatsItem> stats) {
    final csv = ClassroomService.generateExcelCsvReport(
      classroomName: _service.currentClassroom?.name ?? 'Turma Kairós',
      periodLabel: _getPeriodLabel(),
      stats: stats,
    );

    // Permite copiar ou baixar
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Relatório Excel Gerado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'O relatório foi formatado com codificação UTF-8 BOM, 100% compatível com Microsoft Excel e LibreOffice Calc.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              height: 120,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: SelectableText(csv, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar Dados Excel'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csv));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Relatório copiado! Cole direto no Excel ou Bloco de Notas.')),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleSyncSheets(List<StudentStatsItem> stats) async {
    setState(() => _isSyncingSheets = true);
    final ok = await _service.syncWithGoogleSheetsWebhook(
      stats: stats,
      periodName: _getPeriodLabel(),
    );
    if (mounted) {
      setState(() => _isSyncingSheets = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Planilha do Google Sheets sincronizada com sucesso!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao sincronizar. Verifique a URL do Webhook nas configurações.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGlass = ThemeService().isAnyGlass;

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final cr = _service.currentClassroom;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              cr != null ? cr.name : 'Turmas & Pequenos Grupos',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              if (cr != null && _service.isTeacher) ...[
                IconButton(
                  icon: const Icon(Icons.settings_suggest_rounded),
                  tooltip: 'Configurar Webhook Sheets',
                  onPressed: _showWebhookConfigDialog,
                ),
              ],
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar Dados',
                onPressed: () => _service.fetchClassroomData(),
              ),
            ],
            bottom: cr != null && _service.isTeacher
                ? TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.emoji_events_rounded), text: 'Visão Geral (Evento)'),
                      Tab(icon: Icon(Icons.supervised_user_circle_rounded), text: 'Visão Individual'),
                    ],
                  )
                : null,
          ),
          body: _service.isLoading
              ? const Center(child: CircularProgressIndicator())
              : cr == null
                  ? _buildNoClassroomView(theme, isGlass)
                  : _service.isTeacher
                      ? _buildTeacherView(theme, isGlass)
                      : _buildStudentView(theme, isGlass),
        );
      },
    );
  }

  /// Tela quando o usuário não pertence a nenhuma turma ainda
  Widget _buildNoClassroomView(ThemeData theme, bool isGlass) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.diversity_3_rounded, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Participe de uma Classe Jovem ou PG',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Conecte-se com sua turma da Escola Sabatina para estudarem juntos, manterem a chama acesa e celebrarem o progresso espiritual.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              // Campo para código de 6 caracteres
              TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
                decoration: InputDecoration(
                  labelText: 'Código da Turma (6 dígitos)',
                  hintText: 'KAI777',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                key: const Key('join_classroom_button'),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Entrar na Turma', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _handleJoinClass,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OU PROFESSOR / LÍDER', style: theme.textTheme.labelSmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                key: const Key('create_classroom_button'),
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Criar Nova Turma ou Pequeno Grupo'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _showCreateClassDialog,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Visão do Aluno: Posição, mural e detalhes da sua turma
  Widget _buildStudentView(ThemeData theme, bool isGlass) {
    final range = _getPeriodDateRange();
    final stats = _service.calculateStudentStats(startDate: range.$1, endDate: range.$2);
    final user = AuthService().currentUser;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card da Turma
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _service.currentClassroom!.name,
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _service.currentClassroom!.churchName,
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Text(
                        _service.currentClassroom!.code,
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Filtro de Período
              _buildPeriodSelector(theme),
              const SizedBox(height: 20),
              Text(
                'Mural da Classe Jovem',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Lista de Posições
              for (int i = 0; i < stats.length; i++) ...[
                _buildStudentCard(theme, stats[i], rank: i + 1, isCurrentUser: stats[i].member.userId == user?.id),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Visão do Professor (2 abas com filtro de período)
  Widget _buildTeacherView(ThemeData theme, bool isGlass) {
    final range = _getPeriodDateRange();
    final stats = _service.calculateStudentStats(startDate: range.$1, endDate: range.$2);

    return Column(
      children: [
        // Barra Superior do Professor com Filtro e Botões de Ação
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Row(
            children: [
              Expanded(child: _buildPeriodSelector(theme)),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(Icons.file_download_rounded),
                tooltip: 'Exportar Planilha Excel (.xlsx/.csv)',
                onPressed: () => _exportExcelReport(stats),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                icon: _isSyncingSheets
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded),
                tooltip: 'Sincronizar Agora com Google Sheets',
                onPressed: _isSyncingSheets ? null : () => _handleSyncSheets(stats),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Aba 1: Visão Geral (Modo Evento / Premiação)
              _buildTeacherGeneralView(theme, isGlass, stats),
              // Aba 2: Visão Individual (Acompanhamento Pastoral)
              _buildTeacherIndividualView(theme, isGlass, stats),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return SegmentedButton<ClassroomPeriodFilter>(
      segments: const [
        ButtonSegment(value: ClassroomPeriodFilter.currentWeek, label: Text('Semana')),
        ButtonSegment(value: ClassroomPeriodFilter.currentMonth, label: Text('Mês')),
        ButtonSegment(value: ClassroomPeriodFilter.currentQuarter, label: Text('Trimestre')),
      ],
      selected: {_selectedPeriod},
      onSelectionChanged: (val) {
        setState(() => _selectedPeriod = val.first);
      },
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  /// Visão Geral (Modo Evento / Premiação da Igreja)
  Widget _buildTeacherGeneralView(ThemeData theme, bool isGlass, List<StudentStatsItem> stats) {
    final totalHours = stats.fold<int>(0, (sum, s) => sum + s.totalMinutes) / 60.0;
    final totalQuizzes = stats.fold<int>(0, (sum, s) => sum + s.totalQuizzes);
    final fullFlameCount = stats.where((s) => s.isFullStreakActive).length;
    final fullFlamePercent = stats.isNotEmpty ? (fullFlameCount / stats.length * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Termômetro Coletivo da Classe
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      theme,
                      title: 'Horas com Deus',
                      value: '${totalHours.toStringAsFixed(1)}h',
                      icon: Icons.access_time_filled_rounded,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      theme,
                      title: 'Quizzes Feitos',
                      value: '$totalQuizzes',
                      icon: Icons.quiz_rounded,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      theme,
                      title: 'Ofensiva Completa',
                      value: '$fullFlamePercent%',
                      icon: Icons.local_fire_department_rounded,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Pódio Visual Top 3
              Text(
                'Pódio de Destaque da Classe',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              _buildPodiumView(theme, stats),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(ThemeData theme, {required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Pódio Top 3 Estilizado
  Widget _buildPodiumView(ThemeData theme, List<StudentStatsItem> stats) {
    if (stats.isEmpty) {
      return const Center(child: Text('Nenhum aluno cadastrado na turma ainda.'));
    }

    final first = stats.isNotEmpty ? stats[0] : null;
    final second = stats.length > 1 ? stats[1] : null;
    final third = stats.length > 2 ? stats[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 2º Lugar
        if (second != null)
          Expanded(child: _buildPodiumStep(theme, second, rank: 2, height: 160, color: Colors.grey.shade400))
        else
          const Spacer(),
        const SizedBox(width: 12),
        // 1º Lugar
        if (first != null)
          Expanded(child: _buildPodiumStep(theme, first, rank: 1, height: 210, color: Colors.amber))
        else
          const Spacer(),
        const SizedBox(width: 12),
        // 3º Lugar
        if (third != null)
          Expanded(child: _buildPodiumStep(theme, third, rank: 3, height: 130, color: Colors.brown.shade400))
        else
          const Spacer(),
      ],
    );
  }

  Widget _buildPodiumStep(ThemeData theme, StudentStatsItem item, {required int rank, required double height, required Color color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AvatarCustomWidget(
          config: item.member.avatarConfig,
          size: rank == 1 ? 72 : 56,
        ),
        const SizedBox(height: 6),
        Text(
          item.member.studentName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          '${item.totalXp} XP',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(color: color, width: 2),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#$rank',
                style: TextStyle(fontSize: rank == 1 ? 32 : 24, fontWeight: FontWeight.bold, color: color),
              ),
              const Icon(Icons.workspace_premium_rounded, size: 28),
            ],
          ),
        ),
      ],
    );
  }

  /// Visão Individual (Acompanhamento Pastoral)
  Widget _buildTeacherIndividualView(ThemeData theme, bool isGlass, List<StudentStatsItem> stats) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) => _buildStudentCard(theme, stats[i], rank: i + 1),
    );
  }

  Widget _buildStudentCard(ThemeData theme, StudentStatsItem item, {required int rank, bool isCurrentUser = false}) {
    Color flameColor;
    String flameText;
    switch (item.currentFlame) {
      case FlameType.fullFlame:
        flameColor = Colors.orange;
        flameText = 'Completa';
        break;
      case FlameType.halfFlame:
        flameColor = Colors.amber;
        flameText = 'Meia';
        break;
      case FlameType.none:
        flameColor = Colors.grey;
        flameText = 'Apagada';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentUser
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 12),
          AvatarCustomWidget(
            config: item.member.avatarConfig,
            size: 44,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.member.studentName,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('VOCÊ', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      '⏱ ${item.totalMinutes}m com Deus',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '📖 ${item.lessonsStudiedDays} dias lição',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '🎯 Quiz: ${item.totalScore} pts',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: flameColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 14, color: flameColor),
                    const SizedBox(width: 2),
                    Text(
                      flameText,
                      style: TextStyle(color: flameColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${item.totalXp} XP',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
