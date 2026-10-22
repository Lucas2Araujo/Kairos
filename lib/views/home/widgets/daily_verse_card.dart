import 'dart:io' as io;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../controllers/bible_controller.dart';
import '../../../controllers/devotional_controller.dart';
import '../../../services/theme_service.dart';
import '../../../services/wallpaper_service.dart';
import '../../devotional/meditacao_destaque_view.dart';

/// Card editorial do Versículo do Dia (estilo YouVersion / AndBible / SelecaoView Flet)
/// com wallpaper curado de natureza, gradiente sobreposto escuro para legibilidade perfeita,
/// tipografia HymnSerif elegante e abertura da visualização imersiva MeditacaoDestaqueView.
class DailyVerseCard extends StatefulWidget {
  final BibleController bibleController;
  final void Function(int tabIndex) onNavigateToTab;
  final DevotionalController devotionalController;
  final bool isGlass;

  const DailyVerseCard({
    super.key,
    required this.bibleController,
    required this.onNavigateToTab,
    required this.devotionalController,
    required this.isGlass,
  });

  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard> {
  final GlobalKey _cardKey = GlobalKey();

  void _openDestaque(BuildContext context, String verseText, String ref) {
    final devo = widget.devotionalController.currentDevotional;
    MeditacaoDestaqueView.show(
      context,
      devotional: devo,
      fallbackVerse: verseText,
      fallbackReference: ref,
      onNavigateToTab: widget.onNavigateToTab,
    );
  }

  Future<void> _exportCard(String verseText, String ref) async {
    try {
      var boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      if (boundary.debugNeedsPaint) {
        await WidgetsBinding.instance.endOfFrame;
        boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary == null) return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) return;

      if (!kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final filename = 'versiculo_${DateTime.now().millisecondsSinceEpoch}.png';
          final file = io.File('${dir.path}/$filename');
          await file.writeAsBytes(bytes);
        } catch (_) {
          // Ignorado em ambientes sem suporte ao path_provider ou em testes
        }
      }

      Clipboard.setData(ClipboardData(text: '“$verseText” — $ref\n(Compartilhado via Kairós)'));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card de versículo exportado com sucesso!'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro na exportação do card: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final wallpaperUrl = WallpaperService().getDailyWallpaper();

    return ListenableBuilder(
      listenable: widget.devotionalController,
      builder: (context, _) {
        final devo = widget.devotionalController.currentDevotional;
        final rawVerse = devo?.verseText.trim();
        final verseText = (rawVerse != null && rawVerse.isNotEmpty)
            ? rawVerse
            : 'Porque nenhum de nós vive para si mesmo, nem morre para si';

        final rawRef = devo?.verseReference.trim();
        final ref = (rawRef != null && rawRef.isNotEmpty) ? rawRef : 'Romanos 14:7';

        final category = (devo?.category != null && devo!.category.trim().isNotEmpty)
            ? devo.category.trim().toUpperCase()
            : 'JOVEM';

        final multiplier = themeService.fontSizeMultiplier;

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openDestaque(context, verseText, ref),
            child: RepaintBoundary(
              key: _cardKey,
              child: Container(
                height: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isGlass
                        ? Colors.white.withValues(alpha: 0.28)
                        : Colors.white.withValues(alpha: 0.15),
                    width: widget.isGlass ? 1.2 : 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Imagem de fundo cobrindo o card
                      Image.network(
                        wallpaperUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1B2A47), Color(0xFF111827)],
                            ),
                          ),
                        ),
                      ),

                      // 2. Gradiente escuro sobreposto para garantir legibilidade dos textos
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.40),
                              Colors.black.withValues(alpha: 0.88),
                            ],
                          ),
                        ),
                      ),

                      // 3. Conteúdo Editorial Centralizado
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                        child: Column(
                          children: [
                            // Cabeçalho: Tag + Versículo do Dia + Categoria + Botão de Download/Exportação
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFFFFD54F), // Âmbar luminoso
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'VERSÍCULO DO DIA',
                                  style: TextStyle(
                                    color: Color(0xFFFFD54F),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.50),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    category,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                                  tooltip: 'Exportar card',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: () => _exportCard(verseText, ref),
                                ),
                              ],
                            ),

                            const Spacer(),

                            // Centro: Texto do Versículo em HymnSerif (Centralizado e em Itálico)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                '“${verseText.replaceAll(RegExp(r"""^[“"«'\s]+|[”"»'\s]+$"""), '').trim()}”',
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.5 * multiplier,
                                  fontFamily: 'HymnSerif',
                                  fontStyle: FontStyle.italic,
                                  height: 1.45,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 8,
                                      offset: Offset(0, 1.5),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Referência Bíblica (Centralizada, Negrito)
                            Text(
                              ref,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),

                            const Spacer(),

                            // Rodapé: Toque para ler a meditação completa >
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Toque para ler a meditação completa',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      ),
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
}
