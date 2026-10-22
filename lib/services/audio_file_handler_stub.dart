import 'dart:async';

/// Stub implementation of AudioFileHandler for platforms without `dart:io` (e.g. Flutter Web).
class AudioFileHandler {
  static Future<String?> findLocalAudioFile(int hymnId, {String edition = 'novo'}) async {
    return null;
  }

  static bool isHymnDownloaded(int hymnId, {String edition = 'novo'}) {
    return false;
  }

  static Future<bool> downloadHymn(
    int hymnId,
    String url, {
    String edition = 'novo',
    String? preferredExtension,
    void Function(double progress)? onProgress,
  }) async {
    return false;
  }

  static Future<bool> deleteDownloadedHymn(int hymnId, {String edition = 'novo'}) async {
    return false;
  }

  static void invalidateCache([String? edition]) {}
}
