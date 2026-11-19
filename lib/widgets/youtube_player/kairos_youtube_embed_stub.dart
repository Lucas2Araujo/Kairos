import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/utils/youtube_url_parser.dart';
import 'kairos_youtube_controller.dart';

/// Constrói o reprodutor do YouTube para plataformas não-Web:
/// - **Android / iOS**: usa `webview_flutter` carregando a página mobile do YouTube
///   (`m.youtube.com/watch?v=...`), funcionando independentemente de o canal ter
///   ativado incorporação (`embed`), com ponte JS para a barra de progresso do Kairós.
/// - **Desktop / Testes / Fallback**: exibe a capa do vídeo com abertura via
///   navegador interno (`inAppBrowserView`) ou app externo.
Widget buildYoutubeEmbed(
  BuildContext context, {
  required String videoId,
  required String title,
  KairosYoutubeController? controller,
}) {
  final isMobile = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  if (isMobile && WebViewPlatform.instance != null) {
    return _MobileYoutubeWebView(
      key: ValueKey('yt_webview_$videoId'),
      videoId: videoId,
      title: title,
      playerController: controller,
    );
  }

  return _YoutubeFallbackView(
    videoId: videoId,
    title: title,
  );
}

class _MobileYoutubeWebView extends StatefulWidget {
  final String videoId;
  final String title;
  final KairosYoutubeController? playerController;

  const _MobileYoutubeWebView({
    super.key,
    required this.videoId,
    required this.title,
    this.playerController,
  });

  @override
  State<_MobileYoutubeWebView> createState() => _MobileYoutubeWebViewState();
}

