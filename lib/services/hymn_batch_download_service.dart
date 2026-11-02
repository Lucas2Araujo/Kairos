import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/hymn.dart';
import 'audio_service.dart';

/// Serviço central de gerenciamento de download em lote (batch) de áudios dos hinos.
/// Executa em segundo plano com notificações reativas de progresso e cancelamento.
class HymnBatchDownloadService extends ChangeNotifier {
  static final HymnBatchDownloadService _instance = HymnBatchDownloadService._internal();
  factory HymnBatchDownloadService() => _instance;
  HymnBatchDownloadService._internal();

  final AudioService _audioService = AudioService();

  bool _isRunning = false;
  bool _isCancelled = false;
  int _current = 0;
  int _total = 0;
  int _successCount = 0;
  int _failedCount = 0;
  String _currentHymnTitle = '';

  bool get isRunning => _isRunning;
  int get current => _current;
  int get total => _total;
  int get successCount => _successCount;
  int get failedCount => _failedCount;
  String get currentHymnTitle => _currentHymnTitle;
  double get progress => _total > 0 ? _current / _total : 0.0;

  /// Inicia o processo de download em lote para a lista de hinos selecionada
  Future<void> startBatch({
    required List<Hymn> hymns,
    required String edition,
  }) async {
    if (_isRunning || hymns.isEmpty) return;

    _isRunning = true;
    _isCancelled = false;
    _current = 0;
    _total = hymns.length;
    _successCount = 0;
    _failedCount = 0;
    _currentHymnTitle = '';
    notifyListeners();

    _audioService.precacheDownloadedHymns(edition);

    for (int i = 0; i < hymns.length; i++) {
      if (_isCancelled) break;

      final hymn = hymns[i];
      _current = i + 1;
      _currentHymnTitle = 'Hino ${hymn.numero} • ${hymn.titulo}';
      notifyListeners();

      // Se já estiver baixado no dispositivo, pula sem re-download
      if (_audioService.isHymnDownloaded(hymn.id, edition: edition)) {
        _successCount++;
        notifyListeners();
        continue;
      }

      try {
        final success = await _audioService.downloadHymn(
          hymn.id,
          null,
          edition: edition,
          isInstrumental: false,
        );

        if (success) {
          _successCount++;
        } else {
          _failedCount++;
        }
      } catch (e) {
        debugPrint('[HymnBatchDownloadService] Falha no download do hino ${hymn.numero}: $e');
        _failedCount++;
      }

      notifyListeners();
    }

    _isRunning = false;
    _audioService.precacheDownloadedHymns(edition);
    notifyListeners();
  }

  /// Cancela o processo de download em lote atual
  void cancel() {
    if (_isRunning) {
      _isCancelled = true;
      _isRunning = false;
      notifyListeners();
    }
  }
}
