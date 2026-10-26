class EgwCitation {
  final String bookTitle;
  final String? bookId;
  final String? details;
  final String? quote;
  final String rawText;
  final int startIndex;
  final int endIndex;

  const EgwCitation({
    required this.bookTitle,
    required this.rawText,
    required this.startIndex,
    required this.endIndex,
    this.bookId,
    this.details,
    this.quote,
  });

  String get webUrl {
    if (bookId != null && bookId!.isNotEmpty) {
      return 'https://m.egwwritings.org/pt/book/$bookId.0';
    }
    return 'https://m.egwwritings.org/pt/search?query=${Uri.encodeComponent(bookTitle)}';
  }

  String? get coverUrl {
    if (bookId != null && bookId!.isNotEmpty) {
      return 'https://media4.egwwritings.org/covers/${bookId}_s.jpg';
    }
    return null;
  }
}

class EgwTextSegment {
  final String text;
  final EgwCitation? citation;

  const EgwTextSegment({
    required this.text,
    this.citation,
  });

  bool get isCitation => citation != null;
}

class EgwExtractor {
  static const Map<String, String> bookIdMap = {
    'o desejado de todas as nações': '1813',
    'desejado de todas as nações': '1813',
    'o grande conflito': '11125',
    'grande conflito': '11125',
    'patriarcas e profetas': '1815',
    'profetas e reis': '1816',
    'atos dos apóstolos': '1806',
    'caminho a cristo': '11121',
    'parábolas de jesus': '1931',
    'mensagens aos jovens': '1951',
    'educação': '1948',
    'educacao': '1948',
    'o lar adventista': '1955',
    'lar adventista': '1955',
    'primeiros escritos': '1957',
    'história da redenção': '1949',
    'historia da redencao': '1949',
    'a ciência do bom viver': '11255',
    'a ciencia do bom viver': '11255',
    'mensagens escolhidas': '11246',
    'mensagens escolhidas 1': '11246',
    'mensagens escolhidas 2': '11098',
    'mensagens escolhidas 3': '11097',
    'testemunhos para a igreja': '1819',
    'conselhos sobre a escola sabatina': '1724',
    'conselhos sobre educacao': '1947',
    'conselhos sobre educação': '1947',
    'conselhos sobre regime alimentar': '11093',
    'conselhos sobre mordomia': '1810',
    'serviço cristão': '1818',
    'servico cristao': '1818',
    'vida de jesus': '1727',
    'o maior discurso de cristo': '1956',
    'maior discurso de cristo': '1956',
    'eventos finais': '1729',
    'beneficência social': '1945',
    'beneficencia social': '1945',
  };

  static final List<String> _sortedBookNames = bookIdMap.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  static final String _booksRegexGroup =
      _sortedBookNames.map(RegExp.escape).join('|');

  static final RegExp _citationRegex = RegExp(
    r'(?:Ellen\s+G\.\s+White,\s+)?(?:<[^>]+>)*(' +
        _booksRegexGroup +
        r')(?:<[^>]+>)*(?:\s*\[[^\]]*\])?((?:\s*,\s*(?:v\.|vol\.|volume)\s*\d+)?(?:\s*,\s*(?:p\.|pág\.|páginas?|cap\.|capítulo)\s*[\d\s,-]+)?)',
    caseSensitive: false,
  );

  static final RegExp _quotePrefixRegex = RegExp(
    r'([“\"][^”\"]+[”\"])',
    dotAll: true,
  );

  /// Extrai todas as citações de Ellen White encontradas no texto.
  static List<EgwCitation> extractCitations(String text) {
    if (text.isEmpty) return const [];

    final List<EgwCitation> citations = [];
    final matches = _citationRegex.allMatches(text);

    for (final match in matches) {
      final matchedBook = match.group(1) ?? '';
      final detailsRaw = match.group(2)?.trim() ?? '';
      final details = detailsRaw.startsWith(',') ? detailsRaw.substring(1).trim() : detailsRaw;
      final rawText = match.group(0) ?? '';

      final lowerBook = matchedBook.toLowerCase().trim();
      final bookId = bookIdMap[lowerBook];

      // Busca citação entre aspas que antecede o trecho
      String? quote;
      final prefix = text.substring(0, match.start).trim();
      final quoteMatches = _quotePrefixRegex.allMatches(prefix);
      if (quoteMatches.isNotEmpty) {
        quote = quoteMatches.last.group(1)?.trim();
      }

      // Normaliza título padronizado
      final standardTitle = _standardizeTitle(matchedBook);

      citations.add(
        EgwCitation(
          bookTitle: standardTitle,
          bookId: bookId,
          details: details.isNotEmpty ? details : null,
          quote: quote,
          rawText: rawText,
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    return citations;
  }

  /// Divide o texto em segmentos de texto comum e citações EGW.
  static List<EgwTextSegment> splitTextByEgwCitations(String text) {
    if (text.isEmpty) return const [];

    final citations = extractCitations(text);
    if (citations.isEmpty) {
      return [EgwTextSegment(text: text)];
    }

    final List<EgwTextSegment> segments = [];
    int lastEnd = 0;

    for (final citation in citations) {
      if (citation.startIndex > lastEnd) {
        segments.add(
          EgwTextSegment(
            text: text.substring(lastEnd, citation.startIndex),
          ),
        );
      }

      segments.add(
        EgwTextSegment(
          text: citation.rawText,
          citation: citation,
        ),
      );

      lastEnd = citation.endIndex;
    }

    if (lastEnd < text.length) {
      segments.add(
        EgwTextSegment(
          text: text.substring(lastEnd),
        ),
      );
    }

    return segments;
  }

  static String _standardizeTitle(String rawTitle) {
    final lower = rawTitle.toLowerCase().trim();
    if (lower.contains('desejado')) return 'O Desejado de Todas as Nações';
    if (lower.contains('grande conflito')) return 'O Grande Conflito';
    if (lower.contains('patriarcas')) return 'Patriarcas e Profetas';
    if (lower.contains('profetas e reis')) return 'Profetas e Reis';
    if (lower.contains('atos dos apóstolos')) return 'Atos dos Apóstolos';
    if (lower.contains('caminho a cristo')) return 'Caminho a Cristo';
    if (lower.contains('parábolas')) return 'Parábolas de Jesus';
    if (lower.contains('jovens')) return 'Mensagens aos Jovens';
    if (lower.contains('educação') || lower.contains('educacao')) return 'Educação';
    if (lower.contains('lar adventista')) return 'O Lar Adventista';
    if (lower.contains('primeiros escritos')) return 'Primeiros Escritos';
    if (lower.contains('redenção') || lower.contains('redencao')) return 'História da Redenção';
    if (lower.contains('bom viver')) return 'A Ciência do Bom Viver';
    if (lower.contains('escolhidas')) return 'Mensagens Escolhidas';
    if (lower.contains('escola sabatina')) return 'Conselhos sobre a Escola Sabatina';

    // Capitaliza padrão
    return rawTitle.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (['de', 'da', 'do', 'das', 'dos', 'e', 'a', 'o', 'em', 'por'].contains(word.toLowerCase())) {
        return word.toLowerCase();
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
