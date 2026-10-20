import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/updater_service.dart';

class UpdateDialog extends StatefulWidget {
  final String currentVersion;

  const UpdateDialog({
    super.key,
    this.currentVersion = UpdaterService.defaultCurrentVersion,
  });

  static Future<void> show(
    BuildContext context, {
    String currentVersion = UpdaterService.defaultCurrentVersion,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => UpdateDialog(currentVersion: currentVersion),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  final UpdaterService _updaterService = UpdaterService();

  bool _isChecking = true;
  String? _errorMessage;
  ReleaseUpdateInfo? _updateInfo;
  List<String> _deviceAbis = [];

  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  int _receivedBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _checkUpdate();
  }

  Future<void> _checkUpdate() async {
    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final abis = await _updaterService.getDeviceAbis();
      final info = await _updaterService.checkForUpdate(currentVersion: widget.currentVersion);
      if (mounted) {
        setState(() {
          _deviceAbis = abis;
          _updateInfo = info;
          _isChecking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao buscar atualizações: $e';
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _startDownloadAndInstall() async {
    final info = _updateInfo;
    if (info == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _receivedBytes = 0;
      _totalBytes = info.assetSize;
      _errorMessage = null;
    });

    try {
      await _updaterService.downloadAndInstallApk(
        info,
        onProgress: (progress, received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
              _receivedBytes = received;
              _totalBytes = total;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha no download/instalação: $e';
          _isDownloading = false;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final mb = bytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: const Row(
        children: [
          Icon(Icons.system_update),
          SizedBox(width: 8),
          Text('Atualização do Aplicativo'),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isChecking) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                const Center(
                  child: Text(
                    'Verificando novas versões no GitHub...',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _checkUpdate,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                ),
              ] else if (_updateInfo == null) ...[
                const SizedBox(height: 12),
                const Center(
                  child: Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Seu aplicativo já está na versão mais recente',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Versão instalada: v${widget.currentVersion}',
                    style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://github.com/Lucas2Araujo/NHA_Intel/releases'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: const Text('Ver lançamentos no GitHub'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nova versão: ${_updateInfo!.tagName}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                    ),
                    Text(
                      'Atual: v${widget.currentVersion}',
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Arquivo: ${_updateInfo!.assetName} (${_formatBytes(_updateInfo!.assetSize)})',
                  style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                ),
                if (_deviceAbis.isNotEmpty)
                  Text(
                    'Arquitetura: ${_updateInfo!.abi}',
                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8)),
                  ),
                const Divider(height: 24),
                if (_updateInfo!.changelog.isNotEmpty) ...[
                  const Text(
                    'Notas da Versão:',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _updateInfo!.changelog,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isDownloading) ...[
                  LinearProgressIndicator(value: _downloadProgress > 0 ? _downloadProgress : null),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '${_formatBytes(_receivedBytes)} / ${_formatBytes(_totalBytes)}',
                        style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (!_isDownloading)
                  if (isAndroid)
                    FilledButton.icon(
                      onPressed: _startDownloadAndInstall,
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar e Instalar Atualização'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(_updateInfo!.downloadUrl.isNotEmpty
                            ? _updateInfo!.downloadUrl
                            : 'https://github.com/Lucas2Araujo/NHA_Intel/releases/latest'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Abrir no Navegador'),
                    ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDownloading ? null : () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
