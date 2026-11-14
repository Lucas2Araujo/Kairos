import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../data/services/sabbath_school_service.dart';

/// Widget com auto-cache em memória (LRU) + persistência em SQLite para tirinhas,
/// capas de lições, capas de livros e demais imagens remotas.
/// Carrega instantaneamente da RAM na mesma sessão ou do SQLite entre sessões;
/// caso contrário, baixa da web, salva no SQLite e exibe sem travar.
class CachedSSTirinhaImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;
  final bool showLoadingIndicator;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  /// Limite de imagens mantidas no cache em memória RAM.
  static const int maxMemoryCacheEntries = 60;
  static final LinkedHashMap<String, Uint8List> _memoryCache = LinkedHashMap<String, Uint8List>();
  static final Map<String, Future<Uint8List?>> _inFlightRequests = <String, Future<Uint8List?>>{};

  @visibleForTesting
  static void clearMemoryCache() {
    _memoryCache.clear();
    _inFlightRequests.clear();
  }

  @visibleForTesting
  static int get memoryCacheLength => _memoryCache.length;

  @visibleForTesting
  static void seedMemoryCacheForTest(String url, Uint8List bytes) {
    _putInMemoryCache(url.trim(), bytes);
  }

  static void _putInMemoryCache(String key, Uint8List bytes) {
    if (bytes.isEmpty) return;
    _memoryCache.remove(key);
    _memoryCache[key] = bytes;
    while (_memoryCache.length > maxMemoryCacheEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
  }

  const CachedSSTirinhaImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.showLoadingIndicator = true,
    this.errorBuilder,
  });

  @override
  State<CachedSSTirinhaImage> createState() => _CachedSSTirinhaImageState();
}

class _CachedSSTirinhaImageState extends State<CachedSSTirinhaImage> {
  final SabbathSchoolService _service = SabbathSchoolService();
  Uint8List? _bytes;
  bool _isLoading = true;
  bool _hasError = false;
  bool _fallbackToNetworkOnWeb = false;

  @override
  void initState() {
    super.initState();
    _initFromCacheOrLoad();
  }

  @override
  void didUpdateWidget(covariant CachedSSTirinhaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _initFromCacheOrLoad();
    }
  }

  void _initFromCacheOrLoad() {
    final url = widget.imageUrl.trim();
    if (url.isEmpty) {
      _bytes = null;
      _isLoading = false;
      _hasError = true;
      _fallbackToNetworkOnWeb = false;
      return;
    }

    final memHit = CachedSSTirinhaImage._memoryCache[url];
    if (memHit != null && memHit.isNotEmpty) {
      // Atualiza recência no LRU
      CachedSSTirinhaImage._putInMemoryCache(url, memHit);
      _bytes = memHit;
      _isLoading = false;
      _hasError = false;
      _fallbackToNetworkOnWeb = false;
      return;
    }

    _bytes = null;
    _isLoading = true;
    _hasError = false;
    _fallbackToNetworkOnWeb = false;
    _loadImage(url);
  }

  Future<Uint8List?> _resolveImageBytes(String url) {
    final existing = CachedSSTirinhaImage._inFlightRequests[url];
    if (existing != null) return existing;

    final future = () async {
      try {
        // 1. Tenta pegar do SQLite primeiro
        final cached = await _service.getCachedImage(url);
        if (cached != null && cached.isNotEmpty) {
          CachedSSTirinhaImage._putInMemoryCache(url, cached);
          return cached;
        }

        // 2. Se não estiver no cache, busca da rede e auto-cacheia no SQLite
        final fetched = await _service.fetchAndCacheImage(url);
        if (fetched != null && fetched.isNotEmpty) {
          CachedSSTirinhaImage._putInMemoryCache(url, fetched);
          return fetched;
        }
        return null;
      } finally {
        CachedSSTirinhaImage._inFlightRequests.remove(url);
      }
    }();

    CachedSSTirinhaImage._inFlightRequests[url] = future;
    return future;
  }

  Future<void> _loadImage(String url) async {
    try {
      final bytes = await _resolveImageBytes(url);
      if (!mounted || widget.imageUrl.trim() != url) return;

      if (bytes != null && bytes.isNotEmpty) {
        setState(() {
          _bytes = bytes;
          _isLoading = false;
          _hasError = false;
        });
      } else if (kIsWeb) {
        // Na Web, http.get pode ser bloqueado por CORS; delega ao elemento <img> nativo
        setState(() {
          _isLoading = false;
          _fallbackToNetworkOnWeb = true;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    } catch (_) {
      if (!mounted || widget.imageUrl.trim() != url) return;
      if (kIsWeb) {
        setState(() {
          _isLoading = false;
          _fallbackToNetworkOnWeb = true;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return Image.memory(
        _bytes!,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        gaplessPlayback: true,
        errorBuilder: (ctx, err, stack) =>
            widget.errorBuilder?.call(ctx, err, stack) ?? const SizedBox.shrink(),
      );
    }

    if (_fallbackToNetworkOnWeb) {
      return Image.network(
        widget.imageUrl.trim(),
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        alignment: widget.alignment,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (ctx, err, stack) =>
            widget.errorBuilder?.call(ctx, err, stack) ?? const SizedBox.shrink(),
      );
    }

    if (_isLoading) {
      if (!widget.showLoadingIndicator) {
        return SizedBox(width: widget.width, height: widget.height);
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_hasError) {
      return widget.errorBuilder?.call(context, 'Erro ao carregar imagem', null) ??
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                SizedBox(height: 8),
                Text(
                  'Não foi possível carregar a imagem.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
    }

    return SizedBox(width: widget.width, height: widget.height);
  }
}
