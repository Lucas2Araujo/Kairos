import 'package:flutter/material.dart';
import '../../../controllers/sabbath_school_controller.dart';
import '../../../data/services/sabbath_school_service.dart';
import '../../../models/sabbath_school_models.dart';

/// Modal amplo estilo Streaming/Netflix para seleção de trimestres da Escola Sabatina.
/// Organizado em duas seções horizontais rolantes: Lições de Adultos e Lições de Jovens.
class QuarterlyCatalogDialog extends StatefulWidget {
  final SabbathSchoolController controller;

  const QuarterlyCatalogDialog({super.key, required this.controller});

  static Future<void> show(BuildContext context, SabbathSchoolController controller) {
    return showDialog(
      context: context,
      builder: (_) => QuarterlyCatalogDialog(controller: controller),
    );
  }

  @override
  State<QuarterlyCatalogDialog> createState() => _QuarterlyCatalogDialogState();
}

class _QuarterlyCatalogDialogState extends State<QuarterlyCatalogDialog> {
  final SabbathSchoolService _service = SabbathSchoolService();
  List<SSQuarterly> _adultQuarterlies = [];
  List<SSQuarterly> _jovensQuarterlies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final results = await Future.wait([
        _service.getQuarterlies(category: 'adultos'),
        _service.getQuarterlies(category: 'jovens'),
      ]);
      if (mounted) {
        setState(() {
          _adultQuarterlies = results[0];
          _jovensQuarterlies = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _simplifyYear(SSQuarterly q) {
    if (q.id.length >= 4) {
      final y = q.id.substring(0, 4);
      final quarter = q.id.contains('-01')
          ? '1º Tri'
          : q.id.contains('-02')
              ? '2º Tri'
              : q.id.contains('-03')
                  ? '3º Tri'
                  : q.id.contains('-04')
                      ? '4º Tri'
                      : '';
      return quarter.isNotEmpty ? '$quarter • $y' : y;
    }
    return q.humanDate;
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String category,
    required List<SSQuarterly> list,
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${list.length} edições',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: list.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum trimestre encontrado.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final q = list[index];
                    final isSelected = widget.controller.selectedQuarterly?.id == q.id;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        if (widget.controller.category != category) {
                          await widget.controller.setCategory(category);
                        }
                        await widget.controller.selectQuarterly(q);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        width: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.dividerColor.withValues(alpha: 0.15),
                            width: isSelected ? 2.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Capa
                              Expanded(
                                flex: 3,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (q.cover.isNotEmpty)
                                      Image.network(
                                        q.cover,
                                        fit: BoxFit.cover,
                                        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: theme.colorScheme.surfaceContainerHigh,
                                          child: Icon(
                                            Icons.auto_stories,
                                            size: 36,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: theme.colorScheme.surfaceContainerHigh,
                                        child: Icon(
                                          Icons.auto_stories,
                                          size: 36,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    if (isSelected)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Info
                              Expanded(
                                flex: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  color: theme.colorScheme.surfaceContainer,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        q.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.onSurface,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _simplifyYear(q),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho do Catálogo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.movie_filter_outlined, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Catálogo de Lições',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Escolha o trimestre para estudo',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
            // Conteúdo
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSection(
                            context,
                            title: 'Lições de Adultos',
                            icon: Icons.school_outlined,
                            category: 'adultos',
                            list: _adultQuarterlies,
                          ),
                          const SizedBox(height: 16),
                          _buildSection(
                            context,
                            title: 'Lições de Jovens',
                            icon: Icons.local_fire_department_outlined,
                            category: 'jovens',
                            list: _jovensQuarterlies,
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

