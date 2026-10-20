import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class TirinhaView extends StatefulWidget {
  final String imageSrc;
  final bool isNetwork;
  final String title;

  const TirinhaView({
    super.key,
    required this.imageSrc,
    required this.isNetwork,
    this.title = '',
  });

  static Future<void> show(
    BuildContext context, {
    required String imageSrc,
    required bool isNetwork,
    String title = '',
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => TirinhaView(
          imageSrc: imageSrc,
          isNetwork: isNetwork,
          title: title,
        ),
      ),
    );
  }

  @override
  State<TirinhaView> createState() => _TirinhaViewState();
}

class _TirinhaViewState extends State<TirinhaView> {
  final TransformationController _transformationController = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      final x = -position.dx * 1.5;
      final y = -position.dy * 1.5;
      _transformationController.value = Matrix4.identity()
        ..setEntry(0, 0, 2.5)
        ..setEntry(1, 1, 2.5)
        ..setEntry(0, 3, x)
        ..setEntry(1, 3, y);
    }
  }

  Future<void> _downloadImage() async {
    try {
      if (kIsWeb) {
        if (widget.isNetwork) {
          final uri = Uri.tryParse(widget.imageSrc);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        Uint8List bytes;
        if (widget.isNetwork) {
          final res = await http.get(Uri.parse(widget.imageSrc));
          bytes = res.bodyBytes;
        } else {
          final data = await rootBundle.load(widget.imageSrc);
          bytes = data.buffer.asUint8List();
        }
        final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        final filename = 'tirinha_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = io.File('${dir.path}/$filename');
        await file.writeAsBytes(bytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tirinha salva com sucesso!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar imagem: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Visualizador com Pan & Zoom e Double-tap
          GestureDetector(
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 1.0,
              maxScale: 5.0,
              child: Center(
                child: widget.isNetwork
                    ? Image.network(
                        widget.imageSrc,
                        fit: BoxFit.contain,
                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      )
                    : Image.asset(
                        widget.imageSrc,
                        fit: BoxFit.contain,
                      ),
              ),
            ),
          ),

          // Barra Superior com Voltar e Download
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: 'Voltar',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title.isNotEmpty ? widget.title : 'Tirinha da Lição',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    tooltip: 'Salvar Imagem',
                    onPressed: _downloadImage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
