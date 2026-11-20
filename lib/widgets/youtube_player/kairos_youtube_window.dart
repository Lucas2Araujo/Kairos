import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/in_app_link_launcher.dart';
import '../../core/utils/youtube_url_parser.dart';
import '../../services/theme_service.dart';
import 'kairos_youtube_controller.dart';
import 'kairos_youtube_embed.dart';

/// Janela flutuante / modal temática de reprodução de vídeos do YouTube dentro do Kairós.
///
/// Suporta três modos alternáveis sem recarregar o player:
/// - **Teatro (Modal Centralizado)**: foco 16:9 no vídeo com barreira escurecida clicável.
/// - **Tela Cheia**: ocupa 100% da tela com controles ergonômicos no topo.
/// - **Mini-Janela Flutuante (PiP)**: player compacto e arrastável.
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

  /// Abre o vídeo do YouTube dentro do aplicativo, ou faz fallback para abertura in-app
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
        InAppLinkLauncher.openUri(uri);
      }
      return;
    }

    close();

    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _KairosYoutubeOverlay(
        videoId: videoId,
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
  final String title;
  final VoidCallback onClose;

  const _KairosYoutubeOverlay({
    required this.videoId,
    required this.title,
    required this.onClose,
  });

  @override
  State<_KairosYoutubeOverlay> createState() => _KairosYoutubeOverlayState();
}

class _KairosYoutubeOverlayState extends State<_KairosYoutubeOverlay> {
  final GlobalKey _embedKey = GlobalKey();
  final KairosYoutubeController _playerController = KairosYoutubeController();

