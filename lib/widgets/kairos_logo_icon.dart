import 'package:flutter/material.dart';

/// Ícone vetorial adaptável do Kairós baseado no logotipo oficial (cruz + K).
class KairosLogoIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const KairosLogoIcon({
    super.key,
    this.size = 30,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _KairosLogoPainter(color: effectiveColor),
      ),
    );
  }
}

class _KairosLogoPainter extends CustomPainter {
  final Color color;

  _KairosLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Haste vertical da cruz (à esquerda, terminando antes da curva inferior do K)
    canvas.drawLine(
      Offset(w * 0.30, h * 0.14),
      Offset(w * 0.30, h * 0.56),
      strokePaint,
    );

    // Braço horizontal da cruz
    canvas.drawLine(
      Offset(w * 0.12, h * 0.33),
      Offset(w * 0.48, h * 0.33),
      strokePaint,
    );

    // Traço curvo principal do K (sobe da base esquerda até o topo direito)
    final kCurve = Path()
      ..moveTo(w * 0.30, h * 0.86)
      ..cubicTo(
        w * 0.30,
        h * 0.60,
        w * 0.62,
        h * 0.52,
        w * 0.80,
        h * 0.14,
      );
    canvas.drawPath(kCurve, strokePaint);

    // Perna inferior direita do K
    canvas.drawLine(
      Offset(w * 0.53, h * 0.57),
      Offset(w * 0.82, h * 0.86),
      strokePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _KairosLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
