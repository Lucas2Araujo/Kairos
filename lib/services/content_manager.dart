import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/database/database_manager_io.dart'
    if (dart.library.js_interop) '../core/database/database_manager_web.dart';

const Map<String, String> bibleVersionNames = {
  'ARA': 'ARA - Almeida Revista e Atualizada',
  'NVI': 'NVI - Nova Versão Internacional',
  'NTLH': 'NTLH - Nova Tradução na Linguagem de Hoje',
  'KJA': 'KJA - King James Atualizada',
  'AS21': 'AS21 - Almeida Século 21',
  'NVT': 'NVT - Nova Versão Transformadora',
  'ACF': 'ACF - Almeida Corrigida Fiel',
  'ARC': 'ARC - Almeida Revista e Corrigida',
  'JFAA': 'JFAA - João Ferreira de Almeida Atualizada',
  'KJF': 'KJF - King James Fiel',
  'NAA': 'NAA - Nova Almeida Atualizada',
  'NBV': 'NBV - Nova Bíblia Viva',
  'TB': 'TB - Tradução Brasileira',
  'AVM': 'AVM - Bíblia Ave Maria (Católica + Apócrifos)',
};

class BibleModuleInfo {
  final String id;
  final String name;
  final String file;
  final int sizeBytes;
  final String url;
  final List<String> fallbackUrls;
  final bool isBundled;
  bool isInstalled;
  double? downloadProgress;

  BibleModuleInfo({
    required this.id,
    required this.name,
    required this.file,
    required this.sizeBytes,
    required this.url,
    List<String>? fallbackUrls,
    this.isBundled = false,
    this.isInstalled = false,
    this.downloadProgress,
  }) : fallbackUrls = List.unmodifiable(
          (fallbackUrls != null && fallbackUrls.isNotEmpty)
              ? fallbackUrls
              : (url.isNotEmpty ? [url] : const <String>[]),
        );
}

class ContentManager extends ChangeNotifier {
  static final ContentManager _instance = ContentManager._internal();
  factory ContentManager() => _instance;
  ContentManager._internal();

  final List<BibleModuleInfo> _bibleModules = [];
  bool _isInitialized = false;

  List<BibleModuleInfo> get bibleModules => List.unmodifiable(_bibleModules);

  List<String> get installedBibleVersions {
    final list = <String>['ARA'];
    for (final m in _bibleModules) {
      if (m.isInstalled && m.id != 'ARA' && !list.contains(m.id)) {
        list.add(m.id);
      }
    }
    return list;
  }

  bool isVersionInstalled(String version) {
    final v = version.toUpperCase();
    if (v == 'ARA') return true;
    final m = _bibleModules.where((mod) => mod.id == v).firstOrNull;
    return m?.isInstalled ?? false;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    try {
      final manifestStr = await rootBundle.loadString('assets/manifest.json');
      _parseManifest(manifestStr);
    } catch (e) {
      debugPrint('[ContentManager] Erro ao carregar manifest local: $e');
    }

    await _checkInstalledStatus();
    notifyListeners();

    _fetchRemoteManifestInBackground();
  }

  /// Constrói a lista ordenada e sem duplicatas de URLs para download do módulo bíblico.
  ///
  /// No Web ([isWeb] == true):
  /// - URL primária: Cloudflare R2 (`${AppConfig.r2AudioBaseUrl}/biblias/$file`)
  /// - Fallback: [rawUrl] especificada no manifest
  ///
  /// No Mobile/Desktop IO ([isWeb] == false):
  /// - URL primária: [rawUrl]
  /// - Fallback: Cloudflare R2
  @visibleForTesting
  static List<String> buildFallbackUrls({
    required String file,
    required String rawUrl,
    bool isWeb = kIsWeb,
  }) {
    final r2Url = file.isNotEmpty ? '${AppConfig.r2AudioBaseUrl}/biblias/$file' : '';
    final primary = isWeb ? r2Url : (rawUrl.isNotEmpty ? rawUrl : r2Url);
    final fallback = isWeb ? rawUrl : r2Url;

    final result = <String>[];
    if (primary.trim().isNotEmpty) {
      result.add(primary.trim());
    }
    if (fallback.trim().isNotEmpty && !result.contains(fallback.trim())) {
      result.add(fallback.trim());
    }
    return List.unmodifiable(result);
  }

