import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../models/hymn.dart';
import '../../services/theme_service.dart';
import 'hymn_detail_view.dart';
import '../settings/settings_dialog.dart';

class HymnListView extends StatefulWidget {
  final HymnController controller;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const HymnListView({
    super.key,
    required this.controller,
    this.bibleController,
    this.onNavigateToTab,
  });

  @override
  State<HymnListView> createState() => _HymnListViewState();
}

class _HymnListViewState extends State<HymnListView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isDraggingScrollbar = false;
  double _dragFraction = 0.0;
  int _draggedHymnIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.init();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_isDraggingScrollbar && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScrollDrag(double localY, double totalHeight, HymnController ctrl) {
    if (totalHeight <= 0 || ctrl.hymns.isEmpty) return;
    final fraction = (localY / totalHeight).clamp(0.0, 1.0);
    final count = ctrl.hymns.length;
    final index = (fraction * (count - 1)).round().clamp(0, count - 1);
    setState(() {
      _isDraggingScrollbar = true;
      _dragFraction = fraction;
      _draggedHymnIndex = index;
    });
    if (_scrollController.hasClients && _scrollController.position.hasContentDimensions) {
      _scrollController.jumpTo(fraction * _scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isGlass = themeService.isAnyGlass;

        return Scaffold(
          backgroundColor: isGlass ? Colors.transparent : null,
          appBar: AppBar(
            backgroundColor: isGlass ? Colors.transparent : null,
            elevation: isGlass ? 0 : null,
            scrolledUnderElevation: isGlass ? 0 : null,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                return PopupMenuButton<String>(
                  tooltip: 'Trocar edição do hinário',
                  onSelected: (edition) {
                    _searchController.clear();
                    widget.controller.switchEdition(edition);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'novo',
                      child: Row(
                        children: [
                          Icon(
                            widget.controller.edition == 'novo'
                                ? Icons.check_rounded
                                : Icons.music_note_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Hinário Novo (2022)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'antigo',
                      child: Row(
                        children: [
                          Icon(
                            widget.controller.edition == 'antigo'
                                ? Icons.check_rounded
                                : Icons.menu_book_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Hinário Tradicional (1996)',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.controller.edition == 'novo'
                            ? 'Hinário Novo'
                            : 'Hinário Tradicional',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.controller.edition == 'novo' ? '2022' : '1996',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Configurações e Temas',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const SettingsDialog(),
                  );
                },
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Column(
            children: [
              // Barra de pesquisa + Menu de ordenação
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar por número, título ou letra...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    widget.controller.search('');
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isGlass
                              ? (theme.brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white.withValues(alpha: 0.6))
                              : theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: isGlass
                                ? BorderSide(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.5),
                                  )
                                : BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: isGlass
                                ? BorderSide(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.white.withValues(alpha: 0.5),
                                  )
                                : BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          widget.controller.search(val);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedBuilder(
                      animation: widget.controller,
                      builder: (context, _) {
                        return PopupMenuButton<HymnSortMode>(
                          icon: const Icon(Icons.sort_rounded),
                          tooltip: 'Ordenar hinos',
                          initialValue: widget.controller.sortMode,
                          onSelected: (mode) {
                            widget.controller.setSortMode(mode);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: HymnSortMode.numAsc,
                              child: Text('Número (Crescente 1 → 600)'),
                            ),
                            PopupMenuItem(
                              value: HymnSortMode.numDesc,
                              child: Text('Número (Decrescente 600 → 1)'),
                            ),
                            PopupMenuItem(
                              value: HymnSortMode.titleAsc,
                              child: Text('Título (A → Z)'),
                            ),
                            PopupMenuItem(
                              value: HymnSortMode.titleDesc,
                              child: Text('Título (Z → A)'),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // SegmentedButton com 4 abas: Todos, Favoritos, Recentes, Explorar
              AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<HymnTabFilter>(
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        segments: const [
                          ButtonSegment<HymnTabFilter>(
                            value: HymnTabFilter.todos,
                            label: Text('Todos'),
                          ),
                          ButtonSegment<HymnTabFilter>(
                            value: HymnTabFilter.favoritos,
                            label: Text('Favoritos'),
                          ),
                          ButtonSegment<HymnTabFilter>(
                            value: HymnTabFilter.recentes,
                            label: Text('Recentes'),
                          ),
                          ButtonSegment<HymnTabFilter>(
                            value: HymnTabFilter.explorar,
                            label: Text('Explorar'),
                          ),
                        ],
                        selected: {widget.controller.tabFilter},
                        onSelectionChanged: (newSelection) {
                          _searchController.clear();
                          widget.controller.setTabFilter(newSelection.first);
                        },
                      ),
                    ),
                  );
                },
              ),

              // Banner Inteligente de Filtro Ativo (Categoria ou Tema)
              AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  final ctrl = widget.controller;
                  if (!ctrl.hasActiveCategoryOrTheme) return const SizedBox.shrink();

                  final isCategory = ctrl.selectedCategory != null;
                  final label = isCategory
                      ? 'Categoria: ${ctrl.selectedCategory} (${ctrl.hymns.length} hinos)'
                      : 'Tema: ${ctrl.selectedTheme} (${ctrl.hymns.length} hinos)';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isCategory ? Icons.folder_outlined : Icons.label_outline,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                                color: theme.colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (ctrl.originHymn != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.arrow_back, size: 14),
                              label: Text(
                                'Voltar ao Hino ${ctrl.originHymn!.numero}',
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => HymnDetailView(
                                      hymn: ctrl.originHymn!,
                                      edition: widget.controller.edition,
                                      bibleController: widget.bibleController,
                                      onNavigateToTab: widget.onNavigateToTab,
                                    ),
                                  ),
                                ).then((_) => widget.controller.refreshCurrent());
                              },
                            )
                          else
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.explore_outlined, size: 14),
                              label: const Text(
                                'Explorar',
                                style: TextStyle(fontSize: 11.5),
                              ),
                              onPressed: () => ctrl.returnToExplore(),
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Limpar filtro',
                            onPressed: () {
                              _searchController.clear();
                              ctrl.clearCategoryOrThemeFilter();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Área de Conteúdo
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, _) {
                    final ctrl = widget.controller;

                    if (ctrl.isLoading) {
                      return const Center(
                        key: ValueKey('loading'),
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (ctrl.errorMessage != null) {
                      return Center(
                        key: const ValueKey('error'),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                              const SizedBox(height: 12),
                              Text(
                                ctrl.errorMessage!,
                                style: TextStyle(color: theme.colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () => ctrl.init(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    // Se estiver na aba Explorar sem filtro de categoria/tema ativo e sem busca textual
                    if (ctrl.tabFilter == HymnTabFilter.explorar &&
                        !ctrl.hasActiveCategoryOrTheme &&
                        ctrl.searchQuery.isEmpty) {
                      return _buildExploreView(context, ctrl);
                    }

                    if (ctrl.hymns.isEmpty) {
                      String emptyMsg = 'Nenhum hino encontrado.';
                      if (ctrl.tabFilter == HymnTabFilter.favoritos && ctrl.searchQuery.isEmpty) {
                        emptyMsg = 'Nenhum hino favoritado ainda.';
                      } else if (ctrl.tabFilter == HymnTabFilter.recentes && ctrl.searchQuery.isEmpty) {
                        emptyMsg = 'Nenhum hino acessado recentemente.';
                      }
                      return Center(
                        key: const ValueKey('empty'),
                        child: Text(
                          emptyMsg,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final trackHeight = constraints.maxHeight;
                        final hymnCount = ctrl.hymns.length;
                        final showScrollbar = hymnCount > 20;

                        double currentFraction = 0.0;
                        if (_isDraggingScrollbar) {
                          currentFraction = _dragFraction;
                        } else if (_scrollController.hasClients &&
                            _scrollController.position.hasContentDimensions &&
                            _scrollController.position.maxScrollExtent > 0) {
                          currentFraction = (_scrollController.offset /
                                  _scrollController.position.maxScrollExtent)
                              .clamp(0.0, 1.0);
                        }

                        const thumbHeight = 48.0;
                        final thumbTop = (trackHeight - thumbHeight) * currentFraction;

                        return Stack(
                          children: [
                            ListView.builder(
                              key: PageStorageKey(
                                'hymn_list_${ctrl.edition}_${ctrl.tabFilter}_${ctrl.selectedCategory}_${ctrl.selectedTheme}',
                              ),
                              controller: _scrollController,
                              itemCount: hymnCount,
                              itemBuilder: (context, index) {
                                final hymn = ctrl.hymns[index];
                                return _buildHymnTile(context, hymn);
                              },
                            ),
                            if (showScrollbar) ...[
                              Positioned(
                                top: 4,
                                bottom: 4,
                                right: 2,
                                width: 24,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onVerticalDragStart: (details) =>
                                      _handleScrollDrag(details.localPosition.dy, trackHeight - 8, ctrl),
                                  onVerticalDragUpdate: (details) =>
                                      _handleScrollDrag(details.localPosition.dy, trackHeight - 8, ctrl),
                                  onVerticalDragEnd: (_) => setState(() => _isDraggingScrollbar = false),
                                  onVerticalDragCancel: () => setState(() => _isDraggingScrollbar = false),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 4,
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: thumbTop.clamp(0.0, trackHeight - 8 - thumbHeight),
                                        left: 4,
                                        right: 4,
                                        height: thumbHeight,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _isDraggingScrollbar
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_isDraggingScrollbar &&
                                  _draggedHymnIndex >= 0 &&
                                  _draggedHymnIndex < hymnCount) ...[
                                Builder(
                                  builder: (context) {
                                    final hymn = ctrl.hymns[_draggedHymnIndex];
                                    final isTitleSort = ctrl.sortMode == HymnSortMode.titleAsc ||
                                        ctrl.sortMode == HymnSortMode.titleDesc;
                                    final bubbleText = isTitleSort
                                        ? '${hymn.titulo.isNotEmpty ? hymn.titulo[0].toUpperCase() : ''} • ${hymn.numero}'
                                        : 'Hino ${hymn.numero}';

                                    return Positioned(
                                      top: (thumbTop + thumbHeight / 2 - 20)
                                          .clamp(10.0, trackHeight - 50.0),
                                      right: 32,
                                      child: Material(
                                        elevation: 6,
                                        borderRadius: BorderRadius.circular(20),
                                        color: theme.colorScheme.primary,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          child: Text(
                                            bubbleText,
                                            style: TextStyle(
                                              color: theme.colorScheme.onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExploreView(BuildContext context, HymnController ctrl) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📂 Categorias',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                '(${ctrl.categories.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ctrl.categories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Text('Nenhuma categoria cadastrada.'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ctrl.categories.map((cat) {
                return ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 16),
                  label: Text(cat),
                  onPressed: () {
                    _searchController.clear();
                    ctrl.filterByCategoryOrTheme(category: cat);
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text(
                '🏷️ Temas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              Text(
                '(${ctrl.themes.length})',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (ctrl.themes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4.0),
              child: Text('Nenhum tema cadastrado.'),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ctrl.themes.map((themeName) {
                return ActionChip(
                  avatar: const Icon(Icons.label_outline, size: 16),
                  label: Text(themeName),
                  onPressed: () {
                    _searchController.clear();
                    ctrl.filterByCategoryOrTheme(theme: themeName);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildHymnTile(BuildContext context, Hymn hymn) {
    final theme = Theme.of(context);
    final isKids = KidsHymnStyles.isKidsHymn(hymn.numero, edition: widget.controller.edition);

    final tile = ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isKids
              ? Colors.amber.withValues(alpha: 0.2)
              : theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          hymn.numero,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isKids ? (Colors.amber[800] ?? Colors.amber) : theme.colorScheme.primary,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              hymn.titulo,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isKids) ...[
            const SizedBox(width: 6),
            const Text(
              '☀️',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ],
      ),
      subtitle: (hymn.categoria != null && hymn.categoria!.isNotEmpty) || isKids
          ? Row(
              children: [
                if (hymn.categoria != null && hymn.categoria!.isNotEmpty)
                  Flexible(
                    child: Text(
                      hymn.categoria!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.textTheme.bodySmall?.color),
                    ),
                  ),
                if (isKids) ...[
                  if (hymn.categoria != null && hymn.categoria!.isNotEmpty)
                    const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '☀️ Infantil ⭐',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ],
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HymnDetailView(
              hymn: hymn,
              edition: widget.controller.edition,
              bibleController: widget.bibleController,
              onNavigateToTab: widget.onNavigateToTab,
            ),
          ),
        ).then((_) => widget.controller.refreshCurrent());
      },
    );

    return tile;
  }
}
