import 'package:flutter/material.dart';
import '../../../models/egw_models.dart';
import '../../../services/theme_service.dart';
import '../../lesson/widgets/cached_ss_tirinha_image.dart';

/// Painter customizado de alto desempenho para capas de Ellen G. White inspiradas
/// no padrão de design contemporâneo da Casa Publicadora Brasileira (CPB).
///
/// Reproduz fielmente a textura fosca encadernada, o vinco da lombada, os três pontos
/// clássicos no topo, o monograma entrelaçado em serifas `HymnSerif`, a tipografia
/// em caixa alta `Montserrat` e a assinatura canônica "ELLEN G. WHITE".
class EgwCpbCoverPainter extends CustomPainter {
  /// Título completo da obra
  final String title;

  /// Sigla oficial do livro (ex: PP, DTN, GC)
  final String abbreviation;

  /// Se deve utilizar a paleta escura (Charcoal & Champagne Gold) ou clara (Taupe & Bronze)
  final bool isDark;

  /// Etiqueta opcional de série temática
  final String? seriesLabel;

  /// Cor de fundo no modo claro (Taupe aveludado #8E8880)
  static const Color lightBackground = Color(0xFF8E8880);

  /// Cor de destaque no modo claro (Bronze clássico #4D3D2E)
  static const Color lightAccent = Color(0xFF4D3D2E);

  /// Cor de fundo no modo escuro (Charcoal grafite #58595B)
  static const Color darkBackground = Color(0xFF58595B);

  /// Cor de destaque no modo escuro (Champagne Gold acetinado #C5A680)
  static const Color darkAccent = Color(0xFFC5A680);

  /// Branco neutro suave (#F5F3EF) para os pontos e assinatura
  static const Color neutralWhite = Color(0xFFF5F3EF);

  const EgwCpbCoverPainter({
    required this.title,
    required this.abbreviation,
    this.isDark = false,
    this.seriesLabel,
  });

