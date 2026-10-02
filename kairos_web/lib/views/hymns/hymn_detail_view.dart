import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../data/repositories/hymn_repository.dart';
import '../../models/hymn.dart';
import '../../services/theme_service.dart';
import 'widgets/hymn_audio_player_widget.dart';
import 'widgets/hymn_comparativo_dialog.dart';

class HymnDetailView extends StatefulWidget {
  final Hymn hymn;
  final BibleController? bibleController;
  final void Function(int tabIndex)? onNavigateToTab;

  const HymnDetailView({
    super.key,
    required this.hymn,
    this.bibleController,
    this.onNavigateToTab,
  });

  @override
  State<HymnDetailView> createState() => _HymnDetailViewState();
}

class _HymnDetailViewState extends State<HymnDetailView> {
  final HymnRepository _hymnRepo = HymnRepository();
  List<String> _relatedTexts = [];
  bool _showAudio = false;

  @override
  void initState() {
    super.initState();
    _loadRelatedTexts();
  }

  Future<void> _loadRelatedTexts() async {
    final texts = await _hymnRepo.getRelatedBibleTexts(widget.hymn.id);
    if (mounted) {
      setState(() => _relatedTexts = texts);
    }
  }

  void _onSelectBibleRef(String refText) {
    if (widget.bibleController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navegando para $refText...')),
      );
      return;
    }

    // Extrai livro e capítulo da referência (ex: "Apocalipse 4:8" ou "Salmos 99:5")
    final match = RegExp(r'^(.+?)\s+(\d+)(?::(\d+))?').firstMatch(refText.trim());
    if (match != null) {
      final bookName = match.group(1) ?? '';
      final chapter = int.tryParse(match.group(2) ?? '1') ?? 1;
      final verse = int.tryParse(match.group(3) ?? '1') ?? 1;
      widget.bibleController!.jumpToVerse(bookName, chapter, verse);
      Navigator.of(context).pop(); // Volta para a tela principal onde a Bíblia está disponível
      widget.onNavigateToTab?.call(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();
    final hymn = widget.hymn;

    // Combina texto_base e textos relacionados
    final allRefs = <String>[];
    if (hymn.textoBase != null && hymn.textoBase!.trim().isNotEmpty) {
      allRefs.add(hymn.textoBase!.trim());
    }
    for (final t in _relatedTexts) {
      if (!allRefs.contains(t)) allRefs.add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Hino ${hymn.numero}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            tooltip: 'Comparar com Edição Antiga (1996)',
            onPressed: () {
              HymnComparativoDialog.show(
                context,
                numero: hymn.numero,
                titulo: hymn.titulo,
              );
            },
          ),
          IconButton(
            icon: Icon(_showAudio ? Icons.volume_off : Icons.headphones),
            tooltip: _showAudio ? 'Ocultar Player' : 'Tocar Áudio',
            onPressed: () {
              setState(() => _showAudio = !_showAudio);
            },
          ),
        ],
      ),
      bottomNavigationBar: _showAudio
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: HymnAudioPlayerWidget(
                numero: hymn.numero,
                titulo: hymn.titulo,
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Barra de Atalhos Bíblicos (make_hymn_context_bar)
                if (allRefs.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.dividerColor.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Textos Bíblicos:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: allRefs.map((ref) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: ActionChip(
                                    label: Text(ref, style: const TextStyle(fontSize: 11)),
                                    onPressed: () => _onSelectBibleRef(ref),
                                    avatar: const Icon(Icons.open_in_new, size: 12),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Cabeçalho do Hino
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${hymn.numero}. ${hymn.titulo}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: AppConstants.fontHymnSerif,
                        ),
                      ),
                      if (hymn.categoria != null && hymn.categoria!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            hymn.categoria!,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Letra do Hino
                SelectableText(
                  hymn.letra ?? 'Letra não disponível.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: AppConstants.fontHymnSerif,
                    fontSize: 18 * themeService.fontSizeMultiplier,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 32),

                // Rodapé com Créditos de Autores
                if (_hasCredits()) ...[
                  Divider(color: theme.dividerColor.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  if (hymn.autorLetra != null && hymn.autorLetra!.isNotEmpty)
                    Text(
                      'Letra: ${hymn.autorLetra}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  if (hymn.autorMusica != null && hymn.autorMusica!.isNotEmpty)
                    Text(
                      'Música: ${hymn.autorMusica}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  if (hymn.autores != null && hymn.autores!.isNotEmpty)
                    Text(
                      'Autores: ${hymn.autores}',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hasCredits() {
    return (widget.hymn.autorLetra != null && widget.hymn.autorLetra!.isNotEmpty) ||
        (widget.hymn.autorMusica != null && widget.hymn.autorMusica!.isNotEmpty) ||
        (widget.hymn.autores != null && widget.hymn.autores!.isNotEmpty);
  }
}
