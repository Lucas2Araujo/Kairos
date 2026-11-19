import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';
import '../../../services/theme_service.dart';

/// Mascote Reativo "Lamparina Kairós"
///
/// Inspirado na Parábola das Dez Virgens (Mateus 25) e estilizado no mesmo traço
/// artístico da Splash Screen: acabamento em cerâmica terracota, bochechas rosadas,
/// olhos expressivos e chama viva reativa ao progresso espiritual diário:
/// - morningIdle: manhã despertando, chama serena aguardando o primeiro estudo.
/// - eveningSleepy: tarde/noite sem missões, olhinhos dormindo e chama baixinha.
/// - halfFlame: meia ofensiva (1-2 missões), chama radiante acolhedora.
/// - fullFlame: ofensiva completa (3+ missões com Quiz), chama dourada com halo luminoso.
class KairosLampMascotWidget extends StatefulWidget {
  final double size;
  final bool showLabel;
  final LampMascotState? state;
  final double? oilFill;

  const KairosLampMascotWidget({
    super.key,
    this.size = 64,
    this.showLabel = false,
    this.state,
    this.oilFill,
  });

  @override
  State<KairosLampMascotWidget> createState() => _KairosLampMascotWidgetState();
}

class _KairosLampMascotWidgetState extends State<KairosLampMascotWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // Não roda loop infinito durante testes para evitar timeout no pumpAndSettle
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!inTest) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gamification = GamificationService();

    return ListenableBuilder(
      listenable: gamification,
      builder: (context, _) {
        final effectiveState = widget.state ?? gamification.lampMascotState;
        final effectiveOil = widget.oilFill ?? gamification.lampPercentage;

        if (ThemeService().isAscii) {
          return AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return _AsciiLampMascot(
                size: widget.size,
                state: effectiveState,
                oilPercentage: effectiveOil,
                pulse: _animController.value,
                showLabel: widget.showLabel,
                label: _getStateLabel(effectiveState),
              );
            },
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _CuteLampPainter(
                    flamePulse: _animController.value,
                    state: effectiveState,
                    oilPercentage: effectiveOil,
                  ),
                );
              },
            ),
            if (widget.showLabel) ...[
              const SizedBox(height: 4),
              Text(
                _getStateLabel(effectiveState),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _getStateLabel(LampMascotState state) {
    switch (state) {
      case LampMascotState.morningIdle:
        return 'Pavio Pronto';
      case LampMascotState.eveningSleepy:
        return 'Lamparina Baixa';
      case LampMascotState.halfFlame:
        return 'Chama Acesa 🔥';
      case LampMascotState.fullFlame:
        return 'Chama Completa ✨';
    }
  }
}

class _CuteLampPainter extends CustomPainter {
  final double flamePulse;
  final LampMascotState state;
  final double oilPercentage;

  _CuteLampPainter({
    required this.flamePulse,
    required this.state,
    required this.oilPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Sistema de coordenadas normalizado baseado no modelo do splash screen:
    // Caixa de referência: 190 de largura, 160 de altura com centro próximo a (95, 95)
    final scale = size.width / 190.0;

    canvas.save();
    // Centraliza o desenho dentro do canvas disponível
    canvas.translate(size.width * 0.50, size.height * 0.55);
    canvas.scale(scale, scale);

    final isSleepy = state == LampMascotState.eveningSleepy;
    final isFullFlame = state == LampMascotState.fullFlame;
    final isHalfFlame = state == LampMascotState.halfFlame;

    // 1. Halo luminoso atrás da chama (especialmente no modo Chama Completa)
    if (isFullFlame || isHalfFlame) {
      const haloCenter = Offset(-68, -42);
      final haloRadius = isFullFlame ? 82.0 : 54.0;
      final haloIntensity = isFullFlame ? 0.45 : 0.22;
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB74D).withValues(alpha: haloIntensity),
            const Color(0xFFFF9800).withValues(alpha: haloIntensity * 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: haloCenter, radius: haloRadius));
      canvas.drawCircle(haloCenter, haloRadius, haloPaint);
    }

    // 2. Sombra suave no chão
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 46), width: 112, height: 14),
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );

    const clayBase = Color(0xFFD68945);
    const clayDark = Color(0xFFA66028);
    const clayHighlight = Color(0xFFF3B373);
    const outlineColor = Color(0xFF422411);

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 3. Alça Curva Traseira (Direita)
    final handlePath = Path()
      ..moveTo(45, -8)
      ..cubicTo(86, -28, 92, 26, 42, 24);
    canvas.drawPath(
      handlePath,
      Paint()
        ..color = clayBase
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      handlePath,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 15
        ..strokeCap = StrokeCap.round
        ..blendMode = BlendMode.dstOver,
    );

    // 4. Pedestal / Base da Lamparina
    final baseRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(2, 39), width: 66, height: 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(baseRRect, Paint()..color = clayDark);
    canvas.drawRRect(baseRRect, outlinePaint);

    // 5. Corpo da Lamparina com Bico à Esquerda
    final bodyPath = Path()
      ..moveTo(-72, -12)
      ..quadraticBezierTo(-55, -14, -38, -14)
      ..cubicTo(-15, -24, 25, -24, 48, -8)
      ..cubicTo(64, 8, 52, 34, 24, 35)
      ..lineTo(-20, 35)
      ..cubicTo(-42, 34, -52, 10, -72, -12)
      ..close();

    canvas.drawPath(bodyPath, Paint()..color = clayBase);

    // Brilho superior no barro
    final highlightPath = Path()
      ..moveTo(-45, -8)
      ..quadraticBezierTo(5, -18, 38, -5);
    canvas.drawPath(
      highlightPath,
      Paint()
        ..color = clayHighlight.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawPath(bodyPath, outlinePaint);

    // 6. Tampinha Superior com Puxador
    final lidRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(4, -20), width: 42, height: 9),
      const Radius.circular(5),
    );
    canvas.drawRRect(lidRRect, Paint()..color = clayHighlight);
    canvas.drawRRect(lidRRect, outlinePaint);

    final knobPath = Path()
      ..moveTo(-6, -24)
      ..quadraticBezierTo(4, -38, 14, -24)
      ..close();
    canvas.drawPath(knobPath, Paint()..color = clayDark);
    canvas.drawPath(knobPath, outlinePaint);

    // 7. Bochechas rosadas
    final cheekPaint = Paint()..color = const Color(0xFFF28B82).withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-20, 17), width: 13, height: 7.5),
      cheekPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(24, 17), width: 13, height: 7.5),
      cheekPaint,
    );

    // 8. Olhos Expressivos
    if (isSleepy) {
      // Olhos dormindo (^ ^)
      final sleepPath = Path();
      sleepPath.moveTo(-16, 9);
      sleepPath.quadraticBezierTo(-12, 4, -8, 9);
      sleepPath.moveTo(12, 9);
      sleepPath.quadraticBezierTo(16, 4, 20, 9);
      canvas.drawPath(sleepPath, outlinePaint);
    } else {
      // Olhos ovais vivos e abertos
      final eyePaint = Paint()..color = const Color(0xFF261408);
      final catchlightPaint = Paint()..color = Colors.white;

      for (final eyeX in [-12.0, 16.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(eyeX, 8),
            width: 8.5,
            height: 9.5,
          ),
          eyePaint,
        );
        // Brilho no olhar
        canvas.drawCircle(Offset(eyeX - 1.8, 5.8), 2.2, catchlightPaint);
      }
    }

    // 9. Boquinha sorridente
    final smilePath = Path()
      ..moveTo(-3, 14)
      ..quadraticBezierTo(2, isSleepy ? 17 : 21, 7, 14);
    canvas.drawPath(smilePath, outlinePaint);

    // 10. Pavio e Chama Viva no Bico
    final sway = (flamePulse - 0.5) * 4.5;
    double flameScale = 1.0;
    if (isSleepy) flameScale = 0.55;
    if (isFullFlame) flameScale = 1.25;

    canvas.save();
    canvas.translate(-68, -14);
    canvas.scale(flameScale, flameScale);

    // Pavio de tecido
    canvas.drawLine(
      const Offset(0, 2),
      const Offset(0, -5),
      outlinePaint,
    );

    // Chama Externa (Laranja / Âmbar vivo)
    final outerFlame = Path()
      ..moveTo(0, -4)
      ..cubicTo(-18, -14, -14, -40, sway, -56)
      ..cubicTo(14, -40, 18, -14, 0, -4)
      ..close();
    canvas.drawPath(
      outerFlame,
      Paint()
        ..color = isFullFlame ? const Color(0xFFFF6D00) : const Color(0xFFFF9800),
    );

    // Chama Interna (Amarelo Claro Dourado)
    final innerFlame = Path()
      ..moveTo(0, -7)
      ..cubicTo(-9, -15, -7, -32, sway * 0.6, -42)
      ..cubicTo(7, -32, 9, -15, 0, -7)
      ..close();
    canvas.drawPath(
      innerFlame,
      Paint()
        ..color = isFullFlame ? const Color(0xFFFFEA00) : const Color(0xFFFFF176),
    );

    // Ponto central de chama branca super brilhante para Chama Completa
    if (isFullFlame) {
      canvas.drawCircle(
        Offset(sway * 0.3, -20),
        4.0,
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CuteLampPainter oldDelegate) {
    return oldDelegate.flamePulse != flamePulse ||
        oldDelegate.state != state ||
        oldDelegate.oilPercentage != oilPercentage;
  }
}

