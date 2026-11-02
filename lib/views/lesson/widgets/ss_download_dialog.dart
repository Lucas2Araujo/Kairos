import 'package:flutter/material.dart';
import '../../../data/services/sabbath_school_service.dart';
import '../../../models/sabbath_school_models.dart';

/// Diálogo modal de progresso e gerenciamento de download da Escola Sabatina.
class SSDownloadDialog extends StatefulWidget {
  final SSQuarterly? quarterly;
  final SSLesson? lesson;
  final VoidCallback? onCompleted;

  const SSDownloadDialog({
    super.key,
    this.quarterly,
    this.lesson,
    this.onCompleted,
  }) : assert(quarterly != null || lesson != null);

  /// Abre o fluxo de download ou gerenciamento para um trimestre
  static Future<void> showForQuarterly(
    BuildContext context,
    SSQuarterly quarterly, {
    VoidCallback? onCompleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SSDownloadDialog(
        quarterly: quarterly,
        onCompleted: onCompleted,
      ),
    );
  }

  /// Abre o fluxo de download ou gerenciamento para uma lição
  static Future<void> showForLesson(
    BuildContext context,
    SSLesson lesson, {
    VoidCallback? onCompleted,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SSDownloadDialog(
        lesson: lesson,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<SSDownloadDialog> createState() => _SSDownloadDialogState();
}

class _SSDownloadDialogState extends State<SSDownloadDialog> {
  final SabbathSchoolService _service = SabbathSchoolService();
  bool _isChecking = true;
  bool _isDownloaded = false;
  bool _isDownloading = false;
  bool _isCancelled = false;

  double _progress = 0.0;
  String _statusText = 'Preparando download...';
  String _subStatusText = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    bool downloaded = false;
    if (widget.lesson != null) {
      downloaded = await _service.isLessonDownloaded(widget.lesson!.id);
    } else if (widget.quarterly != null) {
      downloaded = await _service.isQuarterlyDownloaded(widget.quarterly!.id);
    }

    if (mounted) {
      setState(() {
        _isDownloaded = downloaded;
        _isChecking = false;
      });

      // Se ainda não estava baixado, inicia o download imediatamente
      if (!_isDownloaded) {
        _startDownload();
      }
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _isCancelled = false;
      _progress = 0.0;
      _statusText = 'Iniciando download...';
      _subStatusText = '';
    });

    try {
      if (widget.lesson != null) {
        await _service.downloadLesson(
          widget.lesson!.id,
          quarterlyId: widget.lesson!.quarterlyId,
          isCancelled: () => _isCancelled,
          onProgress: (currentDay, totalDays, title) {
            if (mounted) {
              setState(() {
                _progress = totalDays > 0 ? currentDay / totalDays : 0.0;
                _statusText = 'Baixando Dia $currentDay de $totalDays';
                _subStatusText = title;
              });
            }
          },
        );
      } else if (widget.quarterly != null) {
        await _service.downloadQuarterly(
          widget.quarterly!.id,
          isCancelled: () => _isCancelled,
          onProgress: (curLesson, totLessons, lessonTitle, curDay, totDays) {
            if (mounted) {
              setState(() {
                _progress = totLessons > 0 ? (curLesson - 1 + (curDay / totDays)) / totLessons : 0.0;
                _statusText = 'Lição $curLesson de $totLessons • Dia $curDay de $totDays';
                _subStatusText = lessonTitle;
              });
            }
          },
        );
      }

      if (!_isCancelled && mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloaded = true;
        });
        widget.onCompleted?.call();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.lesson != null
                ? 'Lição baixada com sucesso!'
                : 'Trimestre baixado com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Erro ao baixar: $e';
        });
      }
    }
  }

  Future<void> _deleteDownload() async {
    setState(() => _isChecking = true);
    if (widget.lesson != null) {
      await _service.deleteLessonDownload(widget.lesson!.id);
    } else if (widget.quarterly != null) {
      await _service.deleteQuarterlyDownload(widget.quarterly!.id);
    }

    if (mounted) {
      widget.onCompleted?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.lesson != null
              ? 'Download da lição removido.'
              : 'Download do trimestre removido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.lesson?.title ?? widget.quarterly?.title ?? 'Escola Sabatina';

    // 1. Verificando estado inicial
    if (_isChecking) {
      return AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text('Verificando status de $title...')),
          ],
        ),
      );
    }

    // 2. Se já estiver baixado e não estiver em processo de re-download: menu de opções
    if (_isDownloaded && !_isDownloading) {
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('Já Disponível Offline', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.lesson != null
                  ? 'Esta lição já está baixada em seu dispositivo. O que você deseja fazer?'
                  : 'Este trimestre completo já está baixado em seu dispositivo. O que você deseja fazer?',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
          TextButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            label: const Text('Remover Download', style: TextStyle(color: Colors.redAccent)),
            onPressed: _deleteDownload,
          ),
          FilledButton.icon(
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Atualizar / Rebaixar'),
            onPressed: _startDownload,
          ),
        ],
      );
    }

    // 3. Em processo de download: Barra de progresso com cancelamento
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.downloading_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.lesson != null ? 'Baixando Lição' : 'Baixando Trimestre',
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress > 0 ? _progress.clamp(0.0, 1.0) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _statusText,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (_progress > 0)
                Text(
                  '${(_progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
          if (_subStatusText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _subStatusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _isCancelled = true;
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Download cancelado.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