class _MobileYoutubeWebViewState extends State<_MobileYoutubeWebView> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _hasError = false;

  Uri get _mobileWatchUri =>
      Uri.parse('https://m.youtube.com/watch?v=${widget.videoId}');

  static const String _bridgeScript = r'''
(function() {
  if (window.__kairosBridgeInstalled) return;
  window.__kairosBridgeInstalled = true;

  try {
    var style = document.createElement('style');
    style.id = 'kairos-hide-yt-controls';
    style.textContent =
      'html, body { margin: 0 !important; padding: 0 !important; width: 100% !important; height: 100% !important; overflow: hidden !important; background: #000 !important; } ' +
      'ytm-mobile-topbar-renderer, .mobile-topbar-header, ytm-watch-metadata, ' +
      'ytm-item-section-renderer, ytm-single-column-watch-next-results-renderer, ' +
      '.related-chips-slot-wrapper, .watch-below-the-player, #below, #secondary, ' +
      '.ytp-chrome-bottom, .ytp-chrome-top, .ytp-gradient-bottom, .ytp-gradient-top, ' +
      '.player-controls-bottom, .player-controls-top, .player-controls-content, ' +
      '.ytm-progress-bar-container, .ytm-time-display, .ytp-watermark, ' +
      'ytm-pivot-bar-renderer { display: none !important; opacity: 0 !important; pointer-events: none !important; } ' +
      '#player-container-id, #player, .player-container, .html5-video-player, .html5-video-container { ' +
      '  position: fixed !important; inset: 0 !important; top: 0 !important; left: 0 !important; ' +
      '  width: 100vw !important; height: 100vh !important; max-width: 100vw !important; max-height: 100vh !important; ' +
      '  margin: 0 !important; padding: 0 !important; background: #000 !important; z-index: 2147483646 !important; ' +
      '} ' +
      'video { ' +
      '  position: fixed !important; inset: 0 !important; top: 0 !important; left: 0 !important; ' +
      '  width: 100vw !important; height: 100vh !important; object-fit: contain !important; ' +
      '  background: #000 !important; z-index: 2147483647 !important; ' +
      '}';
    (document.head || document.documentElement).appendChild(style);
  } catch (_) {}

  function getVideo() {
    return document.querySelector('video');
  }

  window.__kairosPlay = function() {
    var v = getVideo();
    if (v) { v.play().catch(function(){}); }
  };

  window.__kairosPause = function() {
    var v = getVideo();
    if (v) { v.pause(); }
  };

  window.__kairosSeek = function(seconds) {
    var v = getVideo();
    if (v && isFinite(seconds)) { v.currentTime = seconds; }
  };

  setInterval(function() {
    var v = getVideo();
    if (!v || !window.KairosPlayer) return;
    var dur = isFinite(v.duration) && v.duration > 0 ? v.duration : 0;
    var cur = isFinite(v.currentTime) && v.currentTime >= 0 ? v.currentTime : 0;
    try {
      window.KairosPlayer.postMessage(JSON.stringify({
        ready: dur > 0,
        playing: !v.paused && !v.ended,
        positionMs: Math.round(cur * 1000),
        durationMs: Math.round(dur * 1000)
      }));
    } catch (_) {}
  }, 500);
})();
''';

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    widget.playerController?.detach();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _MobileYoutubeWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      _controller?.loadRequest(_mobileWatchUri);
    }
  }

  void _handleChannelMessage(JavaScriptMessage message) {
    final playerCtrl = widget.playerController;
    if (playerCtrl == null) return;
    try {
      final decoded = jsonDecode(message.message);
      if (decoded is Map<String, dynamic>) {
        playerCtrl.updateState(
          isReady: decoded['ready'] == true,
          isPlaying: decoded['playing'] == true,
          position: Duration(milliseconds: (decoded['positionMs'] as num?)?.toInt() ?? 0),
          duration: Duration(milliseconds: (decoded['durationMs'] as num?)?.toInt() ?? 0),
        );
      }
    } catch (_) {}
  }

  void _initController() {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFF0B0F17))
        ..addJavaScriptChannel(
          'KairosPlayer',
          onMessageReceived: _handleChannelMessage,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            },
            onPageFinished: (_) async {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
              try {
                await _controller?.runJavaScript(_bridgeScript);
              } catch (_) {}
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame != true) return;
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            },
          ),
        )
        ..loadRequest(_mobileWatchUri);

      _controller = controller;

      widget.playerController?.attach(
        onPlay: () async {
          try {
            await _controller?.runJavaScript('window.__kairosPlay && window.__kairosPlay();');
          } catch (_) {}
        },
        onPause: () async {
          try {
            await _controller?.runJavaScript('window.__kairosPause && window.__kairosPause();');
          } catch (_) {}
        },
        onSeekTo: (pos) async {
          final seconds = pos.inMilliseconds / 1000.0;
          try {
            await _controller?.runJavaScript(
              'window.__kairosSeek && window.__kairosSeek($seconds);',
            );
          } catch (_) {}
        },
      );
    } catch (_) {
      _controller = null;
      _hasError = true;
      _isLoading = false;
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    if (_controller == null) {
      _initController();
    } else {
      _controller?.loadRequest(_mobileWatchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || _hasError) {
      return _YoutubeFallbackView(
        videoId: widget.videoId,
        title: widget.title,
        onRetry: _retry,
      );
    }

    return ColoredBox(
      color: const Color(0xFF0B0F17),
      child: Stack(
        fit: StackFit.expand,
        children: [
          WebViewWidget(controller: controller),
          if (_isLoading)
            const ColoredBox(
              color: Color(0xCC0B0F17),
              child: Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFDC2626),
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _YoutubeFallbackView extends StatelessWidget {
  final String videoId;
  final String title;
  final VoidCallback? onRetry;

  const _YoutubeFallbackView({
    required this.videoId,
    required this.title,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final watchUri = Uri.parse(YoutubeUrlParser.buildWatchUrl(videoId));
    final thumbUrl = YoutubeUrlParser.buildThumbnailUrl(videoId);

    Future<void> launchInApp() async {
      try {
        final launched = await launchUrl(
          watchUri,
          mode: LaunchMode.inAppBrowserView,
        );
        if (!launched) {
          await launchUrl(watchUri, mode: LaunchMode.externalApplication);
        }
      } catch (_) {
        await launchUrl(watchUri, mode: LaunchMode.externalApplication);
      }
    }

    return ColoredBox(
      color: const Color(0xFF0B0F17),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            thumbUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: launchInApp,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: const Text(
                          'Assistir Vídeo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (onRetry != null)
                        OutlinedButton.icon(
                          onPressed: onRetry,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white70),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Recarregar'),
                        ),
                    ],
                  ),
                  if (title.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
