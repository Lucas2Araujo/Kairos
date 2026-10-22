import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChromaticColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  const ChromaticColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required Color initialColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ChromaticColorPickerDialog(
        initialColor: initialColor,
        onColorSelected: onColorSelected,
      ),
    );
  }

  @override
  State<ChromaticColorPickerDialog> createState() => _ChromaticColorPickerDialogState();
}

class _ChromaticColorPickerDialogState extends State<ChromaticColorPickerDialog> {
  late double _hue; // 0 a 360
  late double _saturation; // 0.0 a 1.0
  late double _lightness; // 0.0 a 1.0

  @override
  void initState() {
    super.initState();
    final hsl = HSLColor.fromColor(widget.initialColor);
    _hue = hsl.hue;
    // Fixamos saturação e luminosidade ideais para o tema claro manter bom contraste
    _saturation = hsl.saturation.clamp(0.45, 0.85);
    _lightness = hsl.lightness.clamp(0.35, 0.55);
  }

  Color _getColor(double h) => HSLColor.fromAHSL(1.0, (h % 360.0), _saturation, _lightness).toColor();

  @override
  Widget build(BuildContext context) {
    final currentColor = _getColor(_hue);
    final analogLeft = _getColor(_hue - 30);
    final analogRight = _getColor(_hue + 30);

    // Avaliação de contraste WCAG no fundo claro padrão (#FCF8FD)
    const bgLight = Color(0xFFFCF8FD);
    final contrastRatio = AppTheme.contrastRatio(currentColor, bgLight);
    final isGoodContrast = contrastRatio >= 3.0; // Padrão M3 para seed colors

    return AlertDialog(
      title: const Text('Círculo Cromático Customizado', style: TextStyle(fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Roda de Cores Interativa
            SizedBox(
              width: 220,
              height: 220,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox == null) return;
                  const center = Offset(110, 110);
                  final localTouch = details.localPosition;
                  final dx = localTouch.dx - center.dx;
                  final dy = localTouch.dy - center.dy;
                  final angle = math.atan2(dy, dx) * 180 / math.pi;
                  setState(() {
                    _hue = (angle + 360) % 360;
                  });
                },
                child: CustomPaint(
                  painter: _HueWheelPainter(selectedHue: _hue),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Saturação & Luminosidade reguladas para o tema claro
            Row(
              children: [
                const Icon(Icons.brightness_medium, size: 18),
                Expanded(
                  child: Slider(
                    value: _lightness,
                    min: 0.30,
                    max: 0.65,
                    divisions: 10,
                    onChanged: (v) => setState(() => _lightness = v),
                  ),
                ),
              ],
            ),

            // Amostra e Cores Análogas
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildColorThumbnail('Análoga -30°', analogLeft),
                _buildColorThumbnail('Escolhida', currentColor, isMain: true),
                _buildColorThumbnail('Análoga +30°', analogRight),
              ],
            ),
            const SizedBox(height: 12),

            // Validação de acessibilidade em tempo real
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isGoodContrast ? Colors.green.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    isGoodContrast ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                    size: 18,
                    color: isGoodContrast ? Colors.green : Colors.amber[800],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isGoodContrast
                          ? 'Excelente contraste no tema claro (${contrastRatio.toStringAsFixed(1)}:1).'
                          : 'Atenção: cor clara demais para leitura nítida.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isGoodContrast ? Colors.green[800] : Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            widget.onColorSelected(currentColor);
            Navigator.of(context).pop();
          },
          child: const Text('Aplicar Cor'),
        ),
      ],
    );
  }

  Widget _buildColorThumbnail(String label, Color color, {bool isMain = false}) {
    return Column(
      children: [
        Container(
          width: isMain ? 44 : 32,
          height: isMain ? 44 : 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isMain ? 3 : 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _HueWheelPainter extends CustomPainter {
  final double selectedHue;
  _HueWheelPainter({required this.selectedHue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 24.0;

    final sweepGradient = SweepGradient(
      colors: List.generate(
        361,
        (i) => HSLColor.fromAHSL(1.0, i.toDouble(), 0.8, 0.5).toColor(),
      ),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, paint);

    // Indicador do seletor
    final rad = selectedHue * (math.pi / 180);
    final thumbDistance = radius - strokeWidth / 2;
    final thumbPos = Offset(
      center.dx + thumbDistance * math.cos(rad),
      center.dy + thumbDistance * math.sin(rad),
    );

    final thumbPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final thumbBorder = Paint()
      ..color = Colors.black45
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(thumbPos, 14, thumbPaint);
    canvas.drawCircle(thumbPos, 14, thumbBorder);
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter oldDelegate) => oldDelegate.selectedHue != selectedHue;
}