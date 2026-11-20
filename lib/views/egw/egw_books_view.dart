import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/utils/in_app_link_launcher.dart';
import '../../models/egw_models.dart';
import '../../services/egw_service.dart';
import '../../services/theme_service.dart';
import 'egw_reader_view.dart';
import 'widgets/egw_book_cover.dart';

/// Tela de Catálogo e Lista de Livros do Espírito de Profecia (Ellen G. White).
/// Permite pesquisar por título/sigla, visualizar status de download offline,
/// baixar ou remover livros e iniciar a leitura.
class EgwBooksView extends StatefulWidget {
  const EgwBooksView({super.key});

  static Future<void> navigateTo(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EgwBooksView()),
    );
  }

  @override
  State<EgwBooksView> createState() => _EgwBooksViewState();
}

class _EgwBooksViewState extends State<EgwBooksView> {
  final EgwService _egwService = EgwService();
  final TextEditingController _searchController = TextEditingController();

  List<EgwBook> _allBooks = [];
  List<EgwBook> _filteredBooks = [];
  List<EgwPhraseMatch> _phraseMatches = [];
  List<EgwPhraseMatch> _onlinePhraseMatches = [];
  bool _isLoading = true;
  bool _isSearchingPhrases = false;
  bool _isSearchingOnline = false;
  Timer? _phraseSearchDebounce;
  String? _downloadingBookId;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  @override
  void dispose() {
    _phraseSearchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    final books = await _egwService.getBooks();
    if (!mounted) return;

    setState(() {
      _allBooks = books;
      _applyFilter(_searchController.text);
      _isLoading = false;
    });
  }

