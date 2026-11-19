import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/tutorial_controller.dart';
import '../services/theme_service.dart';

/// Overlay interativo com spotlight (recorte iluminado), borda de destaque e balão de instrução.
class TutorialSpotlightOverlay extends StatefulWidget {
  final Widget child;

  const TutorialSpotlightOverlay({
    super.key,
    required this.child,
  });

  @override
  State<TutorialSpotlightOverlay> createState() => _TutorialSpotlightOverlayState();
}

class _TutorialSpotlightOverlayState extends State<TutorialSpotlightOverlay> {
  final TutorialController _controller = TutorialController();
  final List<Timer> _settlementTimers = [];
  int _stepGeneration = 0;
  Rect? _lastMeasuredRect;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTutorialChanged);
    if (_controller.isActive) {
      _scheduleTargetSettlement();
    }
  }

  @override
  void dispose() {
    _stepGeneration++;
    _cancelSettlementTimers();
    _controller.removeListener(_onTutorialChanged);
    super.dispose();
  }

  void _cancelSettlementTimers() {
    for (final t in _settlementTimers) {
      t.cancel();
    }
    _settlementTimers.clear();
  }

  void _onTutorialChanged() {
    if (!mounted) return;
    _lastMeasuredRect = null;
    _cancelSettlementTimers();
    setState(() {});
    if (_controller.isActive) {
      _scheduleTargetSettlement();
    } else {
      _stepGeneration++;
    }
  }

  void _scheduleTargetSettlement() {
    _cancelSettlementTimers();
    final int gen = ++_stepGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || gen != _stepGeneration || !_controller.isActive) return;

      final targetCtx = _controller.currentStep?.targetKey?.currentContext;
      if (targetCtx != null && targetCtx.mounted) {
        try {
          await Scrollable.ensureVisible(
            targetCtx,
            alignment: 0.35,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        } catch (_) {}
      }
      _refreshRectIfChanged(gen);

      if (!mounted || gen != _stepGeneration || !_controller.isActive) return;
      // Re-medições escalonadas para aguardar transições de aba (240ms) e NavigationRail.
      for (final delayMs in const [120, 280, 480]) {
        _settlementTimers.add(
          Timer(Duration(milliseconds: delayMs), () {
            _refreshRectIfChanged(gen);
          }),
        );
      }
    });
  }

  void _refreshRectIfChanged(int expectedGen) {
    if (!mounted || expectedGen != _stepGeneration || !_controller.isActive) return;
    final fresh = _resolveTargetRect(_controller.currentStep?.targetKey);
    if (!_rectsClose(fresh, _lastMeasuredRect)) {
      setState(() {
        _lastMeasuredRect = fresh;
      });
    }
  }

  static bool _rectsClose(Rect? a, Rect? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return (a.left - b.left).abs() < 0.5 &&
        (a.top - b.top).abs() < 0.5 &&
        (a.right - b.right).abs() < 0.5 &&
        (a.bottom - b.bottom).abs() < 0.5;
  }

  Rect? _resolveTargetRect(GlobalKey? key) {
    final targetContext = key?.currentContext;
    if (targetContext == null || !targetContext.mounted) return null;
    final renderBox = targetContext.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return null;
    final overlayBox = context.findRenderObject() as RenderBox?;
    final Offset offset = (overlayBox != null && overlayBox.attached)
        ? renderBox.localToGlobal(Offset.zero, ancestor: overlayBox)
        : renderBox.localToGlobal(Offset.zero);
    return (offset & renderBox.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isActive) return widget.child;

    final step = _controller.currentStep!;
    final targetRect = _resolveTargetRect(step.targetKey) ?? _lastMeasuredRect;
    _lastMeasuredRect = targetRect;
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final ts = ThemeService();
    final isSquareRetro = ts.isAscii || ts.isWin95 || ts.isHoloRetro;
    final isLast = _controller.currentIndex + 1 >= _controller.totalSteps;

    final showAbove = targetRect != null && targetRect.center.dy > screenSize.height * 0.55;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: (_) {
            if (_controller.isActive) {
              final gen = _stepGeneration;
              WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRectIfChanged(gen));
            }
            return false;
          },
          child: widget.child,
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (targetRect != null && targetRect.contains(details.localPosition)) {
                _controller.nextStep();
              }
            },
            child: CustomPaint(
              painter: _SpotlightPainter(
                targetRect: targetRect,
                overlayColor: Colors.black.withValues(alpha: 0.72),
                highlightColor: theme.colorScheme.primary,
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          top: showAbove
              ? null
              : (targetRect != null
                  ? (targetRect.bottom + 16).clamp(40.0, screenSize.height - 220)
                  : screenSize.height * 0.35),
          bottom: showAbove
              ? (screenSize.height - targetRect.top + 16).clamp(40.0, screenSize.height - 220)
              : null,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Material(
                elevation: 12,
                shape: RoundedRectangleBorder(
                  borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(20),
                  side: BorderSide(
                    color: ts.isAscii
                        ? theme.colorScheme.primary
                        : (ts.isHoloRetro
                            ? const Color(0xFF33B5E5)
                            : Colors.transparent),
                    width: (ts.isAscii || ts.isHoloRetro) ? 1.5 : 0,
                  ),
                ),
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Passo ${_controller.currentIndex + 1} de ${_controller.totalSteps}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _controller.skipTutorial,
                            child: const Text('Pular'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        step.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_controller.currentIndex > 0) ...[
                            OutlinedButton.icon(
                              onPressed: _controller.previousStep,
                              icon: const Icon(Icons.arrow_back_rounded, size: 16),
                              label: const Text('Anterior'),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: targetRect != null
                                ? Text(
                                    'Toque no destaque ou em Próximo',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: _controller.nextStep,
                            icon: Icon(
                              isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: Text(isLast ? 'Concluir' : 'Próximo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final Color overlayColor;
  final Color highlightColor;

  _SpotlightPainter({
    required this.targetRect,
    required this.overlayColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullPath = Path()..addRect(Offset.zero & size);
    if (targetRect == null) {
      canvas.drawPath(fullPath, Paint()..color = overlayColor);
      return;
    }

    final rrect = RRect.fromRectAndRadius(targetRect!, const Radius.circular(16));
    final cutoutPath = Path()..addRRect(rrect);

    final combined = Path.combine(PathOperation.difference, fullPath, cutoutPath);
    canvas.drawPath(combined, Paint()..color = overlayColor);

    final borderPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
