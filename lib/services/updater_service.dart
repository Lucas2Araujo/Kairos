import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../core/config/app_config.dart';
import 'auth_loopback_stub.dart' if (dart.library.io) 'auth_loopback_io.dart';

class ReleaseUpdateInfo {
  final String tagName;
  final String version;
  final String changelog;
  final String downloadUrl;
  final String assetName;
  final int assetSize;
  final String abi;

  const ReleaseUpdateInfo({
    required this.tagName,
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.assetName,
    required this.assetSize,
    required this.abi,
  });
}

class UpdaterService {
  static const String defaultCurrentVersion = AppConfig.appVersion;
  static const String githubLatestReleaseUrl =
      'https://api.github.com/repos/Lucas2Araujo/NHA_Intel/releases/latest';
  static const MethodChannel _systemChannel = MethodChannel('kairos.app/system');

  /// Retorna a versão instalada do aplicativo (Android PackageInfo ou APP_VERSION compilada)
  Future<String> getInstalledVersion() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final nativeVer = await _systemChannel.invokeMethod<String>('getAppVersion');
        if (nativeVer != null && nativeVer.trim().isNotEmpty) {
          return nativeVer.trim();
        }
      } catch (e) {
        debugPrint('[UpdaterService] Erro ao obter versão nativa do Android: $e');
      }
    }
    return defaultCurrentVersion;
  }

  /// Retorna as ABIs suportadas pelo dispositivo Android (ex: ['arm64-v8a', 'armeabi-v7a'])
  Future<List<String>> getDeviceAbis() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _systemChannel.invokeListMethod<String>('getSupportedAbis');
        if (result != null && result.isNotEmpty) return result;
      } catch (e) {
        debugPrint('[UpdaterService] Erro ao obter ABIs do dispositivo: $e');
      }
    }
    return const ['arm64-v8a'];
  }

  /// Compara se [remoteVer] é estritamente mais recente que [currentVer]
  static bool isNewerVersion(String remoteVer, String currentVer) {
    List<int> parseVersion(String v) {
      var clean = v.trim();
      if (clean.startsWith('v') || clean.startsWith('V')) {
        clean = clean.substring(1);
      }
      clean = clean.split('+').first;
      final parts = clean.split('.');
      final numbers = <int>[];
      for (final p in parts) {
        final match = RegExp(r'^\d+').firstMatch(p);
        numbers.add(match != null ? int.tryParse(match.group(0)!) ?? 0 : 0);
      }
      return numbers;
    }

    final remote = parseVersion(remoteVer);
    final current = parseVersion(currentVer);
    final maxLen = remote.length > current.length ? remote.length : current.length;

    for (int i = 0; i < maxLen; i++) {
      final r = i < remote.length ? remote[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Seleciona o melhor asset APK para a arquitetura do dispositivo
  static Map<String, dynamic>? matchBestAsset(List<dynamic> assets, List<String> deviceAbis) {
    final apkAssets = assets.where((a) {
      if (a is! Map<String, dynamic>) return false;
      final name = (a['name'] ?? '').toString().toLowerCase();
      return name.endsWith('.apk');
    }).cast<Map<String, dynamic>>().toList();

    if (apkAssets.isEmpty) return null;

    for (final abi in deviceAbis) {
      final lowerAbi = abi.toLowerCase();
      for (final asset in apkAssets) {
        final name = (asset['name'] ?? '').toString().toLowerCase();
        if (lowerAbi.contains('arm64') && name.contains('arm64')) {
          return asset;
        }
        if ((lowerAbi.contains('armeabi') || lowerAbi.contains('armv7')) &&
            (name.contains('armv7') || name.contains('armeabi'))) {
          return asset;
        }
        if (lowerAbi.contains('x86_64') && name.contains('x86_64')) {
          return asset;
        }
      }
    }

    return apkAssets.firstWhere(
      (a) => (a['name'] ?? '').toString().toLowerCase().contains('universal'),
      orElse: () => apkAssets.first,
    );
  }

  /// Verifica se há atualizações disponíveis no GitHub Releases
  Future<ReleaseUpdateInfo?> checkForUpdate({String currentVersion = defaultCurrentVersion}) async {
    try {
      final res = await http.get(
        Uri.parse(githubLatestReleaseUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );
      if (res.statusCode != 200) return null;

      final data = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tagName = (data['tag_name'] ?? '').toString();
      final body = (data['body'] ?? '').toString();
      final assets = (data['assets'] as List<dynamic>?) ?? [];

      var remoteVer = tagName;
      if (remoteVer.startsWith('v') || remoteVer.startsWith('V')) {
        remoteVer = remoteVer.substring(1);
      }

      if (!isNewerVersion(remoteVer, currentVersion)) {
        return null;
      }

      final abis = await getDeviceAbis();
      final matchedAsset = matchBestAsset(assets, abis);
      if (matchedAsset == null) return null;

      final assetName = (matchedAsset['name'] ?? '').toString();
      final downloadUrl = (matchedAsset['browser_download_url'] ?? '').toString();
      final assetSize = (matchedAsset['size'] as num?)?.toInt() ?? 0;

      String matchedAbi = 'universal';
      final lowerName = assetName.toLowerCase();
      if (lowerName.contains('arm64')) {
        matchedAbi = 'arm64-v8a';
      } else if (lowerName.contains('armv7') || lowerName.contains('armeabi')) {
        matchedAbi = 'armeabi-v7a';
      } else if (lowerName.contains('x86_64')) {
        matchedAbi = 'x86_64';
      }

      return ReleaseUpdateInfo(
        tagName: tagName,
        version: remoteVer,
        changelog: body,
        downloadUrl: downloadUrl,
        assetName: assetName,
        assetSize: assetSize,
        abi: matchedAbi,
      );
    } catch (e) {
      debugPrint('[UpdaterService] Erro ao verificar atualização: $e');
      return null;
    }
  }

  /// Baixa o APK em diretório temporário e solicita ao sistema Android para instalar
  Future<String> downloadAndInstallApk(
    ReleaseUpdateInfo info, {
    void Function(double progress, int received, int total)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${info.assetName}';

    final savedPath = await downloadFileStream(
      url: info.downloadUrl,
      targetPath: targetPath,
      onProgress: onProgress,
    );

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _systemChannel.invokeMethod('installApk', {'filePath': savedPath});
    }

    return savedPath;
  }
}
