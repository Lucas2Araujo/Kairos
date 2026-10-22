import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/audio_service.dart';
import '../../../services/theme_service.dart';

class HymnAudioPlayerWidget extends StatefulWidget {
  final String numero;
  final String titulo;
  final int? hymnId;
  final String? streamUrl;

  const HymnAudioPlayerWidget({
    super.key,
    required this.numero,
    required this.titulo,
    this.hymnId,
    this.streamUrl,
  });

  @override
  State<HymnAudioPlayerWidget> createState() => _HymnAudioPlayerWidgetState();
}

class _HymnAudioPlayerWidgetState extends State<HymnAudioPlayerWidget> {
  final AudioService _audioService = AudioService();
  double? _dragValue;
  bool _isDownloading = false;

  int get _effectiveHymnId =>
      widget.hymnId ??
      (int.tryParse(widget.numero.replaceAll(RegExp(r'\D'), '')) ?? 0);

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onPlayPausePressed() {
    final isThisHymn = _audioService.currentHymnNumber == widget.numero;

    if (isThisHymn && _audioService.isPlaying) {
      _audioService.pause();
    } else if (isThisHymn &&
        !_audioService.isPlaying &&
        _audioService.position > Duration.zero) {
      _audioService.resume();
    } else {
      _audioService.playHymn(
        hymnId: _effectiveHymnId,
        numero: widget.numero,
        titulo: widget.titulo,
        isInstrumental: _audioService.isInstrumental,
        customUrl: widget.streamUrl,
      );
    }
  }

  void _toggleTrack() async {
    await _audioService.toggleTrack();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _audioService.isInstrumental
                ? 'Faixa: Instrumental'
                : 'Faixa: Cantado Oficial',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _handleDownloadAction(bool isDownloaded) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloads offline não estão disponíveis na versão Web.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (isDownloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Excluir áudio offline?'),
          content: Text(
            'Deseja remover o áudio baixado do Hino ${widget.numero} do armazenamento local?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final deleted = await _audioService.deleteDownloadedHymn(_effectiveHymnId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                deleted
                    ? 'Áudio offline removido com sucesso.'
                    : 'Não foi possível remover o arquivo.',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      setState(() => _isDownloading = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Baixando áudio para reprodução offline...'),
          duration: Duration(seconds: 2),
        ),
      );

      final url = widget.streamUrl ??
          AudioService.getDefaultAudioUrl(
            _effectiveHymnId,
            isInstrumental: _audioService.isInstrumental,
          );

      final success = await _audioService.downloadHymn(_effectiveHymnId, url);
      if (mounted) {
        setState(() => _isDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Áudio do Hino ${widget.numero} baixado com sucesso!'
                  : 'Falha ao baixar o áudio.',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = ThemeService();

    return ListenableBuilder(
      listenable: _audioService,
      builder: (context, _) {
        final isThisHymn = _audioService.currentHymnNumber == widget.numero;
        final isPlaying = isThisHymn && _audioService.isPlaying;
        final isBuffering = isThisHymn && _audioService.isBuffering;
        final isInstrumental =
            isThisHymn ? _audioService.isInstrumental : _audioService.isInstrumental;

        final pos = isThisHymn ? _audioService.position : Duration.zero;
        final dur = isThisHymn ? _audioService.duration : Duration.zero;

        final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final curMs = _dragValue ?? pos.inMilliseconds.toDouble().clamp(0.0, maxMs);

        final isDownloaded = _audioService.isHymnDownloaded(_effectiveHymnId);

        final innerWidget = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // Botão Play/Pause/Buffering
                if (isBuffering)
                  const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      size: 38,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: _onPlayPausePressed,
                    tooltip: isPlaying ? 'Pausar' : 'Reproduzir',
                  ),

                const SizedBox(width: 8),

                // Título e Faixa
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hino ${widget.numero} - ${widget.titulo}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        isInstrumental
                            ? 'Áudio Instrumental'
                            : 'Áudio Cantado Oficial',
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Alternância de Faixa (Cantado / Instrumental)
                Tooltip(
                  message: isInstrumental
                      ? 'Alternar para faixa cantada'
                      : 'Alternar para faixa instrumental',
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: Icon(
                      isInstrumental ? Icons.piano : Icons.mic,
                      size: 15,
                    ),
                    label: Text(
                      isInstrumental ? 'Inst.' : 'Cant.',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onPressed: _toggleTrack,
                  ),
                ),

                const SizedBox(width: 4),

                // Botão de Download / Estado Offline
                if (_isDownloading)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else
                  IconButton(
                    iconSize: 22,
                    icon: Icon(
                      isDownloaded
                          ? Icons.download_done
                          : Icons.download_outlined,
                      color: isDownloaded
                          ? Colors.green
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: isDownloaded
                        ? 'Áudio baixado (Offline). Toque para excluir'
                        : 'Baixar para ouvir offline',
                    onPressed: () => _handleDownloadAction(isDownloaded),
                  ),
              ],
            ),

            // Slider de Progresso
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                trackHeight: 3,
              ),
              child: Slider(
                value: curMs.clamp(0.0, maxMs),
                max: maxMs,
                onChanged: dur.inMilliseconds > 0
                    ? (val) {
                        setState(() => _dragValue = val);
                      }
                    : null,
                onChangeEnd: dur.inMilliseconds > 0
                    ? (val) {
                        _audioService.seek(Duration(milliseconds: val.toInt()));
                        setState(() => _dragValue = null);
                      }
                    : null,
              ),
            ),

            // Rótulos de Tempo (mm:ss)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(
                      _dragValue != null
                          ? Duration(milliseconds: _dragValue!.toInt())
                          : pos,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                  Text(
                    _formatDuration(dur),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        );

        if (themeService.isAnyGlass) {
          return GlassSurface(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: innerWidget,
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: innerWidget,
        );
      },
    );
  }
}
