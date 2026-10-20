import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../controllers/hymn_controller.dart';
import '../../models/hymn.dart';
import 'hymn_detail_view.dart';

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

  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hinário Adventista',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: widget.controller.edition,
                    dropdownColor: theme.cardTheme.color,
                    borderRadius: BorderRadius.circular(8),
                    items: const [
                      DropdownMenuItem(
                        value: 'novo',
                        child: Text('Hinário Novo', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      DropdownMenuItem(
                        value: 'antigo',
                        child: Text('Hinário Antigo (1996)', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                    onChanged: (edition) {
                      if (edition != null) {
                        _searchController.clear();
                        widget.controller.switchEdition(edition);
                      }
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Campo de busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                widget.controller.search(val);
                setState(() {});
              },
            ),
          ),

          // Chips de Categorias
          AnimatedBuilder(
            animation: widget.controller,
            builder: (context, _) {
              final categories = widget.controller.categories;
              if (categories.isEmpty) return const SizedBox.shrink();

              return SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = widget.controller.selectedCategory == null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: const Text('Todos'),
                          selected: isSelected,
                          onSelected: (_) {
                            _searchController.clear();
                            widget.controller.selectCategory(null);
                          },
                        ),
                      );
                    }

                    final cat = categories[index - 1];
                    final isSelected = widget.controller.selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (_) {
                          _searchController.clear();
                          widget.controller.selectCategory(cat);
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const Divider(height: 1),

          // Lista de Hinos
          Expanded(
            child: AnimatedBuilder(
              animation: widget.controller,
              builder: (context, _) {
                final ctrl = widget.controller;

                if (ctrl.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (ctrl.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(
                            ctrl.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent),
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

                if (ctrl.hymns.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhum hino encontrado.',
                      style: TextStyle(fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: ctrl.hymns.length,
                  itemBuilder: (context, index) {
                    final hymn = ctrl.hymns[index];
                    return _buildHymnTile(context, hymn);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHymnTile(BuildContext context, Hymn hymn) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          hymn.numero,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      title: Text(
        hymn.titulo,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: hymn.categoria != null && hymn.categoria!.isNotEmpty
          ? Text(
              hymn.categoria!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textTheme.bodySmall?.color),
            )
          : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HymnDetailView(
              hymn: hymn,
              bibleController: widget.bibleController,
              onNavigateToTab: widget.onNavigateToTab,
            ),
          ),
        );
      },
    );
  }
}
