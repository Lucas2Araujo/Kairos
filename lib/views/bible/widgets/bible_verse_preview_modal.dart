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
  final String? baseReference;
  final BibleRepository? bibleRepository;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;
  final String? contextTitle;

  const BibleVersePreviewModal({
    super.key,
    required this.reference,
    this.references,
    this.baseReference,
    this.bibleRepository,
    this.bibleController,
    this.onNavigateToTab,
    this.contextTitle,
  });

  static Future<void> show(
    BuildContext context, {
    required String reference,
    List<String>? references,
    String? baseReference,
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
        baseReference: baseReference,
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

  late String _activeReference;
  double _localFontSizePt = 18.0;

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

    _localFontSizePt = (16.0 * ThemeService().fontSizeMultiplier).roundToDouble().clamp(12.0, 34.0);

    final cleanRef = BibleExtractor.cleanReference(widget.reference);
    final effective = _effectiveReferences;
    if (cleanRef.isNotEmpty && effective.contains(cleanRef)) {
      _activeReference = cleanRef;
    } else if (effective.contains(widget.reference.trim())) {
      _activeReference = widget.reference.trim();
    } else if (effective.isNotEmpty) {
      _activeReference = effective.first;
    } else {
      _activeReference = widget.reference.trim();
    }

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
    final seen = <String>{};
    final list = <String>[];

    void addRef(String r) {
      final cleaned = BibleExtractor.cleanReference(r);
      final val = cleaned.isNotEmpty ? cleaned : r.trim();
      if (val.isNotEmpty && seen.add(val)) {
        list.add(val);
      }
    }

    if (widget.references != null && widget.references!.isNotEmpty) {
      for (final r in widget.references!) {
        addRef(r);
      }
    }
    if (widget.baseReference != null && widget.baseReference!.trim().isNotEmpty) {
      addRef(widget.baseReference!);
    }
    addRef(widget.reference);

    return list.isNotEmpty ? list : [widget.reference.trim()];
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
    final verses = _passages[_activeReference] ?? [];
    if (verses.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('$_activeReference ($_selectedVersion)');
    for (final v in verses) {
      buffer.writeln('${v.verse}. ${v.text}');
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
    Navigator.of(context).popUntil((route) => route.isFirst);
    final allRefs = _effectiveReferences;
    if (widget.bibleController != null) {
      if (widget.contextTitle != null || allRefs.isNotEmpty) {
        widget.bibleController!.setStudyContext(
          widget.contextTitle ?? 'Estudo',
          allRefs,
        );
      }
      final targetRef = _activeReference;
      final match = RegExp(
        r'^([1-3]?\s?[A-Za-zÀ-ÿ]+(?:\s+[A-Za-zÀ-ÿ]+)*)\s+(\d+)(?::(\d+))?',
      ).firstMatch(targetRef.trim());
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
    final maxHeight = MediaQuery.of(context).size.height * 0.70;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _activeReference,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
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
                    v,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (newVer) {
                if (newVer != null) _changeVersion(newVer);
              },
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 580, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_effectiveReferences.length > 1) _buildPassagesChips(theme),
            Flexible(
              child: SingleChildScrollView(
                child: _buildVersesContent(theme),
              ),
            ),
            const SizedBox(height: 8),
            _buildActionBar(theme),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      actionsOverflowButtonSpacing: 8,
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Fechar'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Tooltip(
              message: 'Ler na Bíblia',
              child: FilledButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Abrir na Bíblia'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: _abrirNoLeitorBiblico,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPassagesChips(ThemeData theme) {
    final isHymn = (widget.baseReference != null && widget.baseReference!.trim().isNotEmpty) ||
        widget.contextTitle == 'Hinário' ||
        widget.contextTitle == null;
    final label = isHymn ? 'Passagens deste hino:' : 'Passagens relacionadas:';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _effectiveReferences.asMap().entries.map((entry) {
                final index = entry.key;
                final ref = entry.value;

                final cleanBase = widget.baseReference != null
                    ? BibleExtractor.cleanReference(widget.baseReference!)
                    : null;
                final isBase = (cleanBase != null &&
                        cleanBase.isNotEmpty &&
                        (cleanBase == ref || cleanBase == BibleExtractor.cleanReference(ref))) ||
                    (index == 0 && widget.baseReference != null);

                final isSelected = _activeReference == ref;

                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ChoiceChip(
                    label: Text(isBase ? '✦ $ref (Base)' : ref),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    selected: isSelected,
                    selectedColor: theme.colorScheme.primaryContainer,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _activeReference = ref);
                      }
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: _isLoading ? null : _copyToClipboard,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            tooltip: 'Diminuir texto',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _localFontSizePt > 12.0
                ? () {
                    setState(() {
                      _localFontSizePt = (_localFontSizePt - 2.0).clamp(12.0, 36.0);
                    });
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              '${_localFontSizePt.round()}pt',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            tooltip: 'Aumentar texto',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _localFontSizePt < 36.0
                ? () {
                    setState(() {
                      _localFontSizePt = (_localFontSizePt + 2.0).clamp(12.0, 36.0);
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildVersesContent(ThemeData theme) {
    final themeService = ThemeService();

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

    final verses = _passages[_activeReference] ?? [];

    if (verses.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
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
          'Texto não encontrado para $_activeReference.',
          style: TextStyle(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    int? lastChapter;
    final List<Widget> verseWidgets = [];
    for (final v in verses) {
      if (lastChapter != null && v.chapter != lastChapter) {
        verseWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: Divider(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
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
                fontSize: _localFontSizePt,
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
                    fontSize: (_localFontSizePt * 0.9).clamp(11.0, 30.0),
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
          ...verseWidgets,
          const SizedBox(height: 4),
          Text(
            'Referência: $_activeReference ($_selectedVersion)',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
