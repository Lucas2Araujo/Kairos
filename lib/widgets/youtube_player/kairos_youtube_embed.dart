import 'package:flutter/material.dart';

import 'kairos_youtube_controller.dart';
import 'kairos_youtube_embed_stub.dart'
    if (dart.library.js_interop) 'kairos_youtube_embed_web.dart' as impl;

/// Widget multiplataforma que incorpora o reprodutor do YouTube na Web (`iframe`)
/// ou usa `webview_flutter` no Android/iOS com sincronização para a barra de
/// progresso nativa do Kairós.
class KairosYoutubeEmbed extends StatelessWidget {
  /// Identificador de vídeo do YouTube.
  final String videoId;

  /// Título exibido para acessibilidade e fallback visual.
  final String title;

  /// Controlador opcional para sincronizar play/pause e barra de progresso do Kairós.
  final KairosYoutubeController? controller;

  /// Constrói a área interna de reprodução do vídeo.
  const KairosYoutubeEmbed({
    super.key,
    required this.videoId,
    required this.title,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildYoutubeEmbed(
      context,
      videoId: videoId,
      title: title,
      controller: controller,
    );
  }
}
