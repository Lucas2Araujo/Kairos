import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/database/database_manager.dart';
import '../../services/audio_service.dart';
import '../../services/auth_service.dart';
import '../../services/content_manager.dart';
import '../../services/gamification_service.dart';
import '../../services/notification_service.dart';
import '../../services/reading_plan_service.dart';
import '../../services/theme_service.dart';
import '../navigation/main_navigation_view.dart';

/// Splash Screen Kairós com morphing animado (Bíblia -> Harpa -> Lápis -> Fósforo -> Lamparina)
/// Filosofia /ponytail: sem dependências externas, CustomPainter e TickerProvider nativo do Flutter.
class SplashView extends StatefulWidget {
  final Duration minDuration;
  final Widget Function()? homeBuilder;

  const SplashView({
    super.key,
    this.minDuration = const Duration(milliseconds: 3400),
    this.homeBuilder,
  });

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _flameController;

  @override
  void initState() {
    super.initState();

    // Duração configurada pelo usuário no ThemeService (padrão 2800ms)
    final durationMs = ThemeService().splashDurationMs;
    _mainController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // Loop contínuo para a chama viva da lamparina
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bootstrap();
  }

  /// Inicializa serviços essenciais em paralelo com a conclusão da animação
  Future<void> _bootstrap() async {
    final animCompleter = Completer<void>();

    _mainController.forward().whenComplete(() {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!animCompleter.isCompleted) animCompleter.complete();
      });
    });

    // Inicia recuperação de sessão em segundo plano
    unawaited(AuthService().init().catchError((e) {
      debugPrint('[SplashView] Erro ao carregar auth em background: $e');
    }));

    try {
      await Future.wait([
        DatabaseManager().initialize(),
        ThemeService().init(),
        AudioService().init(),
        ContentManager().init(),
        GamificationService().init(),
        ReadingPlanService().init(),
        NotificationService().init(),
        animCompleter.future,
      ]);
    } catch (e, st) {
      debugPrint('[SplashView] Erro durante o boot assíncrono: $e\n$st');
      if (!animCompleter.isCompleted) {
        await animCompleter.future;
      }
    }

    if (!mounted) return;

    _navigateToHome();
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.homeBuilder != null
                ? widget.homeBuilder!()
                : const MainNavigationView(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    // Respeita o Material You sem ofuscar à noite
    final bgColor = isDark
        ? Color.lerp(colorScheme.surface, const Color(0xFF141210), 0.7)!
        : colorScheme.surface;
    final lineColor = isDark
        ? Color.lerp(colorScheme.primary, const Color(0xFFFFBA42), 0.6)!
        : colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([_mainController, _flameController]),
            builder: (context, _) {
              final t = _mainController.value;
              // Revelação do texto a partir de 72% da animação
              final textProgress = ((t - 0.72) / 0.22).clamp(0.0, 1.0);
              final curvedText = Curves.easeOutCubic.transform(textProgress);

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 260,
                    child: CustomPaint(
                      painter: _KairosMorphPainter(
                        progress: t,
                        flamePulse: _flameController.value,
                        lineColor: lineColor,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: curvedText,
                    child: Transform.translate(
                      offset: Offset(0, (1 - curvedText) * 16),
                      child: Column(
                        children: [
                          Text(
                            'Kairós',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.0,
                              height: 1.0,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Adoração, Comunhão e Estudo',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              color: lineColor.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KairosMorphPainter extends CustomPainter {
  final double progress;
  final double flamePulse;
  final Color lineColor;
  final bool isDark;

  _KairosMorphPainter({
    required this.progress,
    required this.flamePulse,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);

    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // =========================================================================
    // ATO 1 (0.00 -> 0.26): Linha horizontal desenha a Bíblia e vira a página
    // =========================================================================
    if (progress <= 0.30) {
      final p1 = (progress / 0.26).clamp(0.0, 1.0);
      final fadeOut = progress > 0.24 ? 1.0 - ((progress - 0.24) / 0.06) : 1.0;

      final bookPath = _buildBookPath(center, p1);
      final extracted = _extractPartialPath(bookPath, 0.0, p1.clamp(0.0, 1.0));

      strokePaint.color = lineColor.withValues(alpha: fadeOut.clamp(0.0, 1.0));
      glowPaint.color = lineColor.withValues(alpha: 0.3 * fadeOut.clamp(0.0, 1.0));

      canvas.drawPath(extracted, glowPaint);
      canvas.drawPath(extracted, strokePaint);
    }

    // =========================================================================
    // ATO 2 (0.22 -> 0.48): A página sobe em curva e forma a Harpa com cordas
    // =========================================================================
    if (progress >= 0.22 && progress <= 0.52) {
      final p2 = ((progress - 0.22) / 0.24).clamp(0.0, 1.0);
      final morphOut = ((progress - 0.42) / 0.10).clamp(0.0, 1.0);

      final harpFrame = _buildHarpFramePath(center);
      // Trim path: a moldura se desenha e depois se recolhe deixando as cordas
      final startTrim = morphOut * 0.8;
      final endTrim = (p2 * 1.15).clamp(0.0, 1.0);

      if (endTrim > startTrim) {
        final partialHarp = _extractPartialPath(harpFrame, startTrim, endTrim);
        strokePaint.color = lineColor.withValues(alpha: 1.0 - morphOut);
        canvas.drawPath(partialHarp, glowPaint);
        canvas.drawPath(partialHarp, strokePaint);
      }

      // As cordas da harpa que se inclinam em 45 graus para virar o Lápis
      _drawHarpStringsMorphingToPencil(canvas, center, p2, morphOut, strokePaint);
    }

    // =========================================================================
    // ATO 3 (0.45 -> 0.72): Lápis risca a curva em "S" e vira Palito de Fósforo
    // =========================================================================
    if (progress >= 0.45 && progress <= 0.75) {
      final p3 = ((progress - 0.45) / 0.25).clamp(0.0, 1.0);
      final fadeOut = ((progress - 0.68) / 0.07).clamp(0.0, 1.0);

      _drawPencilToMatchstickAndTrail(
        canvas,
        center,
        p3,
        1.0 - fadeOut,
        lineColor,
      );
    }

    // =========================================================================
    // ATO 4 (0.64 -> 1.00): Lamparina Fofinha + Acendimento
    // =========================================================================
    if (progress >= 0.64) {
      final p4 = ((progress - 0.64) / 0.36).clamp(0.0, 1.0);
      _drawCuteOilLamp(canvas, center, p4, flamePulse);
    }
  }

  // Constrói o caminho contínuo da linha horizontal + Livro aberto + Página virando
  Path _buildBookPath(Offset c, double t) {
    final path = Path();
    // Linha de entrada vinda da esquerda
    path.moveTo(c.dx - 130, c.dy + 35);
    path.lineTo(c.dx - 75, c.dy + 35);

    // Base e lateral esquerda do livro
    path.quadraticBezierTo(c.dx - 38, c.dy + 25, c.dx, c.dy + 35);
    path.quadraticBezierTo(c.dx + 38, c.dy + 25, c.dx + 75, c.dy + 35);
    path.lineTo(c.dx + 65, c.dy - 35);
    path.quadraticBezierTo(c.dx + 32, c.dy - 45, c.dx, c.dy - 32);
    path.lineTo(c.dx, c.dy + 35); // Lombada central
    path.lineTo(c.dx, c.dy - 32);
    path.quadraticBezierTo(c.dx - 32, c.dy - 45, c.dx - 65, c.dy - 35);
    path.lineTo(c.dx - 75, c.dy + 35);

    // Página dinâmica levantando (anima o ângulo conforme t avança)
    final pageLift = Curves.easeInOut.transform((t * 1.4 - 0.4).clamp(0.0, 1.0));
    final pageTipX = lerpDouble(c.dx + 60, c.dx - 25, pageLift)!;
    final pageTipY = lerpDouble(c.dy - 35, c.dy - 65, math.sin(pageLift * math.pi))!;

    path.moveTo(c.dx, c.dy - 32);
    path.quadraticBezierTo(
      (c.dx + pageTipX) / 2,
      pageTipY - 12,
      pageTipX,
      pageTipY,
    );
    path.lineTo(pageTipX + 5, pageTipY + 60);
    path.quadraticBezierTo(c.dx + 20, c.dy + 25, c.dx, c.dy + 35);

    return path;
  }

  // Moldura elegante da Harpa
  Path _buildHarpFramePath(Offset c) {
    final path = Path();
    // Coluna vertical esquerda
    path.moveTo(c.dx - 48, c.dy + 45);
    path.lineTo(c.dx - 48, c.dy - 55);
    // Arco superior em S (vindo da página do livro)
    path.cubicTo(
      c.dx - 25, c.dy - 35,
      c.dx + 25, c.dy - 70,
      c.dx + 52, c.dy - 35,
    );
    // Curva traseira da harpa descendo até a base
    path.cubicTo(
      c.dx + 58, c.dy - 5,
      c.dx + 15, c.dy + 35,
      c.dx - 48, c.dy + 45,
    );
    return path;
  }

  // As cordas da harpa se juntam e inclinam em 45° formando as quinas do Lápis
  void _drawHarpStringsMorphingToPencil(
    Canvas canvas,
    Offset c,
    double p2,
    double morphToPencil,
    Paint paint,
  ) {
    const numStrings = 4;
    final curveT = Curves.easeInOutCubic.transform(morphToPencil);

    for (int i = 0; i < numStrings; i++) {
      final stringProgress = ((p2 - i * 0.08) / 0.5).clamp(0.0, 1.0);
      if (stringProgress <= 0) continue;

      // Posição original na Harpa (vertical)
      final harpX = c.dx - 32 + (i * 18.0);
      final harpTop = Offset(harpX, c.dy - 42 + (i * 2.0));
      final harpBottom = Offset(harpX, c.dy + 34 - (i * 8.0));

      // Posição alvo no Lápis (inclinado a 45° no canto superior direito)
      final offsetParallel = (i - 1.5) * 6.5;
      final pencilTop = Offset(
        c.dx + 45 + offsetParallel,
        c.dy - 55 + offsetParallel,
      );
      final pencilBottom = Offset(
        c.dx - 5 + offsetParallel,
        c.dy - 5 + offsetParallel,
      );

      final start = Offset.lerp(harpTop, pencilTop, curveT)!;
      final end = Offset.lerp(
        harpTop,
        Offset.lerp(harpBottom, pencilBottom, curveT)!,
        stringProgress,
      )!;

      paint.color = lineColor;
      canvas.drawLine(start, end, paint);
    }
  }

  // O Lápis desenha a trilha em "S", se transforma em Fósforo e solta faíscas
  void _drawPencilToMatchstickAndTrail(
    Canvas canvas,
    Offset c,
    double p3,
    double opacity,
    Color color,
  ) {
    // Trilha sinuosa em "S" que termina exatamente na posição do pavio da Lamparina
    final sCurve = Path()
      ..moveTo(c.dx - 5, c.dy - 5)
      ..cubicTo(
        c.dx - 85, c.dy + 15,
        c.dx + 75, c.dy + 40,
        c.dx - 68, c.dy - 8,
      );

    final writeProgress = (p3 / 0.72).clamp(0.0, 1.0);
    final curvedWrite = Curves.easeInOutCubic.transform(writeProgress);

    // A cauda da linha vai sumindo enquanto a ponta avança para o bico
    final tailTrim = ((p3 - 0.35) / 0.65).clamp(0.0, 0.92);
    final visibleTrail = _extractPartialPath(sCurve, tailTrim, curvedWrite);

    final trailPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(visibleTrail, trailPaint);

    // Descobre a coordenada exata da ponta na curva em S
    final tipPos = _getPointAtPath(sCurve, curvedWrite);

    // Metamorfose: Lápis (0.0 -> 0.45) vira Palito de Fósforo (0.45 -> 0.85)
    final matchMorph = ((p3 - 0.35) / 0.40).clamp(0.0, 1.0);
    final bodyWidth = lerpDouble(18.0, 6.0, matchMorph)!;
    final bodyLength = lerpDouble(58.0, 44.0, matchMorph)!;

    canvas.save();
    canvas.translate(tipPos.dx, tipPos.dy);
    // Rotaciona o lápis/fósforo em 45 graus
    canvas.rotate(-math.pi / 4);

    final toolPaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round;

    // Corpo do Lápis / Haste de madeira do Fósforo
    final shaftRect = Rect.fromLTWH(
      14,
      -bodyWidth / 2,
      bodyLength,
      bodyWidth,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaftRect, const Radius.circular(3)),
      toolPaint,
    );

    if (matchMorph < 0.6) {
      // Ponta cônica do Lápis + Borracha traseira
      final tipPath = Path()
        ..moveTo(14, -bodyWidth / 2)
        ..lineTo(0, 0)
        ..lineTo(14, bodyWidth / 2);
      canvas.drawPath(tipPath, toolPaint);
    }

    // Cabeça arredondada do Fósforo surgindo na ponta
    if (matchMorph > 0.2) {
      final headScale = Curves.easeOutBack.transform(
        ((matchMorph - 0.2) / 0.8).clamp(0.0, 1.0),
      );
      final matchHeadPaint = Paint()
        ..color = Color.lerp(
          color,
          const Color(0xFFFF5722),
          matchMorph,
        )!.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(6, 0),
          width: 15 * headScale,
          height: 11 * headScale,
        ),
        matchHeadPaint,
      );
    }
    canvas.restore();

    // Faíscas do fósforo riscando no bico da lamparina (p3 > 0.68)
    if (p3 > 0.68) {
      final sparkT = ((p3 - 0.68) / 0.32).clamp(0.0, 1.0);
      final sparkPaint = Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: (1.0 - sparkT) * opacity)
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      for (int i = 0; i < 5; i++) {
        final angle = -math.pi * 0.85 + (i * 0.38);
        final dist1 = 6.0 + (sparkT * 18.0);
        final dist2 = 14.0 + (sparkT * 28.0);
        canvas.drawLine(
          tipPos + Offset(math.cos(angle) * dist1, math.sin(angle) * dist1),
          tipPos + Offset(math.cos(angle) * dist2, math.sin(angle) * dist2),
          sparkPaint,
        );
      }
    }
  }

  // Desenha a Lamparina com o despertar animado
  void _drawCuteOilLamp(
    Canvas canvas,
    Offset c,
    double p4,
    double flamePulse,
  ) {
    final entrance = Curves.easeOutBack.transform((p4 / 0.55).clamp(0.0, 1.0));
    final awake = ((p4 - 0.32) / 0.35).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(c.dx, c.dy + 12);
    canvas.scale(entrance, entrance);

    // 1. Halo luminoso quente atrás da chama
    if (awake > 0) {
      const haloCenter = Offset(-68, -42);
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFB74D).withValues(alpha: 0.42 * awake),
            const Color(0xFFFF9800).withValues(alpha: 0.12 * awake),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: haloCenter, radius: 75));
      canvas.drawCircle(haloCenter, 75, haloPaint);
    }

    // Sombra oval no chão
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(4, 46), width: 112, height: 14),
      Paint()..color = Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
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

    // 2. Alça Curva Traseira (Direita)
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

    // 3. Pedestal / Base da Lamparina
    final baseRRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(2, 39), width: 66, height: 12),
      const Radius.circular(6),
    );
    canvas.drawRRect(baseRRect, Paint()..color = clayDark);
    canvas.drawRRect(baseRRect, outlinePaint);

    // 4. Corpo da Lamparina com Bico à Esquerda
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

    // 5. Tampinha Superior com Puxador
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

    // 6. Rostinho (Bochechas rosadas + Olhos)
    final cheekPaint = Paint()..color = const Color(0xFFF28B82).withValues(alpha: 0.75);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-20, 17), width: 13, height: 7.5),
      cheekPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(24, 17), width: 13, height: 7.5),
      cheekPaint,
    );

    if (awake < 0.35) {
      canvas.drawLine(const Offset(-16, 8), const Offset(-8, 8), outlinePaint);
      canvas.drawLine(const Offset(12, 8), const Offset(20, 8), outlinePaint);
    } else {
      final eyeScale = Curves.easeOutBack.transform(
        ((awake - 0.35) / 0.65).clamp(0.0, 1.0),
      );
      final eyePaint = Paint()..color = const Color(0xFF261408);
      final catchlightPaint = Paint()..color = Colors.white;

      for (final eyeX in [-12.0, 16.0]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(eyeX, 8),
            width: 8.5,
            height: 9.5 * eyeScale,
          ),
          eyePaint,
        );
        if (eyeScale > 0.6) {
          canvas.drawCircle(Offset(eyeX - 1.8, 5.8), 2.2, catchlightPaint);
        }
      }
    }

    // Boquinha sorridente no centro
    final smilePath = Path()
      ..moveTo(-3, 14)
      ..quadraticBezierTo(2, 19 + (awake * 2), 7, 14);
    canvas.drawPath(smilePath, outlinePaint);

    // 7. Chama viva no bico esquerdo
    if (awake > 0) {
      final flameScale = Curves.easeOutBack.transform(awake);
      final sway = (flamePulse - 0.5) * 4.0;

      canvas.save();
      canvas.translate(-68, -14);
      canvas.scale(flameScale, flameScale);

      // Pavio
      canvas.drawLine(
        const Offset(0, 2),
        const Offset(0, -5),
        outlinePaint,
      );

      // Chama Externa (Laranja/Âmbar)
      final outerFlame = Path()
        ..moveTo(0, -4)
        ..cubicTo(-18, -14, -14, -40, sway, -56)
        ..cubicTo(14, -40, 18, -14, 0, -4)
        ..close();
      canvas.drawPath(
        outerFlame,
        Paint()..color = const Color(0xFFFF9800),
      );

      // Chama Interna (Amarelo Claro Quente)
      final innerFlame = Path()
        ..moveTo(0, -7)
        ..cubicTo(-9, -15, -7, -32, sway * 0.6, -42)
        ..cubicTo(7, -32, 9, -15, 0, -7)
        ..close();
      canvas.drawPath(
        innerFlame,
        Paint()..color = const Color(0xFFFFF176),
      );

      canvas.restore();
    }

    canvas.restore();
  }

  // Utilitários de PathMetrics para Trim Path contínuo
  Path _extractPartialPath(Path source, double startFraction, double endFraction) {
    final result = Path();
    for (final metric in source.computeMetrics()) {
      final start = metric.length * startFraction.clamp(0.0, 1.0);
      final end = metric.length * endFraction.clamp(0.0, 1.0);
      if (end > start) {
        result.addPath(metric.extractPath(start, end), Offset.zero);
      }
    }
    return result;
  }

  Offset _getPointAtPath(Path source, double fraction) {
    final metrics = source.computeMetrics().toList();
    if (metrics.isEmpty) return Offset.zero;
    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(
      metric.length * fraction.clamp(0.0, 1.0),
    );
    return tangent?.position ?? Offset.zero;
  }

  @override
  bool shouldRepaint(covariant _KairosMorphPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.flamePulse != flamePulse ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isDark != isDark;
  }
}
