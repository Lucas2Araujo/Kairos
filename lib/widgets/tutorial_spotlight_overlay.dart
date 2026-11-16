import 'package:flutter/material.dart';
import '../controllers/tutorial_controller.dart';

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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTutorialChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTutorialChanged);
    super.dispose();
  }

  void _onTutorialChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Rect? _resolveTargetRect(GlobalKey? key) {
    final context = key?.currentContext;
    if (context == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return (offset & renderBox.size).inflate(6);
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isActive) return widget.child;

    final step = _controller.currentStep!;
    final targetRect = _resolveTargetRect(step.targetKey);
    final screenSize = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);
    final isLast = _controller.currentIndex + 1 >= _controller.totalSteps;

    final showAbove = targetRect != null && targetRect.center.dy > screenSize.height * 0.55;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              if (targetRect != null && targetRect.contains(details.globalPosition)) {
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
                borderRadius: BorderRadius.circular(20),
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
                          if (targetRect != null)
                            Expanded(
                              child: Text(
                                'Toque na área destacada ou em Próximo',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            )
                          else
                            const Spacer(),
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
