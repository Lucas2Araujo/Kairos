import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'audio_file_handler_stub.dart'
    if (dart.library.io) 'audio_file_handler_io.dart';

/// Serviço central de reprodução de áudio, downloads offline e gerenciamento
/// de faixas cantadas e instrumentais para o Hinário Kairós.
class AudioService extends ChangeNotifier {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  int? _currentHymnId;
  String? _currentHymnNumber;
  String? _currentHymnTitle;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isInstrumental = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 1.0;

  bool _isInitialized = false;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  // Getters reativos
  int? get currentHymnId => _currentHymnId;
  String? get currentHymnNumber => _currentHymnNumber;
  String? get currentHymnTitle => _currentHymnTitle;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isInstrumental => _isInstrumental;
  Duration get position => _position;
  Duration get duration => _duration;
  double get volume => _volume;

  /// Retorna a URL padrão segura para streaming quando não houver URL customizada.
  static String getDefaultAudioUrl(int hymnId, {bool isInstrumental = false}) {
    final track = isInstrumental ? 'instrumental' : 'cantado';
    return 'https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/audio/$track/hino_$hymnId.mp3';
  }

  /// Inicializa os listeners do AudioPlayer.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _playerStateSubscription = _player.onPlayerStateChanged.listen((state) {
      switch (state) {
        case PlayerState.playing:
          _isPlaying = true;
          _isBuffering = false;
          break;
        case PlayerState.paused:
          _isPlaying = false;
          _isBuffering = false;
          break;
        case PlayerState.stopped:
          _isPlaying = false;
          _isBuffering = false;
          _position = Duration.zero;
          break;
        case PlayerState.completed:
          _isPlaying = false;
          _isBuffering = false;
          _position = Duration.zero;
          break;
        case PlayerState.disposed:
          _isPlaying = false;
          _isBuffering = false;
          break;
      }
      notifyListeners();
    });

    _positionSubscription = _player.onPositionChanged.listen((newPos) {
      _position = newPos;
      notifyListeners();
    });

    _durationSubscription = _player.onDurationChanged.listen((newDur) {
      _duration = newDur;
      notifyListeners();
    });
  }

  /// Inicia ou altera a reprodução de um hino.
  /// Verifica se há arquivo local offline baixado ou utiliza URL de streaming remota.
  Future<void> playHymn({
    required int hymnId,
    required String numero,
    required String titulo,
    bool isInstrumental = false,
    String? customUrl,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    _currentHymnId = hymnId;
    _currentHymnNumber = numero;
    _currentHymnTitle = titulo;
    _isInstrumental = isInstrumental;
    _isBuffering = true;
    _position = Duration.zero;
    notifyListeners();

    try {
      Source source;
      String? localPath;

      if (!kIsWeb) {
        localPath = await AudioFileHandler.findLocalAudioFile(hymnId, edition: 'novo');
      }

      if (localPath != null) {
        source = DeviceFileSource(localPath);
      } else {
        final streamUrl = (customUrl != null && customUrl.trim().isNotEmpty)
            ? customUrl.trim()
            : getDefaultAudioUrl(hymnId, isInstrumental: isInstrumental);
        source = UrlSource(streamUrl);
      }

      await _player.stop();
      await _player.setVolume(_volume);
      await _player.play(source);

      _isPlaying = true;
      _isBuffering = false;
      notifyListeners();
    } catch (e) {
      _isPlaying = false;
      _isBuffering = false;
      debugPrint('[AudioService] Erro ao reproduzir hino $numero: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Pausa a reprodução atual.
  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] Erro ao pausar: $e');
    }
  }

  /// Retoma a reprodução pausada.
  Future<void> resume() async {
    try {
      await _player.resume();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] Erro ao retomar: $e');
    }
  }

  /// Para a reprodução e reseta a posição.
  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _position = Duration.zero;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] Erro ao parar: $e');
    }
  }

  /// Move o cursor de reprodução para a posição informada.
  Future<void> seek(Duration newPosition) async {
    try {
      await _player.seek(newPosition);
      _position = newPosition;
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] Erro ao buscar posição: $e');
    }
  }

  /// Ajusta o volume do reprodutor (0.0 a 1.0).
  Future<void> setVolume(double val) async {
    _volume = val.clamp(0.0, 1.0);
    try {
      await _player.setVolume(_volume);
      notifyListeners();
    } catch (e) {
      debugPrint('[AudioService] Erro ao ajustar volume: $e');
    }
  }

  /// Alterna entre faixa instrumental e faixa cantada.
  Future<void> toggleTrack() async {
    _isInstrumental = !_isInstrumental;
    notifyListeners();

    if (_currentHymnId != null &&
        _currentHymnNumber != null &&
        _currentHymnTitle != null &&
        _isPlaying) {
      await playHymn(
        hymnId: _currentHymnId!,
        numero: _currentHymnNumber!,
        titulo: _currentHymnTitle!,
        isInstrumental: _isInstrumental,
      );
    }
  }

  /// Verifica se o hino está disponível offline no disco local (sempre false na Web).
  bool isHymnDownloaded(int hymnId, {String edition = 'novo'}) {
    if (kIsWeb) return false;
    return AudioFileHandler.isHymnDownloaded(hymnId, edition: edition);
  }

  /// Baixa o áudio de um hino para reprodução offline e atualiza o cache local.
  Future<bool> downloadHymn(
    int hymnId,
    String url, {
    String edition = 'novo',
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return false;
    final ok = await AudioFileHandler.downloadHymn(
      hymnId,
      url,
      edition: edition,
      onProgress: onProgress,
    );
    notifyListeners();
    return ok;
  }

  /// Exclui o arquivo de áudio offline baixado de um hino.
  Future<bool> deleteDownloadedHymn(int hymnId, {String edition = 'novo'}) async {
    if (kIsWeb) return false;
    final ok = await AudioFileHandler.deleteDownloadedHymn(hymnId, edition: edition);
    notifyListeners();
    return ok;
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
