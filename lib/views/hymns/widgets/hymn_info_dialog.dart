import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../data/repositories/hymn_repository.dart';
import '../../../models/hymn.dart';
import '../../../services/theme_service.dart';
import '../../bible/widgets/bible_verse_preview_modal.dart';
import 'hymn_comparativo_dialog.dart';

class HymnInfoDialog extends StatefulWidget {
  final Hymn hymn;
  final String? edition;
  final List<String> relatedTexts;
  final List<String> relatedThemes;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;
  final void Function({String? category, String? theme})? onSelectFilter;

  const HymnInfoDialog({
    super.key,
    required this.hymn,
    this.edition,
    this.relatedTexts = const [],
    this.relatedThemes = const [],
    this.bibleController,
    this.onNavigateToTab,
    this.onSelectFilter,
  });

  static Future<void> show(
    BuildContext context, {
    required Hymn hymn,
    String? edition,
    List<String> relatedTexts = const [],
    List<String> relatedThemes = const [],
    BibleController? bibleController,
    void Function(int tabIndex)? onNavigateToTab,
    void Function({String? category, String? theme})? onSelectFilter,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => HymnInfoDialog(
        hymn: hymn,
        edition: edition,
        relatedTexts: relatedTexts,
        relatedThemes: relatedThemes,
        bibleController: bibleController,
        onNavigateToTab: onNavigateToTab,
        onSelectFilter: onSelectFilter,
      ),
    );
  }

  @override
  State<HymnInfoDialog> createState() => _HymnInfoDialogState();
}

class _HymnInfoDialogState extends State<HymnInfoDialog> {
  final HymnRepository _repo = HymnRepository();
  late List<String> _texts;
  late List<String> _themes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final activeEdition = widget.edition ?? ThemeService().currentEdition;
    _repo.setDatabase(activeEdition == 'antigo' ? 'hinario_antigo.db' : 'hinario.db');
    _texts = List.from(widget.relatedTexts);
    _themes = List.from(widget.relatedThemes);
    if (_texts.isEmpty || _themes.isEmpty) {
      _loadExtraData();
    }
  }

  Future<void> _loadExtraData() async {
    setState(() => _isLoading = true);
    try {
      final futures = await Future.wait([
        if (_texts.isEmpty) _repo.getRelatedBibleTexts(widget.hymn.id) else Future.value(_texts),
        if (_themes.isEmpty) _repo.getRelatedThemes(widget.hymn.id) else Future.value(_themes),
      ]);
      if (mounted) {
        setState(() {
          _texts = futures[0];
          _themes = futures[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openBibleRef(String ref) {
    final allRefs = <String>[
      if (widget.hymn.textoBase != null && widget.hymn.textoBase!.trim().isNotEmpty)
        widget.hymn.textoBase!.trim(),
      ..._texts,
    ];
    BibleVersePreviewModal.show(
      context,
      reference: ref,
      references: allRefs,
      baseReference: widget.hymn.textoBase?.trim(),
      contextTitle: 'Hinário',
      bibleController: widget.bibleController,
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hymn = widget.hymn;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${hymn.numero}. ${hymn.titulo}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 550),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Categoria & Subcategoria
              if ((hymn.categoria != null && hymn.categoria!.isNotEmpty) ||
                  (hymn.subcategoria != null && hymn.subcategoria!.isNotEmpty)) ...[
                _buildSectionHeader(theme, 'Classificação', Icons.category_outlined),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (hymn.categoria != null && hymn.categoria!.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.folder_outlined, size: 16),
                        label: Text(hymn.categoria!),
                        tooltip: 'Filtrar por ${hymn.categoria}',
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSelectFilter?.call(category: hymn.categoria);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                    if (hymn.subcategoria != null && hymn.subcategoria!.isNotEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.subdirectory_arrow_right, size: 16),
                        label: Text(hymn.subcategoria!),
                        tooltip: 'Filtrar por ${hymn.subcategoria}',
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onSelectFilter?.call(category: hymn.subcategoria);
                        },
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Autores
              _buildSectionHeader(theme, 'Autores', Icons.people_outline),
              const SizedBox(height: 6),
              _buildAuthorTile(theme, 'Letra', hymn.autorLetra),
              _buildAuthorTile(theme, 'Música', hymn.autorMusica),
              if (hymn.autores != null &&
                  hymn.autores!.isNotEmpty &&
                  hymn.autores != hymn.autorLetra &&
                  hymn.autores != hymn.autorMusica)
                _buildAuthorTile(theme, 'Geral', hymn.autores),
              if ((hymn.autorLetra == null || hymn.autorLetra!.isEmpty) &&
                  (hymn.autorMusica == null || hymn.autorMusica!.isEmpty) &&
                  (hymn.autores == null || hymn.autores!.isEmpty))
                Text(
                  'Autoria não especificada',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              const SizedBox(height: 16),

              // Texto Base
              _buildSectionHeader(theme, 'Texto Bíblico Base', Icons.menu_book),
              const SizedBox(height: 6),
              if (hymn.textoBase != null && hymn.textoBase!.trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.open_in_new, size: 14),
                    label: Text(
                      hymn.textoBase!.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _openBibleRef(hymn.textoBase!.trim()),
                    visualDensity: VisualDensity.compact,
                  ),
                )
              else
                Text(
                  'Nenhum texto base cadastrado',
                  style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              const SizedBox(height: 16),

              // Textos Relacionados
              if (_texts.isNotEmpty) ...[
                _buildSectionHeader(theme, 'Textos Relacionados', Icons.auto_stories_outlined),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _texts.map((ref) {
                    return ActionChip(
                      avatar: const Icon(Icons.open_in_new, size: 14),
                      label: Text(ref, style: const TextStyle(fontSize: 12)),
                      onPressed: () => _openBibleRef(ref),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Temas Relacionados
              if (_themes.isNotEmpty) ...[
                _buildSectionHeader(theme, 'Temas Relacionados', Icons.label_outline),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _themes.map((t) {
                    return ActionChip(
                      avatar: const Icon(Icons.label_outline, size: 14),
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      tooltip: 'Filtrar por $t',
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onSelectFilter?.call(theme: t);
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],

              if (_isLoading) ...[
                const SizedBox(height: 12),
                const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: () {
            HymnComparativoDialog.show(
              context,
              numero: widget.hymn.numero,
              titulo: widget.hymn.titulo,
              isNovo: (widget.edition ?? ThemeService().currentEdition) != 'antigo',
            );
          },
          icon: const Icon(Icons.compare_arrows, size: 16),
          label: const Text('Comparar Edição 1996', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthorTile(ThemeData theme, String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text.rich(
        TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value.trim()),
          ],
        ),
      ),
    );
  }
}
