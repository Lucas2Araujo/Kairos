import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/avatar_config.dart';
import '../../services/gamification_service.dart';

/// Widget que renderiza o Avatar Kairós customizado em Canvas vetorial
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

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Fundo Circular
    final bgColor = AvatarConfig.backgroundColors[
        config.backgroundColorIndex.clamp(0, AvatarConfig.backgroundColors.length - 1)];
    final bgPaint = Paint()..color = bgColor;
    canvas.drawCircle(center, radius, bgPaint);

    // Efeito de Clip circular para o personagem não vazar
    canvas.save();
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    final skinColor = AvatarConfig.skinTones[
        config.skinToneIndex.clamp(0, AvatarConfig.skinTones.length - 1)];
    final hairColor = AvatarConfig.hairColors[
        config.hairColorIndex.clamp(0, AvatarConfig.hairColors.length - 1)];

    // 2. Torso / Roupa Minimalista
    final bodyPaint = Paint()..color = const Color(0xFF1D3557);
    final neckPaint = Paint()..color = skinColor;

    // Pescoço
    final neckRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + radius * 0.42),
      width: radius * 0.38,
      height: radius * 0.35,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(neckRect, Radius.circular(radius * 0.1)), neckPaint);

    // Ombros / Roupa
    final bodyPath = Path();
    bodyPath.moveTo(center.dx - radius * 0.85, size.height + 4);
    bodyPath.quadraticBezierTo(
      center.dx - radius * 0.5,
      center.dy + radius * 0.5,
      center.dx - radius * 0.22,
      center.dy + radius * 0.58,
    );
    bodyPath.lineTo(center.dx + radius * 0.22, center.dy + radius * 0.58);
    bodyPath.quadraticBezierTo(
      center.dx + radius * 0.5,
      center.dy + radius * 0.5,
      center.dx + radius * 0.85,
      size.height + 4,
    );
    bodyPath.close();
    canvas.drawPath(bodyPath, bodyPaint);

    // Gola / Detalhe da roupa
    final collarPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.06;
    final collarPath = Path();
    collarPath.moveTo(center.dx - radius * 0.22, center.dy + radius * 0.58);
    collarPath.quadraticBezierTo(
      center.dx,
      center.dy + radius * 0.72,
      center.dx + radius * 0.22,
      center.dy + radius * 0.58,
    );
    canvas.drawPath(collarPath, collarPaint);

    // 3. Cabeça
    final headCenter = Offset(center.dx, center.dy - radius * 0.04);
    final headRadius = radius * 0.46;
    final headPaint = Paint()..color = skinColor;
    canvas.drawCircle(headCenter, headRadius, headPaint);

    // Orelhas
    final earPaint = Paint()..color = skinColor;
    canvas.drawCircle(
      Offset(headCenter.dx - headRadius * 0.95, headCenter.dy + headRadius * 0.05),
      headRadius * 0.2,
      earPaint,
    );
    canvas.drawCircle(
      Offset(headCenter.dx + headRadius * 0.95, headCenter.dy + headRadius * 0.05),
      headRadius * 0.2,
      earPaint,
    );

    // 4. Cabelo (Parte de trás ou base)
    _drawHair(canvas, headCenter, headRadius, hairColor, config.hairStyleIndex);

    // 5. Olhos & Expressão
    _drawExpression(canvas, headCenter, headRadius, config.expressionIndex);

    // 6. Óculos
    _drawGlasses(canvas, headCenter, headRadius, config.glassesIndex);

    canvas.restore(); // Fim do clip circular

    // 7. Acessórios / Moldura (pode sobrepor o círculo)
    _drawAccessory(canvas, center, radius, config.accessoryIndex);
  }

  void _drawHair(
      Canvas canvas, Offset headCenter, double headRadius, Color hairColor, int styleIndex) {
    if (styleIndex == 5) {
      // Careca / Raspado
      final buzzPaint = Paint()
        ..color = hairColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(headCenter, headRadius + 1, buzzPaint);
      return;
    }

    final hairPaint = Paint()
      ..color = hairColor
      ..style = PaintingStyle.fill;

    switch (styleIndex) {
      case 1:
        // Cacheado Volumoso
        final curlPaint = Paint()..color = hairColor;
        for (double angle = -math.pi * 0.95; angle <= -0.05; angle += 0.32) {
          final offset = Offset(
            headCenter.dx + (headRadius * 1.08) * math.cos(angle),
            headCenter.dy + (headRadius * 1.08) * math.sin(angle),
          );
          canvas.drawCircle(offset, headRadius * 0.28, curlPaint);
        }
        break;

      case 2:
        // Longo / Ondulado
        final path = Path();
        path.moveTo(headCenter.dx - headRadius * 1.15, headCenter.dy + headRadius * 1.1);
        path.quadraticBezierTo(
          headCenter.dx - headRadius * 1.25,
          headCenter.dy - headRadius * 0.7,
          headCenter.dx,
          headCenter.dy - headRadius * 1.25,
        );
        path.quadraticBezierTo(
          headCenter.dx + headRadius * 1.25,
          headCenter.dy - headRadius * 0.7,
          headCenter.dx + headRadius * 1.15,
          headCenter.dy + headRadius * 1.1,
        );
        path.quadraticBezierTo(
          headCenter.dx + headRadius * 0.85,
          headCenter.dy + headRadius * 0.4,
          headCenter.dx + headRadius * 0.7,
          headCenter.dy - headRadius * 0.1,
        );
        path.quadraticBezierTo(
          headCenter.dx,
          headCenter.dy - headRadius * 0.6,
          headCenter.dx - headRadius * 0.7,
          headCenter.dy - headRadius * 0.1,
        );
        path.quadraticBezierTo(
          headCenter.dx - headRadius * 0.85,
          headCenter.dy + headRadius * 0.4,
          headCenter.dx - headRadius * 1.15,
          headCenter.dy + headRadius * 1.1,
        );
        canvas.drawPath(path, hairPaint);
        break;

      case 3:
        // Topete Moderno
        final path = Path();
        path.moveTo(headCenter.dx - headRadius * 0.95, headCenter.dy - headRadius * 0.1);
        path.quadraticBezierTo(
          headCenter.dx - headRadius * 0.95,
          headCenter.dy - headRadius * 1.45,
          headCenter.dx + headRadius * 0.2,
          headCenter.dy - headRadius * 1.35,
        );
        path.quadraticBezierTo(
          headCenter.dx + headRadius * 1.1,
          headCenter.dy - headRadius * 0.9,
          headCenter.dx + headRadius * 0.95,
          headCenter.dy - headRadius * 0.1,
        );
        path.quadraticBezierTo(
          headCenter.dx,
          headCenter.dy - headRadius * 0.5,
          headCenter.dx - headRadius * 0.95,
          headCenter.dy - headRadius * 0.1,
        );
        canvas.drawPath(path, hairPaint);
        break;

      case 4:
        // Coque Alto
        canvas.drawCircle(
          Offset(headCenter.dx, headCenter.dy - headRadius * 1.3),
          headRadius * 0.42,
          hairPaint,
        );
        final base = Path();
        base.addArc(
          Rect.fromCircle(center: headCenter, radius: headRadius * 1.05),
          math.pi,
          math.pi,
        );
        canvas.drawPath(base, hairPaint);
        break;

      case 0:
      default:
        // Curto Elegante
        final path = Path();
        path.moveTo(headCenter.dx - headRadius * 1.02, headCenter.dy + headRadius * 0.05);
        path.quadraticBezierTo(
          headCenter.dx - headRadius * 1.1,
          headCenter.dy - headRadius * 1.25,
          headCenter.dx,
          headCenter.dy - headRadius * 1.18,
        );
        path.quadraticBezierTo(
          headCenter.dx + headRadius * 1.1,
          headCenter.dy - headRadius * 1.25,
          headCenter.dx + headRadius * 1.02,
          headCenter.dy + headRadius * 0.05,
        );
        path.quadraticBezierTo(
          headCenter.dx + headRadius * 0.6,
          headCenter.dy - headRadius * 0.3,
          headCenter.dx,
          headCenter.dy - headRadius * 0.55,
        );
        path.quadraticBezierTo(
          headCenter.dx - headRadius * 0.6,
          headCenter.dy - headRadius * 0.3,
          headCenter.dx - headRadius * 1.02,
          headCenter.dy + headRadius * 0.05,
        );
        canvas.drawPath(path, hairPaint);
        break;
    }
  }

  void _drawExpression(Canvas canvas, Offset headCenter, double headRadius, int expressionIndex) {
    final eyePaint = Paint()
      ..color = const Color(0xFF262626)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = const Color(0xFF262626)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = headRadius * 0.08;

    final leftEye = Offset(headCenter.dx - headRadius * 0.38, headCenter.dy - headRadius * 0.05);
    final rightEye = Offset(headCenter.dx + headRadius * 0.38, headCenter.dy - headRadius * 0.05);

    if (expressionIndex == 2) {
      // Alegre com Olhos fechados em arco (^^)
      final leftArc = Path()
        ..addArc(Rect.fromCircle(center: leftEye, radius: headRadius * 0.16), math.pi, math.pi);
      final rightArc = Path()
        ..addArc(Rect.fromCircle(center: rightEye, radius: headRadius * 0.16), math.pi, math.pi);
      canvas.drawPath(leftArc, strokePaint);
      canvas.drawPath(rightArc, strokePaint);
    } else {
      // Olhos normais circulares
      canvas.drawCircle(leftEye, headRadius * 0.11, eyePaint);
      canvas.drawCircle(rightEye, headRadius * 0.11, eyePaint);
      // Brilho no olho
      final shinePaint = Paint()..color = Colors.white;
      canvas.drawCircle(
          Offset(leftEye.dx - headRadius * 0.03, leftEye.dy - headRadius * 0.03),
          headRadius * 0.04,
          shinePaint);
      canvas.drawCircle(
          Offset(rightEye.dx - headRadius * 0.03, rightEye.dy - headRadius * 0.03),
          headRadius * 0.04,
          shinePaint);
    }

    // Sobrancelhas
    final browPaint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = headRadius * 0.07;
    canvas.drawLine(
      Offset(leftEye.dx - headRadius * 0.15, leftEye.dy - headRadius * 0.22),
      Offset(leftEye.dx + headRadius * 0.15, leftEye.dy - headRadius * 0.24),
      browPaint,
    );
    canvas.drawLine(
      Offset(rightEye.dx - headRadius * 0.15, rightEye.dy - headRadius * 0.24),
      Offset(rightEye.dx + headRadius * 0.15, rightEye.dy - headRadius * 0.22),
      browPaint,
    );

    // Nariz sutil
    final nosePaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = headRadius * 0.06;
    final nosePath = Path();
    nosePath.moveTo(headCenter.dx, headCenter.dy + headRadius * 0.08);
    nosePath.lineTo(headCenter.dx + headRadius * 0.06, headCenter.dy + headRadius * 0.22);
    canvas.drawPath(nosePath, nosePaint);

    // Boca
    final mouthCenter = Offset(headCenter.dx, headCenter.dy + headRadius * 0.44);
    switch (expressionIndex) {
      case 1:
        // Sereno / Confiante
        final mouthPath = Path();
        mouthPath.moveTo(mouthCenter.dx - headRadius * 0.2, mouthCenter.dy);
        mouthPath.quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + headRadius * 0.08,
          mouthCenter.dx + headRadius * 0.2,
          mouthCenter.dy - headRadius * 0.02,
        );
        canvas.drawPath(mouthPath, strokePaint);
        break;
      case 3:
        // Contemplativo (reta suave)
        canvas.drawLine(
          Offset(mouthCenter.dx - headRadius * 0.16, mouthCenter.dy),
          Offset(mouthCenter.dx + headRadius * 0.16, mouthCenter.dy),
          strokePaint,
        );
        break;
      case 0:
      case 2:
      default:
        // Sorridente
        final mouthPath = Path();
        mouthPath.moveTo(mouthCenter.dx - headRadius * 0.25, mouthCenter.dy - headRadius * 0.04);
        mouthPath.quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + headRadius * 0.24,
          mouthCenter.dx + headRadius * 0.25,
          mouthCenter.dy - headRadius * 0.04,
        );
        final fillMouth = Paint()..color = const Color(0xFFC94A4A);
        canvas.drawPath(mouthPath, fillMouth);
        canvas.drawPath(mouthPath, strokePaint);
        break;
    }
  }

  void _drawGlasses(Canvas canvas, Offset headCenter, double headRadius, int glassesIndex) {
    if (glassesIndex == 0) return;

    final glassesPaint = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headRadius * 0.07;

    final leftCenter = Offset(headCenter.dx - headRadius * 0.38, headCenter.dy - headRadius * 0.05);
    final rightCenter = Offset(headCenter.dx + headRadius * 0.38, headCenter.dy - headRadius * 0.05);

    switch (glassesIndex) {
      case 1:
        // Redondo Clássico
        final gRadius = headRadius * 0.24;
        canvas.drawCircle(leftCenter, gRadius, glassesPaint);
        canvas.drawCircle(rightCenter, gRadius, glassesPaint);
        // Ponte
        canvas.drawLine(
          Offset(leftCenter.dx + gRadius, leftCenter.dy),
          Offset(rightCenter.dx - gRadius, rightCenter.dy),
          glassesPaint,
        );
        break;
      case 2:
        // Retangular Moderno
        final rRectL = RRect.fromRectAndRadius(
          Rect.fromCenter(center: leftCenter, width: headRadius * 0.52, height: headRadius * 0.36),
          Radius.circular(headRadius * 0.06),
        );
        final rRectR = RRect.fromRectAndRadius(
          Rect.fromCenter(center: rightCenter, width: headRadius * 0.52, height: headRadius * 0.36),
          Radius.circular(headRadius * 0.06),
        );
        canvas.drawRRect(rRectL, glassesPaint);
        canvas.drawRRect(rRectR, glassesPaint);
        canvas.drawLine(
          Offset(leftCenter.dx + headRadius * 0.26, leftCenter.dy),
          Offset(rightCenter.dx - headRadius * 0.26, rightCenter.dy),
          glassesPaint,
        );
        break;
      case 3:
        // Aviador
        final aviatorPaint = Paint()
          ..color = const Color(0xFFD4AF37)
          ..style = PaintingStyle.stroke
          ..strokeWidth = headRadius * 0.07;
        canvas.drawOval(
          Rect.fromCenter(center: leftCenter, width: headRadius * 0.52, height: headRadius * 0.42),
          aviatorPaint,
        );
        canvas.drawOval(
          Rect.fromCenter(center: rightCenter, width: headRadius * 0.52, height: headRadius * 0.42),
          aviatorPaint,
        );
        canvas.drawLine(
          Offset(leftCenter.dx + headRadius * 0.24, leftCenter.dy - headRadius * 0.05),
          Offset(rightCenter.dx - headRadius * 0.24, rightCenter.dy - headRadius * 0.05),
          aviatorPaint,
        );
        break;
    }
  }

  void _drawAccessory(Canvas canvas, Offset center, double radius, int accessoryIndex) {
    if (accessoryIndex == 0) return;

    switch (accessoryIndex) {
      case 1:
        // Aura Dourada (Azeite / Parábola)
        final auraPaint = Paint()
          ..color = Colors.amber.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.09;
        canvas.drawCircle(center, radius - radius * 0.045, auraPaint);
        break;
      case 2:
        // Ramo de Oliveira (Folhas sutis na borda)
        final leafPaint = Paint()..color = const Color(0xFF588157);
        for (int i = 0; i < 5; i++) {
          final angle = math.pi * 0.65 + (i * 0.18);
          final p = Offset(center.dx + radius * 0.9 * math.cos(angle),
              center.dy + radius * 0.9 * math.sin(angle));
          canvas.drawCircle(p, radius * 0.07, leafPaint);
        }
        break;
      case 3:
        // Pingente / Selo Cruz
        final crossPaint = Paint()
          ..color = Colors.amber.shade700
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
        // Coroa da Vitória (topo)
        final crownPaint = Paint()
          ..color = const Color(0xFFFFD166)
          ..style = PaintingStyle.fill;
        final crownPath = Path();
        final cTop = center.dy - radius * 0.78;
        crownPath.moveTo(center.dx - radius * 0.35, cTop);
        crownPath.lineTo(center.dx - radius * 0.45, cTop - radius * 0.22);
        crownPath.lineTo(center.dx - radius * 0.15, cTop - radius * 0.1);
        crownPath.lineTo(center.dx, cTop - radius * 0.28);
        crownPath.lineTo(center.dx + radius * 0.15, cTop - radius * 0.1);
        crownPath.lineTo(center.dx + radius * 0.45, cTop - radius * 0.22);
        crownPath.lineTo(center.dx + radius * 0.35, cTop);
        crownPath.close();
        canvas.drawPath(crownPath, crownPaint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) {
    return oldDelegate.config != config;
  }
}

/// Modal / BottomSheet de Customização de Avatar
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

  final List<String> _tabs = [
    'Fundo',
    'Pele',
    'Cabelo',
    'Expressão',
    'Óculos',
    'Acessórios',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Criar Avatar Kairós',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    GamificationService().updateAvatarConfig(_config);
                    Navigator.of(context).pop(_config);
                  },
                  child: const Text('Salvar'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Preview do Avatar
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 3,
                ),
              ),
              child: AvatarCustomWidget(
                config: _config,
                size: 110,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: _tabs.map((name) => Tab(text: name)).toList(),
          ),

          // Conteúdo da Aba
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Fundo
                _buildColorSelector(
                  colors: AvatarConfig.backgroundColors,
                  selectedIndex: _config.backgroundColorIndex,
                  onSelect: (i) => setState(() => _config = _config.copyWith(backgroundColorIndex: i)),
                ),

                // 2. Pele
                _buildColorSelector(
                  colors: AvatarConfig.skinTones,
                  selectedIndex: _config.skinToneIndex,
                  onSelect: (i) => setState(() => _config = _config.copyWith(skinToneIndex: i)),
                ),

                // 3. Cabelo (Estilo + Cor)
                _buildHairTab(),

                // 4. Expressão
                _buildOptionList(
                  options: AvatarConfig.expressions,
                  selectedIndex: _config.expressionIndex,
                  onSelect: (i) => setState(() => _config = _config.copyWith(expressionIndex: i)),
                ),

                // 5. Óculos
                _buildOptionList(
                  options: AvatarConfig.glassesList,
                  selectedIndex: _config.glassesIndex,
                  onSelect: (i) => setState(() => _config = _config.copyWith(glassesIndex: i)),
                ),

                // 6. Acessórios
                _buildOptionList(
                  options: AvatarConfig.accessories,
                  selectedIndex: _config.accessoryIndex,
                  onSelect: (i) => setState(() => _config = _config.copyWith(accessoryIndex: i)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector({
    required List<Color> colors,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: colors.length,
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        return InkWell(
          onTap: () => onSelect(index),
          borderRadius: BorderRadius.circular(32),
          child: Container(
            decoration: BoxDecoration(
              color: colors[index],
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                width: isSelected ? 3.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
        );
      },
    );
  }

  Widget _buildHairTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Cor do Cabelo',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AvatarConfig.hairColors.length,
            itemBuilder: (context, index) {
              final isSelected = _config.hairColorIndex == index;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => setState(() => _config = _config.copyWith(hairColorIndex: index)),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AvatarConfig.hairColors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Estilo de Corte',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ...List.generate(AvatarConfig.hairStyles.length, (index) {
          final isSelected = _config.hairStyleIndex == index;
          return RadioListTile<int>(
            title: Text(AvatarConfig.hairStyles[index]),
            value: index,
            groupValue: _config.hairStyleIndex,
            dense: true,
            selected: isSelected,
            onChanged: (val) {
              if (val != null) {
                setState(() => _config = _config.copyWith(hairStyleIndex: val));
              }
            },
          );
        }),
      ],
    );
  }

  Widget _buildOptionList({
    required List<String> options,
    required int selectedIndex,
    required ValueChanged<int> onSelect,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final isSelected = selectedIndex == index;
        return RadioListTile<int>(
          title: Text(options[index]),
          value: index,
          groupValue: selectedIndex,
          selected: isSelected,
          onChanged: (val) {
            if (val != null) onSelect(val);
          },
        );
      },
    );
  }
}