  static String _stripDiacritics(String str) {
    const withDiacritics = 'ÀÁÂÃÄÅàáâãäåÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÙÚÛÜùúûüÇçÑñÝýÿ';
    const withoutDiacritics = 'AAAAAAaaaaaaEEEEeeeeIIIIiiiiOOOOOOooooooUUUUuuuuCcNnYyy';
    var result = str;
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  /// Extrai duas letras maiúsculas representativas para formar o monograma clássico entrelaçado.
  ///
  /// Prioriza siglas estabelecidas ou as iniciais das palavras mais significativas do título,
  /// descartando artigos, preposições e marcadores de volume comuns.
  @visibleForTesting
  static String extractMonogram(String title, {String? abbreviation}) {
    if (abbreviation != null && abbreviation.trim().isNotEmpty) {
      final cleanAbbr = _stripDiacritics(abbreviation)
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toUpperCase();
      if (cleanAbbr.length >= 2) {
        return cleanAbbr.substring(0, 2);
      }
    }

    const stopWords = {
      'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas',
      'de', 'do', 'da', 'dos', 'das', 'e', 'em', 'no', 'na', 'nos', 'nas',
      'para', 'por', 'sobre', 'com', 'sob', 'ao', 'aos', 'à', 'às',
      'vol', 'volume', 'parte'
    };

    final words = _stripDiacritics(title)
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    final significantWords = words
        .where((w) => !stopWords.contains(w.toLowerCase()) && !RegExp(r'^\d+$').hasMatch(w))
        .toList();

    if (significantWords.length >= 2) {
      final firstLetter = _stripDiacritics(significantWords[0][0]).toUpperCase();
      final secondLetter = _stripDiacritics(significantWords[1][0]).toUpperCase();
      return '$firstLetter$secondLetter';
    } else if (significantWords.length == 1) {
      final word = _stripDiacritics(significantWords[0])
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .toUpperCase();
      if (word.length >= 2) {
        return word.substring(0, 2);
      } else if (word.isNotEmpty) {
        return '${word}X';
      }
    }

    final allAlpha = _stripDiacritics(title)
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toUpperCase();
    if (allAlpha.length >= 2) return allAlpha.substring(0, 2);
    return 'EW';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final bgColor = isDark ? darkBackground : lightBackground;
    final accentColor = isDark ? darkAccent : lightAccent;
    const whiteColor = neutralWhite;

    // 1. Fundo com gradiente sutil horizontal (textura de encadernação dura)
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color.lerp(bgColor, Colors.black, 0.05)!,
          bgColor,
          Color.lerp(bgColor, Colors.white, 0.04)!,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // Lombada esquerda com vinco e relevo realista (~6% da largura)
    final spineW = (w * 0.07).clamp(3.0, 14.0);
    final spinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.black.withValues(alpha: isDark ? 0.35 : 0.22),
          Colors.white.withValues(alpha: isDark ? 0.08 : 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, spineW * 1.5, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, spineW * 1.5, h), spinePaint);

    // 2. Três pontos clássicos no topo (~11% da altura)
    final dotRadius = (w * 0.012).clamp(1.2, 2.5);
    final dotY = h * 0.11;
    final dotSpacing = (w * 0.045).clamp(4.0, 10.0);
    final dotPaint = Paint()
      ..color = whiteColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    final centerX = w * 0.52; // Levemente compensado pela lombada
    canvas.drawCircle(Offset(centerX - dotSpacing, dotY), dotRadius, dotPaint);
    canvas.drawCircle(Offset(centerX, dotY), dotRadius, dotPaint);
    canvas.drawCircle(Offset(centerX + dotSpacing, dotY), dotRadius, dotPaint);

    // 3. Monograma entrelaçado (~22% a 54% da altura)
    final monogram = extractMonogram(title, abbreviation: abbreviation);
    if (monogram.length >= 2) {
      final letter1 = monogram[0];
      final letter2 = monogram[1];
      final monogramSize = (h * 0.23).clamp(16.0, 80.0);

      final styleBase = TextStyle(
        fontFamily: 'HymnSerif',
        fontWeight: FontWeight.bold,
        fontSize: monogramSize,
        color: accentColor,
        height: 1.0,
      );

      final tp1 = TextPainter(
        text: TextSpan(text: letter1, style: styleBase),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();

      final tp2 = TextPainter(
        text: TextSpan(text: letter2, style: styleBase),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();

      final shiftX = monogramSize * 0.28;
      final shiftY = monogramSize * 0.34;
      final totalMonoW = tp1.width + shiftX;
      final monoStartX = centerX - (totalMonoW / 2);
      final monoStartY = h * 0.22;

      // Desenha primeira letra
      tp1.paint(canvas, Offset(monoStartX, monoStartY));

      // Efeito de halo/recorte para interseção das letras entrelaçadas
      final tpHalo = TextPainter(
        text: TextSpan(
          text: letter2,
          style: styleBase.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = (monogramSize * 0.06).clamp(2.0, 5.0)
              ..color = bgColor,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      tpHalo.paint(canvas, Offset(monoStartX + shiftX, monoStartY + shiftY));

      // Desenha segunda letra sobreposta
      tp2.paint(canvas, Offset(monoStartX + shiftX, monoStartY + shiftY));
    }

    // 4. Título da obra no terço inferior (~63% a 84% da altura)
    final titleFontSize = (h * 0.055).clamp(7.5, 16.0);
    final titleMaxW = w * 0.82;
    final titleStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w700,
      fontSize: titleFontSize,
      color: accentColor,
      letterSpacing: 1.1,
      height: 1.15,
    );

    final titlePainter = TextPainter(
      text: TextSpan(
        text: title.toUpperCase(),
        style: titleStyle,
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: titleMaxW);

    final titleX = centerX - (titlePainter.width / 2);
    final titleY = h * 0.65;
    titlePainter.paint(canvas, Offset(titleX, titleY));

    // 5. Assinatura da autora no rodapé (~90% da altura)
    final authorFontSize = (h * 0.038).clamp(6.0, 11.0);
    final authorStyle = TextStyle(
      fontFamily: 'Montserrat',
      fontWeight: FontWeight.w600,
      fontSize: authorFontSize,
      color: whiteColor.withValues(alpha: 0.90),
      letterSpacing: 1.6,
      height: 1.0,
    );

    final authorPainter = TextPainter(
      text: TextSpan(text: 'ELLEN G. WHITE', style: authorStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();

    final authorX = centerX - (authorPainter.width / 2);
    final authorY = (h * 0.90).clamp(h - authorPainter.height - 4, h - 2);
    authorPainter.paint(canvas, Offset(authorX, authorY));
  }

  @override
  bool shouldRepaint(covariant EgwCpbCoverPainter oldDelegate) {
    return oldDelegate.title != title ||
        oldDelegate.abbreviation != abbreviation ||
        oldDelegate.isDark != isDark ||
        oldDelegate.seriesLabel != seriesLabel;
  }
}

/// Widget unificado de exibição de capa de livros de Ellen G. White.
///
/// Suporta tanto o modo clássico com imagem do portal oficial quanto a nova
/// arte contemporânea com monograma personalizado estilo CPB via [EgwCpbCoverPainter].
class EgwBookCover extends StatelessWidget {
  /// Instância do livro
  final EgwBook book;

  /// Se deve renderizar a arte moderna contemporânea estilo CPB
  final bool useModernCover;

  /// Largura visual desejada da capa
  final double? width;

  /// Altura visual desejada da capa
  final double? height;

  /// Arredondamento das bordas
  final BorderRadius? borderRadius;

  /// Permite forçar o modo escuro independente do tema do contexto
  final bool? forceDark;

  const EgwBookCover({
    super.key,
    required this.book,
    this.useModernCover = false,
    this.width,
    this.height,
    this.borderRadius,
    this.forceDark,
  });

  Widget _buildPainterFallback(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final renderW = width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : 120.0);
        final renderH = height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : renderW * 1.45);
        return CustomPaint(
          size: Size(renderW, renderH),
          painter: EgwCpbCoverPainter(
            title: book.title,
            abbreviation: book.abbreviation,
            isDark: isDark,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = forceDark ?? (Theme.of(context).brightness == Brightness.dark);
    final radius = borderRadius ?? BorderRadius.circular(10);

    if (ThemeService().isAscii) {
      final cs = Theme.of(context).colorScheme;
      final abbr = book.abbreviation.trim().isNotEmpty ? book.abbreviation.trim() : 'EGW';
      return SizedBox(
        width: width,
        height: height,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: cs.primary, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '+-[$abbr]-+',
                maxLines: 1,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PixelMono',
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: Text(
                    book.title.toUpperCase(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PixelMono',
                      fontSize: 9,
                      height: 1.2,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ),
              Text(
                '== EGW ==',
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PixelMono',
                  fontSize: 8,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget content;

    if (useModernCover) {
      if ((book.cpbCoverUrl ?? '').isNotEmpty) {
        content = CachedSSTirinhaImage(
          imageUrl: book.cpbCoverUrl!,
          width: width,
          height: height,
          fit: BoxFit.cover,
          showLoadingIndicator: false,
          errorBuilder: (_, __, ___) => _buildPainterFallback(isDark),
        );
      } else {
        content = _buildPainterFallback(isDark);
      }
    } else {
      if (book.coverUrl.isNotEmpty) {
        content = CachedSSTirinhaImage(
          imageUrl: book.coverUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          showLoadingIndicator: false,
          errorBuilder: (_, __, ___) => _buildPainterFallback(isDark),
        );
      } else {
        content = _buildPainterFallback(isDark);
      }
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: content,
      ),
    );
  }
}
