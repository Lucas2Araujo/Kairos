import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import '../../core/utils/youtube_url_parser.dart';

@JS('document')
external JSObject get _document;

final Set<String> _registeredViewTypes = <String>{};

/// Constrói o reprodutor incorporado do YouTube na Web usando `iframe` via `HtmlElementView`.
Widget buildYoutubeEmbed(
  BuildContext context, {
  required String videoId,
  required String title,
}) {
  final viewType = 'kairos-yt-iframe-$videoId';
  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = _document.callMethod<JSObject>(
        'createElement'.toJS,
        'iframe'.toJS,
      );
      iframe['src'] = YoutubeUrlParser.buildEmbedUrl(videoId).toJS;
      iframe['title'] = title.toJS;
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
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}