class _AsciiLampMascot extends StatelessWidget {
  final double size;
  final LampMascotState state;
  final double oilPercentage;
  final double pulse;
  final bool showLabel;
  final String label;

  const _AsciiLampMascot({
    required this.size,
    required this.state,
    required this.oilPercentage,
    required this.pulse,
    required this.showLabel,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(size, size),
          painter: _SnesPixelLampMascotPainter(
            state: state,
            oilPercentage: oilPercentage,
            pulse: pulse,
            primaryColor: cs.primary,
            isDark: isDark,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            '[${label.toUpperCase()}]',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'RetroPixel',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class _SnesPixelLampMascotPainter extends CustomPainter {
  final LampMascotState state;
  final double oilPercentage;
  final double pulse;
  final Color primaryColor;
  final bool isDark;

  const _SnesPixelLampMascotPainter({
    required this.state,
    required this.oilPercentage,
    required this.pulse,
    required this.primaryColor,
    required this.isDark,
  });

  static const int _gridSize = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final unitX = size.width / _gridSize;
    final unitY = size.height / _gridSize;
    final paint = Paint()..isAntiAlias = false;

    final outline = isDark
        ? Color.lerp(primaryColor, Colors.white, 0.15)!
        : Color.lerp(primaryColor, Colors.black, 0.72)!;
    final bodyMid = Color.lerp(primaryColor, const Color(0xFFD97706), 0.58)!;
    final bodyDark = Color.lerp(bodyMid, Colors.black, 0.42)!;
    final bodyHi = Color.lerp(bodyMid, Colors.white, 0.48)!;
    final darkInk = isDark ? const Color(0xFF061008) : const Color(0xFF14181F);
    final windowEmpty = isDark ? const Color(0xFF142117) : const Color(0xFFE2E8F0);
    const cheekColor = Color(0xFFFF7A90);
    final flameOuter = switch (state) {
      LampMascotState.fullFlame => const Color(0xFFFF6D00),
      LampMascotState.halfFlame => const Color(0xFFFB8C00),
      LampMascotState.morningIdle => const Color(0xFFFFA726),
      LampMascotState.eveningSleepy => const Color(0xFF94A3B8),
    };
    final flameInner = switch (state) {
      LampMascotState.fullFlame => const Color(0xFFFFEA00),
      LampMascotState.halfFlame => const Color(0xFFFFD54F),
      LampMascotState.morningIdle => const Color(0xFFFFE082),
      LampMascotState.eveningSleepy => const Color(0xFFFFB74D),
    };

    void px(int x, int y, Color color) {
      paint.color = color;
      canvas.drawRect(
        Rect.fromLTWH(x * unitX, y * unitY, unitX + 0.3, unitY + 0.3),
        paint,
      );
    }

    void drawRow(int y, List<String> rows) {
      for (int dy = 0; dy < rows.length; dy++) {
        final row = rows[dy];
        for (int x = 0; x < row.length && x < _gridSize; x++) {
          final ch = row[x];
          final Color? color = switch (ch) {
            'o' => outline,
            'b' => bodyMid,
            'd' => bodyDark,
            'h' => bodyHi,
            'k' => darkInk,
            'w' => Colors.white,
            'p' => cheekColor,
            'f' => flameOuter,
            'y' => flameInner,
            _ => null,
          };
          if (color != null) px(x, y + dy, color);
        }
      }
    }

    // Corpo 16-bit da lamparina clássica (linhas 8..20 na matriz 24x24)
    const bodyRows = <String>[
      '.........oooooo.........', // 8: tampa topo
      '.ooo....ohbbbbho........', // 9: ponta do bico + tampa
      'ohbbo...ooddddoo..oooo..', // 10: bico + pescoço + topo alça
      '.ohbbooohhhhhhhhoobbbbo.', // 11: ligação bico + corpo + alça
      '..oobbbbbbbbbbbbboo..bo.', // 12: corpo superior
      '...obbbbbbbbbbbbbbo..bo.', // 13: região olhos
      '...obbbbbbbbbbbbbbo.obo.', // 14: corpo médio + fim alça
      '...obbbddddddddddboooo..', // 15: janela do reservatório de azeite
      '...obbbddddddddddbo.....', // 16: janela do reservatório de azeite
      '....obbbbbbbbbbbbo......', // 17: base superior
      '.....oddddddddddo.......', // 18: pedestal estreito
      '....ohbbbbbbbbbbho......', // 19: base inferior brilho
      '...ooooooooooooooo......', // 20: linha base
    ];
    drawRow(8, bodyRows);

    // Visor interno de azeite pixelado nas linhas 15..16 (colunas 7..16)
    final clampedOil = oilPercentage.clamp(0.0, 1.0);
    const gaugeCols = 10;
    final litCols = (clampedOil * gaugeCols).round().clamp(0, gaugeCols);
    for (int gy = 15; gy <= 16; gy++) {
      for (int i = 0; i < gaugeCols; i++) {
        final gx = 7 + i;
        if (i < litCols) {
          px(gx, gy, gy == 15 ? flameInner : flameOuter);
        } else {
          px(gx, gy, windowEmpty);
        }
      }
    }

    // Expressão facial pixelada na barriga da lamparina (linhas 12..14)
    if (state == LampMascotState.eveningSleepy) {
      // Olhinhos fechados (- -) e boquinha serena
      px(7, 13, darkInk);
      px(8, 13, darkInk);
      px(13, 13, darkInk);
      px(14, 13, darkInk);
      px(10, 14, darkInk);
      px(11, 14, darkInk);
    } else if (state == LampMascotState.fullFlame) {
      // Olhos alegres em arco (^^) com brilho + bochechas rosadas
      px(6, 13, darkInk);
      px(7, 12, darkInk);
      px(8, 13, darkInk);
      px(13, 13, darkInk);
      px(14, 12, darkInk);
      px(15, 13, darkInk);
      px(5, 14, cheekColor);
      px(16, 14, cheekColor);
      px(10, 14, darkInk);
      px(11, 14, flameInner);
      px(12, 14, darkInk);
    } else {
      // Olhos expressivos 2x2 com reflexo branco
      px(7, 12, Colors.white);
      px(8, 12, darkInk);
      px(7, 13, darkInk);
      px(8, 13, darkInk);
      px(13, 12, Colors.white);
      px(14, 12, darkInk);
      px(13, 13, darkInk);
      px(14, 13, darkInk);
      px(6, 14, cheekColor);
      px(15, 14, cheekColor);
      px(10, 14, darkInk);
      px(11, 14, darkInk);
    }

    // Chama animada pixel-art sobre o bico da lamparina (y=1..8)
    final flickerHigh = pulse >= 0.5;
    if (state == LampMascotState.eveningSleepy) {
      // Apenas pequena brasa cintilante
      px(2, 8, flameOuter);
      px(2, 7, flickerHigh ? flameInner : flameOuter);
    } else if (state == LampMascotState.morningIdle) {
      px(2, 8, flameOuter);
      px(3, 8, flameOuter);
      px(2, 7, flameInner);
      px(3, 7, flameOuter);
      px(2, flickerHigh ? 5 : 6, flameInner);
      px(3, 6, Colors.white);
    } else if (state == LampMascotState.halfFlame) {
      const halfFlameA = [
        '..f...',
        '.fyf..',
        'fyyf..',
        'fwyf..',
        '.ff...',
      ];
      const halfFlameB = [
        '.f....',
        'fyf...',
        'fyyf..',
        'fywf..',
        '.ff...',
      ];
      drawRow(4, flickerHigh ? halfFlameA : halfFlameB);
    } else {
      // fullFlame: chama alta 16-bit + faíscas pixeladas ao redor
      const fullFlameA = [
        '.f....',
        'fyf...',
        'fyyf..',
        'yywyf.',
        'ywwyf.',
        'fyyf..',
        '.ff...',
      ];
      const fullFlameB = [
        '..f...',
        '.fyf..',
        'fyyf..',
        'ywyyf.',
        'yywwf.',
        'fyyf..',
        '.ff...',
      ];
      drawRow(2, flickerHigh ? fullFlameA : fullFlameB);

      // Faíscas mágicas estilo SNES piscando
      if (flickerHigh) {
        px(0, 3, Colors.white);
        px(6, 2, flameInner);
        px(17, 4, flameInner);
      } else {
        px(0, 5, flameInner);
        px(5, 1, Colors.white);
        px(16, 6, Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnesPixelLampMascotPainter oldDelegate) =>
      oldDelegate.state != state ||
      oldDelegate.oilPercentage != oilPercentage ||
      oldDelegate.pulse != pulse ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.isDark != isDark;
}
