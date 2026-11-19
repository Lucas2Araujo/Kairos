import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import '../../core/utils/youtube_url_parser.dart';
import 'kairos_youtube_controller.dart';

@JS('document')
external JSObject get _document;

@JS('window')
external JSObject get _window;

final Set<String> _registeredViewTypes = <String>{};
final Map<String, JSObject> _iframesByViewType = <String, JSObject>{};

/// Constrói o reprodutor incorporado do YouTube na Web usando `iframe` via
/// `HtmlElementView` com `controls=0&enablejsapi=1` sincronizado ao
/// [KairosYoutubeController].
Widget buildYoutubeEmbed(
  BuildContext context, {
  required String videoId,
  required String title,
  KairosYoutubeController? controller,
}) {
  return _WebYoutubeEmbed(
    key: ValueKey('yt_web_$videoId'),
    videoId: videoId,
    title: title,
    playerController: controller,
  );
}

class _WebYoutubeEmbed extends StatefulWidget {
  final String videoId;
  final String title;
  final KairosYoutubeController? playerController;

  const _WebYoutubeEmbed({
    super.key,
    required this.videoId,
    required this.title,
    this.playerController,
  });

  @override
  State<_WebYoutubeEmbed> createState() => _WebYoutubeEmbedState();
}

class _WebYoutubeEmbedState extends State<_WebYoutubeEmbed> {
  late final String _viewType;
  JSFunction? _messageListener;

  @override
  void initState() {
    super.initState();
    _viewType = 'kairos-yt-iframe-${widget.videoId}';
    _registerFactoryIfNeeded();
    _attachController();
    _attachMessageListener();
  }

  void _registerFactoryIfNeeded() {
    if (_registeredViewTypes.add(_viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
        final iframe = _document.callMethod<JSObject>(
          'createElement'.toJS,
          'iframe'.toJS,
        );
        final embedUrl =
            '${YoutubeUrlParser.buildEmbedUrl(widget.videoId)}&controls=0&enablejsapi=1';
        iframe['src'] = embedUrl.toJS;
        iframe['title'] = widget.title.toJS;
        iframe['allow'] =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
                .toJS;
        iframe['allowFullscreen'] = true.toJS;
        iframe['referrerPolicy'] = 'strict-origin-when-cross-origin'.toJS;
        final style = iframe['style'] as JSObject?;
        if (style != null) {
          style['width'] = '100%'.toJS;
          style['height'] = '100%'.toJS;
          style['border'] = 'none'.toJS;
          style['backgroundColor'] = '#000000'.toJS;
        }
        _iframesByViewType[_viewType] = iframe;
        // Inicia escuta de eventos da YouTube IFrame API assim que carregar.
        iframe.callMethod(
          'addEventListener'.toJS,
          'load'.toJS,
          (() {
            _postCommand('listening', const []);
          }).toJS,
        );
        return iframe;
      });
    }
  }

  void _postCommand(String func, List<Object?> args) {
    final iframe = _iframesByViewType[_viewType];
    if (iframe == null) return;
    final contentWindow = iframe['contentWindow'] as JSObject?;
    if (contentWindow == null) return;
    final payload = func == 'listening'
        ? jsonEncode({'event': 'listening'})
        : jsonEncode({'event': 'command', 'func': func, 'args': args});
    try {
      contentWindow.callMethod('postMessage'.toJS, payload.toJS, '*'.toJS);
    } catch (_) {}
  }

  void _attachController() {
    widget.playerController?.attach(
      onPlay: () async => _postCommand('playVideo', const []),
      onPause: () async => _postCommand('pauseVideo', const []),
      onSeekTo: (pos) async =>
          _postCommand('seekTo', [pos.inMilliseconds / 1000.0, true]),
    );
  }

  void _attachMessageListener() {
    if (widget.playerController == null) return;
    final listener = ((JSObject event) {
      final rawData = event['data'];
      if (rawData == null || !rawData.isA<JSString>()) return;
      final text = (rawData as JSString).toDart;
      if (!text.startsWith('{')) return;
      try {
        final decoded = jsonDecode(text);
        if (decoded is! Map<String, dynamic>) return;
        final info = decoded['info'];
        if (info is Map<String, dynamic>) {
          final currentTime = (info['currentTime'] as num?)?.toDouble();
          final duration = (info['duration'] as num?)?.toDouble();
          final playerState = (info['playerState'] as num?)?.toInt();
          widget.playerController?.updateState(
            isReady: true,
            isPlaying: playerState != null ? playerState == 1 : null,
            position: currentTime != null
                ? Duration(milliseconds: (currentTime * 1000).round())
                : null,
            duration: duration != null && duration > 0
                ? Duration(milliseconds: (duration * 1000).round())
                : null,
          );
        }
      } catch (_) {}
    }).toJS;
    _messageListener = listener;
    _window.callMethod('addEventListener'.toJS, 'message'.toJS, listener);
  }

  @override
  void dispose() {
    if (_messageListener != null) {
      _window.callMethod(
        'removeEventListener'.toJS,
        'message'.toJS,
        _messageListener!,
      );
    }
    widget.playerController?.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
