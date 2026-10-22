import 'package:flutter/material.dart';
import '../../../controllers/bible_controller.dart';
import '../../../data/repositories/bible_repository.dart';
import '../../bible/widgets/bible_verse_preview_modal.dart';

/// Diálogo legado para exibição de versículos.
/// Redireciona para o submódulo unificado [BibleVersePreviewModal].
@Deprecated('Use BibleVersePreviewModal.show directly.')
class VerseDialog {
  static Future<void> show(
    BuildContext context, {
    required String reference,
    BibleRepository? bibleRepository,
    BibleController? bibleController,
    void Function(int tabIndex)? onNavigateToTab,
    String? contextTitle,
    List<String>? contextReferences,
  }) {
    return BibleVersePreviewModal.show(
      context,
      reference: reference,
      references: contextReferences,
      bibleRepository: bibleRepository,
      bibleController: bibleController,
      onNavigateToTab: onNavigateToTab,
      contextTitle: contextTitle,
    );
  }
}
