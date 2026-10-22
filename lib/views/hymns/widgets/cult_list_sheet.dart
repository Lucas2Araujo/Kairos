import 'package:flutter/material.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_manager.dart';
import '../../../models/hymn.dart';
import '../../../services/cult_list_recommender.dart';
import '../../../services/theme_service.dart';

export '../../../services/cult_list_recommender.dart';

class CultListSheet extends StatefulWidget {
  final void Function(Hymn hymn) onSelectHymn;
  final CommonDatabase? db;

  const CultListSheet({
    super.key,
    required this.onSelectHymn,
    this.db,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(Hymn hymn) onSelectHymn,
    CommonDatabase? db,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CultListSheet(
        onSelectHymn: onSelectHymn,
        db: db,
      ),
    );
  }

  @override
  State<CultListSheet> createState() => _CultListSheetState();
}

class _CultListSheetState extends State<CultListSheet> {
  CommonDatabase? _db;
  bool _isLoading = true;
  List<CultListModel> _savedLists = [];

  // Modo de criação de nova lista
  bool _isCreating = false;
  final TextEditingController _themeController = TextEditingController();
  List<CultRecommendation> _recommendations = [];

  @override
  void initState() {
    super.initState();
    _initDbAndLoad();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  Future<void> _initDbAndLoad() async {
    try {
      _db = widget.db ?? await DatabaseManager().getDatabase(AppConstants.dbHymns);
      _loadLists();
    } catch (e) {
      debugPrint('[CultListSheet] Erro ao obter banco: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadLists() {
    if (_db == null) return;
    try {
      final lists = CultListRecommender.getLists(_db!);
      if (mounted) {
        setState(() {
          _savedLists = lists;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CultListSheet] Erro ao carregar listas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _generateRecommendations() {
    if (_db == null) return;
    final theme = _themeController.text.trim();
    final recs = CultListRecommender.recommend(db: _db!, theme: theme);
    setState(() {
      _recommendations = recs;
    });
  }

  void _saveNewList() {
    if (_db == null || _recommendations.isEmpty) return;
    final theme = _themeController.text.trim();
    final hymnIds = _recommendations.map((r) => r.hymn.id).toList();
    CultListRecommender.createList(_db!, tema: theme, hymnIds: hymnIds);
    setState(() {
      _isCreating = false;
      _recommendations.clear();
      _themeController.clear();
    });
    _loadLists();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lista de culto salva com sucesso!')),
    );
  }

  void _deleteList(int listId) {
    if (_db == null) return;
    CultListRecommender.deleteList(_db!, listId);
    _loadLists();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final isGlass = themeService.isAnyGlass;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: isGlass
            ? (theme.brightness == Brightness.dark
                ? Colors.grey.shade900.withValues(alpha: 0.95)
                : Colors.grey.shade100.withValues(alpha: 0.95))
            : theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.playlist_play_rounded, color: theme.colorScheme.primary, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      _isCreating ? 'Nova Programação de Culto' : 'Listas de Culto',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isCreating = !_isCreating;
                      if (_isCreating && _recommendations.isEmpty) {
                        _generateRecommendations();
                      }
                    });
                  },
                  icon: Icon(_isCreating ? Icons.arrow_back : Icons.add),
                  label: Text(_isCreating ? 'Minhas Listas' : '+ Nova Lista'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isCreating
                    ? _buildCreationView(theme)
                    : _buildSavedListsView(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildCreationView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recomendador Litúrgico Local',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gere uma ordem de culto harmoniosa com Introito, Oração, Sermão, Ofertório e Despedida.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          // Input do Tema
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _themeController,
                  decoration: InputDecoration(
                    labelText: 'Tema ou Mensagem do Culto',
                    hintText: 'Ex: Graça, Família, Sábado, Batismo...',
                    prefixIcon: const Icon(Icons.church_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _generateRecommendations(),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _generateRecommendations,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Recomendar'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Recomendações
          if (_recommendations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Digite um tema e clique em Recomendar para gerar os hinos.',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            Text(
              'Ordem Litúrgica Recomendada (${_recommendations.length} hinos)',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ..._recommendations.map((rec) => _buildRecommendationCard(rec, theme)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saveNewList,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Salvar Esta Programação de Culto'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(CultRecommendation rec, ThemeData theme) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            '${rec.order}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          '${rec.hymn.numero}. ${rec.hymn.titulo}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Row(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                rec.section,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            if (rec.hymn.subcategoria != null && rec.hymn.subcategoria != rec.section) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  rec.hymn.subcategoria!,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          tooltip: 'Abrir Hino',
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSelectHymn(rec.hymn);
          },
        ),
        onTap: () {
          Navigator.of(context).pop();
          widget.onSelectHymn(rec.hymn);
        },
      ),
    );
  }

  Widget _buildSavedListsView(ThemeData theme) {
    if (_savedLists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_remove_rounded, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                'Nenhuma lista de culto salva',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Toque em "+ Nova Lista" para gerar e salvar programações litúrgicas com hinos para os cultos.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isCreating = true;
                    _generateRecommendations();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Criar Primeira Lista'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedLists.length,
      itemBuilder: (context, index) {
        final item = _savedLists[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.church, color: theme.colorScheme.onPrimaryContainer, size: 20),
            ),
            title: Text(
              item.temaGerador,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${item.hymns.length} hinos • ${item.dataCriacao.split(' ').first}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Excluir Lista',
              onPressed: () => _confirmDelete(item.id, item.temaGerador),
            ),
            children: [
              const Divider(height: 1),
              ...item.hymns.asMap().entries.map((entry) {
                final order = entry.key + 1;
                final hymn = entry.value;
                final sectionLabel = order <= CultListRecommender.sections.length
                    ? CultListRecommender.sections[order - 1]
                    : 'Momento de Louvor';

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    child: Text('$order', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${hymn.numero}. ${hymn.titulo}'),
                  subtitle: Text(
                    sectionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onSelectHymn(hymn);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(int listId, String tema) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Lista?'),
        content: Text('Deseja realmente remover a lista "$tema"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteList(listId);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }
}
