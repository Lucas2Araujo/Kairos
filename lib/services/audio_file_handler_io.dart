import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// IO implementation of AudioFileHandler for desktop and mobile platforms.
class AudioFileHandler {
  static final Map<String, Set<int>> _cache = {};
  static String? _appDocsPath;

  /// Inicializa o caminho do AppDocumentsDirectory para checagens síncronas no Android/iOS.
  static Future<void> init() async {
    if (_appDocsPath != null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      _appDocsPath = dir.path;
    } catch (_) {}
  }

  static String _getFilePrefix(int hymnId, {bool isInstrumental = false}) {
    return isInstrumental ? 'hino_${hymnId}_inst' : 'hino_$hymnId';
  }

  static int _getCacheKey(int hymnId, {bool isInstrumental = false}) {
    return isInstrumental ? -hymnId : hymnId;
  }

  static Future<List<Directory>> _getCandidateDirs(String edition) async {
    final dirs = <Directory>[];

    // 1. Current working directory downloads (e.g. Linux desktop / development)
    final localDir = Directory(p.join('downloads', 'audio_$edition'));
    dirs.add(localDir);

    // 2. App Documents directory downloads (e.g. Android / installed app)
    if (_appDocsPath != null) {
      dirs.add(Directory(p.join(_appDocsPath!, 'downloads', 'audio_$edition')));
    } else {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        _appDocsPath = appDir.path;
        dirs.add(Directory(p.join(appDir.path, 'downloads', 'audio_$edition')));
      } catch (_) {}
    }

    return dirs;
  }

  static Future<Directory> _getTargetDownloadDir(String edition) async {
    final localDir = Directory(p.join('downloads', 'audio_$edition'));
    if (await localDir.exists()) {
      return localDir;
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _appDocsPath = appDir.path;
      final dir = Directory(p.join(appDir.path, 'downloads', 'audio_$edition'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      // Fallback para diretório local
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }
      return localDir;
    }
  }

  static void invalidateCache([String? edition]) {
    if (edition != null) {
      _cache.remove(edition);
    } else {
      _cache.clear();
    }
  }

  static Future<String?> findLocalAudioFile(
    int hymnId, {
    String edition = 'novo',
    bool isInstrumental = false,
  }) async {
    final dirs = await _getCandidateDirs(edition);
    final prefix = _getFilePrefix(hymnId, isInstrumental: isInstrumental);
    final cacheKey = _getCacheKey(hymnId, isInstrumental: isInstrumental);

    for (final dir in dirs) {
      if (await dir.exists()) {
        for (final ext in ['.m4a', '.mp3', '.ogg']) {
          final file = File(p.join(dir.path, '$prefix$ext'));
          if (await file.exists() && (await file.length()) > 0) {
            _cache.putIfAbsent(edition, () => <int>{}).add(cacheKey);
            return file.path;
          }
        }
      }
    }
    return null;
  }

  static bool isHymnDownloaded(
    int hymnId, {
    String edition = 'novo',
    bool isInstrumental = false,
  }) {
    final cacheKey = _getCacheKey(hymnId, isInstrumental: isInstrumental);
    // 1. Verifica cache em memória
    final cached = _cache[edition];
    if (cached != null && cached.contains(cacheKey)) {
      return true;
    }

    final prefix = _getFilePrefix(hymnId, isInstrumental: isInstrumental);
    final candidatePaths = <String>[
      p.join('downloads', 'audio_$edition'),
      if (_appDocsPath != null) p.join(_appDocsPath!, 'downloads', 'audio_$edition'),
    ];

    // 2. Checagem síncrona nos diretórios candidatos
    for (final dirPath in candidatePaths) {
      final dir = Directory(dirPath);
      if (dir.existsSync()) {
        for (final ext in ['.m4a', '.mp3', '.ogg']) {
          final f = File(p.join(dir.path, '$prefix$ext'));
          if (f.existsSync() && f.lengthSync() > 0) {
            _cache.putIfAbsent(edition, () => <int>{}).add(cacheKey);
            return true;
          }
        }
      }
    }

    return false;
  }

  static Future<bool> downloadHymn(
    int hymnId,
    String url, {
    String edition = 'novo',
    bool isInstrumental = false,
    String? preferredExtension,
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final dir = await _getTargetDownloadDir(edition);
      final isMp3 = url.toLowerCase().contains('.mp3');
      final extension = preferredExtension ?? (isMp3 ? '.mp3' : '.m4a');
      final prefix = _getFilePrefix(hymnId, isInstrumental: isInstrumental);
      final cacheKey = _getCacheKey(hymnId, isInstrumental: isInstrumental);
      final targetFile = File(p.join(dir.path, '$prefix$extension'));
      final tempFile = File(p.join(dir.path, '$prefix$extension.tmp'));

      if (await targetFile.exists() && (await targetFile.length()) > 0) {
        _cache.putIfAbsent(edition, () => <int>{}).add(cacheKey);
        return true;
      }

      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      if (response.statusCode != 200) {
        return false;
      }

      final total = response.contentLength ?? 0;
      int received = 0;
      final sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          final progress = (received / total).clamp(0.0, 1.0);
          onProgress(progress);
        }
      }
      await sink.flush();
      await sink.close();

      if (await tempFile.length() == 0) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        return false;
      }

      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetFile.path);

      invalidateCache(edition);
      _cache.putIfAbsent(edition, () => <int>{}).add(cacheKey);
      return true;
    } catch (e) {
      debugPrint('[AudioFileHandler] Erro no download do hino $hymnId: $e');
      return false;
    } finally {
      client.close();
    }
  }

  static Future<bool> deleteDownloadedHymn(
    int hymnId, {
    String edition = 'novo',
    bool isInstrumental = false,
  }) async {
    bool deleted = false;
    final dirs = await _getCandidateDirs(edition);
    final prefix = _getFilePrefix(hymnId, isInstrumental: isInstrumental);

    for (final dir in dirs) {
      if (await dir.exists()) {
        for (final ext in ['.m4a', '.mp3', '.ogg', '.tmp']) {
          final file = File(p.join(dir.path, '$prefix$ext'));
          if (await file.exists()) {
            try {
              await file.delete();
              deleted = true;
            } catch (_) {}
          }
        }
      }
    }
    invalidateCache(edition);
    return deleted;
  }
}
