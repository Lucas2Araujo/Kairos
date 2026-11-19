import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/utils/bible_extractor.dart';
import '../../models/egw_models.dart';
import '../../services/egw_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/kairos_reader_gesture_layer.dart';
import '../bible/widgets/bible_verse_preview_modal.dart';

/// Tela completa de leitura de livros do Espírito de Profecia (Ellen G. White).
/// Oferece navegação por capítulos, download offline, sumário interativo,
/// ajuste tipográfico responsivo e identificação de referências bíblicas inline.
class EgwReaderView extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final String? initialChapterId;
  /// Número 1-based opcional do capítulo inicial a ser aberto ao carregar o livro.
  final int? initialChapterNumber;
  final String? targetRefCode;

  const EgwReaderView({
    super.key,
    required this.bookId,
    required this.bookTitle,
    this.initialChapterId,
    this.initialChapterNumber,
    this.targetRefCode,
  });

  @override
  State<EgwReaderView> createState() => _EgwReaderViewState();
}

class _EgwReaderViewState extends State<EgwReaderView> {
  final EgwService _egwService = EgwService();
  final ScrollController _scrollController = ScrollController();

  List<EgwChapterHeader> _toc = [];
  EgwChapter? _currentChapter;
  int _currentChapterIndex = 0;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  // Preferências de Leitura locais
  double _fontSize = 17.0;
  bool _showRefCodes = true;

