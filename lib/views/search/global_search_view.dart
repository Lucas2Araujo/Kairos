import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/devotional_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../controllers/sabbath_school_controller.dart';
import '../../services/search_service.dart';
import '../hymns/hymn_detail_view.dart';

class GlobalSearchView extends StatefulWidget {
  final BibleController bibleController;
  final HymnController hymnController;
  final DevotionalController devotionalController;
  final SabbathSchoolController sabbathSchoolController;
  final void Function(int tabIndex) onNavigateToTab;

  const GlobalSearchView({
    super.key,
    required this.bibleController,
    required this.hymnController,
    required this.devotionalController,
    required this.sabbathSchoolController,
    required this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    required BibleController bibleController,
    required HymnController hymnController,
    required DevotionalController devotionalController,
    required SabbathSchoolController sabbathSchoolController,
    required void Function(int tabIndex) onNavigateToTab,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: GlobalSearchView(
            bibleController: bibleController,
            hymnController: hymnController,
            devotionalController: devotionalController,
            sabbathSchoolController: sabbathSchoolController,
            onNavigateToTab: onNavigateToTab,
          ),
        ),
      ),
    );
  }

  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends State<GlobalSearchView> {
  final SearchService _searchService = SearchService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  SearchContentType? _selectedFilter;
  SearchResultsPage _results = SearchResultsPage.empty;
  bool _isLoading = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch();
    });
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _results = SearchResultsPage.empty;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final page = await _searchService.search(
        query,
        typeFilter: _selectedFilter,
        limit: 60,
      );
      if (mounted) {
        setState(() {
          _results = page;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onFilterSelected(SearchContentType? filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _performSearch();
  }

  void _onItemTapped(SearchResultItem item) async {
    Navigator.of(context).pop();
    final meta = item.metadata;

    switch (item.contentType) {
      case SearchContentType.biblia:
        final book = meta['book_id'] ?? meta['book_name'];
        final ch = (meta['chapter'] as num?)?.toInt() ?? 1;
        final v = (meta['verse'] as num?)?.toInt() ?? 1;
        await widget.bibleController.jumpToVerse(book, ch, v);
        widget.onNavigateToTab(1);
        break;

      case SearchContentType.hino:
        final numStr = meta['numero']?.toString() ?? '';
        if (numStr.isNotEmpty && widget.hymnController.hymns.isNotEmpty) {
          final matchedHymn = widget.hymnController.hymns
              .where((h) => h.numero == numStr)
              .firstOrNull;
          if (matchedHymn != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HymnDetailView(
                  hymn: matchedHymn,
                  bibleController: widget.bibleController,
                  onNavigateToTab: widget.onNavigateToTab,
                ),
              ),
            );
            return;
          }
        }
        await widget.hymnController.search(numStr);
        widget.onNavigateToTab(2);
        break;

      case SearchContentType.meditacao:
        final dateStr = meta['published_at'] as String?;
        if (dateStr != null) {
          final dt = DateTime.tryParse(dateStr);
          if (dt != null) {
            await widget.devotionalController.selectDate(dt);
          }
        }
        if (meta['category'] != null) {
          await widget.devotionalController.selectCategory(meta['category'].toString());
        }
        widget.onNavigateToTab(3);
        break;

      case SearchContentType.licao:
        widget.onNavigateToTab(4);
        break;
    }
  }

  Widget _buildTypeIcon(SearchContentType type, ColorScheme colorScheme) {
    switch (type) {
      case SearchContentType.hino:
        return Icon(Icons.music_note, color: colorScheme.secondary, size: 20);
      case SearchContentType.biblia:
        return Icon(Icons.menu_book, color: colorScheme.primary, size: 20);
      case SearchContentType.meditacao:
        return Icon(Icons.wb_sunny_outlined, color: colorScheme.tertiary, size: 20);
      case SearchContentType.licao:
        return Icon(Icons.school_outlined, color: colorScheme.primary, size: 20);
    }
  }

  String _getTypeLabel(SearchContentType type) {
    switch (type) {
      case SearchContentType.hino:
        return 'Hino';
      case SearchContentType.biblia:
        return 'Bíblia';
      case SearchContentType.meditacao:
        return 'Meditação';
      case SearchContentType.licao:
        return 'Lição';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countHinos = _results.countsByType[SearchContentType.hino] ?? 0;
    final countBiblia = _results.countsByType[SearchContentType.biblia] ?? 0;
    final countMeditacao = _results.countsByType[SearchContentType.meditacao] ?? 0;
    final countLicao = _results.countsByType[SearchContentType.licao] ?? 0;
    final total = _results.totalCount;

    return Column(
      children: [
        // Barra Superior / Campo de Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Pesquisar hinos, versículos, meditações e lições...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Limpar',
                            onPressed: () {
                              _searchController.clear();
                              _performSearch();
                            },
                          )
                        : null,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Fechar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),

        // Barra de progresso de busca
        if (_isLoading)
          const LinearProgressIndicator(minHeight: 2)
        else
          const SizedBox(height: 2),

        // Filtros (ChoiceChips)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('Todos ($total)'),
                selected: _selectedFilter == null,
                onSelected: (_) => _onFilterSelected(null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Hinos ($countHinos)'),
                selected: _selectedFilter == SearchContentType.hino,
                onSelected: (_) => _onFilterSelected(SearchContentType.hino),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Bíblia ($countBiblia)'),
                selected: _selectedFilter == SearchContentType.biblia,
                onSelected: (_) => _onFilterSelected(SearchContentType.biblia),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Meditação ($countMeditacao)'),
                selected: _selectedFilter == SearchContentType.meditacao,
                onSelected: (_) => _onFilterSelected(SearchContentType.meditacao),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Lição ($countLicao)'),
                selected: _selectedFilter == SearchContentType.licao,
                onSelected: (_) => _onFilterSelected(SearchContentType.licao),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista de Resultados
        Expanded(
          child: _searchController.text.trim().isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search, size: 56, color: theme.disabledColor),
                      const SizedBox(height: 12),
                      Text(
                        'Digite uma palavra ou número para buscar.',
                        style: TextStyle(color: theme.disabledColor, fontSize: 15),
                      ),
                    ],
                  ),
                )
              : _results.items.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off, size: 56, color: theme.disabledColor),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhum resultado encontrado.',
                            style: TextStyle(color: theme.disabledColor, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _results.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _results.items[index];

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            child: _buildTypeIcon(item.contentType, theme.colorScheme),
                          ),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _getTypeLabel(item.contentType),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.subtitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          onTap: () => _onItemTapped(item),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
