import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../data/repositories/bible_repository.dart';
import '../../../models/bible_verse.dart';

class VerseDialog extends StatefulWidget {
  final String reference;
  final BibleRepository? bibleRepository;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const VerseDialog({
    super.key,
    required this.reference,
    this.bibleRepository,
    this.bibleController,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    required String reference,
    BibleRepository? bibleRepository,
    BibleController? bibleController,
    void Function(int tabIndex)? onNavigateToTab,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => VerseDialog(
        reference: reference,
        bibleRepository: bibleRepository,
        bibleController: bibleController,
        onNavigateToTab: onNavigateToTab,
      ),
    );
  }

  @override
  State<VerseDialog> createState() => _VerseDialogState();
}

class _VerseDialogState extends State<VerseDialog> {
  late final BibleRepository _repo;
  List<BibleVerse> _verses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repo = widget.bibleRepository ?? BibleRepository();
    _loadVerses();
  }

  Future<void> _loadVerses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _repo.buscarPassagem(widget.reference);
      if (mounted) {
        setState(() {
          _verses = results;
          _isLoading = false;
          if (results.isEmpty) {
            _error = 'Nenhum versículo encontrado para "${widget.reference}".';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao consultar versículos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _abrirNoLeitorBiblico() {
    Navigator.of(context).pop(); // Fecha o diálogo
    if (widget.bibleController != null) {
      final match = RegExp(r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?::(\d+))?').firstMatch(widget.reference.trim());
      if (match != null) {
        final book = match.group(1) ?? '';
        final ch = int.tryParse(match.group(2) ?? '1') ?? 1;
        final v = int.tryParse(match.group(3) ?? '1') ?? 1;
        widget.bibleController!.jumpToVerse(book, ch, v);
      }
    }
    widget.onNavigateToTab?.call(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_stories,
              size: 20,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.reference,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                Text(
                  'Almeida Revista e Atualizada (ARA)',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 400),
        child: _buildContent(theme),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actions: [
        if (widget.bibleController != null || widget.onNavigateToTab != null)
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Ler Capítulo Completo'),
            onPressed: _abrirNoLeitorBiblico,
          ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          _error!,
          style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _verses.map((v) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  height: 1.55,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: '${v.verse} ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  TextSpan(text: v.text),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
