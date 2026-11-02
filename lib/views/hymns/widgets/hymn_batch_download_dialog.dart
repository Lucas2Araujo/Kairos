import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../controllers/hymn_controller.dart';
import '../../../models/hymn.dart';
import '../../../services/hymn_batch_download_service.dart';

enum HymnBatchMode { all, range, favorites }

/// Diálogo de seleção e configuração de download em lote de áudios do Hinário.
class HymnBatchDownloadDialog extends StatefulWidget {
  final HymnController controller;

  const HymnBatchDownloadDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, HymnController controller) {
    return showDialog(
      context: context,
      builder: (_) => HymnBatchDownloadDialog(controller: controller),
    );
  }

  @override
  State<HymnBatchDownloadDialog> createState() => _HymnBatchDownloadDialogState();
}

class _HymnBatchDownloadDialogState extends State<HymnBatchDownloadDialog> {
  final HymnBatchDownloadService _batchService = HymnBatchDownloadService();
  HymnBatchMode _mode = HymnBatchMode.all;
  List<Hymn> _favoriteHymns = [];

  final TextEditingController _startController = TextEditingController(text: '1');
  final TextEditingController _endController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _endController.text = '${widget.controller.hymns.length}';
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await widget.controller.getFavorites();
    if (mounted) {
      setState(() {
        _favoriteHymns = favs;
      });
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  List<Hymn> _getTargetHymns() {
    final all = widget.controller.hymns;
    switch (_mode) {
      case HymnBatchMode.all:
        return all;
      case HymnBatchMode.favorites:
        return _favoriteHymns;
      case HymnBatchMode.range:
        final start = int.tryParse(_startController.text.trim()) ?? 1;
        final end = int.tryParse(_endController.text.trim()) ?? all.length;
        final lower = start < end ? start : end;
        final upper = start < end ? end : start;

        return all.where((h) {
          final num = int.tryParse(h.numero) ?? 0;
          return num >= lower && num <= upper;
        }).toList();
    }
  }

  void _startDownload() {
    if (kIsWeb) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloads offline de áudio são suportados no app Android/Desktop.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final targets = _getTargetHymns();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum hino encontrado no critério selecionado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _batchService.startBatch(
      hymns: targets,
      edition: widget.controller.edition,
    );

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download de ${targets.length} hinos iniciado em segundo plano.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allCount = widget.controller.hymns.length;
    final favCount = _favoriteHymns.length;

    return ListenableBuilder(
      listenable: _batchService,
      builder: (context, _) {
        final isRunning = _batchService.isRunning;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.download_for_offline_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Download em Lote de Áudios', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isRunning) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Download em andamento (${_batchService.current}/${_batchService.total})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(value: _batchService.progress),
                        const SizedBox(height: 6),
                        Text(
                          _batchService.currentHymnTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  'Escolha os hinos que deseja baixar para ouvir sem conexão:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),

                RadioListTile<HymnBatchMode>(
                  title: Text('Todos os hinos ($allCount hinos)'),
                  subtitle: const Text('Baixa a edição completa em segundo plano'),
                  value: HymnBatchMode.all,
                  groupValue: _mode,
                  onChanged: isRunning ? null : (v) => setState(() => _mode = v!),
                  contentPadding: EdgeInsets.zero,
                ),

                RadioListTile<HymnBatchMode>(
                  title: const Text('Intervalo personalizado'),
                  subtitle: const Text('Defina o hino inicial e final'),
                  value: HymnBatchMode.range,
                  groupValue: _mode,
                  onChanged: isRunning ? null : (v) => setState(() => _mode = v!),
                  contentPadding: EdgeInsets.zero,
                ),

                if (_mode == HymnBatchMode.range) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Do Hino',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('até'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Até o Hino',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                RadioListTile<HymnBatchMode>(
                  title: Text('Apenas Favoritos ($favCount hinos)'),
                  subtitle: const Text('Baixa apenas os hinos marcados com estrela'),
                  value: HymnBatchMode.favorites,
                  groupValue: _mode,
                  onChanged: isRunning ? null : (v) => setState(() => _mode = v!),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),
                Text(
                  'Nota: Os hinos baixados utilizam a faixa cantada (vocal) oficial e ocupam cerca de 2-4 MB cada.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
            if (isRunning)
              FilledButton.tonal(
                onPressed: () {
                  _batchService.cancel();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancelar Download'),
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.download_rounded),
                label: const Text('Iniciar Download'),
                onPressed: _startDownload,
              ),
          ],
        );
      },
    );
  }
}
