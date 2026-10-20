import 'package:flutter/material.dart';

class HymnAudioPlayerWidget extends StatefulWidget {
  final String numero;
  final String titulo;

  const HymnAudioPlayerWidget({
    super.key,
    required this.numero,
    required this.titulo,
  });

  @override
  State<HymnAudioPlayerWidget> createState() => _HymnAudioPlayerWidgetState();
}

class _HymnAudioPlayerWidgetState extends State<HymnAudioPlayerWidget> {
  bool _isPlaying = false;
  bool _isInstrumental = false;
  double _positionSeconds = 0.0;
  final double _durationSeconds = 180.0; // 3 min padrão

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _toggleTrack() {
    setState(() {
      _isInstrumental = !_isInstrumental;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isInstrumental ? 'Faixa: Instrumental' : 'Faixa: Cantado',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _formatTime(double seconds) {
    final m = (seconds / 60).floor();
    final s = (seconds % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                onPressed: _togglePlay,
                tooltip: _isPlaying ? 'Pausar' : 'Reproduzir',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hino ${widget.numero} - ${widget.titulo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      _isInstrumental ? 'Áudio Instrumental' : 'Áudio Cantado Oficial',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(_isInstrumental ? Icons.piano : Icons.mic, size: 14),
                label: Text(_isInstrumental ? 'Inst.' : 'Cant.', style: const TextStyle(fontSize: 11)),
                onPressed: _toggleTrack,
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              trackHeight: 3,
            ),
            child: Slider(
              value: _positionSeconds.clamp(0.0, _durationSeconds),
              max: _durationSeconds,
              onChanged: (val) {
                setState(() => _positionSeconds = val);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(_positionSeconds),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
                Text(
                  _formatTime(_durationSeconds),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
