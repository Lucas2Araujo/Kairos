import 'package:flutter/material.dart';
import '../../controllers/bible_controller.dart';
import '../../models/bible_verse.dart';
import '../../services/theme_service.dart';
import 'widgets/study_bottom_sheet.dart';

class BibleReaderView extends StatefulWidget {
  final BibleController controller;

  const BibleReaderView({super.key, required this.controller});

  @override
  State<BibleReaderView> createState() => _BibleReaderViewState();
}

class _BibleReaderViewState extends State<BibleReaderView> {
  @override
  void initState() {
    super.initState();
    widget.controller.init();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ctrl.books.isNotEmpty)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<BibleBook>(
                      value: ctrl.selectedBook,
                      dropdownColor: Theme.of(context).cardTheme.color,
                      items: ctrl.books.map((book) {
                        return DropdownMenuItem(
                          value: book,
                          child: Text(
                            book.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (book) {
                        if (book != null) ctrl.selectBook(book);
                      },
                    ),
                  ),
                const SizedBox(width: 8),
                if (ctrl.selectedBook != null)
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: ctrl.selectedChapter,
                      dropdownColor: Theme.of(context).cardTheme.color,
                      items: List.generate(
                        ctrl.selectedBook!.chaptersCount,
                        (index) => DropdownMenuItem(
                          value: index + 1,
                          child: Text('Capítulo ${index + 1}'),
                        ),
                      ),
                      onChanged: (chapter) {
                        if (chapter != null) ctrl.selectChapter(chapter);
                      },
                    ),
                  ),
              ],
            ),
          ),
          body: _buildBody(ctrl),
        );
      },
    );
  }

  Widget _buildBody(BibleController ctrl) {
    if (ctrl.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (ctrl.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                ctrl.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ctrl.init(),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (ctrl.verses.isEmpty) {
      return const Center(
        child: Text('Nenhum versículo encontrado para este capítulo.'),
      );
    }

    final theme = Theme.of(context);
    final themeService = ThemeService();
    final multiplier = themeService.fontSizeMultiplier;
    final baseFontSize = 18.0 * multiplier;

    // Mapeia versículo -> título de perícope para inserção no topo do versículo
    final Map<int, String> pericopeMap = {
      for (final p in ctrl.pericopes) p.verse: p.title,
    };

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: ctrl.verses.length,
      itemBuilder: (context, index) {
        final verse = ctrl.verses[index];
        final pericopeTitle = pericopeMap[verse.verse];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (pericopeTitle != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Text(
                  pericopeTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 16.0 * multiplier,
                  ),
                ),
              ),
            ],
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => StudyBottomSheet.show(context, ctrl, verse),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4, right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${verse.verse}',
                        style: TextStyle(
                          fontSize: 12 * multiplier,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        verse.text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: baseFontSize,
                          height: 1.6,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      tooltip: 'Estudo do Versículo',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => StudyBottomSheet.show(context, ctrl, verse),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
