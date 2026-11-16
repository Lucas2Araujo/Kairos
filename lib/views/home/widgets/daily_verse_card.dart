import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../controllers/bible_controller.dart';
import '../../../controllers/devotional_controller.dart';
import '../../../core/utils/system_share_download.dart';
import '../../../core/utils/verse_card_renderer.dart';
import '../../../services/solar_service.dart';
import '../../../services/theme_service.dart';
import '../../../services/wallpaper_service.dart';
import '../../devotional/meditacao_destaque_view.dart';
import '../../devotional/pordosol_view.dart';
import '../../lesson/widgets/cached_ss_tirinha_image.dart';

/// Card editorial do Versículo do Dia (estilo YouVersion / AndBible)
/// com wallpaper curado de natureza, gradiente sobreposto escuro para legibilidade perfeita,
/// download limpo sem botões de UI e abertura da visualização imersiva MeditacaoDestaqueView.
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

  Future<void> _exportCard({
    required String verseText,
    required String ref,
    required String category,
    required String wallpaperUrl,
    required bool isSunsetTime,
  }) async {
    try {
      Uint8List? bytes = await VerseCardRenderer.renderCardPng(
        verseText: verseText,
        verseReference: ref,
        category: category,
        isSunset: isSunsetTime,
        wallpaperUrl: wallpaperUrl,
      );

      if (bytes == null) {
        var boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          if (boundary.debugNeedsPaint) {
            await WidgetsBinding.instance.endOfFrame;
            boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          }
          if (boundary != null) {
            final image = await boundary.toImage(pixelRatio: 2.0);
            final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
            bytes = byteData?.buffer.asUint8List();
          }
        }
      }

      if (bytes == null) return;

      await SystemShareDownload.saveBytes(
        bytes: bytes,
        fileName: 'versiculo_kairos_${DateTime.now().millisecondsSinceEpoch}.png',
        mimeType: 'image/png',
      );

      Clipboard.setData(
        ClipboardData(text: '“$verseText” — $ref\n(Compartilhado via Kairós)'),
      );

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
    final now = DateTime.now();

    final isFriday = now.weekday == DateTime.friday;
    bool isSunsetTime = false;
    if (isFriday) {
      final sunset = SolarService.getFridaySunset(referenceDate: now);
      final diffMinutes = sunset.difference(now).inMinutes;
      if (diffMinutes <= 180 &&
          now.isBefore(DateTime(now.year, now.month, now.day, 23, 59))) {
        isSunsetTime = true;
      }
    }

    return ListenableBuilder(
      listenable: widget.devotionalController,
      builder: (context, _) {
        final devo = widget.devotionalController.currentDevotional;
        final rawVerse = devo?.verseText.trim();
        final defaultVerse = (rawVerse != null && rawVerse.isNotEmpty)
            ? rawVerse
            : 'Porque nenhum de nós vive para si mesmo, nem morre para si';

        final verseText = isSunsetTime
            ? 'Lembra-te do dia do sábado, para o santificar. Seis dias trabalharás, e farás toda a tua obra, mas o sétimo dia é o sábado do Senhor teu Deus.'
            : defaultVerse;

        final rawRef = devo?.verseReference.trim();
        final defaultRef = (rawRef != null && rawRef.isNotEmpty) ? rawRef : 'Romanos 14:7';
        final ref = isSunsetTime ? 'Êxodo 20:8-10' : defaultRef;

        final rawCategory = (devo?.category != null && devo!.category.trim().isNotEmpty)
            ? devo.category.trim().toUpperCase()
            : 'JOVEM';
        final category = isSunsetTime ? 'PÔR DO SOL' : rawCategory;

        final multiplier = themeService.fontSizeMultiplier;
        final cleanVerse =
            '“${verseText.replaceAll(RegExp(r"""^[“"«'\s]+|[”"»'\s]+$"""), '').trim()}”';

        if (themeService.isWin95) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final frameBg = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFC0C0C0);
          final textColor = isDark ? const Color(0xFFF2F2F2) : const Color(0xFF000000);
          final mutedColor = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF404040);

          return RepaintBoundary(
            key: _cardKey,
            child: Win95BevelBox(
              padding: const EdgeInsets.all(3),
              color: frameBg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF000080), Color(0xFF1084D0)],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Win95PixelIcon(type: Win95PixelIconType.notepad, size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            isSunsetTime
                                ? 'POR_DO_SOL.TXT - Bloco de Notas'
                                : 'LEITURA_DIARIA.TXT - Bloco de Notas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '[_][□][X]',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      'Arquivo   Editar   Pesquisar   Ajuda',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 11),
                    ),
                  ),
                  Win95SunkenField(
                    padding: const EdgeInsets.all(12),
                    onTap: () {
                      if (isSunsetTime) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PorDoSolView(
                              devotionalController: widget.devotionalController,
                            ),
                          ),
                        );
                      } else {
                        _openDestaque(context, verseText, ref);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isSunsetTime
                              ? '+--- HORAS SAGRADAS • PÔR DO SOL ---+'
                              : '+--- VERSÍCULO DO DIA ---+',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF000080),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          cleanVerse,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14.5 * multiplier,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '-- [ $ref ] --',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isSunsetTime
                                    ? '> Abrir recepção do Sábado'
                                    : '> Ler meditação completa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: mutedColor, fontSize: 11),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Win95BevelBox(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              onTap: () => _exportCard(
                                verseText: verseText,
                                ref: ref,
                                category: category,
                                wallpaperUrl: wallpaperUrl,
                                isSunsetTime: isSunsetTime,
                              ),
                              child: Text(
                                'Salvar .PNG',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (themeService.isHoloRetro) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bgColor = isDark ? const Color(0xFF101824) : const Color(0xFFFFFFFF);
          final textColor = isDark ? const Color(0xFFF3F3F3) : const Color(0xFF1A1A1A);
          final subColor = isDark ? const Color(0xFFBBBBBB) : const Color(0xFF4D4D4D);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isSunsetTime) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PorDoSolView(
                        devotionalController: widget.devotionalController,
                      ),
                    ),
                  );
                } else {
                  _openDestaque(context, verseText, ref);
                }
              },
              child: RepaintBoundary(
                key: _cardKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: const Border(
                      top: BorderSide(color: Color(0xFF33B5E5), width: 1.2),
                      left: BorderSide(color: Color(0xFF33B5E5), width: 1.2),
                      right: BorderSide(color: Color(0xFF33B5E5), width: 1.2),
                      bottom: BorderSide(color: Color(0xFF33B5E5), width: 4.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF162130) : const Color(0xFFEAEAEA),
                          border: const Border(
                            bottom: BorderSide(color: Color(0xFF33B5E5), width: 1.5),
                          ),
                        ),
                        child: CustomPaint(
                          painter: HoloCarbonPinstripePainter(isDark: isDark),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.bolt_sharp,
                                  color: Color(0xFF33B5E5),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isSunsetTime
                                        ? 'HORAS SAGRADAS • PÔR DO SOL'
                                        : 'VERSÍCULO DO DIA',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF33B5E5),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.9,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.download_sharp,
                                    color: textColor,
                                    size: 19,
                                  ),
                                  tooltip: 'Exportar card',
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
                                  onPressed: () => _exportCard(
                                    verseText: verseText,
                                    ref: ref,
                                    category: category,
                                    wallpaperUrl: wallpaperUrl,
                                    isSunsetTime: isSunsetTime,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanVerse,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 15.5 * multiplier,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ref.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF33B5E5),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ),
                                Text(
                                  'LER MEDITAÇÃO',
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_sharp, color: subColor, size: 16),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (isSunsetTime) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PorDoSolView(
                      devotionalController: widget.devotionalController,
                    ),
                  ),
                );
              } else {
                _openDestaque(context, verseText, ref);
              }
            },
            child: RepaintBoundary(
              key: _cardKey,
              child: Container(
                constraints: const BoxConstraints(minHeight: 240),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: themeService.isOledVivid
                        ? themeService.currentColor.withValues(alpha: 0.55)
                        : widget.isGlass
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.15),
                    width: (widget.isGlass || themeService.isOledVivid) ? 1.2 : 0.8,
                  ),
                  boxShadow: themeService.isZen
                      ? const []
                      : [
                          BoxShadow(
                            color: themeService.isOledVivid
                                ? themeService.currentColor.withValues(alpha: 0.16)
                                : Colors.black.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      if (isSunsetTime)
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFF57C00),
                                  Color(0xFF880E4F),
                                  Color(0xFF1A237E),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned.fill(
                          child: CachedSSTirinhaImage(
                            imageUrl: wallpaperUrl,
                            fit: BoxFit.cover,
                            showLoadingIndicator: false,
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
                        ),

                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: isSunsetTime ? 0.35 : 0.40),
                                Colors.black.withValues(alpha: isSunsetTime ? 0.78 : 0.88),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isSunsetTime ? Icons.wb_twilight_rounded : Icons.auto_awesome,
                                  color: const Color(0xFFFFD54F),
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isSunsetTime
                                        ? 'HORAS SAGRADAS • PÔR DO SOL'
                                        : 'VERSÍCULO DO DIA',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  tooltip: 'Exportar card',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                                  onPressed: () => _exportCard(
                                    verseText: verseText,
                                    ref: ref,
                                    category: category,
                                    wallpaperUrl: wallpaperUrl,
                                    isSunsetTime: isSunsetTime,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                '“${verseText.replaceAll(RegExp(r"""^[“"«'\s]+|[”"»'\s]+$"""), '').trim()}”',
                                textAlign: TextAlign.center,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0 * multiplier,
                                  fontFamily: 'AppSans',
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

                            const SizedBox(height: 14),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    isSunsetTime
                                        ? 'Toque para abrir a recepção do Sábado'
                                        : 'Toque para ler a meditação completa',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  size: 16,
                                ),
                              ],
                            ),
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