  @override
  void initState() {
    super.initState();
    _loadBookAndChapter();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBookAndChapter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final toc = await _egwService.getTableOfContents(widget.bookId);
      if (!mounted) return;

      if (toc.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Não foi possível carregar o índice deste livro. Verifique sua conexão.';
        });
        return;
      }

      _toc = toc;

      // Determina o capítulo inicial
      int targetIndex = 0;
      if (widget.initialChapterId != null) {
        final found = toc.indexWhere((h) => h.chapterId == widget.initialChapterId);
        if (found != -1) targetIndex = found;
      } else if (widget.initialChapterNumber != null) {
        final chNum = widget.initialChapterNumber!;
        final pattern = RegExp(r'\bCap(?:ítulo|\.)?\s*' + chNum.toString() + r'\b', caseSensitive: false);
        final found = toc.indexWhere(
          (h) => h.chapterIndex == chNum || pattern.hasMatch(h.title),
        );
        targetIndex = found != -1 ? found : (chNum - 1).clamp(0, toc.length - 1);
      }

      await _loadChapterByIndex(targetIndex);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao carregar livro: $e';
      });
    }
  }

  Future<void> _loadChapterByIndex(int index) async {
    if (index < 0 || index >= _toc.length) return;

    setState(() {
      _isLoading = true;
      _currentChapterIndex = index;
    });

    final header = _toc[index];
    final chapter = await _egwService.getChapter(
      widget.bookId,
      header.chapterId,
      chapterIndex: header.chapterIndex,
      fallbackTitle: header.title,
    );

    if (!mounted) return;

    setState(() {
      _currentChapter = chapter;
      _isLoading = false;
      if (chapter == null) {
        _errorMessage = 'Não foi possível carregar o conteúdo deste capítulo.';
      } else {
        _errorMessage = null;
      }
    });

    // Rola de volta ao topo suavemente
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _showTableOfContentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.list_alt_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sumário — ${widget.bookTitle}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: _toc.length,
                    itemBuilder: (_, i) {
                      final h = _toc[i];
                      final isCurrent = i == _currentChapterIndex;
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                          child: Text(
                            '${h.chapterIndex}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCurrent
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        title: Text(
                          h.title,
                          style: TextStyle(
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            color: isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _loadChapterByIndex(i);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReadingSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Ajustes de Leitura',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tamanho do Texto: ${_fontSize.round()} pt',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      const Text('A', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 14.0,
                          max: 26.0,
                          divisions: 6,
                          label: '${_fontSize.round()}',
                          onChanged: (val) {
                            setSheetState(() => _fontSize = val);
                            setState(() => _fontSize = val);
                          },
                        ),
                      ),
                      const Text('A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Exibir códigos de página (ex: DTN 9.1)'),
                    value: _showRefCodes,
                    onChanged: (val) {
                      setSheetState(() => _showRefCodes = val);
                      setState(() => _showRefCodes = val);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _startBookDownload() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Baixar Livro Completo'),
        content: Text(
          'Deseja baixar todos os ${_toc.length} capítulos de "${widget.bookTitle}" para leitura offline?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Baixar Agora'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await _egwService.downloadBook(
        widget.bookId,
        onProgress: (current, total) {
          if (!mounted) return;
          setState(() {
            _downloadProgress = total > 0 ? (current / total) : 0.0;
          });
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Livro "${widget.bookTitle}" baixado com sucesso para visualização offline!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no download: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ts = ThemeService();
    final hasGlobalBg = ts.hasGlobalBackgroundShell;
    final hasPrev = _currentChapterIndex > 0;
    final hasNext = _currentChapterIndex < (_toc.length - 1);

    return Scaffold(
      backgroundColor: hasGlobalBg ? Colors.transparent : null,
      appBar: AppBar(
        backgroundColor: ts.isAscii
            ? theme.colorScheme.surface
            : (ts.isWin95
                ? const Color(0xFF000080)
                : (ts.hasAtmosphericBackground ? Colors.transparent : null)),
        foregroundColor: ts.isWin95 ? Colors.white : null,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: ts.isAscii
            ? Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 1.5))
            : (ts.isHoloRetro
                ? const Border(bottom: BorderSide(color: Color(0xFF33B5E5), width: 2))
                : null),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.bookTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_currentChapter != null)
              Text(
                _currentChapter!.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_isDownloading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Baixar livro completo',
              onPressed: _startBookDownload,
            ),
          IconButton(
            icon: const Icon(Icons.format_size_rounded),
            tooltip: 'Ajustes de texto',
            onPressed: _showReadingSettingsSheet,
          ),
          IconButton(
            icon: const Icon(Icons.list_rounded),
            tooltip: 'Sumário',
            onPressed: _toc.isNotEmpty ? _showTableOfContentsSheet : null,
          ),
        ],
        bottom: _isDownloading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3.0),
                child: LinearProgressIndicator(value: _downloadProgress),
              )
            : null,
      ),
      body: KairosReaderGestureLayer(
        onNextChapter:
            hasNext ? () => _loadChapterByIndex(_currentChapterIndex + 1) : null,
        onPreviousChapter:
            hasPrev ? () => _loadChapterByIndex(_currentChapterIndex - 1) : null,
        child: _buildBody(theme),
      ),
      bottomNavigationBar: _toc.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.chevron_left_rounded),
                      label: const Text('Anterior'),
                      onPressed: hasPrev ? () => _loadChapterByIndex(_currentChapterIndex - 1) : null,
                    ),
                    Text(
                      '${_currentChapterIndex + 1} de ${_toc.length}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.chevron_right_rounded),
                      label: const Text('Próximo'),
                      onPressed: hasNext ? () => _loadChapterByIndex(_currentChapterIndex + 1) : null,
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Carregando capítulo...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Tentar Novamente'),
                onPressed: () => _loadChapterByIndex(_currentChapterIndex),
              ),
            ],
          ),
        ),
      );
    }

    if (_currentChapter == null || _currentChapter!.paragraphs.isEmpty) {
      return const Center(child: Text('Nenhum texto encontrado neste capítulo.'));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      itemCount: _currentChapter!.paragraphs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Cabeçalho do Capítulo
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentChapter!.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(color: theme.colorScheme.primary.withValues(alpha: 0.3), thickness: 1.5),
              ],
            ),
          );
        }

        final para = _currentChapter!.paragraphs[index - 1];
        return _buildParagraphItem(context, theme, para);
      },
    );
  }

  Widget _buildParagraphItem(BuildContext context, ThemeData theme, EgwParagraph para) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRichParagraphText(context, theme, para.text),
          if (_showRefCodes && para.refcode.isNotEmpty) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                para.refcode,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Constrói o texto do parágrafo identificando referências bíblicas e tornando-as clicáveis.
  Widget _buildRichParagraphText(BuildContext context, ThemeData theme, String text) {
    final ts = ThemeService();
    return ListenableBuilder(
      listenable: ts,
      builder: (context, _) {
        return EgwLinkableParagraph(
          text: text,
          fontSize: (_fontSize * ts.fontSizeMultiplier).clamp(13.0, 34.0),
          contextTitle: widget.bookTitle,
        );
      },
    );
  }
}

