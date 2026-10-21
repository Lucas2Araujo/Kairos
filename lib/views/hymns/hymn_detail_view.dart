import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/bible_controller.dart';
import '../../data/repositories/hymn_repository.dart';
import '../../models/hymn.dart';
import '../../services/theme_service.dart';
import '../bible/widgets/bible_verse_preview_modal.dart';
import 'widgets/hymn_audio_player_widget.dart';
import 'widgets/hymn_comparativo_dialog.dart';
import 'widgets/hymn_info_dialog.dart';
import 'widgets/hymn_text_format_sheet.dart';

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
  late Hymn _currentHymn;
  bool _isFavorite = false;
  List<String> _relatedTexts = [];
  List<String> _relatedThemes = [];
  int _maxHymnNumber = 600;
  bool _showAudio = false;
  bool _isLoadingNav = false;

  @override
  void initState() {
    super.initState();
    _currentHymn = widget.hymn;
    _loadHymnData(_currentHymn);
    _loadMaxHymnNumber();
  }

  Future<void> _loadMaxHymnNumber() async {
    final maxNum = await _hymnRepo.getMaxHymnNumber();
    if (mounted) {
      setState(() => _maxHymnNumber = maxNum);
    }
  }

  Future<void> _loadHymnData(Hymn hymn) async {
    final favFuture = _hymnRepo.isFavorite(hymn.id);
    final textsFuture = _hymnRepo.getRelatedBibleTexts(hymn.id);
    final themesFuture = _hymnRepo.getRelatedThemes(hymn.id);

    final results = await Future.wait([favFuture, textsFuture, themesFuture]);
    if (mounted) {
      setState(() {
        _isFavorite = results[0] as bool;
        _relatedTexts = results[1] as List<String>;
        _relatedThemes = results[2] as List<String>;
      });
    }
  }

  int get _numericPart =>
      int.tryParse(_currentHymn.numero.replaceAll(RegExp(r'\D'), '')) ?? 1;

  bool get _canGoPrevious => _numericPart > 1 || _currentHymn.numero.endsWith('B');
  bool get _canGoNext => _numericPart < _maxHymnNumber || _currentHymn.numero.endsWith('A');

  Future<void> _navigateToPrevious() async {
    if (!_canGoPrevious || _isLoadingNav) return;
    setState(() => _isLoadingNav = true);
    try {
      final prevHymn = await _hymnRepo.getPreviousHymn(_currentHymn.numero) ??
          await _hymnRepo.getByNumero((_numericPart - 1).toString());
      if (prevHymn != null && mounted) {
        setState(() => _currentHymn = prevHymn);
        _loadHymnData(prevHymn);
      }
    } finally {
      if (mounted) setState(() => _isLoadingNav = false);
    }
  }

  Future<void> _navigateToNext() async {
    if (!_canGoNext || _isLoadingNav) return;
    setState(() => _isLoadingNav = true);
    try {
      final nextHymn = await _hymnRepo.getNextHymn(_currentHymn.numero) ??
          await _hymnRepo.getByNumero((_numericPart + 1).toString());
      if (nextHymn != null && mounted) {
        setState(() => _currentHymn = nextHymn);
        _loadHymnData(nextHymn);
      }
    } finally {
      if (mounted) setState(() => _isLoadingNav = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final newStatus = await _hymnRepo.toggleFavorite(_currentHymn.id);
    if (mounted) {
      setState(() => _isFavorite = newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Hino adicionado aos favoritos!' : 'Hino removido dos favoritos.',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _onSelectBibleRef(String refText, List<String> allRefs) {
    if (widget.bibleController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navegando para $refText...')),
      );
      return;
    }

    final match = RegExp(r'^(.+?)\s+(\d+)(?::(\d+))?').firstMatch(refText.trim());
    if (match != null) {
      final bookName = match.group(1) ?? '';
      final chapter = int.tryParse(match.group(2) ?? '1') ?? 1;
      final verse = int.tryParse(match.group(3) ?? '1') ?? 1;
      widget.bibleController!.setStudyContext('Hino ${_currentHymn.numero}', allRefs);
      widget.bibleController!.jumpToVerse(bookName, chapter, verse);
      Navigator.of(context).pop();
      widget.onNavigateToTab?.call(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    final allRefs = <String>[];
    if (_currentHymn.textoBase != null && _currentHymn.textoBase!.trim().isNotEmpty) {
      allRefs.add(_currentHymn.textoBase!.trim());
    }
    for (final t in _relatedTexts) {
      if (!allRefs.contains(t)) allRefs.add(t);
    }

    final isKids = KidsHymnStyles.isKidsHymn(_currentHymn.numero);

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final isGlass = themeService.isLiquidGlass;
        final isBlur = isGlass && themeService.glassBlurEnabled;

        Widget bottomBar = Container(
          decoration: BoxDecoration(
            color: isGlass
                ? (theme.brightness == Brightness.dark
                    ? Colors.black.withValues(alpha: 0.35)
                    : Colors.white.withValues(alpha: 0.7))
                : theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: isGlass
                    ? (theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.6))
                    : theme.dividerColor.withValues(alpha: 0.1),
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Botão 1: Formatação Rápida
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => HymnTextFormatSheet.show(context),
                  icon: const Icon(Icons.format_size, size: 18),
                  label: const Text('Texto', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botão 2: Reprodutor de Áudio
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _showAudio = !_showAudio),
                  icon: Icon(
                    _showAudio ? Icons.headphones : Icons.headphones_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _showAudio ? 'Ocultar' : 'Áudio',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botão 3: YouTube
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_currentHymn.linkVideo != null && _currentHymn.linkVideo!.trim().isNotEmpty)
                      ? () => _openExternalUrl(_currentHymn.linkVideo!.trim())
                      : null,
                  icon: Icon(
                    Icons.play_circle_fill,
                    size: 18,
                    color: (_currentHymn.linkVideo != null && _currentHymn.linkVideo!.trim().isNotEmpty)
                        ? Colors.red
                        : null,
                  ),
                  label: const Text('Vídeo', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
        );

        if (isBlur) {
          bottomBar = ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: bottomBar,
            ),
          );
        }

        return LiquidGlassBackground(
          child: Scaffold(
            backgroundColor: isGlass ? Colors.transparent : null,
            appBar: AppBar(
              backgroundColor: isGlass ? Colors.transparent : null,
              elevation: isGlass ? 0 : null,
              scrolledUnderElevation: isGlass ? 0 : null,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).pop(),
              ),
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Hino anterior',
                    onPressed: _canGoPrevious ? _navigateToPrevious : null,
                  ),
                  Text(
                    'Hino ${_currentHymn.numero}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Próximo hino',
                    onPressed: _canGoNext ? _navigateToNext : null,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.compare_arrows),
                  tooltip: 'Comparar com Edição Antiga (1996)',
                  onPressed: () {
                    HymnComparativoDialog.show(
                      context,
                      numero: _currentHymn.numero,
                      titulo: _currentHymn.titulo,
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : null,
                  ),
                  tooltip: _isFavorite ? 'Remover dos favoritos' : 'Favoritar hino',
                  onPressed: _toggleFavorite,
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Informações do hino',
                  onPressed: () {
                    HymnInfoDialog.show(
                      context,
                      hymn: _currentHymn,
                      relatedTexts: _relatedTexts,
                      relatedThemes: _relatedThemes,
                      bibleController: widget.bibleController,
                      onNavigateToTab: widget.onNavigateToTab,
                    );
                  },
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _showAudio
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: HymnAudioPlayerWidget(
                              key: ValueKey('audio_${_currentHymn.numero}'),
                              numero: _currentHymn.numero,
                              titulo: _currentHymn.titulo,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  bottomBar,
                ],
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge Infantil se for Hino Infantil
                      if (isKids) ...[
                        Center(child: KidsHymnStyles.buildBadge()),
                        const SizedBox(height: 16),
                      ],

                      // Barra de Atalhos Bíblicos
                      if (allRefs.isNotEmpty) ...[
                        if (isGlass)
                          GlassSurface(
                            borderRadius: 12,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: _buildBibleRefsContent(theme, allRefs),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.1),
                              ),
                            ),
                            child: _buildBibleRefsContent(theme, allRefs),
                          ),
                        const SizedBox(height: 16),
                      ],

                      // Cabeçalho do Hino
                      if (isGlass)
                        GlassSurface(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(16),
                          child: _buildHeaderContent(theme, themeService),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.1),
                            ),
                          ),
                          child: _buildHeaderContent(theme, themeService),
                        ),
                      const SizedBox(height: 24),

                      // Letra do Hino
                      if (isKids) ...[
                        ..._buildKidsStanzas(context),
                      ] else ...[
                        if (isGlass)
                          GlassSurface(
                            borderRadius: 16,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            child: SelectableText(
                              _currentHymn.letra ?? 'Letra não disponível.',
                              textAlign: themeService.hymnTextAlign,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontFamily: themeService.fontFamily,
                                fontSize: 18 * themeService.fontSizeMultiplier,
                                height: 1.8,
                              ),
                            ),
                          )
                        else
                          SelectableText(
                            _currentHymn.letra ?? 'Letra não disponível.',
                            textAlign: themeService.hymnTextAlign,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontFamily: themeService.fontFamily,
                              fontSize: 18 * themeService.fontSizeMultiplier,
                              height: 1.8,
                            ),
                          ),
                      ],
                      const SizedBox(height: 32),

                      // Rodapé com Créditos de Autores
                      if (_hasCredits()) ...[
                        Divider(color: theme.dividerColor.withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        if (_currentHymn.autorLetra != null && _currentHymn.autorLetra!.isNotEmpty)
                          Text(
                            'Letra: ${_currentHymn.autorLetra}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        if (_currentHymn.autorMusica != null && _currentHymn.autorMusica!.isNotEmpty)
                          Text(
                            'Música: ${_currentHymn.autorMusica}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        if (_currentHymn.autores != null && _currentHymn.autores!.isNotEmpty)
                          Text(
                            'Autores: ${_currentHymn.autores}',
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
          ),
        );
      },
    );
  }

  Widget _buildBibleRefsContent(ThemeData theme, List<String> allRefs) {
    return Row(
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
                    onPressed: () => _onSelectBibleRef(ref, allRefs),
                    avatar: const Icon(Icons.open_in_new, size: 12),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderContent(ThemeData theme, ThemeService themeService) {
    return Column(
      children: [
        Text(
          '${_currentHymn.numero}. ${_currentHymn.titulo}',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFamily: themeService.fontFamily,
          ),
        ),
        if (_currentHymn.textoBase != null && _currentHymn.textoBase!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: () {
              BibleVersePreviewModal.show(
                context,
                reference: _currentHymn.textoBase!.trim(),
                bibleController: widget.bibleController,
                onNavigateToTab: widget.onNavigateToTab,
              );
            },
            icon: const Icon(Icons.menu_book, size: 16),
            label: Text(
              'Texto Base: ${_currentHymn.textoBase!.trim()}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildKidsStanzas(BuildContext context) {
    final rawLyrics = (_currentHymn.letra ?? '').trim();
    final stanzas = rawLyrics
        .split(RegExp(r'\n\s*\n'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    if (stanzas.isEmpty) {
      return const [
        Text('Letra não disponível.', textAlign: TextAlign.center),
      ];
    }

    return [
      for (int i = 0; i < stanzas.length; i++) ...[
        KidsHymnStyles.buildVerseCard(
          estrofe: stanzas[i].trim(),
          index: i + 1,
          context: context,
        ),
        if (i < stanzas.length - 1) const SizedBox(height: 12),
      ],
    ];
  }

  bool _hasCredits() {
    return (_currentHymn.autorLetra != null && _currentHymn.autorLetra!.isNotEmpty) ||
        (_currentHymn.autorMusica != null && _currentHymn.autorMusica!.isNotEmpty) ||
        (_currentHymn.autores != null && _currentHymn.autores!.isNotEmpty);
  }

  void _openExternalUrl(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Erro ao abrir URL: $e');
    }
  }
}
