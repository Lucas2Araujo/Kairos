import 'package:flutter/foundation.dart';

/// Controlador multiplataforma para sincronizar estado de reprodução (play/pause,
/// posição atual e duração total) entre a barra de progresso nativa do Kairós e
/// o player interno do YouTube (WebView no Android/iOS ou iframe na Web).
class KairosYoutubeController extends ChangeNotifier {
  bool _isReady = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Future<void> Function()? _onPlay;
  Future<void> Function()? _onPause;
  Future<void> Function(Duration position)? _onSeekTo;

  /// Indica se a ponte de controle do player já reportou estado válido.
  bool get isReady => _isReady;

  /// Indica se o vídeo está em reprodução no momento.
  bool get isPlaying => _isPlaying;

  /// Posição atual de reprodução do vídeo.
  Duration get position => _position;

  /// Duração total do vídeo.
  Duration get duration => _duration;

  /// Vincula os callbacks concretos da plataforma ativa (Android WebView ou Web iframe).
  void attach({
    required Future<void> Function() onPlay,
    required Future<void> Function() onPause,
    required Future<void> Function(Duration position) onSeekTo,
  }) {
    _onPlay = onPlay;
    _onPause = onPause;
    _onSeekTo = onSeekTo;
  }

  /// Remove os callbacks da plataforma ao desmontar o embed.
  void detach() {
    _onPlay = null;
    _onPause = null;
    _onSeekTo = null;
  }

  /// Atualiza o estado reportado pelo player interno.
  void updateState({
    bool? isReady,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    var changed = false;
    if (isReady != null && _isReady != isReady) {
      _isReady = isReady;
      changed = true;
    }
    if (isPlaying != null && _isPlaying != isPlaying) {
      _isPlaying = isPlaying;
      changed = true;
    }
    if (position != null && _position != position) {
      _position = position;
      changed = true;
    }
    if (duration != null && _duration != duration) {
      _duration = duration;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Retoma explicitamente a reprodução (útil ao alternar entre PiP e tela cheia).
  Future<void> play() async {
    _isPlaying = true;
    notifyListeners();
    await _onPlay?.call();
  }

  /// Alterna entre reproduzir e pausar o vídeo.
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      _isPlaying = false;
      notifyListeners();
      await _onPause?.call();
    } else {
      _isPlaying = true;
      notifyListeners();
      await _onPlay?.call();
    }
  }

  /// Move a reprodução para a [target] especificada.
  Future<void> seekTo(Duration target) async {
    final clamped = _duration > Duration.zero
        ? Duration(
            milliseconds: target.inMilliseconds.clamp(0, _duration.inMilliseconds),
          )
        : target;
    _position = clamped;
    notifyListeners();
    await _onSeekTo?.call(clamped);
  }
}
