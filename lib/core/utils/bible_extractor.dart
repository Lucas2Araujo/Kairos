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
    r'(?<![-–—\d])\b((?:(?:[1-3]|I{1,3})\s*)?[A-Za-zÀ-ÿ]+)\s+(?:'
    r'(\d+)\s*[:.]\s*(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)\s*[:.]\s*(\d+)'
    r'|'
    r'(\d+)\s*[:.]\s*(\d+(?:\s*[-–—]\s*\d+)?(?:(?:,\s*|\s+(?:e|ou|&|e/ou)\s+)(?!(?:[1-3]|I{1,3})\s*(?!(?:e|ou|a|at[eé])\b)[A-Za-zÀ-ÿ])\d+(?!\s*[:.]\s*\d)(?:\s*[-–—]\s*\d+)?)*)'
    r'|'
    r'(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)(?!\s*[:.])'
    r'|'
    r'(\d+)(?!\s*[:.]\s*\d|\s+(?:[1-3]|I{1,3})\s+[A-Za-zÀ-ÿ]|\s+[A-Za-zÀ-ÿ]+\s*\d)'
    r')\b',
    caseSensitive: false,
  );

  static final RegExp _contiguousSeparatorRegex = RegExp(
    r'^(?:\]\([^\)]*\))?[\s,;–—\(\)\[\]-]*(?:e|ou|&|e/ou)?[\s,;–—\(\)\[\]-]*$',
    caseSensitive: false,
  );

  static final RegExp _cvRegex = RegExp(
    r'\b(?:'
    r'(\d+)\s*[:.]\s*(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)\s*[:.]\s*(\d+)'
    r'|'
    r'(\d+)\s*[:.]\s*(\d+(?:\s*[-–—]\s*\d+)?(?:(?:,\s*|\s+(?:e|ou|&|e/ou)\s+)(?!(?:[1-3]|I{1,3})\s*(?!(?:e|ou|a|at[eé])\b)[A-Za-zÀ-ÿ])\d+(?!\s*[:.]\s*\d)(?:\s*[-–—]\s*\d+)?)*)'
    r'|'
    r'(\d+)\s*(?:[-–—]|(?:\s+a\s+|\s+at[eé]\s+))\s*(\d+)(?!\s*[:.])'
    r'|'
    r'(\d+)(?!\s*[:.]|\s+(?!(?:e|ou|&|e/ou|a|at[eé])\b)[A-Za-zÀ-ÿ])'
    r')\b',
    caseSensitive: false,
  );

  /// Limpa pontuações envolventes e prefixos conjuntivos como "e ", "ou ", "& ", "e/ou "
  static String cleanReference(String ref) {
    var cleaned = ref.trim().replaceAll(RegExp(r'^[\[\(\{"\\]+|[\]\)\}"\.\\]+$'), '').trim();
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

  static ({int chapter, int verse, int? endChapter, int? endVerse}) _parseCv(
    String? g2, String? g3, String? g4, String? g5,
    String? g6, String? g7,
    String? g8, String? g9,
    String? g10,
  ) {
    int chapter = 1;
    int verse = 1;
    int? endChapter;
    int? endVerse;

    if (g2 != null) {
      chapter = int.tryParse(g2) ?? 1;
      verse = int.tryParse(g3 ?? '1') ?? 1;
      endChapter = int.tryParse(g4 ?? '');
      endVerse = int.tryParse(g5 ?? '');
    } else if (g6 != null) {
      chapter = int.tryParse(g6) ?? 1;
      final rangeMatch = RegExp(r'^(\d+)(?:\s*[-–—]\s*(\d+))?').firstMatch(g7 ?? '1');
      if (rangeMatch != null) {
        verse = int.tryParse(rangeMatch.group(1) ?? '1') ?? 1;
        if (rangeMatch.group(2) != null) {
          endVerse = int.tryParse(rangeMatch.group(2)!);
        }
      }
    } else if (g8 != null) {
      chapter = int.tryParse(g8) ?? 1;
      endChapter = int.tryParse(g9 ?? '');
    } else if (g10 != null) {
      chapter = int.tryParse(g10) ?? 1;
    }
    return (chapter: chapter, verse: verse, endChapter: endChapter, endVerse: endVerse);
  }

  /// Localiza todas as ocorrências de referências bíblicas no texto fornecido.
  static List<BibleRefMatch> findBibleReferences(String text) {
    if (text.isEmpty) return const [];
    final mdMatches = <BibleRefMatch>[];

    if (text.contains('bible://')) {
      final mdRegex = RegExp(r'\[([^\]]+)\]\(bible:\/\/([^\)]+)\)');
      String? mdLastBook;
      for (final m in mdRegex.allMatches(text)) {
        final label = m.group(1) ?? '';
        final rawUrl = Uri.decodeComponent((m.group(2) ?? '').replaceFirst('bible://', '').trim());

        String targetText = cleanReference(label);
        var refMatch = _refRegex.firstMatch(targetText);
        String? book = refMatch?.group(1)?.trim();

        if (book == null || _resolveBook(book) == null) {
          targetText = cleanReference(rawUrl);
          refMatch = _refRegex.firstMatch(targetText);
          book = refMatch?.group(1)?.trim();
        }

        if ((book == null || _resolveBook(book) == null) && mdLastBook != null) {
          targetText = '$mdLastBook $targetText';
          refMatch = _refRegex.firstMatch(targetText);
          book = refMatch?.group(1)?.trim();
        }

        if (refMatch == null || book == null || _resolveBook(book) == null) continue;
        mdLastBook = book;

        final cv = _parseCv(refMatch[2], refMatch[3], refMatch[4], refMatch[5], refMatch[6], refMatch[7], refMatch[8], refMatch[9], refMatch[10]);
        mdMatches.add(BibleRefMatch(
          start: m.start,
          end: m.end,
          rawText: targetText,
          book: book,
          chapter: cv.chapter,
          verse: cv.verse,
          endChapter: cv.endChapter,
          endVerse: cv.endVerse,
        ));
      }
    }

    final plainMatches = <BibleRefMatch>[];
    final allMatches = _refRegex.allMatches(text).where((m) {
      final bookRaw = m.group(1)?.trim() ?? '';
      return _resolveBook(bookRaw) != null;
    }).toList();
    for (int i = 0; i < allMatches.length; i++) {
      final m = allMatches[i];
      final bookRaw = m.group(1)?.trim() ?? '';

      final cv = _parseCv(m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10]);
      plainMatches.add(BibleRefMatch(
        start: m.start,
        end: m.end,
        rawText: m.group(0)!,
        book: bookRaw,
        chapter: cv.chapter,
        verse: cv.verse,
        endChapter: cv.endChapter,
        endVerse: cv.endVerse,
      ));

      int searchStart = m.end;
      final nextOuterStart = (i + 1 < allMatches.length) ? allMatches[i + 1].start : text.length;

      while (searchStart < nextOuterStart) {
        final sub = text.substring(searchStart, nextOuterStart);
        final cvMatch = _cvRegex.firstMatch(sub);
        if (cvMatch == null) break;

        final cvStart = searchStart + cvMatch.start;
        final cvEnd = searchStart + cvMatch.end;
        final between = text.substring(searchStart, cvStart);

        if (between.contains('\n\n') || !_contiguousSeparatorRegex.hasMatch(between)) {
          break;
        }

        final subCv = _parseCv(
          cvMatch[1], cvMatch[2], cvMatch[3], cvMatch[4],
          cvMatch[5], cvMatch[6],
          cvMatch[7], cvMatch[8],
          cvMatch[9],
        );
        plainMatches.add(BibleRefMatch(
          start: cvStart,
          end: cvEnd,
          rawText: '$bookRaw ${text.substring(cvStart, cvEnd)}',
          book: bookRaw,
          chapter: subCv.chapter,
          verse: subCv.verse,
          endChapter: subCv.endChapter,
          endVerse: subCv.endVerse,
        ));

        searchStart = cvEnd;
      }
    }

    if (mdMatches.isEmpty) return plainMatches;

    final combined = List<BibleRefMatch>.from(mdMatches);
    for (final pt in plainMatches) {
      final overlaps = mdMatches.any((md) => !(pt.end <= md.start || pt.start >= md.end));
      if (!overlaps) {
        combined.add(pt);
      }
    }
    combined.sort((a, b) => a.start.compareTo(b.start));
    return combined;
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
        return normRaw == normTarget ||
            m.rawText.trim().toLowerCase() == normTarget ||
            normRaw.endsWith(' $normTarget') ||
            normTarget.endsWith(' $normRaw');
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
      final displayText = (m.rawText.isNotEmpty && m.end - m.start > m.rawText.length + 5)
          ? m.rawText
          : text.substring(m.start, m.end);
      segments.add((text: displayText, reference: m.rawText));
      lastEnd = m.end;
    }
    if (lastEnd < text.length) {
      segments.add((text: text.substring(lastEnd), reference: null));
    }
    return segments;
  }
}
