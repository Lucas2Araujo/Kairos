import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../data/services/sabbath_school_service.dart';

/// Widget com auto-cache transparente em SQLite para tirinhas e imagens da Escola Sabatina.
/// Carrega instantaneamente do banco local se já estiver cacheado;
/// caso contrário, baixa da web, salva no SQLite e exibe sem travar.
class CachedSSTirinhaImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final bool showLoadingIndicator;
  final Widget Function(BuildContext context, Object error, StackTrace? stackTrace)? errorBuilder;

  const CachedSSTirinhaImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
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

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant CachedSSTirinhaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // 1. Tenta pegar do SQLite primeiro
      final cached = await _service.getCachedImage(widget.imageUrl);
      if (cached != null && cached.isNotEmpty) {
        if (mounted) {
          setState(() {
            _bytes = cached;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Se não estiver no cache e for URL válida, busca da rede e auto-cacheia
      final fetched = await _service.fetchAndCacheImage(widget.imageUrl);
      if (mounted) {
        setState(() {
          _bytes = fetched;
          _isLoading = false;
          _hasError = fetched == null;
        });
      }
    } catch (_) {
      if (mounted) {
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
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) =>
            widget.errorBuilder?.call(ctx, err, stack) ?? const SizedBox.shrink(),
      );
    }

    if (_isLoading) {
      if (!widget.showLoadingIndicator) {
        return const SizedBox.shrink();
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
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
                  'Não foi possível carregar a tirinha.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          );
    }

    return const SizedBox.shrink();
  }
}
