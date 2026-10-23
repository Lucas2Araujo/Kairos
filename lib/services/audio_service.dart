import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import 'audio_file_handler_stub.dart'
    if (dart.library.io) 'audio_file_handler_io.dart';
import 'theme_service.dart';

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

  String? _lastCustomUrl;
  String? _lastLinkVideo;

  /// Hook para testes injetarem resolução sem acessar rede externa.
  @visibleForTesting
  Future<String?> Function(String url)? youtubeResolverOverride;

  @visibleForTesting
  AudioPlayer get player => _player;

  /// Verifica se uma URL pertence ao YouTube.
  static bool isYouTubeUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.trim().toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  /// Extrai a URL direta do stream de áudio do YouTube com maior bitrate,
  /// priorizando streams mp4 (m4a/aac) para compatibilidade universal.
  Future<String?> resolveYouTubeAudioStream(String url) async {
    if (youtubeResolverOverride != null) {
      return youtubeResolverOverride!(url);
    }
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient.getManifest(url.trim());
      // Prioriza container mp4 (m4a/aac) para compatibilidade universal com audioplayers e extensão .m4a
      final mp4Streams = manifest.audioOnly.where((s) => s.container.name.toLowerCase() == 'mp4');
      final streamInfo = mp4Streams.isNotEmpty
          ? mp4Streams.withHighestBitrate()
          : manifest.audioOnly.withHighestBitrate();
      return streamInfo.url.toString();
    } catch (e) {
      debugPrint('[AudioService] Erro ao extrair áudio do YouTube ($url): $e');
      return null;
    } finally {
      yt.close();
    }
  }

  void _cacheStreamInBackground(
    int hymnId,
    String streamUrl, {
    String? edition,
    bool isInstrumental = false,
  }) {
    if (kIsWeb) return;
    unawaited(() async {
      try {
        final currentEdition = edition ?? ThemeService().currentEdition;
        final success = await AudioFileHandler.downloadHymn(
          hymnId,
          streamUrl,
          edition: currentEdition,
          isInstrumental: isInstrumental,
          preferredExtension: '.m4a',
        );
        if (success) {
          debugPrint('[AudioService] Hino $hymnId ($currentEdition) salvo em cache local (.m4a).');
          notifyListeners();
        }
      } catch (e) {
        debugPrint('[AudioService] Erro ao armazenar cache do hino $hymnId: $e');
      }
    }());
  }

  /// Retorna a URL padrão segura para streaming quando não houver URL customizada.
  static String getDefaultAudioUrl(int hymnId, {bool isInstrumental = false}) {
    final track = isInstrumental ? 'instrumental' : 'cantado';
    return 'https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/audio/$track/hino_$hymnId.mp3';
  }

  /// Inicializa os listeners do AudioPlayer e caminhos de arquivos.
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb) {
      await AudioFileHandler.init();
    }

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
    String? linkVideo,
    String? edition,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    final currentEdition = edition ?? ThemeService().currentEdition;
    _currentHymnId = hymnId;
    _currentHymnNumber = numero;
    _currentHymnTitle = titulo;
    _isInstrumental = isInstrumental;
    _lastCustomUrl = customUrl;
    _lastLinkVideo = linkVideo;
    _isBuffering = true;
    _position = Duration.zero;
    notifyListeners();

    try {
      Source source;
      String? localPath;

      if (!kIsWeb) {
        localPath = await AudioFileHandler.findLocalAudioFile(
          hymnId,
          edition: currentEdition,
          isInstrumental: isInstrumental,
        );
      }

      if (localPath != null) {
        source = DeviceFileSource(localPath);
      } else {
        String? streamUrl;

        // Se houver URL do YouTube em customUrl ou linkVideo (apenas se for faixa cantada)
        final candidateUrl = (customUrl != null && isYouTubeUrl(customUrl))
            ? customUrl.trim()
            : (linkVideo != null && isYouTubeUrl(linkVideo) ? linkVideo.trim() : null);

        if (candidateUrl != null && !isInstrumental) {
          final resolvedYt = await resolveYouTubeAudioStream(candidateUrl);
          if (resolvedYt != null) {
            streamUrl = resolvedYt;
            if (!kIsWeb) {
              _cacheStreamInBackground(
                hymnId,
                resolvedYt,
                edition: currentEdition,
                isInstrumental: isInstrumental,
              );
            }
          }
        }

        // Se a resolução do YouTube falhar ou não houver link do YouTube:
        // Preserva fallback para URLs raw do GitHub ou customUrl não-YouTube
        if (streamUrl == null) {
          if (customUrl != null && !isYouTubeUrl(customUrl) && customUrl.trim().isNotEmpty) {
            streamUrl = customUrl.trim();
          } else {
            streamUrl = getDefaultAudioUrl(hymnId, isInstrumental: isInstrumental);
          }
        }

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
        customUrl: _isInstrumental ? null : _lastCustomUrl,
        linkVideo: _lastLinkVideo,
      );
    }
  }

  /// Verifica se o hino está disponível offline no disco local (sempre false na Web).
  bool isHymnDownloaded(int hymnId, {String? edition, bool isInstrumental = false}) {
    if (kIsWeb) return false;
    final currentEdition = edition ?? ThemeService().currentEdition;
    return AudioFileHandler.isHymnDownloaded(
      hymnId,
      edition: currentEdition,
      isInstrumental: isInstrumental,
    );
  }

  /// Baixa o áudio de um hino para reprodução offline e atualiza o cache local.
  Future<bool> downloadHymn(
    int hymnId,
    String url, {
    String? edition,
    bool isInstrumental = false,
    String? preferredExtension,
    void Function(double progress)? onProgress,
  }) async {
    if (kIsWeb) return false;
    final currentEdition = edition ?? ThemeService().currentEdition;
    String targetUrl = url;
    String? ext = preferredExtension;

    if (isYouTubeUrl(url)) {
      final resolved = await resolveYouTubeAudioStream(url);
      if (resolved != null) {
        targetUrl = resolved;
        ext = '.m4a';
      } else {
        targetUrl = getDefaultAudioUrl(hymnId, isInstrumental: isInstrumental);
      }
    }

    final ok = await AudioFileHandler.downloadHymn(
      hymnId,
      targetUrl,
      edition: currentEdition,
      isInstrumental: isInstrumental,
      preferredExtension: ext,
      onProgress: onProgress,
    );
    notifyListeners();
    return ok;
  }

  /// Exclui o arquivo de áudio offline baixado de um hino.
  Future<bool> deleteDownloadedHymn(
    int hymnId, {
    String? edition,
    bool isInstrumental = false,
  }) async {
    if (kIsWeb) return false;
    final currentEdition = edition ?? ThemeService().currentEdition;
    final ok = await AudioFileHandler.deleteDownloadedHymn(
      hymnId,
      edition: currentEdition,
      isInstrumental: isInstrumental,
    );
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
