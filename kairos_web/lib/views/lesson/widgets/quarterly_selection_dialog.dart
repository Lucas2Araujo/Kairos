import 'package:flutter/material.dart';
import '../../../controllers/sabbath_school_controller.dart';

/// Diálogo Modal para Seleção de Trimestre da Escola Sabatina.
/// Exibe cards com título, período humano (ex: 3º Trimestre 2024), descrição
/// e indicador visual do trimestre atualmente selecionado.
class QuarterlySelectionDialog extends StatelessWidget {
  final SabbathSchoolController controller;

  const QuarterlySelectionDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, SabbathSchoolController controller) {
    return showDialog(
      context: context,
      builder: (_) => QuarterlySelectionDialog(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quarterlies = controller.quarterlies;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.calendar_month, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Escolher Trimestre',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      content: SizedBox(
        width: 540,
        child: quarterlies.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('Nenhum trimestre disponível.')),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: quarterlies.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final q = quarterlies[index];
                  final isSelected = q.id == controller.selectedQuarterly?.id;

                  return Card(
                    elevation: isSelected ? 3 : 1,
                    color: isSelected
                        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
                        : theme.colorScheme.surfaceContainerHigh,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.dividerColor.withValues(alpha: 0.1),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        controller.selectQuarterly(q);
                        Navigator.of(context).pop();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.auto_stories,
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          q.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isSelected
                                                ? theme.colorScheme.onPrimaryContainer
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Atual',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: theme.colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    q.humanDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  if (q.description.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      q.description,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
