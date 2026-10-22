import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../controllers/bible_controller.dart';
import '../../../core/utils/bible_extractor.dart';
import '../../../data/repositories/bible_repository.dart';
import '../../../models/bible_verse.dart';
import '../../../services/content_manager.dart';
import '../../../services/theme_service.dart';

/// Submódulo moderno e unificado de visualização rápida de passagens bíblicas.
/// Utilizável em Hinário, Escola Sabatina, Devocionais e Estudos Bíblicos.
class BibleVersePreviewModal extends StatefulWidget {
  final String reference;
  final List<String>? references;
  final BibleRepository? bibleRepository;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;
  final String? contextTitle;

  const BibleVersePreviewModal({
    super.key,
    required this.reference,
    this.references,
    this.bibleRepository,
    this.bibleController,
    this.onNavigateToTab,
    this.contextTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String reference,
    List<String>? references,
    BibleRepository? bibleRepository,
    BibleController? bibleController,
    void Function(int tabIndex)? onNavigateToTab,
    String? contextTitle,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => BibleVersePreviewModal(
        reference: reference,
        references: references,
        bibleRepository: bibleRepository,
        bibleController: bibleController,
        onNavigateToTab: onNavigateToTab,
        contextTitle: contextTitle,
      ),
    );
  }

  @override
  State<BibleVersePreviewModal> createState() => _BibleVersePreviewModalState();
}

class _BibleVersePreviewModalState extends State<BibleVersePreviewModal> {
  late final BibleRepository _repo;
  late String _selectedVersion;
  final List<String> _availableVersions = [];

  bool _isLoading = true;
  String? _error;
  Map<String, List<BibleVerse>> _passages = {};

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.bibleController?.activeVersion ??
        widget.bibleRepository?.activeVersion ??
        'ARA';
    _repo = widget.bibleRepository ?? BibleRepository(initialVersion: _selectedVersion);
    _repo.activeVersion = _selectedVersion;

