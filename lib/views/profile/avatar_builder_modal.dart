import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/avatar_config.dart';
import '../../services/gamification_service.dart';

/// Widget que renderiza o Avatar Kairós 2.0 customizado em Canvas vetorial rico
class AvatarCustomWidget extends StatelessWidget {
  final AvatarConfig config;
  final double size;

  const AvatarCustomWidget({
    super.key,
    required this.config,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AvatarPainter(config: config),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final AvatarConfig config;

  _AvatarPainter({required this.config});

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Fundo Circular com Gradiente Suave
    final bgIdx = config.backgroundColorIndex.clamp(0, AvatarConfig.backgroundColors.length - 1);
    final baseBg = AvatarConfig.backgroundColors[bgIdx];
    final rect = Rect.fromCircle(center: center, radius: radius);

    final List<Color> bgGradientColors = bgIdx == 6
        ? const [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFF0EA5E9)]
        : bgIdx == 7
            ? const [Color(0xFFF59E0B), Color(0xFFEA580C), Color(0xFF7C2D12)]
            : [_lighten(baseBg, 0.12), baseBg, _darken(baseBg, 0.14)];

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: bgGradientColors,
      ).createShader(rect);
    canvas.drawCircle(center, radius, bgPaint);

    // Brilho radial sutil ao fundo da cabeça
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(center.dx, center.dy - radius * 0.1),
        radius: radius * 0.85,
      ));
    canvas.drawCircle(center, radius, glowPaint);

    // Clip circular para manter torso/cabelos alinhados na borda
    canvas.save();
    final clipPath = Path()..addOval(rect);
    canvas.clipPath(clipPath);

    final skinColor = AvatarConfig.skinTones[
        config.skinToneIndex.clamp(0, AvatarConfig.skinTones.length - 1)];
    final skinShadow = _darken(skinColor, 0.09);
    final hairColor = AvatarConfig.hairColors[
        config.hairColorIndex.clamp(0, AvatarConfig.hairColors.length - 1)];
    final outfitColor = AvatarConfig.outfitColors[
        config.outfitColorIndex.clamp(0, AvatarConfig.outfitColors.length - 1)];

    // Cabelo longo/afro parte traseira antes do pescoço/rosto
    _drawBackHair(canvas, Offset(center.dx, center.dy - radius * 0.05), radius * 0.45,
        hairColor, config.hairStyleIndex);

    // 2. Pescoço com sombra suave abaixo do queixo
    final neckRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.42),
      width: radius * 0.36,
      height: radius * 0.38,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(neckRect, Radius.circular(radius * 0.12)),
      Paint()..color = skinColor,
    );
    final chinShadowRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.33),
      width: radius * 0.36,
      height: radius * 0.15,
    );
    canvas.drawOval(chinShadowRect, Paint()..color = skinShadow.withValues(alpha: 0.65));

    // 3. Traje / Roupa Personalizável
    _drawOutfit(
      canvas,
      size,
      center,
      radius,
      config.outfitIndex,
      outfitColor,
    );

    // 4. Orelhas e Rosto com Formato Selecionável
    final headCenter = Offset(center.dx, center.dy - radius * 0.05);
    final headRadius = radius * 0.45;

    final earPaint = Paint()..color = skinShadow;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - headRadius * 0.96, headCenter.dy + headRadius * 0.06),
        width: headRadius * 0.28,
        height: headRadius * 0.38,
      ),
      earPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx + headRadius * 0.96, headCenter.dy + headRadius * 0.06),
        width: headRadius * 0.28,
        height: headRadius * 0.38,
      ),
      earPaint,
    );

    _drawFaceShape(canvas, headCenter, headRadius, skinColor, config.faceShapeIndex);

    // Blush suave nas bochechas
    final blushPaint = Paint()..color = const Color(0xFFFF758F).withValues(alpha: 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx - headRadius * 0.52, headCenter.dy + headRadius * 0.22),
        width: headRadius * 0.32,
        height: headRadius * 0.18,
      ),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(headCenter.dx + headRadius * 0.52, headCenter.dy + headRadius * 0.22),
        width: headRadius * 0.32,
        height: headRadius * 0.18,
      ),
      blushPaint,
    );

    // 5. Barba / Bigode (se selecionado)
    _drawFacialHair(canvas, headCenter, headRadius, hairColor, config.facialHairIndex);

    // 6. Olhos, Sobrancelhas & Expressão
    _drawExpression(canvas, headCenter, headRadius, hairColor, config.expressionIndex);

    // 7. Cabelo frontal / topo com brilho
    _drawFrontHair(canvas, headCenter, headRadius, hairColor, config.hairStyleIndex);

    // 8. Óculos
    _drawGlasses(canvas, headCenter, headRadius, config.glassesIndex);

    canvas.restore(); // Fim do clip circular

    // Borda interna sutil de acabamento
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // 9. Acessórios / Molduras / Insígnias
    _drawAccessory(canvas, center, radius, config.accessoryIndex);
  }

  void _drawFaceShape(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    Color skinColor,
    int shapeIdx,
  ) {
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 1.15,
        colors: [_lighten(skinColor, 0.05), skinColor, _darken(skinColor, 0.05)],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius * 1.1));

    switch (shapeIdx) {
      case 1:
        // Jovem Arredondado
        canvas.drawCircle(headCenter, headRadius * 1.02, headPaint);
        break;
      case 2:
        // Angular Definido
        final rrect = RRect.fromRectAndCorners(
          Rect.fromCenter(
            center: headCenter,
            width: headRadius * 1.92,
            height: headRadius * 2.08,
          ),
          topLeft: Radius.circular(headRadius * 0.9),
          topRight: Radius.circular(headRadius * 0.9),
          bottomLeft: Radius.circular(headRadius * 0.58),
          bottomRight: Radius.circular(headRadius * 0.58),
        );
        canvas.drawRRect(rrect, headPaint);
        break;
      case 3:
        // Delicado (queixo afilado suave)
        final path = Path();
        path.moveTo(headCenter.dx, headCenter.dy - headRadius * 1.02);
        path.cubicTo(
          headCenter.dx + headRadius * 1.06,
          headCenter.dy - headRadius * 1.02,
          headCenter.dx + headRadius * 0.98,
          headCenter.dy + headRadius * 0.45,
          headCenter.dx,
          headCenter.dy + headRadius * 1.06,
        );
        path.cubicTo(
          headCenter.dx - headRadius * 0.98,
          headCenter.dy + headRadius * 0.45,
          headCenter.dx - headRadius * 1.06,
          headCenter.dy - headRadius * 1.02,
          headCenter.dx,
          headCenter.dy - headRadius * 1.02,
        );
        canvas.drawPath(path, headPaint);
        break;
      case 0:
      default:
        // Oval Suave
        canvas.drawOval(
          Rect.fromCenter(
            center: headCenter,
            width: headRadius * 1.94,
            height: headRadius * 2.08,
          ),
          headPaint,
        );
        break;
    }
  }

  void _drawOutfit(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
    int outfitIdx,
    Color baseColor,
  ) {
    Color primary = baseColor;
    if (outfitIdx == 4) primary = const Color(0xFF8D6E63); // Túnica Bereana terrosa
    if (outfitIdx == 6) primary = const Color(0xFFF8FAFC); // Manto de Luz Dourada

    final bodyPath = Path()
      ..moveTo(center.dx - radius * 0.9, size.height + 4)
      ..quadraticBezierTo(
        center.dx - radius * 0.56,
        center.dy + radius * 0.48,
        center.dx - radius * 0.2,
        center.dy + radius * 0.56,
      )
      ..lineTo(center.dx + radius * 0.2, center.dy + radius * 0.56)
      ..quadraticBezierTo(
        center.dx + radius * 0.56,
        center.dy + radius * 0.48,
        center.dx + radius * 0.9,
        size.height + 4,
      )
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(primary, 0.06), primary, _darken(primary, 0.1)],
      ).createShader(Rect.fromLTWH(0, center.dy + radius * 0.45, size.width, radius));
    canvas.drawPath(bodyPath, bodyPaint);

    final neckY = center.dy + radius * 0.56;

    switch (outfitIdx) {
      case 1:
      case 5:
        // Social de Sábado (1) ou Mestre Sabatino (5 - com lapela dourada)
        final shirtPath = Path()
          ..moveTo(center.dx - radius * 0.18, neckY)
          ..lineTo(center.dx, size.height)
          ..lineTo(center.dx + radius * 0.18, neckY)
          ..close();
        canvas.drawPath(shirtPath, Paint()..color = Colors.white);

        final tiePaint = Paint()
          ..color = outfitIdx == 5 ? const Color(0xFFD97706) : const Color(0xFFC1121F);
        final tiePath = Path()
          ..moveTo(center.dx - radius * 0.05, neckY + radius * 0.04)
          ..lineTo(center.dx + radius * 0.05, neckY + radius * 0.04)
          ..lineTo(center.dx + radius * 0.07, size.height)
          ..lineTo(center.dx - radius * 0.07, size.height)
          ..close();
        canvas.drawPath(tiePath, tiePaint);

        if (outfitIdx == 5) {
          final pinPaint = Paint()..color = const Color(0xFFFFD166);
          canvas.drawCircle(
            Offset(center.dx + radius * 0.3, neckY + radius * 0.2),
            radius * 0.055,
            pinPaint,
          );
        }
        break;

      case 2:
        // Moletom Jovem (capuz + cordões)
        final hoodPaint = Paint()
          ..color = _darken(primary, 0.12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.08
          ..strokeCap = StrokeCap.round;
        final hoodPath = Path()
          ..moveTo(center.dx - radius * 0.28, neckY + radius * 0.02)
          ..quadraticBezierTo(center.dx, neckY + radius * 0.2, center.dx + radius * 0.28, neckY + radius * 0.02);
        canvas.drawPath(hoodPath, hoodPaint);

        final cordPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = radius * 0.03
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(center.dx - radius * 0.11, neckY + radius * 0.12),
          Offset(center.dx - radius * 0.11, neckY + radius * 0.32),
          cordPaint,
        );
        canvas.drawLine(
          Offset(center.dx + radius * 0.11, neckY + radius * 0.12),
          Offset(center.dx + radius * 0.11, neckY + radius * 0.32),
          cordPaint,
        );
        break;

      case 3:
        // Uniforme com Lenço Amarelo
        final scarfPath = Path()
          ..moveTo(center.dx - radius * 0.3, neckY)
          ..lineTo(center.dx, neckY + radius * 0.34)
          ..lineTo(center.dx + radius * 0.3, neckY)
          ..close();
        canvas.drawPath(scarfPath, Paint()..color = const Color(0xFFFFBE0B));
        canvas.drawCircle(
          Offset(center.dx, neckY + radius * 0.18),
          radius * 0.055,
          Paint()..color = const Color(0xFF1D3557),
        );
        break;

      case 4:
        // Túnica Bereana (faixa transversal)
        final sashPath = Path()
          ..moveTo(center.dx - radius * 0.45, neckY - radius * 0.02)
          ..lineTo(center.dx - radius * 0.22, neckY - radius * 0.02)
          ..lineTo(center.dx + radius * 0.35, size.height + 2)
          ..lineTo(center.dx + radius * 0.1, size.height + 2)
          ..close();
        canvas.drawPath(sashPath, Paint()..color = const Color(0xFFD4A373));
        break;

      case 6:
        // Manto de Luz Dourada (bordado áureo)
        final goldTrim = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.07;
        final trimPath = Path()
          ..moveTo(center.dx - radius * 0.24, neckY)
          ..quadraticBezierTo(center.dx, neckY + radius * 0.22, center.dx + radius * 0.24, neckY);
        canvas.drawPath(trimPath, goldTrim);
        break;

      case 7:
        // Jaqueta da Comunidade (gola contrastante + listra)
        final zipPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = radius * 0.035;
        canvas.drawLine(Offset(center.dx, neckY + radius * 0.08), Offset(center.dx, size.height), zipPaint);
        canvas.drawCircle(
          Offset(center.dx - radius * 0.28, neckY + radius * 0.22),
          radius * 0.06,
          Paint()..color = const Color(0xFFFFD166),
        );
        break;

      case 0:
      default:
        // Camiseta Casual com gola limpa
        final collarPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.055;
        final collarPath = Path()
          ..moveTo(center.dx - radius * 0.22, neckY)
          ..quadraticBezierTo(center.dx, neckY + radius * 0.15, center.dx + radius * 0.22, neckY);
        canvas.drawPath(collarPath, collarPaint);
        break;
    }
  }

  void _drawBackHair(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    Color hairColor,
    int styleIndex,
  ) {
    final backPaint = Paint()..color = _darken(hairColor, 0.06);
    if (styleIndex == 2) {
      // Longo Ondulado atrás do pescoço
      final path = Path()
        ..moveTo(headCenter.dx - headRadius * 1.15, headCenter.dy)
        ..quadraticBezierTo(
          headCenter.dx - headRadius * 1.32,
          headCenter.dy + headRadius * 0.9,
          headCenter.dx - headRadius * 0.95,
          headCenter.dy + headRadius * 1.45,
        )
        ..lineTo(headCenter.dx + headRadius * 0.95, headCenter.dy + headRadius * 1.45)
        ..quadraticBezierTo(
          headCenter.dx + headRadius * 1.32,
          headCenter.dy + headRadius * 0.9,
          headCenter.dx + headRadius * 1.15,
          headCenter.dy,
        )
        ..close();
      canvas.drawPath(path, backPaint);
    } else if (styleIndex == 6) {
      // Black Power / Afro volumoso
      canvas.drawCircle(
        Offset(headCenter.dx, headCenter.dy - headRadius * 0.18),
        headRadius * 1.36,
        backPaint,
      );
    }
  }

  void _drawFrontHair(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    Color hairColor,
    int styleIndex,
  ) {
    if (styleIndex == 5) {
      // Raspado / Careca sutil
      final buzzPaint = Paint()..color = hairColor.withValues(alpha: 0.16);
      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headRadius * 1.01),
        math.pi,
        math.pi,
        false,
        buzzPaint,
      );
      return;
    }

    final hairPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_lighten(hairColor, 0.08), hairColor, _darken(hairColor, 0.05)],
      ).createShader(Rect.fromCircle(center: headCenter, radius: headRadius * 1.4));

    switch (styleIndex) {
      case 1:
        // Cacheado Volumoso
        for (double angle = -math.pi * 0.98; angle <= -0.02; angle += 0.28) {
          final offset = Offset(
            headCenter.dx + (headRadius * 1.05) * math.cos(angle),
            headCenter.dy + (headRadius * 1.02) * math.sin(angle),
          );
          canvas.drawCircle(offset, headRadius * 0.3, hairPaint);
        }
        break;

      case 2:
        // Longo Ondulado (franja lateral fluida)
        final path = Path()
          ..moveTo(headCenter.dx - headRadius * 1.08, headCenter.dy + headRadius * 0.15)
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 1.18,
            headCenter.dy - headRadius * 1.25,
            headCenter.dx,
            headCenter.dy - headRadius * 1.2,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 1.18,
            headCenter.dy - headRadius * 1.25,
            headCenter.dx + headRadius * 1.08,
            headCenter.dy + headRadius * 0.15,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 0.45,
            headCenter.dy - headRadius * 0.55,
            headCenter.dx - headRadius * 0.2,
            headCenter.dy - headRadius * 0.62,
          )
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 0.75,
            headCenter.dy - headRadius * 0.45,
            headCenter.dx - headRadius * 1.08,
            headCenter.dy + headRadius * 0.15,
          );
        canvas.drawPath(path, hairPaint);
        break;

      case 3:
        // Topete Moderno
        final path = Path()
          ..moveTo(headCenter.dx - headRadius * 0.96, headCenter.dy - headRadius * 0.08)
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 0.98,
            headCenter.dy - headRadius * 1.48,
            headCenter.dx + headRadius * 0.24,
            headCenter.dy - headRadius * 1.36,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 1.12,
            headCenter.dy - headRadius * 0.9,
            headCenter.dx + headRadius * 0.96,
            headCenter.dy - headRadius * 0.08,
          )
          ..quadraticBezierTo(
            headCenter.dx,
            headCenter.dy - headRadius * 0.55,
            headCenter.dx - headRadius * 0.96,
            headCenter.dy - headRadius * 0.08,
          );
        canvas.drawPath(path, hairPaint);
        break;

      case 4:
        // Coque Alto
        canvas.drawCircle(
          Offset(headCenter.dx, headCenter.dy - headRadius * 1.28),
          headRadius * 0.42,
          hairPaint,
        );
        final base = Path()
          ..moveTo(headCenter.dx - headRadius * 1.0, headCenter.dy - headRadius * 0.05)
          ..quadraticBezierTo(
            headCenter.dx,
            headCenter.dy - headRadius * 1.35,
            headCenter.dx + headRadius * 1.0,
            headCenter.dy - headRadius * 0.05,
          )
          ..quadraticBezierTo(
            headCenter.dx,
            headCenter.dy - headRadius * 0.62,
            headCenter.dx - headRadius * 1.0,
            headCenter.dy - headRadius * 0.05,
          );
        canvas.drawPath(base, hairPaint);
        break;

      case 6:
        // Black Power / Afro (contorno de nuvem no topo)
        for (double angle = -math.pi * 1.05; angle <= 0.05; angle += 0.26) {
          final offset = Offset(
            headCenter.dx + (headRadius * 1.18) * math.cos(angle),
            headCenter.dy - headRadius * 0.12 + (headRadius * 1.12) * math.sin(angle),
          );
          canvas.drawCircle(offset, headRadius * 0.34, hairPaint);
        }
        break;

      case 7:
        // Médio com Franja
        final path = Path()
          ..moveTo(headCenter.dx - headRadius * 1.06, headCenter.dy + headRadius * 0.05)
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 1.08,
            headCenter.dy - headRadius * 1.28,
            headCenter.dx,
            headCenter.dy - headRadius * 1.22,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 1.08,
            headCenter.dy - headRadius * 1.28,
            headCenter.dx + headRadius * 1.06,
            headCenter.dy + headRadius * 0.05,
          )
          ..lineTo(headCenter.dx + headRadius * 0.65, headCenter.dy - headRadius * 0.36)
          ..lineTo(headCenter.dx + headRadius * 0.25, headCenter.dy - headRadius * 0.22)
          ..lineTo(headCenter.dx - headRadius * 0.15, headCenter.dy - headRadius * 0.38)
          ..lineTo(headCenter.dx - headRadius * 0.55, headCenter.dy - headRadius * 0.22)
          ..close();
        canvas.drawPath(path, hairPaint);
        break;

      case 0:
      default:
        // Curto Elegante
        final path = Path()
          ..moveTo(headCenter.dx - headRadius * 1.0, headCenter.dy + headRadius * 0.02)
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 1.08,
            headCenter.dy - headRadius * 1.25,
            headCenter.dx,
            headCenter.dy - headRadius * 1.18,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 1.08,
            headCenter.dy - headRadius * 1.25,
            headCenter.dx + headRadius * 1.0,
            headCenter.dy + headRadius * 0.02,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 0.55,
            headCenter.dy - headRadius * 0.42,
            headCenter.dx,
            headCenter.dy - headRadius * 0.58,
          )
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 0.55,
            headCenter.dy - headRadius * 0.42,
            headCenter.dx - headRadius * 1.0,
            headCenter.dy + headRadius * 0.02,
          );
        canvas.drawPath(path, hairPaint);
        break;
    }
  }

  void _drawFacialHair(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    Color hairColor,
    int facialHairIdx,
  ) {
    if (facialHairIdx <= 0) return;

    switch (facialHairIdx) {
      case 1:
        // Barba Sutil (sombreado no maxilar)
        final stubblePaint = Paint()..color = hairColor.withValues(alpha: 0.26);
        final path = Path()
          ..addArc(
            Rect.fromCenter(
              center: Offset(headCenter.dx, headCenter.dy + headRadius * 0.06),
              width: headRadius * 1.82,
              height: headRadius * 1.92,
            ),
            0.12,
            math.pi - 0.24,
          );
        canvas.drawPath(path, stubblePaint);
        break;

      case 2:
        // Cavanhaque + Bigode
        final beardPaint = Paint()..color = hairColor.withValues(alpha: 0.85);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(headCenter.dx, headCenter.dy + headRadius * 0.34),
              width: headRadius * 0.52,
              height: headRadius * 0.1,
            ),
            Radius.circular(headRadius * 0.05),
          ),
          beardPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(headCenter.dx, headCenter.dy + headRadius * 0.86),
            width: headRadius * 0.55,
            height: headRadius * 0.3,
          ),
          beardPaint,
        );
        break;

      case 3:
        // Barba Cheia
        final fullBeard = Paint()..color = hairColor.withValues(alpha: 0.9);
        final path = Path()
          ..moveTo(headCenter.dx - headRadius * 0.92, headCenter.dy + headRadius * 0.14)
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 0.88,
            headCenter.dy + headRadius * 1.08,
            headCenter.dx,
            headCenter.dy + headRadius * 1.08,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 0.88,
            headCenter.dy + headRadius * 1.08,
            headCenter.dx + headRadius * 0.92,
            headCenter.dy + headRadius * 0.14,
          )
          ..quadraticBezierTo(
            headCenter.dx + headRadius * 0.45,
            headCenter.dy + headRadius * 0.52,
            headCenter.dx,
            headCenter.dy + headRadius * 0.44,
          )
          ..quadraticBezierTo(
            headCenter.dx - headRadius * 0.45,
            headCenter.dy + headRadius * 0.52,
            headCenter.dx - headRadius * 0.92,
            headCenter.dy + headRadius * 0.14,
          );
        canvas.drawPath(path, fullBeard);
        break;
    }
  }

  void _drawExpression(
    Canvas canvas,
    Offset headCenter,
    double headRadius,
    Color hairColor,
    int expressionIndex,
  ) {
    final eyePaint = Paint()..color = const Color(0xFF1E293B);
    final strokePaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = headRadius * 0.075;

    final leftEye = Offset(headCenter.dx - headRadius * 0.36, headCenter.dy - headRadius * 0.04);
    final rightEye = Offset(headCenter.dx + headRadius * 0.36, headCenter.dy - headRadius * 0.04);

    if (expressionIndex == 2) {
      // Alegre com Olhos Fechados (^^)
      canvas.drawPath(
        Path()..addArc(Rect.fromCircle(center: leftEye, radius: headRadius * 0.15), math.pi, math.pi),
        strokePaint,
      );
      canvas.drawPath(
        Path()..addArc(Rect.fromCircle(center: rightEye, radius: headRadius * 0.15), math.pi, math.pi),
        strokePaint,
      );
    } else if (expressionIndex == 4) {
      // Piscadela Amigável
      _drawSingleEye(canvas, leftEye, headRadius, eyePaint);
      canvas.drawPath(
        Path()..addArc(Rect.fromCircle(center: rightEye, radius: headRadius * 0.15), math.pi, math.pi),
        strokePaint,
      );
    } else {
      _drawSingleEye(canvas, leftEye, headRadius, eyePaint);
      _drawSingleEye(canvas, rightEye, headRadius, eyePaint);
    }

    // Sobrancelhas acompanhando a cor do cabelo
    final browPaint = Paint()
      ..color = _darken(hairColor, 0.05)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = headRadius * 0.075;
    canvas.drawLine(
      Offset(leftEye.dx - headRadius * 0.16, leftEye.dy - headRadius * 0.24),
      Offset(leftEye.dx + headRadius * 0.15, leftEye.dy - headRadius * 0.26),
      browPaint,
    );
    canvas.drawLine(
      Offset(rightEye.dx - headRadius * 0.15, rightEye.dy - headRadius * 0.26),
      Offset(rightEye.dx + headRadius * 0.16, rightEye.dy - headRadius * 0.24),
      browPaint,
    );

    // Nariz delicado
    final nosePaint = Paint()
      ..color = const Color(0x30000000)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = headRadius * 0.055;
    final nosePath = Path()
      ..moveTo(headCenter.dx, headCenter.dy + headRadius * 0.06)
      ..quadraticBezierTo(
        headCenter.dx + headRadius * 0.08,
        headCenter.dy + headRadius * 0.2,
        headCenter.dx - headRadius * 0.02,
        headCenter.dy + headRadius * 0.22,
      );
    canvas.drawPath(nosePath, nosePaint);

    // Boca
    final mouthCenter = Offset(headCenter.dx, headCenter.dy + headRadius * 0.44);
    switch (expressionIndex) {
      case 1:
        // Sereno / Confiante
        final mouthPath = Path()
          ..moveTo(mouthCenter.dx - headRadius * 0.2, mouthCenter.dy)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy + headRadius * 0.1,
            mouthCenter.dx + headRadius * 0.22,
            mouthCenter.dy - headRadius * 0.03,
          );
        canvas.drawPath(mouthPath, strokePaint);
        break;
      case 3:
        // Contemplativo
        canvas.drawLine(
          Offset(mouthCenter.dx - headRadius * 0.15, mouthCenter.dy + headRadius * 0.02),
          Offset(mouthCenter.dx + headRadius * 0.15, mouthCenter.dy + headRadius * 0.02),
          strokePaint,
        );
        break;
      case 0:
      case 2:
      case 4:
      default:
        // Sorridente com brilho de dentes sutil
        final mouthPath = Path()
          ..moveTo(mouthCenter.dx - headRadius * 0.25, mouthCenter.dy - headRadius * 0.03)
          ..quadraticBezierTo(
            mouthCenter.dx,
            mouthCenter.dy + headRadius * 0.25,
            mouthCenter.dx + headRadius * 0.25,
            mouthCenter.dy - headRadius * 0.03,
          )
          ..close();
        canvas.drawPath(mouthPath, Paint()..color = const Color(0xFFB23A48));
        canvas.drawPath(mouthPath, strokePaint);
        break;
    }
  }

  void _drawSingleEye(Canvas canvas, Offset pos, double headRadius, Paint eyePaint) {
    canvas.drawCircle(pos, headRadius * 0.115, eyePaint);
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(
      Offset(pos.dx - headRadius * 0.035, pos.dy - headRadius * 0.035),
      headRadius * 0.04,
      shinePaint,
    );
  }

  void _drawGlasses(Canvas canvas, Offset headCenter, double headRadius, int glassesIndex) {
    if (glassesIndex == 0) return;

    final leftCenter = Offset(headCenter.dx - headRadius * 0.36, headCenter.dy - headRadius * 0.04);
    final rightCenter = Offset(headCenter.dx + headRadius * 0.36, headCenter.dy - headRadius * 0.04);

    final lensTint = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final framePaint = Paint()
      ..color = glassesIndex == 3 ? const Color(0xFFD4AF37) : const Color(0xFF1F2937)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headRadius * 0.068;

    switch (glassesIndex) {
      case 1:
        final gRadius = headRadius * 0.24;
        canvas.drawCircle(leftCenter, gRadius, lensTint);
        canvas.drawCircle(rightCenter, gRadius, lensTint);
        canvas.drawCircle(leftCenter, gRadius, framePaint);
        canvas.drawCircle(rightCenter, gRadius, framePaint);
        canvas.drawLine(
          Offset(leftCenter.dx + gRadius, leftCenter.dy),
          Offset(rightCenter.dx - gRadius, rightCenter.dy),
          framePaint,
        );
        break;
      case 2:
        final rRectL = RRect.fromRectAndRadius(
          Rect.fromCenter(center: leftCenter, width: headRadius * 0.5, height: headRadius * 0.35),
          Radius.circular(headRadius * 0.07),
        );
        final rRectR = RRect.fromRectAndRadius(
          Rect.fromCenter(center: rightCenter, width: headRadius * 0.5, height: headRadius * 0.35),
          Radius.circular(headRadius * 0.07),
        );
        canvas.drawRRect(rRectL, lensTint);
        canvas.drawRRect(rRectR, lensTint);
        canvas.drawRRect(rRectL, framePaint);
        canvas.drawRRect(rRectR, framePaint);
        canvas.drawLine(
          Offset(leftCenter.dx + headRadius * 0.25, leftCenter.dy),
          Offset(rightCenter.dx - headRadius * 0.25, rightCenter.dy),
          framePaint,
        );
        break;
      case 3:
        canvas.drawOval(
          Rect.fromCenter(center: leftCenter, width: headRadius * 0.5, height: headRadius * 0.4),
          framePaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: rightCenter, width: headRadius * 0.5, height: headRadius * 0.4),
          framePaint,
        );
        canvas.drawLine(
          Offset(leftCenter.dx + headRadius * 0.23, leftCenter.dy - headRadius * 0.05),
          Offset(rightCenter.dx - headRadius * 0.23, rightCenter.dy - headRadius * 0.05),
          framePaint,
        );
        break;
      case 4:
        // Meia-Armação Intelectual
        final topBar = Paint()
          ..color = const Color(0xFF1E293B)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = headRadius * 0.095;
        canvas.drawLine(
          Offset(leftCenter.dx - headRadius * 0.25, leftCenter.dy - headRadius * 0.16),
          Offset(leftCenter.dx + headRadius * 0.25, leftCenter.dy - headRadius * 0.16),
          topBar,
        );
        canvas.drawLine(
          Offset(rightCenter.dx - headRadius * 0.25, rightCenter.dy - headRadius * 0.16),
          Offset(rightCenter.dx + headRadius * 0.25, rightCenter.dy - headRadius * 0.16),
          topBar,
        );
        canvas.drawLine(
          Offset(leftCenter.dx + headRadius * 0.22, leftCenter.dy - headRadius * 0.14),
          Offset(rightCenter.dx - headRadius * 0.22, rightCenter.dy - headRadius * 0.14),
          framePaint,
        );
        break;
    }
  }

  void _drawAccessory(Canvas canvas, Offset center, double radius, int accessoryIndex) {
    if (accessoryIndex == 0) return;

    switch (accessoryIndex) {
      case 1:
        // Aura Dourada (Azeite)
        final auraPaint = Paint()
          ..color = const Color(0xFFFFB703).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.085;
        canvas.drawCircle(center, radius - radius * 0.04, auraPaint);
        break;
      case 2:
        // Ramo de Oliveira
        final leafPaint = Paint()..color = const Color(0xFF52B788);
        for (int i = 0; i < 6; i++) {
          final angle = math.pi * 0.6 + (i * 0.16);
          final p = Offset(
            center.dx + radius * 0.9 * math.cos(angle),
            center.dy + radius * 0.9 * math.sin(angle),
          );
          canvas.drawCircle(p, radius * 0.065, leafPaint);
        }
        break;
      case 3:
        // Pingente Cruz / Fé
        final crossPaint = Paint()
          ..color = const Color(0xFFFFD166)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = radius * 0.06;
        final pCenter = Offset(center.dx, center.dy + radius * 0.76);
        canvas.drawLine(
          Offset(pCenter.dx, pCenter.dy - radius * 0.09),
          Offset(pCenter.dx, pCenter.dy + radius * 0.09),
          crossPaint,
        );
        canvas.drawLine(
          Offset(pCenter.dx - radius * 0.06, pCenter.dy - radius * 0.03),
          Offset(pCenter.dx + radius * 0.06, pCenter.dy - radius * 0.03),
          crossPaint,
        );
        break;
      case 4:
        // Coroa da Vitória
        final crownPaint = Paint()..color = const Color(0xFFFFD166);
        final crownPath = Path();
        final cTop = center.dy - radius * 0.76;
        crownPath.moveTo(center.dx - radius * 0.34, cTop);
        crownPath.lineTo(center.dx - radius * 0.42, cTop - radius * 0.22);
        crownPath.lineTo(center.dx - radius * 0.15, cTop - radius * 0.09);
        crownPath.lineTo(center.dx, cTop - radius * 0.26);
        crownPath.lineTo(center.dx + radius * 0.15, cTop - radius * 0.09);
        crownPath.lineTo(center.dx + radius * 0.42, cTop - radius * 0.22);
        crownPath.lineTo(center.dx + radius * 0.34, cTop);
        crownPath.close();
        canvas.drawPath(crownPath, crownPaint);
        break;
      case 5:
        // Auréola Sentinela da Manhã
        final haloPaint = Paint()
          ..color = const Color(0xFFFFEA00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.065;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(center.dx, center.dy - radius * 0.78),
            width: radius * 0.72,
            height: radius * 0.18,
          ),
          haloPaint,
        );
        break;
      case 6:
        // Insígnia da Turma (Medalha de Comunidade no canto inferior direito)
        final badgeCenter = Offset(center.dx + radius * 0.66, center.dy + radius * 0.66);
        canvas.drawCircle(badgeCenter, radius * 0.22, Paint()..color = const Color(0xFF4F46E5));
        canvas.drawCircle(
          badgeCenter,
          radius * 0.22,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.04,
        );
        canvas.drawCircle(badgeCenter, radius * 0.09, Paint()..color = const Color(0xFFFFD166));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.config != config;
  }
}

