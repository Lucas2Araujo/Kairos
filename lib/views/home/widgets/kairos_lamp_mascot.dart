import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/gamification_service.dart';

/// Mascote Reativo "Lamparina Kairós"
///
/// Inspirado na Parábola das Dez Virgens (Mateus 25).
/// Renderizado em CustomPainter vetorial com bojo de argila, nível de azeite
/// e chama animada que reage aos 4 estados espirituais do dia:
/// - morningIdle: manhã despertando, pavio aguardando o primeiro estudo.
/// - eveningSleepy: tarde/noite sem missões, chama suave quase apagando.
/// - halfFlame: meia ofensiva (1-2 missões), chama acesa acolhedora.
/// - fullFlame: ofensiva completa (3+ missões com Quiz), chama dourada transbordando de brilho.
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
      duration: const Duration(milliseconds: 1800),
    );
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
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
                  painter: _LampPainter(
                    animationValue: _animController.value,
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

class _LampPainter extends CustomPainter {
  final double animationValue;
  final LampMascotState state;
  final double oilPercentage;

  _LampPainter({
    required this.animationValue,
    required this.state,
    required this.oilPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final clayPaint = Paint()
      ..color = const Color(0xFFC77844) // Barro / Terracota bíblica
      ..style = PaintingStyle.fill;

    final clayDarkPaint = Paint()
      ..color = const Color(0xFF8D4A21)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    // 1. Corpo da Lamparina (Bojo oval + Bico + Asa)
    final lampPath = Path();
    // Bico à esquerda (onde fica a chama)
    lampPath.moveTo(w * 0.22, h * 0.52);
    // Borda superior até a boca do reservatório
    lampPath.quadraticBezierTo(w * 0.38, h * 0.50, w * 0.50, h * 0.56);
    // Borda direita até a asa
    lampPath.quadraticBezierTo(w * 0.75, h * 0.52, w * 0.82, h * 0.60);
    // Asa (alça de segurar)
    lampPath.quadraticBezierTo(w * 0.96, h * 0.70, w * 0.82, h * 0.78);
    // Fundo da lamparina
    lampPath.quadraticBezierTo(w * 0.55, h * 0.90, w * 0.28, h * 0.76);
    // Subida até a ponta do bico
    lampPath.quadraticBezierTo(w * 0.16, h * 0.64, w * 0.22, h * 0.52);
    lampPath.close();

    canvas.drawPath(lampPath, clayPaint);
    canvas.drawPath(lampPath, clayDarkPaint);

    // 2. Asa interna (furo da alça)
    final handleHole = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.83, h * 0.69),
        width: w * 0.08,
        height: h * 0.08,
      ));
    final holePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawPath(handleHole, holePaint);
    canvas.drawPath(handleHole, clayDarkPaint..strokeWidth = 1.2);

    // 3. Reservatório de Azeite translúcido brilhante
    final effectiveOil = oilPercentage.clamp(0.15, 1.0);
    final oilHeight = (h * 0.20) * effectiveOil;
    final oilRect = Rect.fromLTRB(w * 0.34, h * 0.78 - oilHeight, w * 0.70, h * 0.80);

    final oilPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.amber.shade300.withValues(alpha: 0.85),
          Colors.amber.shade700.withValues(alpha: 0.90),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(oilRect)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(oilRect, Radius.circular(w * 0.08)),
      oilPaint,
    );

    // 4. Pavio na ponta do bico
    final wickPaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.23, h * 0.54), Offset(w * 0.23, h * 0.46), wickPaint);

    // 5. Olhinhos expressivos da Lamparina (Mascote)
    _drawMascotFace(canvas, w, h);

    // 6. Chama animada na ponta do pavio
    _drawFlame(canvas, w, h);
  }

  void _drawMascotFace(Canvas canvas, double w, double h) {
    final eyePaint = Paint()
      ..color = const Color(0xFF2E1C0C)
      ..style = PaintingStyle.fill;

    final eyeCenterY = h * 0.68;

    if (state == LampMascotState.eveningSleepy) {
      // Olhos fechadinhos dormindo (^ ^)
      final sleepEyePath = Path();
      sleepEyePath.moveTo(w * 0.42, eyeCenterY + 1);
      sleepEyePath.quadraticBezierTo(w * 0.45, eyeCenterY - 3, w * 0.48, eyeCenterY + 1);
      sleepEyePath.moveTo(w * 0.54, eyeCenterY + 1);
      sleepEyePath.quadraticBezierTo(w * 0.57, eyeCenterY - 3, w * 0.60, eyeCenterY + 1);

      final linePaint = Paint()
        ..color = const Color(0xFF2E1C0C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(sleepEyePath, linePaint);
    } else {
      // Olhos abertos e vivos
      canvas.drawCircle(Offset(w * 0.45, eyeCenterY), 2.2, eyePaint);
      canvas.drawCircle(Offset(w * 0.57, eyeCenterY), 2.2, eyePaint);

      // Brilho nos olhos
      final shinePaint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(w * 0.44, eyeCenterY - 0.7), 0.9, shinePaint);
      canvas.drawCircle(Offset(w * 0.56, eyeCenterY - 0.7), 0.9, shinePaint);

      // Sorriso sereno
      final mouthPath = Path();
      mouthPath.moveTo(w * 0.48, eyeCenterY + 4);
      mouthPath.quadraticBezierTo(w * 0.51, eyeCenterY + 6.5, w * 0.54, eyeCenterY + 4);
      final mouthPaint = Paint()
        ..color = const Color(0xFF2E1C0C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(mouthPath, mouthPaint);
    }
  }

  void _drawFlame(Canvas canvas, double w, double h) {
    final flameCenterX = w * 0.23;
    final flameBaseY = h * 0.46;

    final flicker = math.sin(animationValue * math.pi * 2) * 2.0;

    switch (state) {
      case LampMascotState.morningIdle:
        // Pequena faísca azul/amarela aguardando
        final sparkPaint = Paint()
          ..color = Colors.amber.shade400
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(flameCenterX, flameBaseY - 3 + flicker * 0.5), 3.0, sparkPaint);
        break;

      case LampMascotState.eveningSleepy:
        // Chama suave bem tênue
        final sleepyFlame = Path()
          ..moveTo(flameCenterX - 3, flameBaseY)
          ..quadraticBezierTo(flameCenterX - 4, flameBaseY - 8, flameCenterX, flameBaseY - 14 + flicker)
          ..quadraticBezierTo(flameCenterX + 4, flameBaseY - 8, flameCenterX + 3, flameBaseY)
          ..close();
        final flamePaint = Paint()
          ..shader = LinearGradient(
            colors: [Colors.orange.shade300, Colors.amber.shade200],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ).createShader(Rect.fromLTWH(flameCenterX - 5, flameBaseY - 16, 10, 16));
        canvas.drawPath(sleepyFlame, flamePaint);
        break;

      case LampMascotState.halfFlame:
        // Meia ofensiva: chama aconchegante e aquecida (azul na base, âmbar no corpo)
        final flamePath = Path()
          ..moveTo(flameCenterX - 5, flameBaseY)
          ..quadraticBezierTo(
              flameCenterX - 7, flameBaseY - 10, flameCenterX, flameBaseY - 22 + flicker)
          ..quadraticBezierTo(
              flameCenterX + 7, flameBaseY - 10, flameCenterX + 5, flameBaseY)
          ..close();

        final flamePaint = Paint()
          ..shader = const RadialGradient(
            colors: [Colors.lightBlueAccent, Colors.amber, Colors.deepOrange],
            stops: [0.1, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(flameCenterX, flameBaseY - 10), radius: 14));
        canvas.drawPath(flamePath, flamePaint);
        break;

      case LampMascotState.fullFlame:
        // Ofensiva Completa: Chama dourada intensa, alta e radiante
        final flameGlowPaint = Paint()
          ..color = Colors.amber.shade300.withValues(alpha: 0.35 + animationValue * 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(flameCenterX, flameBaseY - 14), 16, flameGlowPaint);

        final flamePath = Path()
          ..moveTo(flameCenterX - 6, flameBaseY)
          ..quadraticBezierTo(
              flameCenterX - 9, flameBaseY - 14, flameCenterX, flameBaseY - 28 + flicker * 1.5)
          ..quadraticBezierTo(
              flameCenterX + 9, flameBaseY - 14, flameCenterX + 6, flameBaseY)
          ..close();

        final flamePaint = Paint()
          ..shader = const LinearGradient(
            colors: [Colors.deepOrange, Colors.amber, Colors.yellowAccent, Colors.white],
            stops: [0.0, 0.4, 0.85, 1.0],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ).createShader(Rect.fromLTWH(flameCenterX - 9, flameBaseY - 30, 18, 30));
        canvas.drawPath(flamePath, flamePaint);

        // Partículas de brilho douradas ao redor
        final sparklePaint = Paint()..color = Colors.amber.shade300;
        final p1 = Offset(flameCenterX - 8 + flicker, flameBaseY - 24);
        final p2 = Offset(flameCenterX + 10 - flicker, flameBaseY - 18);
        final p3 = Offset(flameCenterX + 2, flameBaseY - 32 + flicker);
        canvas.drawCircle(p1, 1.5, sparklePaint);
        canvas.drawCircle(p2, 1.8, sparklePaint);
        canvas.drawCircle(p3, 1.2, sparklePaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _LampPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.state != state ||
        oldDelegate.oilPercentage != oilPercentage;
  }
}