    _initAvailableVersions();
    _loadAllVerses();
  }

  void _initAvailableVersions() {
    final installed = ContentManager().installedBibleVersions;
    for (final v in installed) {
      if (!_availableVersions.contains(v)) {
        _availableVersions.add(v);
      }
    }
    if (!_availableVersions.contains('ARA')) {
      _availableVersions.add('ARA');
    }
    if (!_availableVersions.contains(_selectedVersion)) {
      _availableVersions.add(_selectedVersion);
    }
  }

  List<String> get _effectiveReferences {
    if (widget.references != null && widget.references!.isNotEmpty) {
      final seen = <String>{};
      final list = <String>[];
      for (final r in widget.references!) {
        final cleaned = BibleExtractor.cleanReference(r);
        if (cleaned.isNotEmpty && seen.add(cleaned)) {
          list.add(cleaned);
        }
      }
      if (list.isNotEmpty) return list;
    }
    final singleCleaned = BibleExtractor.cleanReference(widget.reference);
    return [singleCleaned.isNotEmpty ? singleCleaned : widget.reference.trim()];
  }

  Future<void> _loadAllVerses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final refs = _effectiveReferences;
      final Map<String, List<BibleVerse>> results = {};
      bool foundAny = false;

      for (final ref in refs) {
        final verses = await _repo.buscarPassagem(ref);
        results[ref] = verses;
        if (verses.isNotEmpty) {
          foundAny = true;
        }
      }

      if (mounted) {
        setState(() {
          _passages = results;
          _isLoading = false;
          if (!foundAny) {
            _error = 'Nenhum versículo encontrado para a(s) passagem(ns) selecionada(s).';
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

  Future<void> _changeVersion(String newVersion) async {
    if (newVersion == _selectedVersion) return;
    setState(() {
      _selectedVersion = newVersion;
      _repo.activeVersion = newVersion;
    });
    if (widget.bibleController != null && widget.bibleController!.activeVersion != newVersion) {
      widget.bibleController!.selectVersion(newVersion);
    }
    await _loadAllVerses();
  }

  void _copyToClipboard() {
    final buffer = StringBuffer();
    for (final entry in _passages.entries) {
      if (entry.value.isNotEmpty) {
        buffer.writeln('${entry.key} ($_selectedVersion)');
        for (final v in entry.value) {
          buffer.writeln('${v.verse}. ${v.text}');
        }
        buffer.writeln();
      }
    }

    final text = buffer.toString().trim();
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passagem bíblica copiada!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _abrirNoLeitorBiblico() {
    Navigator.of(context).pop();
    final allRefs = _effectiveReferences;
    if (widget.bibleController != null) {
      if (widget.contextTitle != null || allRefs.isNotEmpty) {
        widget.bibleController!.setStudyContext(
          widget.contextTitle ?? 'Estudo',
          allRefs,
        );
      }
      final firstRef = allRefs.isNotEmpty ? allRefs.first : widget.reference;
      final match = RegExp(
        r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?::(\d+))?',
      ).firstMatch(firstRef.trim());
      if (match != null) {
        final book = match.group(1) ?? '';
        final ch = int.tryParse(match.group(2) ?? '1') ?? 1;
        final v = int.tryParse(match.group(3) ?? '1') ?? 1;
        widget.bibleController!.jumpToVerse(book, ch, v);
      }
    }
    widget.onNavigateToTab?.call(1);
  }

  String get _headerTitle {
    final refs = _effectiveReferences;
    if (refs.length == 1) {
      return refs.first;
    }
    if (refs.length <= 2) {
      return refs.join(', ');
    }
    return '${refs.first} (+${refs.length - 1})';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.70;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
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
                  _headerTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedVersion,
                    isDense: true,
                    iconSize: 16,
                    items: _availableVersions.map((v) {
                      return DropdownMenuItem<String>(
                        value: v,
                        child: Text(
                          'Versão $v',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newVer) {
                      if (newVer != null) _changeVersion(newVer);
                    },
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
        constraints: BoxConstraints(maxWidth: 580, maxHeight: maxHeight),
        child: _buildContent(theme),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actionsOverflowButtonSpacing: 8,
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar'),
          onPressed: _isLoading ? null : _copyToClipboard,
        ),
        if (widget.bibleController != null || widget.onNavigateToTab != null)
          FilledButton.icon(
            icon: const Icon(Icons.menu_book_rounded, size: 16),
            label: const Text('Ler na Bíblia'),
            onPressed: _abrirNoLeitorBiblico,
          ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    final themeService = ThemeService();
    final multiplier = themeService.fontSizeMultiplier;

    if (_isLoading) {
      return const SizedBox(
        height: 140,
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

    final isMultiple = _passages.length > 1;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _passages.entries.map((entry) {
          final passageRef = entry.key;
          final verses = entry.value;

          if (verses.isEmpty) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                    width: 3.5,
                  ),
                ),
              ),
              child: Text(
                'Texto não encontrado para $passageRef.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          int? lastChapter;
          final List<Widget> verseWidgets = [];
          for (final v in verses) {
            if (lastChapter != null && v.chapter != lastChapter) {
              verseWidgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Capítulo ${v.chapter}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            lastChapter = v.chapter;

            verseWidgets.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: themeService.fontFamily,
                      fontSize: 15.5 * multiplier,
                      fontStyle: FontStyle.italic,
                      height: 1.6,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: '${v.verse}. ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.normal,
                          color: theme.colorScheme.primary,
                          fontSize: 13.5 * multiplier,
                        ),
                      ),
                      TextSpan(text: v.text),
                    ],
                  ),
                  textAlign: themeService.bibleTextAlign,
                ),
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 3.5,
                ),
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isMultiple)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$passageRef ($_selectedVersion)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          tooltip: 'Abrir esta passagem na Bíblia',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () {
                            Navigator.of(context).pop();
                            final match = RegExp(
                              r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?::(\d+))?',
                            ).firstMatch(passageRef.trim());
                            if (match != null && widget.bibleController != null) {
                              final book = match.group(1) ?? '';
                              final ch = int.tryParse(match.group(2) ?? '1') ?? 1;
                              final v = int.tryParse(match.group(3) ?? '1') ?? 1;
                              widget.bibleController!.jumpToVerse(book, ch, v);
                            }
                            widget.onNavigateToTab?.call(1);
                          },
                        ),
                      ],
                    ),
                  ),
                ...verseWidgets,
                if (!isMultiple) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Referência: $passageRef ($_selectedVersion)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
