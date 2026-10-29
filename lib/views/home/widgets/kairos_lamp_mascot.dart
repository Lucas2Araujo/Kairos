import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';

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
