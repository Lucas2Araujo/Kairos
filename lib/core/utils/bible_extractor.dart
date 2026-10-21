import '../../data/repositories/bible_repository.dart';

class BibleRefMatch {
  final int start;
  final int end;
  final String rawText;
  final String book;
  final int chapter;
  final int verse;
  final int? endVerse;
  final int? endChapter;

  const BibleRefMatch({
    required this.start,
    required this.end,
    required this.rawText,
    required this.book,
    required this.chapter,
    required this.verse,
    this.endVerse,
    this.endChapter,
  });
}

class BibleExtractor {
  // Regex unificado que identifica:
  // 1) Versículos entre múltiplos capítulos (ex: "Ef 2:19 - 3:15", "Ef 2:19 a 3:15")
  // 2) Versículos em um capítulo (ex: "Jo 3:16", "Sl 23:1-3", "1Co 13:4-7")
  // 3) Capítulos inteiros contínuos (ex: "Ef 2 - 3", "Sl 23 a 24")
  // 4) Capítulo único inteiro (ex: "Is 6", "Sl 23")
  static final RegExp _refRegex = RegExp(
    r'\b((?:(?:[1-3]|I{1,3})\s*)?[A-Za-zÀ-ÿ]+)\s+(?:'
    r'(\d+)\s*[:.]\s*(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)\s*[:.]\s*(\d+)'
    r'|'
    r'(\d+)\s*[:.]\s*(\d+(?:\s*[-–—]\s*\d+)?(?:,\s*(?!(?:[1-3]|I{1,3})\s+[A-Za-zÀ-ÿ])\d+(?:\s*[-–—]\s*\d+)?)*)'
    r'|'
    r'(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)(?!\s*[:.])'
    r'|'
    r'(\d+)(?!\s*[:.])'
    r')\b',
    caseSensitive: false,
  );

  static final RegExp _contiguousSeparatorRegex = RegExp(
    r'^(?:\]\([^\)]*\))?[\s,;–—-]*(?:e|ou|&|e/ou)?[\s,;–—-]*(?:\[)?$',
    caseSensitive: false,
  );

  /// Limpa pontuações envolventes e prefixos conjuntivos como "e ", "ou ", "& ", "e/ou "
  static String cleanReference(String ref) {
    var cleaned = ref.trim().replaceAll(RegExp(r'^[\[\(\{"\\]+|[\]\)\}"\\]+$'), '').trim();
    cleaned = cleaned.replaceFirst(RegExp(r'^(?:e|ou|&|e/ou)\s+', caseSensitive: false), '').trim();
    return cleaned;
  }

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

      int chapter = 1;
      int verse = 1;
      int? endChapter;
      int? endVerse;

      if (m.group(2) != null) {
        // Multi-capítulo com versículos (ex: Ef 2:19 - 3:15)
        chapter = int.tryParse(m.group(2)!) ?? 1;
        verse = int.tryParse(m.group(3)!) ?? 1;
        endChapter = int.tryParse(m.group(4)!);
        endVerse = int.tryParse(m.group(5)!);
      } else if (m.group(6) != null) {
        // Capítulo único com versículos (ex: Jo 3:16, Sl 23:1-3)
        chapter = int.tryParse(m.group(6)!) ?? 1;
        final verseStr = m.group(7) ?? '1';
        final rangeMatch = RegExp(r'^(\d+)(?:\s*[-–—]\s*(\d+))?').firstMatch(verseStr);
        if (rangeMatch != null) {
          verse = int.tryParse(rangeMatch.group(1) ?? '1') ?? 1;
          if (rangeMatch.group(2) != null) {
            endVerse = int.tryParse(rangeMatch.group(2)!);
          }
        }
      } else if (m.group(8) != null) {
        // Múltiplos capítulos inteiros (ex: Ef 2 - 3)
        chapter = int.tryParse(m.group(8)!) ?? 1;
        endChapter = int.tryParse(m.group(9)!);
      } else if (m.group(10) != null) {
        // Capítulo único inteiro (ex: Is 6, Sl 23)
        chapter = int.tryParse(m.group(10)!) ?? 1;
      }

      matches.add(BibleRefMatch(
        start: m.start,
        end: m.end,
        rawText: m.group(0)!,
        book: bookRaw,
        chapter: chapter,
        verse: verse,
        endChapter: endChapter,
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
      final cleaned = cleanReference(m.rawText);
      if (seen.add(cleaned)) {
        result.add(cleaned);
      }
    }
    return result;
  }

  /// Identifica todas as referências bíblicas contíguas no parágrafo/trecho ao redor de [targetRef].
  /// Agrupa sequências como "João 14:3, 1 Coríntios 14:9, Efésios 4:11-13" ou "Rm 8:28 e Lucas 12:15".
  static List<String> getContiguousReferences(String fullText, String targetRef) {
    final cleanTarget = cleanReference(targetRef);
    if (fullText.isEmpty) {
      return cleanTarget.isNotEmpty ? [cleanTarget] : const [];
    }

    final matches = findBibleReferences(fullText);
    if (matches.isEmpty) {
      return cleanTarget.isNotEmpty ? [cleanTarget] : const [];
    }

    final List<List<BibleRefMatch>> clusters = [];
    List<BibleRefMatch> currentCluster = [matches.first];

    for (int i = 1; i < matches.length; i++) {
      final prev = matches[i - 1];
      final curr = matches[i];
      final between = fullText.substring(prev.end, curr.start);

      if (!between.contains('\n\n') && _contiguousSeparatorRegex.hasMatch(between)) {
        currentCluster.add(curr);
      } else {
        clusters.add(currentCluster);
        currentCluster = [curr];
      }
    }
    clusters.add(currentCluster);

    final normTarget = cleanTarget.toLowerCase();
    for (final cluster in clusters) {
      final hasMatch = cluster.any((m) {
        final normRaw = cleanReference(m.rawText).toLowerCase();
        return normRaw == normTarget || m.rawText.trim().toLowerCase() == normTarget;
      });
      if (hasMatch) {
        return cluster.map((m) => cleanReference(m.rawText)).toList();
      }
    }

    return cleanTarget.isNotEmpty ? [cleanTarget] : const [];
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
