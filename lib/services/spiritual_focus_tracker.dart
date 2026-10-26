import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'audio_service.dart';
import 'gamification_service.dart';

/// Rastreador de Presença e Foco Espiritual com Regra Anti-AFK de 120 segundos.
///
/// Envolve a área de leitura e contabiliza segundos de estudo ativo.
/// Se passar 2 minutos (120s) sem toque/scroll na tela E sem áudio tocando
/// (AudioService.isPlaying), a contagem pausa automaticamente até a próxima interação.
class SpiritualFocusTracker extends StatefulWidget {
  final Widget child;
  final bool enableTracking;

  const SpiritualFocusTracker({
    super.key,
    required this.child,
    this.enableTracking = true,
  });

  @override
  State<SpiritualFocusTracker> createState() => SpiritualFocusTrackerState();
}

class SpiritualFocusTrackerState extends State<SpiritualFocusTracker> {
  Timer? _ticker;
  int _secondsSinceLastInteraction = 0;
  bool _isAfk = false;

  int get secondsSinceLastInteraction => _secondsSinceLastInteraction;
  bool get isAfk => _isAfk;

  bool get _isTestEnv => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  @override
  void initState() {
    super.initState();
    if (widget.enableTracking && !_isTestEnv) {
      _startTracking();
    }
  }

  @override
  void didUpdateWidget(covariant SpiritualFocusTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableTracking != oldWidget.enableTracking) {
      if (widget.enableTracking && !_isTestEnv) {
        _startTracking();
      } else {
        _stopTracking();
      }
    }
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  void _startTracking() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void _stopTracking() {
    _ticker?.cancel();
    _ticker = null;
  }

  GamificationService? _gamificationOverride;
  AudioService? _audioServiceOverride;

  @visibleForTesting
  void initForTesting({
    GamificationService? gamificationService,
    AudioService? audioService,
  }) {
    _gamificationOverride = gamificationService;
    _audioServiceOverride = audioService;
  }

  void _onTick(Timer _) {
    _secondsSinceLastInteraction++;

    final audio = _audioServiceOverride ?? AudioService();
    final gamification = _gamificationOverride ?? GamificationService();

    final isAudioPlaying = audio.isPlaying;
    final isUserActive = _secondsSinceLastInteraction < 120 || isAudioPlaying;

    if (isUserActive) {
      if (_isAfk) {
        _isAfk = false;
        if (mounted) setState(() {});
      }
      gamification.addFocusSeconds(1);
    } else {
      if (!_isAfk) {
        _isAfk = true;
        if (mounted) setState(() {});
      }
    }
  }

  /// Registra uma interação do usuário (toque, scroll, tecla) resetando o relógio Anti-AFK
  void recordUserInteraction() {
    _secondsSinceLastInteraction = 0;
    if (_isAfk) {
      _isAfk = false;
      if (mounted) setState(() {});
    }
  }

  /// Método utilitário para disparar tick sob demanda (útil em testes unitários)
  void tickForTesting() {
    _onTick(_ticker ?? Timer(Duration.zero, () {}));
  }

  /// Força o tempo de inatividade para testes
  void setInactivityForTesting(int seconds) {
    _secondsSinceLastInteraction = seconds;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enableTracking) return widget.child;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => recordUserInteraction(),
      onPointerMove: (_) => recordUserInteraction(),
      onPointerSignal: (_) => recordUserInteraction(),
      onPointerHover: (_) => recordUserInteraction(),
      child: widget.child,
    );
  }
}
