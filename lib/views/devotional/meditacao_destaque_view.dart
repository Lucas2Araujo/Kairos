import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  void _shareVerse() {
    final textToShare = '“$_verseText”\n— $_verseRef\n(Compartilhado via Kairós)';
    Clipboard.setData(ClipboardData(text: textToShare));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Texto do versículo copiado para compartilhamento!'),
        duration: Duration(seconds: 2),
      ),
    );
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
          // Imagem de Wallpaper de Alta Resolução
          Image.network(
            wallpaper,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF1E293B),
            ),
          ),

          // Gradiente Escuro de Alta Legibilidade
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

          // Conteúdo da Tela
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Botão Fechar X no topo esquerdo
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),

                  const Spacer(flex: 2),

                  // Tag VERSÍCULO DO DIA
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

                  // Referência Bíblica
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

                  // Texto do Versículo em Fonte HymnSerif Imersiva
                  Text(
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

                  const Spacer(flex: 3),

                  // Barra de Ações Inferior (Favoritar, Compartilhar, Ler Meditação)
                  Row(
                    children: [
                      // Botão Favoritar
                      InkWell(
                        onTap: _toggleFavorite,
                        borderRadius: BorderRadius.circular(30),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite ? Colors.redAccent : Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Favoritar',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Botão Compartilhar
                      InkWell(
                        onTap: _shareVerse,
                        borderRadius: BorderRadius.circular(30),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.share_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Compartilhar',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Botão Ler Meditação
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
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
}