  void _applyFilter(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) {
      _filteredBooks = List.from(_allBooks);
      _phraseSearchDebounce?.cancel();
      _phraseMatches = [];
      _onlinePhraseMatches = [];
      _isSearchingPhrases = false;
      _isSearchingOnline = false;
    } else {
      _filteredBooks = _allBooks.where((b) {
        return b.title.toLowerCase().contains(q) ||
            b.abbreviation.toLowerCase().contains(q) ||
            b.description.toLowerCase().contains(q);
      }).toList();
      _schedulePhraseSearch(query);
    }
  }

  void _schedulePhraseSearch(String rawQuery) {
    _phraseSearchDebounce?.cancel();
    final trimmed = rawQuery.trim();
    if (trimmed.length < 3) {
      _phraseMatches = [];
      _onlinePhraseMatches = [];
      _isSearchingPhrases = false;
      _isSearchingOnline = false;
      return;
    }
    _isSearchingPhrases = true;
    _isSearchingOnline = true;
    _phraseSearchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final localFuture = _egwService.searchInDownloadedBooks(trimmed);
      final onlineFuture = _egwService.searchOnlinePortal(trimmed);

      final localResults = await localFuture;
      if (!mounted || _searchController.text.trim() != trimmed) return;
      setState(() {
        _phraseMatches = localResults;
        _isSearchingPhrases = false;
      });

      final onlineResults = await onlineFuture;
      if (!mounted || _searchController.text.trim() != trimmed) return;
      final localKeys = localResults.map((m) => '${m.bookId}.${m.chapterId}').toSet();
      final dedupedOnline = onlineResults
          .where((m) => !localKeys.contains('${m.bookId}.${m.chapterId}'))
          .toList();
      setState(() {
        _onlinePhraseMatches = dedupedOnline;
        _isSearchingOnline = false;
      });
    });
  }

  void _openOnlineEgwSearch(String query) {
    final encoded = Uri.encodeQueryComponent(query.trim());
    InAppLinkLauncher.openUrl('https://m.egwwritings.org/pt/search?query=$encoded');
  }

  Future<void> _handleDownloadBook(EgwBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Baixar "${book.title}"'),
        content: const Text(
          'Deseja baixar todos os capítulos para leitura offline? O progresso continuará em segundo plano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.download_rounded),
            label: const Text('Baixar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _downloadingBookId = book.id;
      _downloadProgress = 0.0;
    });

    try {
      await _egwService.downloadBook(
        book.id,
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
          content: Text('"${book.title}" baixado com sucesso!'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      await _loadBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao baixar: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloadingBookId = null;
        });
      }
    }
  }

  Future<void> _handleDeleteDownload(EgwBook book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover Download'),
        content: Text('Deseja excluir os capítulos salvos de "${book.title}" do armazenamento local?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _egwService.deleteBookDownload(book.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Download de "${book.title}" removido.')),
    );
    await _loadBooks();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ts = ThemeService();
    final hasGlobalBg = ts.hasGlobalBackgroundShell;
    final isSquareRetro = ts.isAscii || ts.isWin95 || ts.isHoloRetro;

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
        title: const Text('Espírito de Profecia'),
        actions: [
          ListenableBuilder(
            listenable: ThemeService(),
            builder: (context, _) {
              final isModern = ThemeService().egwUseModernCovers;
              return IconButton(
                icon: Icon(
                  isModern ? Icons.style_rounded : Icons.auto_awesome_mosaic_rounded,
                ),
                tooltip: 'Alternar Capa (Clássica EGW / Nova CPB)',
                onPressed: () {
                  ThemeService().setEgwUseModernCovers(!isModern);
                },
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar livro, sigla ou frase nos livros...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFilter(''));
                        },
                      )
                    : null,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(16),
                  borderSide: ts.isAscii
                      ? BorderSide(color: theme.colorScheme.primary, width: 1.2)
                      : BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _applyFilter(val)),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: ThemeService(),
        builder: (context, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final activeQuery = _searchController.text.trim();
          final hasPhraseSearch = activeQuery.length >= 3;

          if (hasPhraseSearch) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _isSearchingPhrases
                                    ? 'Buscando trechos nos livros baixados...'
                                    : 'Trechos nos livros baixados (${_phraseMatches.length})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isSearchingPhrases)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_isSearchingPhrases && _phraseMatches.isEmpty)
                          Text(
                            'Nenhum trecho encontrado nos livros baixados localmente.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ..._phraseMatches.map(
                          (match) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              title: Text(
                                '${match.bookTitle}${match.refcode.isNotEmpty ? ' • ${match.refcode}' : ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (match.chapterTitle.isNotEmpty)
                                    Text(
                                      match.chapterTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    match.snippet,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EgwReaderView(
                                      bookId: match.bookId,
                                      bookTitle: match.bookTitle,
                                      initialChapterId: match.chapterId,
                                      targetRefCode: match.refcode.isNotEmpty
                                          ? match.refcode
                                          : null,
                                    ),
                                  ),
                                );
                                if (mounted) _loadBooks();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.cloud_outlined,
                              size: 18,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _isSearchingOnline
                                    ? 'Buscando também em livros online...'
                                    : 'Resultados online (${_onlinePhraseMatches.length})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (_isSearchingOnline)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ..._onlinePhraseMatches.map(
                          (match) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              title: Text(
                                match.bookTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                match.snippet,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall,
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => EgwReaderView(
                                      bookId: match.bookId,
                                      bookTitle: match.bookTitle,
                                      initialChapterId: match.chapterId,
                                    ),
                                  ),
                                );
                                if (mounted) _loadBooks();
                              },
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('egw_search_online_btn'),
                            onPressed: () => _openOnlineEgwSearch(activeQuery),
                            icon: const Icon(Icons.travel_explore_rounded, size: 18),
                            label: const Text('Abrir busca completa no EGW Writings'),
                          ),
                        ),
                        if (_filteredBooks.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(
                            'Livros (${_filteredBooks.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_filteredBooks.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 175,
                        mainAxisExtent: 250,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 20,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final book = _filteredBooks[index];
                          final isDownloadingThis = _downloadingBookId == book.id;
                          return _buildBookshelfItem(context, theme, book, isDownloadingThis);
                        },
                        childCount: _filteredBooks.length,
                      ),
                    ),
                  ),
              ],
            );
          }

          return _filteredBooks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 56,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum livro encontrado',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadBooks,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 175,
                      mainAxisExtent: 250,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = _filteredBooks[index];
                      final isDownloadingThis = _downloadingBookId == book.id;
                      return _buildBookshelfItem(context, theme, book, isDownloadingThis);
                    },
                  ),
                );
        },
      ),
    );
  }

  Widget _buildBookshelfItem(
    BuildContext context,
    ThemeData theme,
    EgwBook book,
    bool isDownloadingThis,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EgwReaderView(
                    bookId: book.id,
                    bookTitle: book.title,
                  ),
                ),
              );
              if (mounted) _loadBooks();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                    blurRadius: 8,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    EgwBookCover(
                      book: book,
                      useModernCover: ThemeService().egwUseModernCovers,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    // Badge de sigla
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.abbreviation,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    // Ação de download / offline
                    Positioned(
                      top: 4,
                      right: 4,
                      child: isDownloadingThis
                          ? Padding(
                              padding: const EdgeInsets.all(6),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  value: _downloadProgress > 0 ? _downloadProgress : null,
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Material(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: const CircleBorder(),
                              child: IconButton(
                                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                color: book.isDownloaded ? Colors.greenAccent : Colors.white,
                                tooltip: book.isDownloaded
                                    ? 'Baixado (toque para gerenciar/remover)'
                                    : 'Baixar para offline',
                                icon: Icon(
                                  book.isDownloaded
                                      ? Icons.offline_pin_rounded
                                      : Icons.download_rounded,
                                ),
                                onPressed: () => book.isDownloaded
                                    ? _handleDeleteDownload(book)
                                    : _handleDownloadBook(book),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Prateleira sutil abaixo do livro
        Container(
          height: 6,
          margin: const EdgeInsets.only(top: 4, bottom: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.brown.shade800.withValues(alpha: 0.65)
                : Colors.brown.shade300.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  @visibleForTesting
  Widget buildBookCard(
    BuildContext context,
    ThemeData theme,
    EgwBook book,
    bool isDownloadingThis,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EgwReaderView(
                bookId: book.id,
                bookTitle: book.title,
              ),
            ),
          );
          if (mounted) _loadBooks();
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Capa com cantos arredondados
              EgwBookCover(
                book: book,
                useModernCover: ThemeService().egwUseModernCovers,
                width: 60,
                height: 88,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 14),

              // Informações do livro
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.abbreviation,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (book.isDownloaded)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade600),
                              const SizedBox(width: 3),
                              Text(
                                'Offline',
                                style: TextStyle(
                                  color: Colors.green.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      book.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (book.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        book.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (isDownloadingThis) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _downloadProgress),
                    ],
                  ],
                ),
              ),

              // Botão de Opções / Download
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (val) {
                  if (val == 'download') {
                    _handleDownloadBook(book);
                  } else if (val == 'delete') {
                    _handleDeleteDownload(book);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!book.isDownloaded)
                    const PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: [
                          Icon(Icons.download_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Baixar livro'),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remover download', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
