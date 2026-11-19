import 'package:flutter/material.dart';
import '../../services/content_manager.dart';
import '../../services/theme_service.dart';

class DownloadsDialog extends StatefulWidget {
  const DownloadsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const DownloadsDialog(),
    );
  }

  @override
  State<DownloadsDialog> createState() => _DownloadsDialogState();
}

class _DownloadsDialogState extends State<DownloadsDialog> {
  final ContentManager _contentManager = ContentManager();

  @override
  void initState() {
    super.initState();
    _contentManager.init();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([_contentManager, ThemeService()]),
      builder: (context, _) {
        final modules = _contentManager.bibleModules;
        final ts = ThemeService();
        final isSquareRetro = ts.isWin95 || ts.isAscii || ts.isHoloRetro;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: isSquareRetro ? BorderRadius.zero : BorderRadius.circular(20),
            side: ts.isAscii
                ? BorderSide(color: theme.colorScheme.primary, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const KairosAdaptiveDialogHeader(
                  title: 'Versões Bíblicas',
                  icon: Icons.cloud_download_outlined,
                ),
                const Divider(height: 1),
                Flexible(
                  child: modules.isEmpty
                      ? const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          itemCount: modules.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final module = modules[index];
                            final isDownloading = module.downloadProgress != null;
                            final sizeMb = (module.sizeBytes / (1024 * 1024)).toStringAsFixed(1);

                            return ListTile(
                              dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        title: Text(
                          module.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 4),
                            if (isDownloading) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: module.downloadProgress,
                                  minHeight: 4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${((module.downloadProgress ?? 0) * 100).toInt()}% baixado...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else if (module.isBundled) ...[
                              const Chip(
                                label: Text('Integrada (Padrão)', style: TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ] else if (module.isInstalled) ...[
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Instalada ($sizeMb MB)',
                                    style: const TextStyle(fontSize: 12, color: Colors.green),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                '$sizeMb MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: isDownloading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : module.isBundled
                                ? const Icon(Icons.check, size: 20, color: Colors.grey)
                                : module.isInstalled
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        tooltip: 'Excluir versão',
                                        onPressed: () async {
                                          await _contentManager.deleteModule(module.id);
                                        },
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.cloud_download_outlined),
                                        tooltip: 'Baixar versão',
                                        onPressed: () async {
                                          try {
                                            await _contentManager.downloadModule(module.id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Falha ao baixar ${module.id}: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
