/// Utilitário puro para identificar e normalizar links do YouTube em IDs e URLs de embed.
class YoutubeUrlParser {
  const YoutubeUrlParser._();

  static final RegExp _validIdPattern = RegExp(r'^[a-zA-Z0-9_-]{6,20}$');

  /// Extrai o `videoId` de qualquer URL válida do YouTube (`watch`, `youtu.be`,
  /// `embed`, `shorts`, `live`). Retorna `null` caso não seja um link de vídeo válido.
  static String? extractVideoId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final normalized = trimmed.contains('://') ? trimmed : 'https://$trimmed';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return null;

    final host = uri.host.toLowerCase();
    String? candidate;

    if (host == 'youtu.be' || host.endsWith('.youtu.be')) {
      if (uri.pathSegments.isNotEmpty) {
        candidate = uri.pathSegments.first;
      }
    } else if (host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtube-nocookie.com' ||
        host.endsWith('.youtube-nocookie.com')) {
      final vParam = uri.queryParameters['v'];
      if (vParam != null && vParam.trim().isNotEmpty) {
        candidate = vParam.trim();
      } else if (uri.pathSegments.length >= 2) {
        final first = uri.pathSegments[0].toLowerCase();
        if (first == 'embed' || first == 'shorts' || first == 'live' || first == 'v') {
          candidate = uri.pathSegments[1];
        }
      }
    }

    if (candidate == null) return null;
    final cleanId = candidate.trim();
    if (!_validIdPattern.hasMatch(cleanId)) return null;
    return cleanId;
  }

  /// Indica se a URL fornecida aponta para um vídeo reconhecido do YouTube.
  static bool isYoutubeUrl(String url) => extractVideoId(url) != null;

  /// Retorna a URL limpa de incorporação sem cookies para `iframe`.
  static String buildEmbedUrl(String videoId) =>
      'https://www.youtube-nocookie.com/embed/$videoId?autoplay=1&rel=0&modestbranding=1&playsinline=1';

  /// Retorna a URL canônica de visualização do YouTube.
  static String buildWatchUrl(String videoId) =>
      'https://www.youtube.com/watch?v=$videoId';

  /// Retorna a URL da miniatura padrão de alta qualidade.
  static String buildThumbnailUrl(String videoId) =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}