  void _parseManifest(String manifestJson) {
    try {
      final decoded = json.decode(manifestJson) as Map<String, dynamic>;
      final rawModules = decoded['modules'] as List<dynamic>? ?? [];

      for (final raw in rawModules) {
        if (raw is! Map<String, dynamic>) continue;
        final id = raw['id'] as String? ?? '';
        final file = raw['file'] as String? ?? '';
        final rawUrl = raw['url'] as String? ?? '';
        final fallbackUrls = buildFallbackUrls(
          file: file,
          rawUrl: rawUrl,
          isWeb: kIsWeb,
        );
        final url = fallbackUrls.isNotEmpty ? fallbackUrls.first : rawUrl;
        final sizeBytes = raw['size_bytes'] as int? ?? 0;

        if (id.isEmpty || id.startsWith('hinario') || !file.contains('.sqlite')) {
          continue;
        }

        final name = bibleVersionNames[id] ?? id;
        final isBundled = (id == 'ARA');

        final existingIndex = _bibleModules.indexWhere((m) => m.id == id);
        if (existingIndex >= 0) {
          final old = _bibleModules[existingIndex];
          _bibleModules[existingIndex] = BibleModuleInfo(
            id: id,
            name: name,
            file: file,
            sizeBytes: sizeBytes > 0 ? sizeBytes : old.sizeBytes,
            url: url.isNotEmpty ? url : old.url,
            fallbackUrls: fallbackUrls.isNotEmpty ? fallbackUrls : old.fallbackUrls,
            isBundled: isBundled,
            isInstalled: old.isInstalled,
            downloadProgress: old.downloadProgress,
          );
        } else {
          _bibleModules.add(BibleModuleInfo(
            id: id,
            name: name,
            file: file,
            sizeBytes: sizeBytes,
            url: url,
            fallbackUrls: fallbackUrls,
            isBundled: isBundled,
            isInstalled: isBundled,
          ));
        }
      }
    } catch (e) {
      debugPrint('[ContentManager] Erro ao processar dados do manifest: $e');
    }
  }

  Future<void> _checkInstalledStatus() async {
    for (final m in _bibleModules) {
      if (m.isBundled) {
        m.isInstalled = true;
      } else {
        m.isInstalled = await isDbFileInstalled('${m.id}.sqlite');
      }
    }
  }

  void _fetchRemoteManifestInBackground() {
    unawaited(() async {
      try {
        final uri = Uri.parse(
          'https://raw.githubusercontent.com/Lucas2Araujo/NHA_Intel/main/manifest.json',
        );
        final resp = await http.get(uri).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          _parseManifest(resp.body);
          await _checkInstalledStatus();
          notifyListeners();
        }
      } catch (_) {
        // Silencioso em caso de falha de conexão/offline
      }
    }());
  }

  /// Baixa o módulo bíblico compactado em gzip e retorna os bytes do SQLite descompactado.
  ///
  /// Executa tentativa em ordem pelas URLs disponíveis ([BibleModuleInfo.fallbackUrls])
  /// com fallback automático antes de lançar [StateError].
  Future<Uint8List> fetchAndDecompressModuleBytes(
    String id, {
    void Function(double progress)? onProgress,
  }) async {
    final module = _bibleModules.where((m) => m.id == id).firstOrNull;
    if (module == null) {
      throw ArgumentError('Módulo Bíblico $id não encontrado no catálogo.');
    }

    final candidateUrls = <String>[];
    for (final u in [module.url, ...module.fallbackUrls]) {
      final trimmed = u.trim();
      if (trimmed.isNotEmpty && !candidateUrls.contains(trimmed)) {
        candidateUrls.add(trimmed);
      }
    }

    if (candidateUrls.isEmpty) {
      throw StateError('Nenhuma URL configurada para o módulo $id.');
    }

    final client = http.Client();
    final failures = <String>[];

    try {
      for (int i = 0; i < candidateUrls.length; i++) {
        final currentUrl = candidateUrls[i];
        try {
          final request = http.Request('GET', Uri.parse(currentUrl));
          final response = await client.send(request);
          if (response.statusCode != 200) {
            failures.add('$currentUrl (HTTP ${response.statusCode})');
            debugPrint(
              '[ContentManager] Tentativa ${i + 1}/${candidateUrls.length} falhou ($currentUrl): HTTP ${response.statusCode}',
            );
            continue;
          }

          final total = response.contentLength ?? module.sizeBytes;
          int received = 0;
          final chunks = <List<int>>[];

          await for (final chunk in response.stream) {
            chunks.add(chunk);
            received += chunk.length;
            if (total > 0) {
              final progress = (received / total).clamp(0.0, 1.0);
              module.downloadProgress = progress;
              onProgress?.call(progress);
              notifyListeners();
            }
          }

          final gzBytes = Uint8List.fromList(chunks.expand((c) => c).toList());
          return await decompressGzip(gzBytes);
        } catch (e) {
          failures.add('$currentUrl ($e)');
          debugPrint(
            '[ContentManager] Erro na tentativa ${i + 1}/${candidateUrls.length} ($currentUrl): $e',
          );
        }
      }

      throw StateError(
        'Falha ao baixar módulo $id após tentar todas as URLs: ${failures.join('; ')}',
      );
    } finally {
      client.close();
    }
  }

  Future<void> downloadModule(
    String id, {
    void Function(double progress)? onProgress,
  }) async {
    final module = _bibleModules.where((m) => m.id == id).firstOrNull;
    if (module != null) {
      module.downloadProgress = 0.0;
      notifyListeners();
    }

    try {
      final decompressedBytes = await fetchAndDecompressModuleBytes(
        id,
        onProgress: onProgress,
      );
      await saveDbFileBytes('$id.sqlite', decompressedBytes);
      if (module != null) {
        module.isInstalled = true;
        module.downloadProgress = null;
      }
      notifyListeners();
    } catch (e) {
      if (module != null) {
        module.downloadProgress = null;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteModule(String id) async {
    if (id == 'ARA') return; // ARA é integrada e protegida

    final module = _bibleModules.where((m) => m.id == id).firstOrNull;
    closePlatformDatabase('$id.sqlite');
    await deleteDbFile('$id.sqlite');

    if (module != null) {
      module.isInstalled = false;
      module.downloadProgress = null;
    }
    notifyListeners();
  }
}
