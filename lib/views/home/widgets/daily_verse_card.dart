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
  final bool isDesktopExpanded;

  const DailyVerseCard({
    super.key,
    required this.bibleController,
    required this.onNavigateToTab,
    required this.devotionalController,
    required this.isGlass,
    this.isDesktopExpanded = false,
  });

  @override
  State<DailyVerseCard> createState() => _DailyVerseCardState();
}

class _DailyVerseCardState extends State<DailyVerseCard> {
  final GlobalKey _cardKey = GlobalKey();

  void _openPrimary(
    BuildContext context, {
    required bool isSunsetTime,
    required String verseText,
    required String ref,
  }) {
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
  }

  static String? _extractDevoExcerpt(String? rawContent) {
    if (rawContent == null || rawContent.trim().isEmpty) return null;
    final cleaned = rawContent
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? null : cleaned;
  }

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
        final devoTitle = devo?.title.trim() ?? '';
        final devoExcerpt = _extractDevoExcerpt(devo?.content);
        final expanded = widget.isDesktopExpanded;

        if (themeService.isWin95 && themeService.useSlimDailyVerseCard) {
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
                          '[X]',
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
                    padding: EdgeInsets.all(expanded ? 16 : 12),
                    onTap: () => _openPrimary(
                      context,
                      isSunsetTime: isSunsetTime,
                      verseText: verseText,
                      ref: ref,
                    ),
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
                          maxLines: expanded ? 7 : 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: (expanded ? 16.0 : 14.5) * multiplier,
                            height: 1.45,
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
                        if (expanded && (devoTitle.isNotEmpty || devoExcerpt != null)) ...[
                          const SizedBox(height: 12),
                          Divider(height: 1, color: mutedColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 10),
                          if (devoTitle.isNotEmpty)
                            Text(
                              devoTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF000080),
                                fontWeight: FontWeight.bold,
                                fontSize: 13 * multiplier,
                              ),
                            ),
                          if (devoExcerpt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              devoExcerpt,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 12 * multiplier,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Win95BevelBox(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              onTap: () => _openPrimary(
                                context,
                                isSunsetTime: isSunsetTime,
                                verseText: verseText,
                                ref: ref,
                              ),
                              child: Text(
                                isSunsetTime ? 'Recepção do Sábado' : 'Ler Meditação',
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (expanded)
                              Win95BevelBox(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                onTap: () => widget.onNavigateToTab(1),
                                child: Text(
                                  'Abrir na Bíblia',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            Win95BevelBox(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                                  fontSize: 11.5,
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

        if (themeService.isAscii && themeService.useSlimDailyVerseCard) {
          final cs = Theme.of(context).colorScheme;
          return RepaintBoundary(
            key: _cardKey,
            child: AsciiBoxSurface(
              label: isSunsetTime ? 'HORAS SAGRADAS - POR DO SOL' : 'VERSICULO DO DIA',
              doubleBorder: true,
              padding: EdgeInsets.all(expanded ? 18 : 14),
              onTap: () => _openPrimary(
                context,
                isSunsetTime: isSunsetTime,
                verseText: verseText,
                ref: ref,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SnesPixelIcon(
                        type: isSunsetTime ? SnesPixelIconType.sun : SnesPixelIconType.bible,
                        size: 22,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          cleanVerse,
                          maxLines: expanded ? 7 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'RetroPixel',
                            color: cs.onSurface,
                            fontSize: (expanded ? 15.0 : 13.5) * multiplier,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '-- [ $ref ] --',
                    style: TextStyle(
                      fontFamily: 'RetroPixel',
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5 * multiplier,
                    ),
                  ),
                  if (expanded && (devoTitle.isNotEmpty || devoExcerpt != null)) ...[
                    const SizedBox(height: 12),
                    Text(
                      '----------------------------------------',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: 'RetroPixel',
                        color: cs.primary.withValues(alpha: 0.65),
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (devoTitle.isNotEmpty)
                      Text(
                        '> ${devoTitle.toUpperCase()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'RetroPixel',
                          color: cs.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12 * multiplier,
                        ),
                      ),
                    if (devoExcerpt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        devoExcerpt,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'RetroPixel',
                          color: cs.onSurfaceVariant,
                          fontSize: 11 * multiplier,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AsciiBoxSurface(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onTap: () => _openPrimary(
                          context,
                          isSunsetTime: isSunsetTime,
                          verseText: verseText,
                          ref: ref,
                        ),
                        child: Text(
                          isSunsetTime ? '[ POR DO SOL > ]' : '[ LER MEDITACAO > ]',
                          style: TextStyle(
                            fontFamily: 'RetroPixel',
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (expanded)
                        AsciiBoxSurface(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          onTap: () => widget.onNavigateToTab(1),
                          child: Text(
                            '[ ABRIR BIBLIA ]',
                            style: TextStyle(
                              fontFamily: 'RetroPixel',
                              color: cs.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      AsciiBoxSurface(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        onTap: () => _exportCard(
                          verseText: verseText,
                          ref: ref,
                          category: category,
                          wallpaperUrl: wallpaperUrl,
                          isSunsetTime: isSunsetTime,
                        ),
                        child: Text(
                          '[ .PNG ]',
                          style: TextStyle(
                            fontFamily: 'RetroPixel',
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        if (themeService.isHoloRetro && themeService.useSlimDailyVerseCard) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final bgColor = isDark ? const Color(0xFF101824) : const Color(0xFFFFFFFF);
          final textColor = isDark ? const Color(0xFFF3F3F3) : const Color(0xFF1A1A1A);
          final subColor = isDark ? const Color(0xFFBBBBBB) : const Color(0xFF4D4D4D);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openPrimary(
                context,
                isSunsetTime: isSunsetTime,
                verseText: verseText,
                ref: ref,
              ),
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
                        padding: EdgeInsets.fromLTRB(
                          16,
                          expanded ? 20 : 16,
                          16,
                          expanded ? 18 : 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanVerse,
                              maxLines: expanded ? 7 : 5,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textColor,
                                fontSize: (expanded ? 17.0 : 15.5) * multiplier,
                                height: 1.48,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
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
                            if (expanded && (devoTitle.isNotEmpty || devoExcerpt != null)) ...[
                              const SizedBox(height: 14),
                              const Divider(height: 1, color: Color(0xFF33B5E5)),
                              const SizedBox(height: 12),
                              if (devoTitle.isNotEmpty)
                                Text(
                                  devoTitle.toUpperCase(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5 * multiplier,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              if (devoExcerpt != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  devoExcerpt,
                                  maxLines: 5,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: subColor,
                                    fontSize: 12.5 * multiplier,
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openPrimary(
                                    context,
                                    isSunsetTime: isSunsetTime,
                                    verseText: verseText,
                                    ref: ref,
                                  ),
                                  icon: const Icon(Icons.menu_book_sharp, size: 16),
                                  label: Text(isSunsetTime ? 'RECEPÇÃO DO SÁBADO' : 'LER MEDITAÇÃO'),
                                ),
                                if (expanded)
                                  OutlinedButton.icon(
                                    onPressed: () => widget.onNavigateToTab(1),
                                    icon: const Icon(Icons.auto_stories_sharp, size: 16),
                                    label: const Text('ABRIR NA BÍBLIA'),
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
          );
        }

        if (themeService.useSlimDailyVerseCard) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          return RepaintBoundary(
            key: _cardKey,
            child: GlassSurface(
              borderRadius: themeService.isZen ? 14 : 18,
              padding: EdgeInsets.fromLTRB(
                18,
                expanded ? 20 : 14,
                14,
                expanded ? 18 : 14,
              ),
              onTap: () => _openPrimary(
                context,
                isSunsetTime: isSunsetTime,
                verseText: verseText,
                ref: ref,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSunsetTime ? Icons.wb_twilight_rounded : Icons.auto_awesome,
                        color: cs.primary,
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
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.download_rounded,
                          color: cs.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: 'Exportar card',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
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
                  const SizedBox(height: 10),
                  Text(
                    cleanVerse,
                    maxLines: expanded ? 7 : 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontFamily: themeService.isClassicBook ? 'HymnSerif' : null,
                      fontStyle: FontStyle.italic,
                      fontSize: (expanded ? 18.0 : 15.5) * multiplier,
                      height: 1.5,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ref,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5 * multiplier,
                          ),
                        ),
                      ),
                      if (!expanded) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isSunsetTime ? 'Sábado' : 'Ler meditação',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  if (expanded) ...[
                    if (devoTitle.isNotEmpty || devoExcerpt != null) ...[
                      const SizedBox(height: 14),
                      Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.45)),
                      const SizedBox(height: 12),
                      if (devoTitle.isNotEmpty)
                        Text(
                          devoTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                      if (devoExcerpt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          devoExcerpt,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 13 * multiplier,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () => _openPrimary(
                            context,
                            isSunsetTime: isSunsetTime,
                            verseText: verseText,
                            ref: ref,
                          ),
                          icon: Icon(
                            isSunsetTime ? Icons.wb_twilight_rounded : Icons.volunteer_activism_outlined,
                            size: 18,
                          ),
                          label: Text(isSunsetTime ? 'Recepção do Sábado' : 'Ler Meditação'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => widget.onNavigateToTab(1),
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: const Text('Abrir na Bíblia'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openPrimary(
              context,
              isSunsetTime: isSunsetTime,
              verseText: verseText,
              ref: ref,
            ),
            child: RepaintBoundary(
              key: _cardKey,
              child: Container(
                constraints: BoxConstraints(minHeight: expanded ? 390 : 220),
                decoration: BoxDecoration(
                  borderRadius: themeService.isAscii || themeService.isWin95
                      ? BorderRadius.zero
                      : BorderRadius.circular(16),
                  border: Border.all(
                    color: themeService.isAscii
                        ? Theme.of(context).colorScheme.primary
                        : widget.isGlass
                            ? Colors.white.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.15),
                    width: (widget.isGlass || themeService.isAscii) ? 1.3 : 0.8,
                  ),
                  boxShadow: (themeService.isZen || themeService.isAscii)
                      ? const []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.22),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ClipRRect(
                  borderRadius: themeService.isAscii || themeService.isWin95
                      ? BorderRadius.zero
                      : BorderRadius.circular(15),
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
                                Colors.black.withValues(alpha: isSunsetTime ? 0.35 : 0.42),
                                Colors.black.withValues(alpha: isSunsetTime ? 0.82 : 0.90),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? 22.0 : 18.0,
                          vertical: expanded ? 20.0 : 14.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: expanded
                              ? CrossAxisAlignment.stretch
                              : CrossAxisAlignment.center,
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

                            SizedBox(height: expanded ? 20 : 14),

                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0),
                              child: Text(
                                cleanVerse,
                                textAlign: expanded ? TextAlign.left : TextAlign.center,
                                maxLines: expanded ? 6 : 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: (expanded ? 19.0 : 16.0) * multiplier,
                                  fontFamily: 'AppSans',
                                  fontStyle: FontStyle.italic,
                                  height: 1.48,
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
                              textAlign: expanded ? TextAlign.left : TextAlign.center,
                              style: TextStyle(
                                color: const Color(0xFFFFD54F),
                                fontWeight: FontWeight.bold,
                                fontSize: (expanded ? 14.5 : 13.5) * multiplier,
                                letterSpacing: 0.4,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),

                            if (expanded && (devoTitle.isNotEmpty || devoExcerpt != null)) ...[
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.36),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (devoTitle.isNotEmpty) ...[
                                      Text(
                                        devoTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5 * multiplier,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                    ],
                                    if (devoExcerpt != null)
                                      Text(
                                        devoExcerpt,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.88),
                                          fontSize: 12.5 * multiplier,
                                          height: 1.45,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            SizedBox(height: expanded ? 18 : 14),

                            if (expanded)
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _openPrimary(
                                      context,
                                      isSunsetTime: isSunsetTime,
                                      verseText: verseText,
                                      ref: ref,
                                    ),
                                    icon: Icon(
                                      isSunsetTime
                                          ? Icons.wb_twilight_rounded
                                          : Icons.volunteer_activism_outlined,
                                      size: 18,
                                    ),
                                    label: Text(
                                      isSunsetTime ? 'Recepção do Sábado' : 'Ler Meditação',
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.45),
                                      ),
                                    ),
                                    onPressed: () => widget.onNavigateToTab(1),
                                    icon: const Icon(Icons.menu_book_rounded, size: 18),
                                    label: const Text('Abrir na Bíblia'),
                                  ),
                                ],
                              )
                            else
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
