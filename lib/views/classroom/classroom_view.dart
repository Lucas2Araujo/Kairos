import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/system_share_download.dart';
import '../../core/utils/xlsx_builder.dart';
import '../../services/auth_service.dart';
import '../../services/classroom_service.dart';
import '../../services/gamification_service.dart';
import '../../services/theme_service.dart';
import '../gamification/monthly_streak_view.dart';
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

class _ClassroomViewState extends State<ClassroomView> {
  final ClassroomService _service = ClassroomService();
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _classNameController = TextEditingController();
  final TextEditingController _churchNameController = TextEditingController();
  final TextEditingController _webhookUrlController = TextEditingController();

  ClassroomPeriodFilter _selectedPeriod = ClassroomPeriodFilter.currentWeek;
  bool _isSyncingSheets = false;
  final Set<String> _expandedMembers = {};

  @override
  void initState() {
    super.initState();

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
        final start = now.subtract(Duration(days: now.weekday % 7));
        final end = start.add(const Duration(days: 6));
        return (
          DateTime(start.year, start.month, start.day),
          DateTime(end.year, end.month, end.day, 23, 59, 59),
        );
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
        content: SingleChildScrollView(
          child: Column(
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
                  const SnackBar(
                    content: Text('Por favor, preencha o nome da turma e da igreja.'),
                  ),
                );
                return;
              }

              final auth = AuthService();
              if (!auth.isAuthenticated) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Você precisa estar conectado à sua conta Kairós para criar uma turma.',
                    ),
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
                      content: Text('Turma criada com sucesso! Código: ${created.code}'),
                    ),
                  );
                  _showInviteDialog();
                }
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
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
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add_alt_1_rounded, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Código & Convite',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Compartilhe o código ou o link da turma com os alunos da sua classe:',
                    style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CÓDIGO DA CLASSE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SelectableText(
                          cr.code,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 5,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          label: const Text('Copiar Código'),
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
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Compartilhar Convite'),
                    onPressed: () async {
                      final shared = await SystemShareDownload.shareText(
                        text: inviteMessage,
                        subject: 'Convite Classe ${cr.name}',
                      );
                      if (!shared && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Convite copiado para a área de transferência!'),
                          ),
                        );
                      }
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
        );
      },
    );
  }

  void _showClassSettingsDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;
    _classNameController.text = cr.name;
    _churchNameController.text = cr.churchName;

    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.tune_rounded),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Configurações da Turma',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
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
                    leading: Icon(Icons.table_chart_rounded, color: scheme.primary),
                    title: const Text('Integração Google Sheets'),
                    subtitle: Text(
                      cr.webhookUrl != null && cr.webhookUrl!.isNotEmpty
                          ? 'Webhook configurado'
                          : 'Não configurado',
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
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error),
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
                final ok =
                    await _service.updateClassroomDetails(name: newName, churchName: newChurch);
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dados da turma atualizados!')),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteClassDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 44),
          title: const Text('Excluir Turma Definitivamente?'),
          content: Text(
            'Esta ação é irreversível! A turma "${cr.name}" será excluída e todos os membros serão desvinculados.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await _service.deleteClassroom();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok
                          ? 'Turma excluída com sucesso.'
                          : 'Erro ao excluir turma. Verifique sua conexão.',
                    ),
                  ),
                );
              },
              child: const Text('Excluir Turma'),
            ),
          ],
        );
      },
    );
  }

  void _showLeaveClassDialog() {
    final cr = _service.currentClassroom;
    if (cr == null) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Sair da Turma?'),
          content: Text(
            'Deseja sair da turma "${cr.name}"? Você poderá entrar novamente depois usando o código ${cr.code}.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final ok = await _service.leaveClassroom();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Você saiu da turma.' : 'Erro ao sair da turma.'),
                  ),
                );
              },
              child: const Text('Sair da Turma'),
            ),
          ],
        );
      },
    );
  }

  void _showWebhookConfigDialog() {
    _webhookUrlController.text = _service.currentClassroom?.webhookUrl ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Integração Google Sheets'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Sincronize automaticamente os dados da sua turma com uma planilha do Google Sheets via Web App do Apps Script.',
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
                label: const Text('Ver Código do Apps Script'),
                onPressed: _showAppsScriptCodeModal,
              ),
            ],
          ),
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Abra Google Planilhas > Extensões > Apps Script\n'
                '2. Cole o código abaixo e implante como App da Web\n'
                '3. Cole a URL gerada nas configurações da Turma.',
                style: TextStyle(fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                height: 140,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
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
              Clipboard.setData(
                const ClipboardData(text: ClassroomService.googleAppsScriptTemplate),
              );
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

  void _showDownloadReportSheet(List<StudentStatsItem> stats) {
    final className = _service.currentClassroom?.name ?? 'Turma_Kairos';
    final safeSlug = className
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final periodLabel = _getPeriodLabel();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Baixar Pontuações da Turma',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escolha o formato do arquivo ($periodLabel):',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  leading: Icon(Icons.grid_on_rounded, color: theme.colorScheme.primary),
                  title: const Text(
                    'Planilha Excel (.xlsx)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Formato nativo Excel / Google Planilhas com colunas e cabeçalho estilizado',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final bytes = ClassroomService.generateExcelXlsxReport(
                      classroomName: className,
                      periodLabel: periodLabel,
                      stats: stats,
                    );
                    final ok = await SystemShareDownload.saveBytes(
                      bytes: bytes,
                      fileName: 'Relatorio_${safeSlug}_${DateTime.now().millisecondsSinceEpoch}.xlsx',
                      mimeType: XlsxBuilder.mimeType,
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Planilha .xlsx baixada com sucesso!'
                              : 'Não foi possível salvar a planilha .xlsx.',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  leading: Icon(Icons.description_outlined, color: theme.colorScheme.secondary),
                  title: const Text(
                    'Arquivo CSV (.csv UTF-8)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Texto tabular leve compatível com qualquer sistema',
                    style: TextStyle(fontSize: 12),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final csv = ClassroomService.generateExcelCsvReport(
                      classroomName: className,
                      periodLabel: periodLabel,
                      stats: stats,
                    );
                    final bytes = Uint8List.fromList(utf8.encode(csv));
                    final ok = await SystemShareDownload.saveBytes(
                      bytes: bytes,
                      fileName: 'Relatorio_${safeSlug}_${DateTime.now().millisecondsSinceEpoch}.csv',
                      mimeType: 'text/csv;charset=utf-8',
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Arquivo .csv baixado com sucesso!'
                              : 'Não foi possível salvar o arquivo .csv.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Planilha do Google Sheets sincronizada com sucesso!'
                : 'Configure a URL do Webhook nas Configurações da Turma antes de sincronizar.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final gamification = GamificationService();

    return ListenableBuilder(
      listenable: Listenable.merge([_service, themeService, gamification]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final isGlass = themeService.isAnyGlass;
        final cr = _service.currentClassroom;
        final range = _getPeriodDateRange();
        final stats = cr != null
            ? _service.calculateStudentStats(startDate: range.$1, endDate: range.$2)
            : const <StudentStatsItem>[];

        return Scaffold(
          backgroundColor: isGlass ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cr != null ? cr.name : 'Turmas & Classes',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (cr != null && cr.churchName.isNotEmpty)
                  Text(
                    cr.churchName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: _isSyncingSheets
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
                tooltip: 'Atualizar Dados',
                onPressed: () => _service.fetchClassroomData(),
              ),
              if (cr != null)
                PopupMenuButton<String>(
                  key: const Key('classroom_overflow_menu'),
                  tooltip: 'Opções da Turma',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (action) {
                    switch (action) {
                      case 'invite':
                        _showInviteDialog();
                        break;
                      case 'download':
                        _showDownloadReportSheet(stats);
                        break;
                      case 'sheets':
                        _handleSyncSheets(stats);
                        break;
                      case 'achievements':
                        MonthlyStreakView.show(context);
                        break;
                      case 'settings':
                        _showClassSettingsDialog();
                        break;
                      case 'leave':
                        _showLeaveClassDialog();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'invite',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.vpn_key_rounded),
                        title: Text('Código & Convite'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'download',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.download_rounded),
                        title: Text('Baixar Pontuações (.xlsx / .csv)'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'achievements',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.emoji_events_outlined),
                        title: Text('Minhas Conquistas & Avatar'),
                      ),
                    ),
                    if (_service.isTeacher) ...[
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'sheets',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.cloud_upload_outlined),
                          title: Text('Sincronizar Google Sheets'),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.tune_rounded),
                          title: Text('Configurações da Turma'),
                        ),
                      ),
                    ] else ...[
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'leave',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
                          title: Text(
                            'Sair da Turma',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          body: _service.isLoading
              ? const Center(child: CircularProgressIndicator())
              : cr == null
                  ? _buildNoClassroomView(theme)
                  : _buildUnifiedClassroomBody(theme, stats, themeService.fontSizeMultiplier),
        );
      },
    );
  }

  Widget _buildNoClassroomView(ThemeData theme) {
    final auth = AuthService();
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!auth.isAuthenticated)
                GlassSurface(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(12),
                  borderRadius: 14,
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Faça login com sua conta Kairós para entrar na turma e pontuar no ranking com seu estudo.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Icon(Icons.diversity_3_rounded, size: 68, color: scheme.primary),
              const SizedBox(height: 14),
              Text(
                'Participe de uma Classe ou PG',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Acompanhe o progresso espiritual da sua turma, celebre conquistas e mantenham juntos a chama acesa.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              if (_joinCodeController.text.trim().isNotEmpty)
                GlassSurface(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(14),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      Icon(Icons.mail_outline_rounded, color: scheme.primary, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Convite de Turma Detectado!',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              'Confirme o código abaixo para ingressar:',
                              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                ),
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
                label: const Text(
                  'Entrar na Turma',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _handleJoinClass,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OU PROFESSOR / LÍDER', style: theme.textTheme.labelSmall),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 22),
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

  Widget _buildUnifiedClassroomBody(
    ThemeData theme,
    List<StudentStatsItem> stats,
    double fontMultiplier,
  ) {
    final scheme = theme.colorScheme;
    final user = AuthService().currentUser;
    final totalHours = stats.fold<int>(0, (sum, s) => sum + s.totalMinutes) / 60.0;
    final totalQuizzes = stats.fold<int>(0, (sum, s) => sum + s.totalQuizzes);
    final fullFlameCount = stats.where((s) => s.isFullStreakActive).length;
    final fullFlamePercent =
        stats.isNotEmpty ? (fullFlameCount / stats.length * 100).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra limpa: Filtro de Período + Ação rápida de Download
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: const Text('Semana'),
                        selected: _selectedPeriod == ClassroomPeriodFilter.currentWeek,
                        onSelected: (_) => setState(
                          () => _selectedPeriod = ClassroomPeriodFilter.currentWeek,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Mês'),
                        selected: _selectedPeriod == ClassroomPeriodFilter.currentMonth,
                        onSelected: (_) => setState(
                          () => _selectedPeriod = ClassroomPeriodFilter.currentMonth,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Trimestre'),
                        selected: _selectedPeriod == ClassroomPeriodFilter.currentQuarter,
                        onSelected: (_) => setState(
                          () => _selectedPeriod = ClassroomPeriodFilter.currentQuarter,
                        ),
                      ),
                    ],
                  ),
                  ActionChip(
                    key: const Key('download_classroom_scores_chip'),
                    avatar: Icon(Icons.download_rounded, size: 17, color: scheme.primary),
                    label: const Text('Baixar Planilha'),
                    onPressed: () => _showDownloadReportSheet(stats),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Resumo objetivo da turma
              GlassSurface(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                borderRadius: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCompactSummaryStat(
                        theme,
                        icon: Icons.people_alt_rounded,
                        value: '${stats.length}',
                        label: 'Alunos',
                        color: scheme.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildCompactSummaryStat(
                        theme,
                        icon: Icons.schedule_rounded,
                        value: '${totalHours.toStringAsFixed(1)}h',
                        label: 'Com Deus',
                        color: scheme.tertiary,
                      ),
                    ),
                    Expanded(
                      child: _buildCompactSummaryStat(
                        theme,
                        icon: Icons.quiz_rounded,
                        value: '$totalQuizzes',
                        label: 'Quizzes',
                        color: scheme.secondary,
                      ),
                    ),
                    Expanded(
                      child: _buildCompactSummaryStat(
                        theme,
                        icon: Icons.local_fire_department_rounded,
                        value: '$fullFlamePercent%',
                        label: 'Chama Cheia',
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Cabeçalho da lista de alunos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Alunos, Pontuações & Diagnóstico',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: (16 * fontMultiplier).clamp(14.0, 22.0),
                      ),
                    ),
                  ),
                  Text(
                    _getPeriodLabel(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (stats.isEmpty)
                GlassSurface(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 18,
                  child: Column(
                    children: [
                      Icon(Icons.group_add_outlined, size: 40, color: scheme.outline),
                      const SizedBox(height: 8),
                      const Text(
                        'Nenhum aluno registrado ainda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showInviteDialog,
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Compartilhar código da turma'),
                      ),
                    ],
                  ),
                )
              else
                for (int i = 0; i < stats.length; i++) ...[
                  _buildStudentCard(
                    theme,
                    stats[i],
                    rank: i + 1,
                    isCurrentUser: stats[i].member.userId == user?.id,
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactSummaryStat(
    ThemeData theme, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    ThemeData theme,
    StudentStatsItem item, {
    required int rank,
    required bool isCurrentUser,
  }) {
    final scheme = theme.colorScheme;
    final gamification = GamificationService();
    final isExpanded = _expandedMembers.contains(item.member.userId) || rank <= 3 || isCurrentUser;

    Color flameColor;
    String flameText;
    switch (item.currentFlame) {
      case FlameType.fullFlame:
        flameColor = Colors.deepOrange;
        flameText = 'Chama Cheia';
        break;
      case FlameType.halfFlame:
        flameColor = Colors.amber.shade700;
        flameText = 'Meia Chama';
        break;
      case FlameType.none:
        flameColor = scheme.outline;
        flameText = 'Apagada';
        break;
    }

    final featuredDef = item.featuredBadgeId != null
        ? gamification.getAchievementById(item.featuredBadgeId!)
        : null;

    final rankColor = rank == 1
        ? Colors.amber.shade700
        : rank == 2
            ? Colors.blueGrey
            : rank == 3
                ? Colors.brown.shade400
                : scheme.onSurfaceVariant;

    return GlassSurface(
      borderRadius: 18,
      padding: const EdgeInsets.all(14),
      color: isCurrentUser ? scheme.primaryContainer.withValues(alpha: 0.22) : null,
      onTap: () {
        setState(() {
          if (_expandedMembers.contains(item.member.userId)) {
            _expandedMembers.remove(item.member.userId);
          } else {
            _expandedMembers.add(item.member.userId);
          }
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Posição / Medalha
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rank <= 3
                      ? rankColor.withValues(alpha: 0.16)
                      : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
                child: Text(
                  '$rankº',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: rankColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AvatarCustomWidget(
                config: isCurrentUser ? gamification.avatarConfig : item.member.avatarConfig,
                size: 46,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.member.studentName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isCurrentUser)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VOCÊ',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (featuredDef != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: featuredDef.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(featuredDef.icon, size: 11, color: featuredDef.color),
                                const SizedBox(width: 3),
                                Text(
                                  featuredDef.title,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: featuredDef.color,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (item.unlockedBadgesCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '🏆 ${item.unlockedBadgesCount}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      children: [
                        Text(
                          '⏱ ${item.totalMinutes}m',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '📖 ${item.lessonsStudiedDays}d lição',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '🎯 Quiz: ${item.totalScore} pts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.totalXp} XP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: flameColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, size: 12, color: flameColor),
                        const SizedBox(width: 2),
                        Text(
                          flameText,
                          style: TextStyle(
                            color: flameColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Seção limpa de Tarefas Feitas & Pontos onde melhorar
          if (isExpanded &&
              (item.completedTasksLabels.isNotEmpty || item.improvementPoints.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.35)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...item.completedTasksLabels.map(
                  (task) => _buildDiagnosticPill(
                    icon: Icons.check_circle_outline_rounded,
                    label: task,
                    color: Colors.green.shade700,
                  ),
                ),
                ...item.improvementPoints.map(
                  (imp) => _buildDiagnosticPill(
                    icon: Icons.trending_up_rounded,
                    label: imp,
                    color: scheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiagnosticPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
