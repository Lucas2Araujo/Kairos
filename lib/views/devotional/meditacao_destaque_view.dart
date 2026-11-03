import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/system_share_download.dart';
import '../../core/utils/verse_card_renderer.dart';
import '../../models/devotional.dart';
import '../../services/wallpaper_service.dart';

class MeditacaoDestaqueView extends StatefulWidget {
  final Devotional? devotional;
  final String? fallbackVerse;
  final String? fallbackReference;
  final void Function(int tabIndex)? onNavigateToTab;

  const MeditacaoDestaqueView({
    super.key,
    this.devotional,
    this.fallbackVerse,
    this.fallbackReference,
    this.onNavigateToTab,
  });

  static Future<void> show(
    BuildContext context, {
    Devotional? devotional,
    String? fallbackVerse,
    String? fallbackReference,
    void Function(int tabIndex)? onNavigateToTab,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.6),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: MeditacaoDestaqueView(
              devotional: devotional,
              fallbackVerse: fallbackVerse,
              fallbackReference: fallbackReference,
              onNavigateToTab: onNavigateToTab,
            ),
          );
        },
      ),
    );
  }

  @override
  State<MeditacaoDestaqueView> createState() => _MeditacaoDestaqueViewState();
}

class _MeditacaoDestaqueViewState extends State<MeditacaoDestaqueView> {
  bool _isFavorite = false;
  bool _isDownloading = false;

  String get _verseText {
    final t = widget.devotional?.verseText;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return widget.fallbackVerse ??
        'Porque nenhum de nós vive para si mesmo, nem morre para si.';
  }

  String get _verseRef {
    final r = widget.devotional?.verseReference;
    if (r != null && r.trim().isNotEmpty) return r.trim();
    return widget.fallbackReference ?? 'Romanos 14:7';
  }

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('meditacao_favoritos') ?? [];
    if (mounted) {
      setState(() {
        _isFavorite = favs.contains(_verseRef);
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList('meditacao_favoritos') ?? [];
    setState(() {
      if (_isFavorite) {
        favs.remove(_verseRef);
        _isFavorite = false;
      } else {
        favs.add(_verseRef);
        _isFavorite = true;
      }
    });
    await prefs.setStringList('meditacao_favoritos', favs);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? 'Versículo favoritado!' : 'Removido dos favoritos',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _shareVerse() async {
    final textToShare = '“$_verseText”\n— $_verseRef\n(Compartilhado via Kairós)';
    final shared = await SystemShareDownload.shareText(
      text: textToShare,
      subject: _verseRef,
    );
    if (!shared && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Texto do versículo copiado para compartilhamento!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _downloadVerseImage(String wallpaperUrl) async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final bytes = await VerseCardRenderer.renderCardPng(
        verseText: _verseText,
        verseReference: _verseRef,
        category: widget.devotional?.category ?? 'Kairós',
        wallpaperUrl: wallpaperUrl,
      );
      if (bytes != null) {
        final ok = await SystemShareDownload.saveBytes(
          bytes: bytes,
          fileName: 'versiculo_kairos_${DateTime.now().millisecondsSinceEpoch}.png',
          mimeType: 'image/png',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                ok
                    ? 'Imagem da meditação baixada com sucesso!'
                    : 'Não foi possível salvar a imagem.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _lerMeditacao() {
    Navigator.of(context).pop();
    widget.onNavigateToTab?.call(3);
  }

  @override
  Widget build(BuildContext context) {
    final wallpaper = WallpaperService().getDailyWallpaper();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            wallpaper,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1E293B),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.black.withValues(alpha: 0.25),
                  Colors.black.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  const Spacer(flex: 2),

                  Text(
                    'VERSÍCULO DO DIA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _verseRef,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Flexible(
                    flex: 5,
                    child: SingleChildScrollView(
                      child: Text(
                        _verseText,
                        style: const TextStyle(
                          fontFamily: 'HymnSerif',
                          fontSize: 24,
                          height: 1.45,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Barra de Ações Inferior responsiva (Favoritar, Baixar, Compartilhar, Ler Meditação)
                  Wrap(
                    spacing: 6,
                    runSpacing: 10,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionIconButton(
                            onTap: _toggleFavorite,
                            icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                            iconColor: _isFavorite ? Colors.redAccent : Colors.white,
                            label: 'Favoritar',
                          ),
                          _buildActionIconButton(
                            key: const Key('destaque_download_button'),
                            onTap: () => _downloadVerseImage(wallpaper),
                            icon: _isDownloading
                                ? Icons.hourglass_top_rounded
                                : Icons.download_rounded,
                            iconColor: Colors.white,
                            label: 'Baixar',
                          ),
                          _buildActionIconButton(
                            onTap: _shareVerse,
                            icon: Icons.share_outlined,
                            iconColor: Colors.white,
                            label: 'Compartilhar',
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.7),
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        ),
                        icon: const Icon(Icons.menu_book, size: 18),
                        label: const Text(
                          'Ler Meditação',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _lerMeditacao,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionIconButton({
    Key? key,
    required VoidCallback onTap,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 23),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
