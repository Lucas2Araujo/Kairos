import 'package:flutter/material.dart';

import 'kairos_youtube_embed_stub.dart'
    if (dart.library.js_interop) 'kairos_youtube_embed_web.dart' as impl;

/// Widget multiplataforma que incorpora o reprodutor do YouTube na Web (`iframe`)
/// ou exibe um reprodutor interativo com abertura in-app no Android/Desktop.
class KairosYoutubeEmbed extends StatelessWidget {
  /// Identificador de vídeo do YouTube.
  final String videoId;

  /// Título exibido para acessibilidade e fallback visual.
  final String title;

  /// Constrói a área interna de reprodução do vídeo 16:9.
  const KairosYoutubeEmbed({
    super.key,
    required this.videoId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return impl.buildYoutubeEmbed(
      context,
      videoId: videoId,
      title: title,
    );
  }
}
