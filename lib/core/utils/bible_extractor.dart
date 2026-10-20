import '../../data/repositories/bible_repository.dart';

class BibleRefMatch {
  final int start;
  final int end;
  final String rawText;
  final String book;
  final int chapter;
  final int verse;
  final int? endVerse;

  const BibleRefMatch({
    required this.start,
    required this.end,
    required this.rawText,
    required this.book,
    required this.chapter,
    required this.verse,
    this.endVerse,
  });
}

class BibleExtractor {
  static final RegExp _refRegex = RegExp(
    r'\b((?:(?:[1-3]|I{1,3})\s*)?[A-Za-zÀ-ÿ]+)\s+(\d+)\s*[:.]\s*(\d+(?:\s*[-–]\s*\d+)?(?:,\s*\d+(?:\s*[-–]\s*\d+)?(?![A-Za-zÀ-ÿ]))*)\b',
    caseSensitive: false,
  );

  static int? _resolveBook(String raw) {
    var id = BibleRepository.resolveBookId(raw);
    if (id != null) return id;
    final normalized = raw.trim()
        .replaceFirst(RegExp(r'^iii\s*', caseSensitive: false), '3 ')
        .replaceFirst(RegExp(r'^ii\s*', caseSensitive: false), '2 ')
        .replaceFirst(RegExp(r'^i\s*', caseSensitive: false), '1 ');
    return BibleRepository.resolveBookId(normalized);
  }

  /// Localiza todas as ocorrências de referências bíblicas no texto fornecido.
  static List<BibleRefMatch> findBibleReferences(String text) {
    if (text.isEmpty) return const [];
    final matches = <BibleRefMatch>[];
    for (final m in _refRegex.allMatches(text)) {
      final bookRaw = m.group(1)?.trim() ?? '';
      if (_resolveBook(bookRaw) == null) continue;

      final chapter = int.tryParse(m.group(2) ?? '1') ?? 1;
      final verseStr = m.group(3) ?? '1';

      int verse = 1;
      int? endVerse;
      final rangeMatch = RegExp(r'^(\d+)(?:\s*[-–]\s*(\d+))?').firstMatch(verseStr);
      if (rangeMatch != null) {
        verse = int.tryParse(rangeMatch.group(1) ?? '1') ?? 1;
        if (rangeMatch.group(2) != null) {
          endVerse = int.tryParse(rangeMatch.group(2)!);
        }
      }

      matches.add(BibleRefMatch(
        start: m.start,
        end: m.end,
        rawText: m.group(0)!,
        book: bookRaw,
        chapter: chapter,
        verse: verse,
        endVerse: endVerse,
      ));
    }
    return matches;
  }

  /// Retorna lista única e ordenada de strings de referências bíblicas encontradas no texto.
  static List<String> extractAllBibleRefs(String text) {
    final matches = findBibleReferences(text);
    final seen = <String>{};
    final result = <String>[];
    for (final m in matches) {
      if (seen.add(m.rawText)) {
        result.add(m.rawText);
      }
    }
    return result;
  }

  /// Divide o texto em fragmentos alternando entre texto comum e referências bíblicas clicáveis.
  static List<({String text, String? reference})> splitTextByBibleRefs(String text) {
    if (text.isEmpty) return const [];
    final matches = findBibleReferences(text);
    if (matches.isEmpty) {
      return [(text: text, reference: null)];
    }

    final List<({String text, String? reference})> segments = [];
    int lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        segments.add((text: text.substring(lastEnd, m.start), reference: null));
      }
      segments.add((text: m.rawText, reference: m.rawText));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      segments.add((text: text.substring(lastEnd), reference: null));
    }
    return segments;
  }
}
