import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Utilitário centralizado para abrir links web dentro do próprio aplicativo
/// usando o navegador interno (`LaunchMode.inAppBrowserView` / Chrome Custom Tabs),
/// com fallback automático para `LaunchMode.externalApplication`.
class InAppLinkLauncher {
  const InAppLinkLauncher._();

  /// Abre uma [Uri] no navegador interno do app para esquemas `http`/`https`,
  /// ou via aplicativo externo para demais esquemas (`mailto:`, `tel:`, etc.).
  static Future<bool> openUri(Uri uri) async {
    final isWebScheme = uri.scheme == 'http' || uri.scheme == 'https';
    if (isWebScheme) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.inAppBrowserView,
        );
        if (launched) return true;
      } catch (e) {
        debugPrint('[InAppLinkLauncher] Falha no inAppBrowserView: $e');
      }
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[InAppLinkLauncher] Falha ao abrir link externo: $e');
      return false;
    }
  }

  /// Faz parse seguro de uma [url] em texto e abre via [openUri].
  static Future<bool> openUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return false;
    return openUri(uri);
  }
}
