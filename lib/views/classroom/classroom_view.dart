import 'package:flutter/foundation.dart';
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
  final String? initialCode;

  const ClassroomView({
    super.key,
    this.initialCode,
  });

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

    if (widget.initialCode != null && widget.initialCode!.isNotEmpty) {
      _joinCodeController.text = widget.initialCode!.trim().toUpperCase();
    } else if (kIsWeb) {
      try {
        final params = AuthService.extractParamsFromUri(Uri.base);
        final joinParam = params['join'];
        if (joinParam != null && joinParam.isNotEmpty) {
          _joinCodeController.text = joinParam.trim().toUpperCase();
        }
      } catch (_) {}
    }

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
                  _showInviteDialog();
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

  void _showInviteDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;
    final inviteUrl = _service.getInviteUrl();
    final inviteMessage = _service.getInviteMessage();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Convidar para a Turma'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Compartilhe o código ou o link da turma com os membros e amigos da sua classe:',
                  style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CÓDIGO DA CLASSE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        cr.code,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar Apenas o Código'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: cr.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Código ${cr.code} copiado!')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Copiar Convite Formatado (WhatsApp)'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteMessage));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mensagem de convite copiada! Pronta para colar no WhatsApp/Telegram.')),
                    );
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Copiar Link Direto'),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link direto copiado!')),
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.help_outline_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Como o aluno entra?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1. O aluno clica no link compartilhado ou abre o app Kairós.\n'
                        '2. Se ainda não tiver login, basta entrar com a conta Google.\n'
                        '3. Na aba Turmas, o código será preenchido automaticamente (ou o aluno digita ${cr.code}).',
                        style: const TextStyle(fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  void _showClassSettingsDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;
    _classNameController.text = cr.name;
    _churchNameController.text = cr.churchName;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.tune_rounded),
            SizedBox(width: 8),
            Text('Configurações da Turma'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _classNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da Classe',
                    prefixIcon: Icon(Icons.group_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _churchNameController,
                  decoration: const InputDecoration(
                    labelText: 'Igreja / Congregação',
                    prefixIcon: Icon(Icons.church_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.table_chart_rounded, color: Colors.green),
                  title: const Text('Integração Google Sheets'),
                  subtitle: Text(
                    cr.webhookUrl != null && cr.webhookUrl!.isNotEmpty ? 'Configurado' : 'Não configurado',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showWebhookConfigDialog();
                  },
                ),
                const Divider(height: 24),
                Text(
                  'Zona de Risco',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(ctx).colorScheme.error,
                    side: BorderSide(color: Theme.of(ctx).colorScheme.error),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded),
                  label: const Text('Excluir Turma Permanentemente'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showDeleteClassDialog();
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
              final newName = _classNameController.text.trim();
              final newChurch = _churchNameController.text.trim();
              if (newName.isEmpty || newChurch.isEmpty) return;
              Navigator.of(ctx).pop();
              final ok = await _service.updateClassroomDetails(name: newName, churchName: newChurch);
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados da turma atualizados!')),
                );
              }
            },
            child: const Text('Salvar Alterações'),
          ),
        ],
      ),
    );
  }

  void _showDeleteClassDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
        title: const Text('Excluir Turma Definitivamente?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Atenção: Esta ação é irreversível!\n\n'
                'A turma "${cr.name}" será excluída do servidor Kairós e todos os membros serão desvinculados.',
                style: const TextStyle(fontSize: 13, color: Colors.red, fontWeight: FontWeight.w500),
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await _service.deleteClassroom();
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Turma excluída com sucesso.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao excluir turma. Verifique sua conexão.')),
                );
              }
            },
            child: const Text('Sim, Excluir Turma'),
          ),
        ],
      ),
    );
  }

  void _showLeaveClassDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Sair da Turma?'),
          ],
        ),
        content: Text(
          'Deseja sair da turma "${cr.name}"?\n\n'
          'Seu progresso deixará de ser compartilhado com os colegas desta classe. Você poderá entrar novamente a qualquer momento usando o código ${cr.code}.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await _service.leaveClassroom();
              if (!mounted) return;
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Você saiu da turma.')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erro ao sair da turma.')),
                );
              }
            },
            child: const Text('Sair da Turma'),
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
              if (cr != null) ...[
                IconButton(
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  tooltip: _service.isTeacher ? 'Convidar Alunos' : 'Convidar Colega',
                  onPressed: _showInviteDialog,
                ),
                if (_service.isTeacher)
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'Configurações da Turma',
                    onPressed: _showClassSettingsDialog,
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.logout_rounded),
                    tooltip: 'Sair da Turma',
                    onPressed: _showLeaveClassDialog,
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

  /// Cabeçalho permanente com Código da Turma e Ações
  Widget _buildClassroomHeader(ThemeData theme, {required bool isTeacher}) {
    final cr = _service.currentClassroom;
    if (cr == null) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.fromLTRB(16, isTeacher ? 12 : 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primary,
                child: Icon(
                  isTeacher ? Icons.workspace_premium_rounded : Icons.school_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cr.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      cr.churchName,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Badge permanente de Código da Turma com Cópia Rápida
              Tooltip(
                message: 'Toque para copiar o código',
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: cr.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Código ${cr.code} copiado!'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          cr.code,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: theme.colorScheme.primary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 14, color: theme.colorScheme.primary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Botões de Ação do Cabeçalho
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              FilledButton.tonalIcon(
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Convidar'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: _showInviteDialog,
              ),
              if (isTeacher)
                OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text('Configurações'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _showClassSettingsDialog,
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Sair da Turma'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.5)),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: _showLeaveClassDialog,
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tela quando o usuário não pertence a nenhuma turma ainda
  Widget _buildNoClassroomView(ThemeData theme, bool isGlass) {
    final auth = AuthService();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!auth.isAuthenticated) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber.shade900),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Faça login com sua conta Kairós para entrar na turma e pontuar no ranking com seu estudo.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.brightness == Brightness.dark ? Colors.amber.shade200 : Colors.amber.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              const SizedBox(height: 24),
              if (_joinCodeController.text.trim().isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, color: theme.colorScheme.primary, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Convite de Turma Detectado!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Código pronto para confirmação. Toque abaixo para ingressar:',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
              const SizedBox(height: 32),
              // Tutorial de Instruções
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Como funciona a Classe da Escola Sabatina?',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• O professor cria a turma no app e compartilha o código de 6 dígitos.\n'
                      '• Os alunos entram informando o código ou clicando no link direto recebido.\n'
                      '• O estudo diário da lição e os quizzes realizados pontuam automaticamente no mural da turma.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.45, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
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
              _buildClassroomHeader(theme, isTeacher: false),
              const SizedBox(height: 12),
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
        _buildClassroomHeader(theme, isTeacher: true),
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