  bool _isPip = false;
  bool _isFullscreen = false;
  bool _floatingBarVisible = true;
  Timer? _autoHideTimer;
  Offset _pipRightBottomOffset = const Offset(16, 86);

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _scheduleFloatingBarAutoHide();
  }

  void _scheduleFloatingBarAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (ThemeService().videoProgressBarMode == VideoProgressBarMode.floatingAutoHide) {
        setState(() => _floatingBarVisible = false);
      }
    });
  }

  void _revealFloatingBar() {
    if (!_floatingBarVisible) {
      setState(() => _floatingBarVisible = true);
    }
    _scheduleFloatingBarAutoHide();
  }

  void _applySystemUiForFullscreen(bool fullscreen) {
    if (!_isMobilePlatform) return;
    try {
      SystemChrome.setEnabledSystemUIMode(
        fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    } catch (_) {}
  }

  void _resumeAfterLayoutTransition(bool wasPlaying) {
    if (!wasPlaying) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playerController.play();
      Future<void>.delayed(const Duration(milliseconds: 280), () {
        if (!mounted) return;
        if (!_playerController.isPlaying) {
          _playerController.play();
        }
      });
    });
  }

  void _toggleFullscreen() {
    final wasPlaying = _playerController.isPlaying;
    final next = !_isFullscreen;
    setState(() {
      _isFullscreen = next;
      if (next) _isPip = false;
    });
    _applySystemUiForFullscreen(next);
    _revealFloatingBar();
    _resumeAfterLayoutTransition(wasPlaying);
  }

  void _togglePip() {
    final wasPlaying = _playerController.isPlaying;
    final next = !_isPip;
    if (next && _isFullscreen) {
      _applySystemUiForFullscreen(false);
    }
    setState(() {
      _isPip = next;
      if (next) _isFullscreen = false;
    });
    _resumeAfterLayoutTransition(wasPlaying);
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    if (_isFullscreen) {
      _applySystemUiForFullscreen(false);
    }
    _playerController.dispose();
    super.dispose();
  }

  Widget _buildVideoWithProgress({
    required Widget videoChild,
    required VideoProgressBarMode barMode,
    required bool showProgressBar,
    required bool darkSurface,
  }) {
    if (!showProgressBar) return videoChild;

    final progressBar = _KairosVideoProgressBar(
      controller: _playerController,
      darkSurface: darkSurface,
      onUserInteract: _revealFloatingBar,
    );

    if (barMode == VideoProgressBarMode.floatingAutoHide) {
      return Stack(
        fit: StackFit.expand,
        children: [
          videoChild,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _revealFloatingBar,
              child: AnimatedOpacity(
                opacity: _floatingBarVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_floatingBarVisible,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xD9000000)],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                    child: progressBar,
                  ),
                ),
              ),
            ),
          ),
          if (!_floatingBarVisible)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 44,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _revealFloatingBar,
                child: const SizedBox.expand(),
              ),
            ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: videoChild),
        progressBar,
      ],
    );
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
        final barMode = themeService.videoProgressBarMode;
        final compactHeader = screenSize.width < 430;

        final maxRight = math.max(8.0, screenSize.width - pipWidth - 8.0);
        final maxBottom = math.max(
          16.0,
          screenSize.height - (pipWidth * 9 / 16 + 64) - padding.top,
        );
        final clampedOffset = Offset(
          _pipRightBottomOffset.dx.clamp(8.0, maxRight),
          _pipRightBottomOffset.dy.clamp(padding.bottom + 8.0, maxBottom),
        );

        final rawEmbed = KairosYoutubeEmbed(
          key: _embedKey,
          videoId: widget.videoId,
          title: widget.title,
          controller: _playerController,
        );

        if (_isFullscreen) {
          return Positioned.fill(
            child: Material(
              color: Colors.black,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: const Color(0xFF11151F),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.smart_display_rounded,
                            size: 20,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _HeaderPillButton(
                            key: const Key('yt_window_fullscreen_toggle'),
                            icon: Icons.fullscreen_exit_rounded,
                            label: compactHeader ? null : 'Reduzir',
                            tooltip: 'Sair da tela cheia',
                            darkSurface: true,
                            onTap: _toggleFullscreen,
                          ),
                          const SizedBox(width: 8),
                          _HeaderPillButton(
                            key: const Key('yt_window_pip_toggle'),
                            icon: Icons.picture_in_picture_alt_rounded,
                            label: compactHeader ? null : 'PiP',
                            tooltip: 'Mini-janela flutuante',
                            darkSurface: true,
                            onTap: _togglePip,
                          ),
                          const SizedBox(width: 8),
                          _HeaderPillButton(
                            key: const Key('yt_window_close'),
                            icon: Icons.close_rounded,
                            label: compactHeader ? null : 'Fechar',
                            tooltip: 'Fechar player',
                            darkSurface: true,
                            isDestructive: true,
                            onTap: widget.onClose,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _buildVideoWithProgress(
                        videoChild: rawEmbed,
                        barMode: barMode,
                        showProgressBar: true,
                        darkSurface: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final videoArea = AspectRatio(
          aspectRatio: 16 / 9,
          child: barMode == VideoProgressBarMode.floatingAutoHide && !_isPip
              ? _buildVideoWithProgress(
                  videoChild: rawEmbed,
                  barMode: barMode,
                  showProgressBar: true,
                  darkSurface: true,
                )
              : rawEmbed,
        );

        final fixedProgressBar =
            !_isPip && barMode == VideoProgressBarMode.fixedBelow
                ? _KairosVideoProgressBar(
                    controller: _playerController,
                    darkSurface: Theme.of(context).brightness == Brightness.dark,
                    onUserInteract: _revealFloatingBar,
                  )
                : null;

        final windowCard = _buildThemedWindowFrame(
          context,
          themeService: themeService,
          embedWidget: videoArea,
          fixedProgressBar: fixedProgressBar,
          compactHeader: compactHeader,
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
    required Widget? fixedProgressBar,
    required bool compactHeader,
    ValueChanged<DragUpdateDetails>? onDragUpdate,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final showLabels = !_isPip && !compactHeader;

    if (themeService.isWin95) {
      final surface = isDark ? const Color(0xFF2B2B2B) : const Color(0xFFC0C0C0);
      final titleBar = GestureDetector(
        onPanUpdate: onDragUpdate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF000080), Color(0xFF1084D0)],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.play_arrow_sharp, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _Win95TitleBtn(
                key: const Key('yt_window_fullscreen_toggle'),
                label: showLabels ? '⛶ Expandir' : '⛶',
                tooltip: 'Expandir tela cheia',
                onTap: _toggleFullscreen,
              ),
              const SizedBox(width: 6),
              _Win95TitleBtn(
                key: const Key('yt_window_pip_toggle'),
                label: _isPip ? '□' : (showLabels ? '_ PiP' : '_'),
                tooltip: _isPip ? 'Restaurar janela' : 'Mini-janela flutuante',
                onTap: _togglePip,
              ),
              const SizedBox(width: 6),
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
            if (fixedProgressBar != null) fixedProgressBar,
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                      size: 16,
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
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _AsciiTitleBtn(
                      key: const Key('yt_window_fullscreen_toggle'),
                      label: '[FULL]',
                      tooltip: 'Expandir tela cheia',
                      onTap: _toggleFullscreen,
                    ),
                    const SizedBox(width: 6),
                    _AsciiTitleBtn(
                      key: const Key('yt_window_pip_toggle'),
                      label: _isPip ? '[+]' : '[PIP]',
                      tooltip: _isPip ? 'Restaurar janela' : 'Mini-janela flutuante',
                      onTap: _togglePip,
                    ),
                    const SizedBox(width: 6),
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
            if (fixedProgressBar != null) fixedProgressBar,
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
              : cs.surfaceContainerHigh.withValues(
                  alpha: themeService.isAnyGlass ? 0.55 : 1.0,
                ),
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
              size: 20,
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
                  fontSize: _isPip ? 12 : 13.5,
                  color: cs.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (_isPip) ...[
              ListenableBuilder(
                listenable: _playerController,
                builder: (context, _) => _HeaderPillButton(
                  key: const Key('yt_window_pip_play_pause'),
                  icon: _playerController.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: _playerController.isPlaying ? 'Pausar' : 'Reproduzir',
                  darkSurface: isDark,
                  compact: true,
                  onTap: _playerController.togglePlayPause,
                ),
              ),
              const SizedBox(width: 6),
            ],
            _HeaderPillButton(
              key: const Key('yt_window_fullscreen_toggle'),
              icon: Icons.fullscreen_rounded,
              label: showLabels ? 'Expandir' : null,
              tooltip: 'Expandir tela cheia',
              darkSurface: isDark,
              compact: _isPip,
              onTap: _toggleFullscreen,
            ),
            SizedBox(width: _isPip ? 6 : 8),
            _HeaderPillButton(
              key: const Key('yt_window_pip_toggle'),
              icon: _isPip
                  ? Icons.open_in_full_rounded
                  : Icons.picture_in_picture_alt_rounded,
              label: showLabels ? 'PiP' : null,
              tooltip: _isPip ? 'Restaurar janela' : 'Mini-janela flutuante (PiP)',
              darkSurface: isDark,
              compact: _isPip,
              onTap: _togglePip,
            ),
            SizedBox(width: _isPip ? 6 : 8),
            _HeaderPillButton(
              key: const Key('yt_window_close'),
              icon: isHolo ? Icons.close_sharp : Icons.close_rounded,
              label: showLabels ? 'Fechar' : null,
              tooltip: 'Fechar player',
              darkSurface: isDark,
              compact: _isPip,
              isDestructive: true,
              onTap: widget.onClose,
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
        if (fixedProgressBar != null) fixedProgressBar,
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

class _HeaderPillButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final String tooltip;
  final bool darkSurface;
  final bool isDestructive;
  final bool compact;
  final VoidCallback onTap;

  const _HeaderPillButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.darkSurface,
    required this.onTap,
    this.label,
    this.isDestructive = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = isDestructive
        ? Colors.redAccent.withValues(alpha: darkSurface ? 0.24 : 0.14)
        : (darkSurface
            ? Colors.white.withValues(alpha: 0.12)
            : cs.onSurface.withValues(alpha: 0.08));
    final fgColor = isDestructive
        ? (darkSurface ? const Color(0xFFFF8A80) : const Color(0xFFC62828))
        : (darkSurface ? Colors.white : cs.onSurface);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: compact ? 36 : 40,
              minHeight: compact ? 36 : 40,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: label != null ? 10 : 8,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 18 : 20, color: fgColor),
                  if (label != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      label!,
                      style: TextStyle(
                        color: fgColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KairosVideoProgressBar extends StatefulWidget {
  final KairosYoutubeController controller;
  final bool darkSurface;
  final VoidCallback onUserInteract;

  const _KairosVideoProgressBar({
    required this.controller,
    required this.darkSurface,
    required this.onUserInteract,
  });

  @override
  State<_KairosVideoProgressBar> createState() => _KairosVideoProgressBarState();
}

class _KairosVideoProgressBarState extends State<_KairosVideoProgressBar> {
  double? _draggingMs;

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds.clamp(0, 359999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bgColor = widget.darkSurface
        ? const Color(0xFF11151F)
        : cs.surfaceContainerHighest;
    final fgColor = widget.darkSurface ? Colors.white : cs.onSurface;
    final mutedColor = widget.darkSurface
        ? Colors.white70
        : cs.onSurfaceVariant;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final durationMs = widget.controller.duration.inMilliseconds.toDouble();
        final maxMs = durationMs > 0 ? durationMs : 1.0;
        final currentMs = (_draggingMs ??
                widget.controller.position.inMilliseconds.toDouble())
            .clamp(0.0, maxMs);
        final displayPos = Duration(milliseconds: currentMs.round());

        return Container(
          key: const Key('kairos_video_progress_bar'),
          color: bgColor,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  key: const Key('kairos_video_play_pause_btn'),
                  onPressed: () {
                    widget.onUserInteract();
                    widget.controller.togglePlayPause();
                  },
                  icon: Icon(
                    widget.controller.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: fgColor,
                    size: 24,
                  ),
                  tooltip: widget.controller.isPlaying ? 'Pausar' : 'Reproduzir',
                  padding: EdgeInsets.zero,
                ),
              ),
              Text(
                _formatDuration(displayPos),
                style: TextStyle(
                  color: fgColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                    activeTrackColor: cs.primary,
                    inactiveTrackColor: mutedColor.withValues(alpha: 0.3),
                    thumbColor: cs.primary,
                  ),
                  child: Slider(
                    key: const Key('kairos_video_progress_slider'),
                    value: currentMs,
                    min: 0.0,
                    max: maxMs,
                    onChangeStart: (v) {
                      widget.onUserInteract();
                      setState(() => _draggingMs = v);
                    },
                    onChanged: durationMs > 0
                        ? (v) {
                            widget.onUserInteract();
                            setState(() => _draggingMs = v);
                          }
                        : null,
                    onChangeEnd: (v) {
                      widget.onUserInteract();
                      setState(() => _draggingMs = null);
                      widget.controller.seekTo(Duration(milliseconds: v.round()));
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(widget.controller.duration),
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        );
      },
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
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
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: filled ? cs.primary : Colors.transparent,
            border: Border.all(color: cs.primary, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'RetroPixel',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: filled ? cs.onPrimary : cs.primary,
            ),
          ),
        ),
      ),
    );
  }
}