/// Widget de parágrafo para textos dos escritos de Ellen G. White que analisa
/// referências bíblicas e as renderiza como links clicáveis com [SelectableText.rich].
///
/// Gerencia adequadamente o ciclo de vida dos [TapGestureRecognizer]s para evitar
/// vazamentos de memória durante a navegação entre capítulos e re-renderizações.
class EgwLinkableParagraph extends StatefulWidget {
  /// Texto completo do parágrafo a ser renderizado.
  final String text;

  /// Tamanho da fonte utilizado na renderização do texto.
  final double fontSize;

  /// Estilo tipográfico base para o texto comum. Se nulo, utiliza estilo padrão do tema.
  final TextStyle? baseStyle;

  /// Estilo tipográfico para as referências bíblicas identificadas.
  /// Se nulo, utiliza a cor primária do tema com sublinhado.
  final TextStyle? linkStyle;

  /// Título contextual (por exemplo, título do livro EGW) exibido no cabeçalho
  /// do modal de pré-visualização de versículos.
  final String? contextTitle;

  /// Callback customizado acionado ao tocar em uma referência bíblica identificada.
  /// Quando nulo, aciona [BibleVersePreviewModal.show] como comportamento padrão.
  final ValueChanged<String>? onBibleRefTap;

  /// Cria uma nova instância de [EgwLinkableParagraph].
  const EgwLinkableParagraph({
    super.key,
    required this.text,
    this.fontSize = 17.0,
    this.baseStyle,
    this.linkStyle,
    this.contextTitle,
    this.onBibleRefTap,
  });

  @override
  State<EgwLinkableParagraph> createState() => _EgwLinkableParagraphState();
}

class _EgwLinkableParagraphState extends State<EgwLinkableParagraph> {
  final List<TapGestureRecognizer> _recognizers = [];
  List<({String text, String? reference})> _segments = const [];

  @override
  void initState() {
    super.initState();
    _extractAndInitRecognizers();
  }

  @override
  void didUpdateWidget(EgwLinkableParagraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _disposeRecognizers();
      _extractAndInitRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _extractAndInitRecognizers() {
    _segments = BibleExtractor.splitTextByBibleRefs(widget.text);
    for (final segment in _segments) {
      final ref = segment.reference;
      if (ref != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => _handleRefTap(ref);
        _recognizers.add(recognizer);
      }
    }
  }

  void _handleRefTap(String ref) {
    if (widget.onBibleRefTap != null) {
      widget.onBibleRefTap!(ref);
    } else {
      BibleVersePreviewModal.show(
        context,
        reference: ref,
        references: BibleExtractor.getContiguousReferences(widget.text, ref),
        contextTitle: widget.contextTitle,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBaseStyle = widget.baseStyle ??
        TextStyle(
          fontSize: widget.fontSize,
          height: 1.65,
          color: theme.colorScheme.onSurface,
        );

    if (_segments.isEmpty || (_segments.length == 1 && _segments.first.reference == null)) {
      return SelectableText(
        widget.text,
        style: effectiveBaseStyle,
      );
    }

    final effectiveLinkStyle = widget.linkStyle ??
        TextStyle(
          fontSize: widget.fontSize,
          height: 1.65,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: theme.colorScheme.primary.withValues(alpha: 0.5),
        );

    int recognizerIndex = 0;
    final spans = <InlineSpan>[];
    for (final part in _segments) {
      if (part.reference != null) {
        final recognizer = recognizerIndex < _recognizers.length
            ? _recognizers[recognizerIndex++]
            : null;
        spans.add(TextSpan(
          text: part.text,
          style: effectiveLinkStyle,
          recognizer: recognizer,
        ));
      } else {
        spans.add(TextSpan(
          text: part.text,
          style: effectiveBaseStyle,
        ));
      }
    }

    return SelectableText.rich(
      TextSpan(
        style: effectiveBaseStyle,
        children: spans,
      ),
    );
  }
}
