import 'package:flutter/material.dart';
import '../../../controllers/sabbath_school_controller.dart';
import '../../../data/services/sabbath_school_service.dart';
import '../sabbath_school_view.dart';
import 'cached_ss_tirinha_image.dart';
import 'ss_download_dialog.dart';

/// Modal estilizado em formato de lista para seleção da lição dentro do trimestre.
/// Quando `controller.category == 'jovens'`, exibe ao lado do nome da lição a tirinha
/// respectiva da semana com opacidade reduzida e fade horizontal suave.
class LessonSelectionSheet extends StatelessWidget {
  final SabbathSchoolController controller;

  const LessonSelectionSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, SabbathSchoolController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonSelectionSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lessons = controller.lessons;
    final size = MediaQuery.sizeOf(context);
    final isYouth = controller.category == 'jovens';
    final quarterlyId = controller.selectedQuarterly?.id ?? '';

    return Container(
      constraints: BoxConstraints(maxHeight: size.height * 0.82),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.format_list_bulleted_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selecionar Lição da Semana',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (controller.selectedQuarterly != null)
                        Text(
                          controller.selectedQuarterly!.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final l = lessons[index];
                final isSelected = l.id == controller.selectedLesson?.id;

                String? youthTirinhaUrl;
                String? bundledTirinhaAsset;
                if (isYouth && quarterlyId.isNotEmpty) {
                  youthTirinhaUrl = SabbathSchoolView.resolveYouthTirinhaUrl(
                    quarterlyId: quarterlyId,
                    lessonIndexOrId: l.index.isNotEmpty ? l.index : l.id,
                  );
                  bundledTirinhaAsset = SabbathSchoolView.bundledTirinhaAssets[youthTirinhaUrl];
                }

                return Card(
                  clipBehavior: Clip.antiAlias,
                  elevation: isSelected ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.dividerColor.withValues(alpha: 0.15),
                      width: isSelected ? 1.8 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      controller.selectLesson(l);
                      Navigator.of(context).pop();
                    },
                    child: Stack(
                      children: [
                        // Para Adultos (ou fallback), mantém capa sutil de fundo
                        if (!isYouth && l.cover.isNotEmpty)
                          Positioned.fill(
                            child: Opacity(
                              opacity: 0.12,
                              child: Image.network(
                                l.cover,
                                fit: BoxFit.cover,
                                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            ),
                          ),

                        // Para Jovens: Tirinha da semana ao lado direito do título com opacidade reduzida
                        if (isYouth && youthTirinhaUrl != null)
                          Positioned(
                            right: 42,
                            top: 0,
                            bottom: 0,
                            width: 132,
                            child: IgnorePointer(
                              child: Opacity(
                                key: Key('youth_tirinha_preview_${l.id}'),
                                opacity: 0.34,
                                child: ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Colors.transparent, Colors.black, Colors.black],
                                    stops: [0.0, 0.28, 1.0],
                                  ).createShader(bounds),
                                  blendMode: BlendMode.dstIn,
                                  child: bundledTirinhaAsset != null
                                      ? Image.asset(
                                          bundledTirinhaAsset,
                                          fit: BoxFit.cover,
                                          alignment: Alignment.topCenter,
                                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                        )
                                      : CachedSSTirinhaImage(
                                          imageUrl: youthTirinhaUrl,
                                          fit: BoxFit.cover,
                                          showLoadingIndicator: false,
                                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                        ),
                                ),
                              ),
                            ),
                          ),

                        // Conteúdo principal do Card
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  l.index.isNotEmpty ? l.index : '${index + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isSelected
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    if (l.startDate.isNotEmpty && l.endDate.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '${l.startDate} a ${l.endDate}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isYouth) const SizedBox(width: 64),
                              FutureBuilder<bool>(
                                future: SabbathSchoolService().isLessonDownloaded(l.id),
                                builder: (context, snapshot) {
                                  final isDown = snapshot.data == true;
                                  return IconButton(
                                    icon: Icon(
                                      isDown
                                          ? Icons.check_circle_rounded
                                          : Icons.download_rounded,
                                      color: isDown
                                          ? Colors.green
                                          : (isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurfaceVariant),
                                      size: 22,
                                    ),
                                    tooltip: isDown
                                        ? 'Gerenciar download da lição'
                                        : 'Baixar lição offline',
                                    onPressed: () {
                                      SSDownloadDialog.showForLesson(
                                        context,
                                        l,
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