/// Modal / BottomSheet de Customização do Avatar Kairós 2.0 com itens especiais de conquistas
class AvatarBuilderModal extends StatefulWidget {
  final AvatarConfig initialConfig;

  const AvatarBuilderModal({
    super.key,
    required this.initialConfig,
  });

  static Future<AvatarConfig?> show(BuildContext context, {AvatarConfig? currentConfig}) {
    final gamification = GamificationService();
    final config = currentConfig ?? gamification.avatarConfig;

    return showModalBottomSheet<AvatarConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AvatarBuilderModal(initialConfig: config),
    );
  }

  @override
  State<AvatarBuilderModal> createState() => _AvatarBuilderModalState();
}

class _AvatarBuilderModalState extends State<AvatarBuilderModal>
    with SingleTickerProviderStateMixin {
  late AvatarConfig _config;
  late TabController _tabController;

  final List<String> _tabs = const [
    'Fundo',
    'Rosto & Pele',
    'Cabelo & Barba',
    'Roupas',
    'Expressão & Óculos',
    'Acessórios & Título',
  ];

  @override
  void initState() {
    super.initState();
    _config = widget.initialConfig;
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showLockedHint(String trophyId) {
    final def = GamificationService().getAchievementById(trophyId);
    final title = def?.title ?? trophyId;
    final desc = def?.description ?? 'Continue sua jornada espiritual para desbloquear.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('🔒 Desbloqueie com a conquista "$title": $desc'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gamification = GamificationService();
    final featuredDef = _config.featuredBadge != null
        ? gamification.getAchievementById(_config.featuredBadge!)
        : null;

    return Container(
      height: (MediaQuery.sizeOf(context).height * 0.84).clamp(420.0, 760.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Criar Avatar Kairós',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Surpreenda-me',
                  onPressed: _randomizeUnlocked,
                  icon: const Icon(Icons.casino_outlined),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: () {
                    gamification.updateAvatarConfig(_config);
                    gamification.setUseCustomAvatar(true);
                    Navigator.of(context).pop(_config);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Salvar'),
                ),
              ],
            ),
          ),

          // Preview do Avatar + Insígnia em destaque
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.35),
                      width: 3,
                    ),
                  ),
                  child: AvatarCustomWidget(
                    config: _config,
                    size: 104,
                  ),
                ),
                if (featuredDef != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: featuredDef.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: featuredDef.color.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(featuredDef.icon, size: 13, color: featuredDef.color),
                        const SizedBox(width: 5),
                        Text(
                          featuredDef.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: featuredDef.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((name) => Tab(text: name)).toList(),
          ),

          // Conteúdo das Abas
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBackgroundTab(theme, gamification),
                _buildFaceAndSkinTab(theme),
                _buildHairAndBeardTab(theme),
                _buildOutfitTab(theme, gamification),
                _buildExpressionAndGlassesTab(theme),
                _buildAccessoriesAndBadgeTab(theme, gamification),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _randomizeUnlocked() {
    final rnd = math.Random();
    setState(() {
      _config = _config.copyWith(
        skinToneIndex: rnd.nextInt(AvatarConfig.skinTones.length),
        faceShapeIndex: rnd.nextInt(AvatarConfig.faceShapes.length),
        hairStyleIndex: rnd.nextInt(AvatarConfig.hairStyles.length),
        hairColorIndex: rnd.nextInt(AvatarConfig.hairColors.length),
        facialHairIndex: rnd.nextInt(2), // leve ou sem barba por padrão
        expressionIndex: rnd.nextInt(AvatarConfig.expressions.length),
        glassesIndex: rnd.nextInt(AvatarConfig.glassesList.length),
        outfitIndex: rnd.nextInt(4), // 0..3 são sempre livres
        outfitColorIndex: rnd.nextInt(AvatarConfig.outfitColors.length),
        backgroundColorIndex: rnd.nextInt(6), // 0..5 sempre livres
      );
    });
  }

  Widget _buildBackgroundTab(ThemeData theme, GamificationService gamification) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisExtent: 74,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: AvatarConfig.backgroundColors.length,
      itemBuilder: (context, index) {
        final req = AvatarConfig.requiredTrophyForBackground(index);
        final locked = req != null && !gamification.isTrophyUnlocked(req);
        final isSelected = _config.backgroundColorIndex == index;
        final color = AvatarConfig.backgroundColors[index];

        return InkWell(
          onTap: () {
            if (locked) {
              _showLockedHint(req);
              return;
            }
            setState(() => _config = _config.copyWith(backgroundColorIndex: index));
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  locked
                      ? Icons.lock_rounded
                      : (isSelected ? Icons.check_circle_rounded : Icons.circle_outlined),
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AvatarConfig.backgroundNames[index],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaceAndSkinTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Tom de Pele', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(AvatarConfig.skinTones.length, (i) {
            final isSelected = _config.skinToneIndex == i;
            return InkWell(
              onTap: () => setState(() => _config = _config.copyWith(skinToneIndex: i)),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AvatarConfig.skinTones[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.white,
                    width: isSelected ? 3.5 : 1.5,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Text(
          'Formato do Rosto',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(AvatarConfig.faceShapes.length, (i) {
            return ChoiceChip(
              label: Text(AvatarConfig.faceShapes[i]),
              selected: _config.faceShapeIndex == i,
              onSelected: (_) => setState(() => _config = _config.copyWith(faceShapeIndex: i)),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildHairAndBeardTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cor do Cabelo e Barba',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(AvatarConfig.hairColors.length, (i) {
            final isSelected = _config.hairColorIndex == i;
            return InkWell(
              onTap: () => setState(() => _config = _config.copyWith(hairColorIndex: i)),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AvatarConfig.hairColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.amber, size: 18) : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        Text(
          'Estilo de Cabelo',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(AvatarConfig.hairStyles.length, (i) {
            return ChoiceChip(
              label: Text(AvatarConfig.hairStyles[i]),
              selected: _config.hairStyleIndex == i,
              onSelected: (_) => setState(() => _config = _config.copyWith(hairStyleIndex: i)),
            );
          }),
        ),
        const SizedBox(height: 18),
        Text(
          'Barba & Bigode',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(AvatarConfig.facialHairStyles.length, (i) {
            return ChoiceChip(
              label: Text(AvatarConfig.facialHairStyles[i]),
              selected: _config.facialHairIndex == i,
              onSelected: (_) => setState(() => _config = _config.copyWith(facialHairIndex: i)),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOutfitTab(ThemeData theme, GamificationService gamification) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cor Principal da Roupa',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List.generate(AvatarConfig.outfitColors.length, (i) {
            final isSelected = _config.outfitColorIndex == i;
            final c = AvatarConfig.outfitColors[i];
            return InkWell(
              onTap: () => setState(() => _config = _config.copyWith(outfitColorIndex: i)),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? theme.colorScheme.primary : Colors.grey.shade400,
                    width: isSelected ? 3 : 1,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: i == 7 ? Colors.black87 : Colors.white,
                        size: 18,
                      )
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 18),
        Text(
          'Trajes & Roupas Especiais',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(AvatarConfig.outfits.length, (index) {
          final req = AvatarConfig.requiredTrophyForOutfit(index);
          final locked = req != null && !gamification.isTrophyUnlocked(req);
          final reqTitle = req != null ? gamification.getAchievementById(req)?.title : null;
          final isSelected = _config.outfitIndex == index;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              dense: true,
              leading: Icon(
                locked
                    ? Icons.lock_outline_rounded
                    : (req != null ? Icons.auto_awesome_rounded : Icons.checkroom_rounded),
                color: locked ? Colors.grey : theme.colorScheme.primary,
              ),
              title: Text(
                AvatarConfig.outfits[index],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: locked ? Colors.grey : null,
                ),
              ),
              subtitle: reqTitle != null
                  ? Text(
                      locked ? 'Conquista: $reqTitle' : 'Desbloqueado por: $reqTitle',
                      style: TextStyle(
                        fontSize: 11,
                        color: locked ? Colors.grey : theme.colorScheme.primary,
                      ),
                    )
                  : null,
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                if (locked) {
                  _showLockedHint(req);
                  return;
                }
                setState(() => _config = _config.copyWith(outfitIndex: index));
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildExpressionAndGlassesTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Expressão Facial',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(AvatarConfig.expressions.length, (i) {
            return ChoiceChip(
              label: Text(AvatarConfig.expressions[i]),
              selected: _config.expressionIndex == i,
              onSelected: (_) => setState(() => _config = _config.copyWith(expressionIndex: i)),
            );
          }),
        ),
        const SizedBox(height: 20),
        Text(
          'Óculos',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(AvatarConfig.glassesList.length, (i) {
            return ChoiceChip(
              label: Text(AvatarConfig.glassesList[i]),
              selected: _config.glassesIndex == i,
              onSelected: (_) => setState(() => _config = _config.copyWith(glassesIndex: i)),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildAccessoriesAndBadgeTab(ThemeData theme, GamificationService gamification) {
    final unlockedAchievements =
        gamification.allAchievements.where((a) => a.isUnlocked).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Acessórios & Molduras',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...List.generate(AvatarConfig.accessories.length, (index) {
          final req = AvatarConfig.requiredTrophyForAccessory(index);
          final locked = req != null && !gamification.isTrophyUnlocked(req);
          final reqTitle = req != null ? gamification.getAchievementById(req)?.title : null;
          final isSelected = _config.accessoryIndex == index;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
                : theme.colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              dense: true,
              leading: Icon(
                locked ? Icons.lock_outline_rounded : Icons.workspace_premium_rounded,
                color: locked ? Colors.grey : theme.colorScheme.primary,
              ),
              title: Text(
                AvatarConfig.accessories[index],
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: locked ? Colors.grey : null,
                ),
              ),
              subtitle: reqTitle != null
                  ? Text(
                      locked ? 'Conquista: $reqTitle' : 'Desbloqueado por: $reqTitle',
                      style: TextStyle(
                        fontSize: 11,
                        color: locked ? Colors.grey : theme.colorScheme.primary,
                      ),
                    )
                  : null,
              trailing: isSelected
                  ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                  : null,
              onTap: () {
                if (locked) {
                  _showLockedHint(req);
                  return;
                }
                setState(() => _config = _config.copyWith(accessoryIndex: index));
              },
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(
          'Título / Insígnia na Turma',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Exiba sua conquista favorita ao lado do seu nome na Turma:',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Nenhum título'),
              selected: _config.featuredBadge == null,
              onSelected: (_) => setState(() => _config = _config.copyWith(clearFeaturedBadge: true)),
            ),
            ...unlockedAchievements.map((a) {
              return ChoiceChip(
                avatar: Icon(a.icon, size: 15, color: a.color),
                label: Text(a.title),
                selected: _config.featuredBadge == a.id,
                onSelected: (_) => setState(() => _config = _config.copyWith(featuredBadge: a.id)),
              );
            }),
          ],
        ),
      ],
    );
  }
}
