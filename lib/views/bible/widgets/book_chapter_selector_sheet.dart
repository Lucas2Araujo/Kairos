import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../models/bible_verse.dart';

class BookChapterSelectorSheet extends StatefulWidget {
  final BibleController controller;

  const BookChapterSelectorSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, BibleController controller) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookChapterSelectorSheet(controller: controller),
    );
  }

  @override
  State<BookChapterSelectorSheet> createState() => _BookChapterSelectorSheetState();
}

class _BookChapterSelectorSheetState extends State<BookChapterSelectorSheet> {
  late BibleBook _selectedBook;
  int _activeTab = 0; // 0: Livro, 1: Capítulo
  String _testamentFilter = 'TODOS'; // 'TODOS', 'VT', 'NT'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.controller.selectedBook ??
        (widget.controller.books.isNotEmpty
            ? widget.controller.books.first
            : const BibleBook(
                id: 1,
                name: 'Gênesis',
                testament: 'VT',
                chaptersCount: 50,
              ));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BibleBook> get _filteredBooks {
    return widget.controller.books.where((book) {
      if (_testamentFilter == 'VT' && book.testament != 'VT') return false;
      if (_testamentFilter == 'NT' && book.testament != 'NT') return false;
      if (_searchQuery.isNotEmpty &&
          !book.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
  }

  void _onBookSelected(BibleBook book) {
    setState(() {
      _selectedBook = book;
      _activeTab = 1;
    });
  }

  void _onChapterSelected(int chapter) {
    widget.controller.selectBook(_selectedBook);
    widget.controller.selectChapter(chapter);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        elevation: 8,
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with Tab Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: [
                        ButtonSegment(
                          value: 0,
                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                          label: Text(
                            _selectedBook.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ButtonSegment(
                          value: 1,
                          icon: const Icon(Icons.format_list_numbered, size: 16),
                          label: Text(
                            'Capítulo ${widget.controller.selectedChapter}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      selected: {_activeTab},
                      onSelectionChanged: (set) {
                        setState(() => _activeTab = set.first);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _activeTab == 0 ? _buildBooksView(theme) : _buildChaptersView(theme),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBooksView(ThemeData theme) {
    final books = _filteredBooks;

    return Column(
      children: [
        // Filtros (Busca e Testamento)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar livro...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Todos'),
                    selected: _testamentFilter == 'TODOS',
                    onSelected: (sel) {
                      if (sel) setState(() => _testamentFilter = 'TODOS');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Antigo (VT)'),
                    selected: _testamentFilter == 'VT',
                    onSelected: (sel) {
                      if (sel) setState(() => _testamentFilter = 'VT');
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Novo (NT)'),
                    selected: _testamentFilter == 'NT',
                    onSelected: (sel) {
                      if (sel) setState(() => _testamentFilter = 'NT');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // Lista de Livros
        Expanded(
          child: books.isEmpty
              ? const Center(child: Text('Nenhum livro encontrado.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: books.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final isSelected = book.id == _selectedBook.id;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      title: Text(
                        book.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              book.testament,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${book.chaptersCount} cap.',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                      onTap: () => _onBookSelected(book),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChaptersView(ThemeData theme) {
    final count = _selectedBook.chaptersCount;
    final currentCh = widget.controller.selectedBook?.id == _selectedBook.id
        ? widget.controller.selectedChapter
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Capítulos de ${_selectedBook.name}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _activeTab = 0),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Trocar Livro', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                final ch = index + 1;
                final isCurrent = ch == currentCh;

                return InkWell(
                  onTap: () => _onChapterSelected(ch),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrent
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$ch',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isCurrent
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
