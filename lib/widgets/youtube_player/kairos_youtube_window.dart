import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/youtube_url_parser.dart';
import '../../services/theme_service.dart';
import 'kairos_youtube_embed.dart';

/// Janela flutuante / modal temática de reprodução de vídeos do YouTube dentro do Kairós.
///
/// Suporta dois modos alternáveis sem recarregar o player:
/// - **Teatro (Modal Centralizado)**: foco 16:9 no vídeo com barreira escurecida clicável.
/// - **Mini-Janela Flutuante (PiP)**: player compacto e arrastável para acompanhar
///   a letra do hino ou a meditação diária simultaneamente.
class KairosYoutubeWindow {
  KairosYoutubeWindow._();

  static OverlayEntry? _activeEntry;

  /// Indica se existe uma janela de vídeo aberta neste momento.
  static bool get isOpen => _activeEntry != null;

  /// Fecha imediatamente a janela ativa do YouTube caso esteja aberta.
  static void close() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  /// Abre o vídeo do YouTube dentro do aplicativo, ou faz fallback para abertura externa
  /// caso a URL informada não seja de vídeo reconhecido do YouTube.
  static void show(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    final videoId = YoutubeUrlParser.extractVideoId(url);
    if (videoId == null) {
      final uri = Uri.tryParse(url.trim());
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    close();

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _KairosYoutubeOverlay(
        videoId: videoId,
        originalUrl: url.trim(),
        title: (title != null && title.trim().isNotEmpty)
            ? title.trim()
            : 'Vídeo do YouTube',
        onClose: close,
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }
}

class _KairosYoutubeOverlay extends StatefulWidget {
  final String videoId;
  final String originalUrl;
  final String title;
  final VoidCallback onClose;

  const _KairosYoutubeOverlay({
    required this.videoId,
    required this.originalUrl,
    required this.title,
    required this.onClose,
  });

  @override
  State<_KairosYoutubeOverlay> createState() => _KairosYoutubeOverlayState();
}

class _KairosYoutubeOverlayState extends State<_KairosYoutubeOverlay> {
  final GlobalKey _embedKey = GlobalKey();
  bool _isPip = false;
  Offset _pipRightBottomOffset = const Offset(16, 86);

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.originalUrl) ??
        Uri.parse(YoutubeUrlParser.buildWatchUrl(widget.videoId));
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[KairosYoutubeWindow] Erro ao abrir externamente: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenSize = mq.size;
    final padding = mq.padding;
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final pipWidth = screenSize.width >= 520 ? 320.0 : 256.0;
        final theaterWidth = math.min(screenSize.width - 28.0, 760.0);

        final maxRight = math.max(8.0, screenSize.width - pipWidth - 8.0);
        final maxBottom = math.max(16.0, screenSize.height - (pipWidth * 9 / 16 + 56) - padding.top);
        final clampedOffset = Offset(
          _pipRightBottomOffset.dx.clamp(8.0, maxRight),
          _pipRightBottomOffset.dy.clamp(padding.bottom + 8.0, maxBottom),
        );

        final embedWidget = AspectRatio(
          aspectRatio: 16 / 9,
          child: KairosYoutubeEmbed(
            key: _embedKey,
            videoId: widget.videoId,
            title: widget.title,
          ),
        );

        final windowCard = _buildThemedWindowFrame(
          context,
          themeService: themeService,
          embedWidget: embedWidget,
          onDragUpdate: _isPip
              ? (details) {
                  setState(() {
                    _pipRightBottomOffset = Offset(
                      (_pipRightBottomOffset.dx - details.delta.dx).clamp(8.0, maxRight),
                      (_pipRightBottomOffset.dy - details.delta.dy)
                          .clamp(padding.bottom + 8.0, maxBottom),
                    );
                  });
                }
              : null,
        );

        if (_isPip) {
          return Stack(
            children: [
              Positioned(
                right: clampedOffset.dx,
                bottom: clampedOffset.dy,
                width: pipWidth,
                child: Material(
                  type: MaterialType.transparency,
                  elevation: 14,
                  child: windowCard,
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onClose,
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: theaterWidth,
                      maxHeight: screenSize.height - 40,
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: SingleChildScrollView(
                        child: windowCard,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemedWindowFrame(
    BuildContext context, {
    required ThemeService themeService,
    required Widget embedWidget,
    ValueChanged<DragUpdateDetails>? onDragUpdate,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (themeService.isWin95) {
      final surface = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFC0C0C0);
      final titleBar = GestureDetector(
        onPanUpdate: onDragUpdate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000080), Color(0xFF1084D0)],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_arrow_sharp, size: 15, color: Colors.white),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              _Win95TitleBtn(
                key: const Key('yt_window_pip_toggle'),
                label: _isPip ? '□' : '_',
                tooltip: _isPip ? 'Expandir janela' : 'Mini-janela flutuante',
                onTap: () => setState(() => _isPip = !_isPip),
              ),
              const SizedBox(width: 3),
              _Win95TitleBtn(
                key: const Key('yt_window_open_external'),
                label: '↗',
                tooltip: 'Abrir no YouTube',
                onTap: _openExternal,
              ),
              const SizedBox(width: 3),
              _Win95TitleBtn(
                key: const Key('yt_window_close'),
                label: 'X',
                tooltip: 'Fechar',
                onTap: widget.onClose,
              ),
            ],
          ),
        ),
      );

      return Win95BevelBox(
        color: surface,
        padding: const EdgeInsets.all(3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleBar,
            const SizedBox(height: 3),
            embedWidget,
          ],
        ),
      );
    }

    if (themeService.isAscii) {
      return AsciiBoxSurface(
        doubleBorder: true,
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onPanUpdate: onDragUpdate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.14),
                  border: Border(
                    bottom: BorderSide(color: cs.primary, width: 2.0),
                  ),
                ),
                child: Row(
                  children: [
                    SnesPixelIcon(
                      type: SnesPixelIconType.bolt,
                      size: 15,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'RetroPixel',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    _AsciiTitleBtn(
                      key: const Key('yt_window_pip_toggle'),
                      label: _isPip ? '[+]' : '[PIP]',
                      tooltip: _isPip ? 'Expandir janela' : 'Mini-janela flutuante',
                      onTap: () => setState(() => _isPip = !_isPip),
                    ),
                    const SizedBox(width: 4),
                    _AsciiTitleBtn(
                      key: const Key('yt_window_open_external'),
                      label: _isPip ? '[↗]' : '[EXT]',
                      tooltip: 'Abrir no YouTube',
                      onTap: _openExternal,
                    ),
                    const SizedBox(width: 4),
                    _AsciiTitleBtn(
                      key: const Key('yt_window_close'),
                      label: '[X]',
                      tooltip: 'Fechar',
                      filled: true,
                      onTap: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            embedWidget,
          ],
        ),
      );
    }

    final isHolo = themeService.isHoloRetro;
    final header = GestureDetector(
      onPanUpdate: onDragUpdate,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _isPip ? 8 : 12,
          vertical: _isPip ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: isHolo
              ? (isDark ? const Color(0xFF162130) : const Color(0xFFEAEAEA))
              : cs.surfaceContainerHigh.withValues(alpha: themeService.isAnyGlass ? 0.55 : 1.0),
          border: isHolo
              ? const Border(bottom: BorderSide(color: Color(0xFF33B5E5), width: 1.5))
              : Border(
                  bottom: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.smart_display_rounded,
              size: 18,
              color: isHolo ? const Color(0xFF33B5E5) : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: _isPip ? 11.5 : 13,
                  color: cs.onSurface,
                ),
              ),
            ),
            IconButton(
              key: const Key('yt_window_pip_toggle'),
              icon: Icon(
                _isPip ? Icons.open_in_full_rounded : Icons.picture_in_picture_alt_rounded,
                size: 18,
              ),
              tooltip: _isPip ? 'Expandir player' : 'Minimizar para mini-janela (PiP)',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _isPip = !_isPip),
            ),
            IconButton(
              key: const Key('yt_window_open_external'),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              tooltip: 'Abrir no YouTube',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: _openExternal,
            ),
            IconButton(
              key: const Key('yt_window_close'),
              icon: Icon(isHolo ? Icons.close_sharp : Icons.close_rounded, size: 18),
              tooltip: 'Fechar player',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );

    final innerContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        embedWidget,
      ],
    );

    if (themeService.isAnyGlass) {
      return GlassSurface(
        borderRadius: _isPip ? 16 : 20,
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isPip ? 16 : 20),
          child: innerContent,
        ),
      );
    }

    if (isHolo) {
      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111111) : Colors.white,
          border: Border.all(color: const Color(0xFF33B5E5), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF33B5E5).withValues(alpha: 0.25),
              blurRadius: 16,
            ),
          ],
        ),
        child: innerContent,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(_isPip ? 14 : 18),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: innerContent,
    );
  }
}

class _Win95TitleBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  const _Win95TitleBtn({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Win95BevelBox(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 10.5,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AsciiTitleBtn extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool filled;
  final VoidCallback onTap;

  const _AsciiTitleBtn({
    super.key,
    required this.label,
    required this.tooltip,
    this.filled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: filled ? cs.primary : Colors.transparent,
            border: Border.all(color: cs.primary, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'RetroPixel',
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: filled ? cs.onPrimary : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
