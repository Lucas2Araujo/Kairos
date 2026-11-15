import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../models/bible_verse.dart';
import '../../../services/theme_service.dart';

/// Folha deslizante de estudo bíblico exibindo referências cruzadas e comentários por autor.
class StudyBottomSheet extends StatefulWidget {
  final BibleController controller;
  final BibleVerse verse;

  const StudyBottomSheet({
    super.key,
    required this.controller,
    required this.verse,
  });

  static void show(BuildContext context, BibleController controller, BibleVerse verse) {
    controller.loadStudyDataForVerse(verse);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudyBottomSheet(controller: controller, verse: verse),
    );
  }

  @override
  State<StudyBottomSheet> createState() => _StudyBottomSheetState();
}

class _StudyBottomSheetState extends State<StudyBottomSheet> {
  String? _selectedAuthor;

  BibleController get controller => widget.controller;
  BibleVerse get verse => widget.verse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget sheet = Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Barra de arraste
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Cabeçalho do Versículo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.menu_book, color: theme.colorScheme.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${verse.bookName} ${verse.chapter}:${verse.verse}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        verse.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Abas: Referências Cruzadas & Comentários Expositivos
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  TabBar(
                    labelColor: theme.colorScheme.primary,
                    indicatorColor: theme.colorScheme.primary,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.compare_arrows, size: 20),
                        text: 'Referências Cruzadas',
                      ),
                      Tab(
                        icon: Icon(Icons.auto_stories_outlined, size: 20),
                        text: 'Comentários Expositivos',
                      ),
                    ],
                  ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) {
                        if (controller.isLoadingStudyData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        return TabBarView(
                          children: [
                            _buildCrossReferencesTab(context),
                            _buildCommentariesTab(context),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (ThemeService().isAnyGlass && ThemeService().glassBlurEnabled) {
      sheet = ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: sheet,
        ),
      );
    }

    return sheet;
  }

  Widget _buildEmptyTabState(BuildContext context, IconData icon, String message) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrossReferencesTab(BuildContext context) {
    final refs = controller.selectedVerseCrossReferences;

    if (refs.isEmpty) {
      return _buildEmptyTabState(
        context,
        Icons.link_off,
        'Nenhuma referência cruzada direta catalogada para este versículo.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: refs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final ref = refs[index];
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Text(
              '${ref.votes}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          title: Text(
            ref.targetReference,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('Relevância: ${ref.votes} votos comunitários'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () {
            Navigator.of(context).pop();
            final Set<int> multipleVerses = {};
            if (ref.toVerseEnd >= ref.toVerseStart && ref.toVerseEnd > 0) {
              for (int i = ref.toVerseStart; i <= ref.toVerseEnd; i++) {
                multipleVerses.add(i);
              }
            } else {
              multipleVerses.add(ref.toVerseStart);
            }
            controller.jumpToVerse(ref.toBookId, ref.toChapter, ref.toVerseStart, multipleVerses);
          },
        );
      },
    );
  }

  Widget _buildCommentariesTab(BuildContext context) {
    final commentaries = controller.selectedVerseCommentaries;

    if (commentaries.isEmpty) {
      return _buildEmptyTabState(
        context,
        Icons.book_outlined,
        'Nenhum comentário expositivo clássico disponível para este versículo específico.',
      );
    }

    final authors = commentaries
        .map((c) => c.authorName)
        .where((a) => a.trim().isNotEmpty)
        .toSet()
        .toList();
    final activeAuthor = authors.contains(_selectedAuthor) ? _selectedAuthor : null;
    final filtered = activeAuthor == null
        ? commentaries
        : commentaries.where((c) => c.authorName == activeAuthor).toList();

    return Column(
      children: [
        if (authors.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: activeAuthor == null,
                    onSelected: (_) => setState(() => _selectedAuthor = null),
                  ),
                ),
                ...authors.map((author) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(author),
                      selected: activeAuthor == author,
                      onSelected: (_) => setState(() => _selectedAuthor = author),
                    ),
                  );
                }),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final comm = filtered[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        comm.author.isNotEmpty ? comm.author[0] : 'E',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comm.author,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    if (comm.title != null && comm.title!.isNotEmpty)
                      Chip(
                        label: Text(comm.title!, style: const TextStyle(fontSize: 10)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(
                  comm.text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
        );
      },
          ),
        ),
      ],
    );
  }
}
