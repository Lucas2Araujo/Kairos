import 'package:flutter/material.dart';
import '../services/theme_service.dart';

/// Camada reutilizável e configurável de gestos para telas de leitura do Kairós.
///
/// Suporta troca rápida de capítulos/dias por deslize horizontal e zoom de fonte
/// por pinça com 2 dedos, respeitando as preferências do [ThemeService].
class KairosReaderGestureLayer extends StatefulWidget {
  /// Conteúdo principal do leitor envolvido pelos gestos.
  final Widget child;

  /// Callback acionado ao deslizar para a esquerda (avançar capítulo, dia ou hino).
  final VoidCallback? onNextChapter;

  /// Callback acionado ao deslizar para a direita (voltar capítulo, dia ou hino).
  final VoidCallback? onPreviousChapter;

  /// Callback opcional para ajuste customizado de fonte em pinça (recebe o fator de escala).
  final ValueChanged<double>? onFontScaleDelta;

  /// Constrói a camada de gestos em torno de [child].
  const KairosReaderGestureLayer({
    super.key,
    required this.child,
    this.onNextChapter,
    this.onPreviousChapter,
    this.onFontScaleDelta,
  });

  @override
  State<KairosReaderGestureLayer> createState() =>
      _KairosReaderGestureLayerState();
}

class _KairosReaderGestureLayerState extends State<KairosReaderGestureLayer> {
  final Map<int, Offset> _pointers = <int, Offset>{};
  double? _initialPinchDistance;
  double _baseMultiplier = 1.0;

  void _handlePointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _initialPinchDistance = (pts[0] - pts[1]).distance;
      _baseMultiplier = ThemeService().fontSizeMultiplier;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final ts = ThemeService();
    if (!ts.gesturesEnabled || !ts.gesturePinchFont) return;
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    if (_pointers.length == 2 &&
        _initialPinchDistance != null &&
        _initialPinchDistance! > 12.0) {
      final pts = _pointers.values.toList();
      final currentDist = (pts[0] - pts[1]).distance;
      final ratio = currentDist / _initialPinchDistance!;
      if (widget.onFontScaleDelta != null) {
        widget.onFontScaleDelta!(ratio);
      } else {
        ts.setFontSizeMultiplier((_baseMultiplier * ratio).clamp(0.8, 1.6));
      }
    }
  }

  void _handlePointerEnd(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _initialPinchDistance = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        final ts = ThemeService();
        if (!ts.gesturesEnabled) {
          return widget.child;
        }

        Widget current = widget.child;

        if (ts.gestureSwipeChapters &&
            (widget.onNextChapter != null || widget.onPreviousChapter != null)) {
          current = GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final v = details.primaryVelocity;
              if (v == null || v.abs() <= 350.0) return;
              if (v < 0) {
                widget.onNextChapter?.call();
              } else {
                widget.onPreviousChapter?.call();
              }
            },
            child: current,
          );
        }

        if (ts.gesturePinchFont) {
          current = Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerEnd,
            onPointerCancel: _handlePointerEnd,
            child: current,
          );
        }

        return current;
      },
    );
  }
}
