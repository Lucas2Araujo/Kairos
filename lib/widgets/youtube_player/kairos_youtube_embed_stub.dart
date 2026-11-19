import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/youtube_url_parser.dart';

/// Fallback multiplataforma (Android/Desktop/Testes) com capa do vídeo e abertura
/// direta via navegador interno (`inAppBrowserView` / Custom Tabs).
Widget buildYoutubeEmbed(
  BuildContext context, {
  required String videoId,
  required String title,
}) {
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
                FilledButton.icon(
                  onPressed: launchInApp,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: const Text(
                    'Assistir Vídeo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
