class EgwCitation {
  final String bookTitle;
  final String? bookId;
  final String? abbreviation;
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
    this.abbreviation,
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
    'o desejado de todas as nacoes': '1813',
    'desejado de todas as nações': '1813',
    'desejado de todas as nacoes': '1813',
    'o grande conflito': '11125',
    'grande conflito': '11125',
    'o conflito dos séculos': '11125',
    'o conflito dos seculos': '11125',
    'conflito dos séculos': '11125',
    'conflito dos seculos': '11125',
    'patriarcas e profetas': '1815',
    'profetas e reis': '1816',
    'atos dos apóstolos': '1806',
    'atos dos apostolos': '1806',
    'caminho a cristo': '11121',
    'parábolas de jesus': '1931',
    'parabolas de jesus': '1931',
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
    'fé e obras': '1726',
    'fe e obras': '1726',
  };

  static const Map<String, String> abbreviationMap = {
    'dtn': '1813',
    'gc': '11125',
    'cs': '11125',
    'pp': '1815',
    'pr': '1816',
    'aa': '1806',
    'cc': '11121',
    'pj': '1931',
    'mj': '1951',
    'ed': '1948',
    'la': '1955',
    'pe': '1957',
    'hr': '1949',
    'cbv': '11255',
    '1me': '11246',
    'me1': '11246',
    '2me': '11098',
    'me2': '11098',
    '3me': '11097',
    'me3': '11097',
    '1t': '1819',
    '2t': '1819',
    '3t': '1819',
    '4t': '1819',
    '5t': '1819',
    '6t': '1819',
    '7t': '1819',
    '8t': '1819',
    '9t': '1819',
    't1': '1819',
    't2': '1819',
    't3': '1819',
    't4': '1819',
    't5': '1819',
    't6': '1819',
    't7': '1819',
    't8': '1819',
    't9': '1819',
    'ces': '1724',
    'cra': '11093',
    'csra': '11093',
    'cm': '1810',
    'sc': '1818',
    'vj': '1727',
    'mdc': '1956',
    'ef': '1729',
    'bs': '1945',
    'fo': '1726',
  };

  static const Map<String, String> abbreviationToTitleMap = {
    'dtn': 'O Desejado de Todas as Nações',
    'gc': 'O Grande Conflito',
    'cs': 'O Grande Conflito',
    'pp': 'Patriarcas e Profetas',
    'pr': 'Profetas e Reis',
    'aa': 'Atos dos Apóstolos',
    'cc': 'Caminho a Cristo',
    'pj': 'Parábolas de Jesus',
    'mj': 'Mensagens aos Jovens',
    'ed': 'Educação',
    'la': 'O Lar Adventista',
    'pe': 'Primeiros Escritos',
    'hr': 'História da Redenção',
    'cbv': 'A Ciência do Bom Viver',
    '1me': 'Mensagens Escolhidas, vol. 1',
    'me1': 'Mensagens Escolhidas, vol. 1',
    '2me': 'Mensagens Escolhidas, vol. 2',
    'me2': 'Mensagens Escolhidas, vol. 2',
    '3me': 'Mensagens Escolhidas, vol. 3',
    'me3': 'Mensagens Escolhidas, vol. 3',
    '1t': 'Testemunhos para a Igreja, vol. 1',
    '2t': 'Testemunhos para a Igreja, vol. 2',
    '3t': 'Testemunhos para a Igreja, vol. 3',
    '4t': 'Testemunhos para a Igreja, vol. 4',
    '5t': 'Testemunhos para a Igreja, vol. 5',
    '6t': 'Testemunhos para a Igreja, vol. 6',
    '7t': 'Testemunhos para a Igreja, vol. 7',
    '8t': 'Testemunhos para a Igreja, vol. 8',
    '9t': 'Testemunhos para a Igreja, vol. 9',
    't1': 'Testemunhos para a Igreja, vol. 1',
    't2': 'Testemunhos para a Igreja, vol. 2',
    't3': 'Testemunhos para a Igreja, vol. 3',
    't4': 'Testemunhos para a Igreja, vol. 4',
    't5': 'Testemunhos para a Igreja, vol. 5',
    't6': 'Testemunhos para a Igreja, vol. 6',
    't7': 'Testemunhos para a Igreja, vol. 7',
    't8': 'Testemunhos para a Igreja, vol. 8',
    't9': 'Testemunhos para a Igreja, vol. 9',
    'ces': 'Conselhos sobre a Escola Sabatina',
    'cra': 'Conselhos sobre o Regime Alimentar',
    'csra': 'Conselhos sobre o Regime Alimentar',
    'cm': 'Conselhos sobre Mordomia',
    'sc': 'Serviço Cristão',
    'vj': 'Vida de Jesus',
    'mdc': 'O Maior Discurso de Cristo',
    'ef': 'Eventos Finais',
    'bs': 'Beneficência Social',
    'fo': 'Fé e Obras',
  };

  static final List<String> _sortedBookNames = bookIdMap.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  static final String _booksRegexGroup =
      _sortedBookNames.map(RegExp.escape).join('|');

  static final RegExp _fullTitleRegex = RegExp(
    r'(?:(?:Ellen\s+G\.\s+White|E\.\s*G\.\s*White|EGW)\s*,\s*)?(?:<[^>]+>)*(' +
        _booksRegexGroup +
        r')(?:<[^>]+>)*(?:\s*\[[^\]]*\])?((?:\s*,\s*(?:v\.|vol\.|volume)\s*\d+)?(?:\s*,\s*(?:p\.|pág\.|páginas?|cap\.|capítulo)\s*[\d\s,-]+)?)',
    caseSensitive: false,
  );

  static final String _abbrGroup = [
    'DTN', 'GC', 'CS', 'PP', 'PR', 'AA', 'CC', 'PJ', 'MJ', 'ED', 'LA', 'PE',
    'HR', 'CBV', '1ME', '2ME', '3ME', 'ME1', 'ME2', 'ME3',
    '1T', '2T', '3T', '4T', '5T', '6T', '7T', '8T', '9T',
    'T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'T8', 'T9',
    'CES', 'CRA', 'CSRA', 'CM', 'SC', 'VJ', 'MDC', 'EF', 'BS', 'FO'
  ].join('|');

  static final RegExp _abbrWithPageRegex = RegExp(
    r'\b(' + _abbrGroup + r')\b(?:<[^>]+>)*(?:\s*,\s*(?:v\.|vol\.|volume)\s*\d+)?(?:\s*,\s*|\s+)(?:(?:p\.|pág\.|páginas?|cap\.|capítulo)\s*)?(\d+[\d\s,-]*)',
    caseSensitive: true,
  );

  static final RegExp _abbrWithAuthorRegex = RegExp(
    r'(?:Ellen\s+G\.\s+White|E\.\s*G\.\s*White|EGW)\s*,\s*\b(' + _abbrGroup + r')\b(?:\s*,\s*(?:p\.|pág\.|páginas?|cap\.|capítulo)?\s*[\d\s,-]+)?',
    caseSensitive: false,
  );

  static final RegExp _quotePrefixRegex = RegExp(
    r'([“\"][^”\"]+[”\"])',
    dotAll: true,
  );

  /// Extrai todas as citações de Ellen White encontradas no texto.
  static List<EgwCitation> extractCitations(String text) {
    if (text.isEmpty) return const [];

    final List<EgwCitation> rawCitations = [];

    // 1. Extração por Título Completo / Parcial
    final fullMatches = _fullTitleRegex.allMatches(text);
    for (final match in fullMatches) {
      final matchedBook = match.group(1) ?? '';
      final detailsRaw = match.group(2)?.trim() ?? '';
      final details = detailsRaw.startsWith(',') ? detailsRaw.substring(1).trim() : detailsRaw;
      final cleanDetails = details.replaceAll(RegExp(r'[,.\s]+$'), '').trim();
      final rawText = match.group(0) ?? '';

      final lowerBook = matchedBook.toLowerCase().trim();
      final bookId = bookIdMap[lowerBook];
      final standardTitle = _standardizeTitle(matchedBook);

      final quote = _findPrecedingQuote(text, match.start);

      rawCitations.add(
        EgwCitation(
          bookTitle: standardTitle,
          bookId: bookId,
          details: cleanDetails.isNotEmpty ? cleanDetails : null,
          quote: quote,
          rawText: rawText,
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    // 2. Extração por Sigla com Página/Referência (ex: DTN, p. 50 ou PP 45)
    final abbrMatches = _abbrWithPageRegex.allMatches(text);
    for (final match in abbrMatches) {
      final abbr = match.group(1) ?? '';
      final pageRaw = match.group(2)?.trim() ?? '';
      final cleanPage = pageRaw.endsWith(',') ? pageRaw.substring(0, pageRaw.length - 1).trim() : pageRaw;
      final rawText = match.group(0) ?? '';

      final lowerAbbr = abbr.toLowerCase();
      final bookId = abbreviationMap[lowerAbbr];
      final title = abbreviationToTitleMap[lowerAbbr] ?? abbr;

      final quote = _findPrecedingQuote(text, match.start);

      rawCitations.add(
        EgwCitation(
          bookTitle: title,
          bookId: bookId,
          abbreviation: abbr.toUpperCase(),
          details: cleanPage.isNotEmpty ? 'p. $cleanPage' : null,
          quote: quote,
          rawText: rawText.endsWith(',') ? rawText.substring(0, rawText.length - 1).trim() : rawText,
          startIndex: match.start,
          endIndex: rawText.endsWith(',') ? match.end - 1 : match.end,
        ),
      );
    }

    // 3. Extração por Autor Explícito com Sigla (ex: Ellen G. White, DTN)
    final authorAbbrMatches = _abbrWithAuthorRegex.allMatches(text);
    for (final match in authorAbbrMatches) {
      final abbr = match.group(1) ?? '';
      final rawText = match.group(0) ?? '';
      final lowerAbbr = abbr.toLowerCase();
      final bookId = abbreviationMap[lowerAbbr];
      final title = abbreviationToTitleMap[lowerAbbr] ?? abbr;

      final quote = _findPrecedingQuote(text, match.start);

      rawCitations.add(
        EgwCitation(
          bookTitle: title,
          bookId: bookId,
          abbreviation: abbr.toUpperCase(),
          quote: quote,
          rawText: rawText,
          startIndex: match.start,
          endIndex: match.end,
        ),
      );
    }

    if (rawCitations.isEmpty) return const [];

    // Ordena por startIndex
    rawCitations.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    // Remove sobreposições mantendo a citação mais longa / prioritária
    final List<EgwCitation> result = [];
    for (final citation in rawCitations) {
      if (result.isEmpty) {
        result.add(citation);
        continue;
      }
      final last = result.last;
      if (citation.startIndex < last.endIndex) {
        // Sobreposição: se a nova citação for maior ou tiver mais detalhes, substitui
        if ((citation.endIndex - citation.startIndex) > (last.endIndex - last.startIndex)) {
          result[result.length - 1] = citation;
        }
      } else {
        result.add(citation);
      }
    }

    return result;
  }

  static String? _findPrecedingQuote(String text, int citationStart) {
    final prefix = text.substring(0, citationStart).trim();
    final quoteMatches = _quotePrefixRegex.allMatches(prefix);
    if (quoteMatches.isNotEmpty) {
      return quoteMatches.last.group(1)?.trim();
    }
    return null;
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
    if (lower.contains('grande conflito') || lower.contains('conflito dos')) return 'O Grande Conflito';
    if (lower.contains('patriarcas')) return 'Patriarcas e Profetas';
    if (lower.contains('profetas e reis')) return 'Profetas e Reis';
    if (lower.contains('atos dos')) return 'Atos dos Apóstolos';
    if (lower.contains('caminho a cristo')) return 'Caminho a Cristo';
    if (lower.contains('parábolas') || lower.contains('parabolas')) return 'Parábolas de Jesus';
    if (lower.contains('jovens')) return 'Mensagens aos Jovens';
    if (lower.contains('educação') || lower.contains('educacao')) return 'Educação';
    if (lower.contains('lar adventista')) return 'O Lar Adventista';
    if (lower.contains('primeiros escritos')) return 'Primeiros Escritos';
    if (lower.contains('redenção') || lower.contains('redencao')) return 'História da Redenção';
    if (lower.contains('bom viver')) return 'A Ciência do Bom Viver';
    if (lower.contains('escolhidas 1')) return 'Mensagens Escolhidas, vol. 1';
    if (lower.contains('escolhidas 2')) return 'Mensagens Escolhidas, vol. 2';
    if (lower.contains('escolhidas 3')) return 'Mensagens Escolhidas, vol. 3';
    if (lower.contains('escolhidas')) return 'Mensagens Escolhidas';
    if (lower.contains('escola sabatina')) return 'Conselhos sobre a Escola Sabatina';
    if (lower.contains('regime alimentar')) return 'Conselhos sobre o Regime Alimentar';
    if (lower.contains('mordomia')) return 'Conselhos sobre Mordomia';
    if (lower.contains('serviço cristão') || lower.contains('servico cristao')) return 'Serviço Cristão';
    if (lower.contains('vida de jesus')) return 'Vida de Jesus';
    if (lower.contains('maior discurso')) return 'O Maior Discurso de Cristo';
    if (lower.contains('eventos finais')) return 'Eventos Finais';
    if (lower.contains('beneficência') || lower.contains('beneficencia')) return 'Beneficência Social';
    if (lower.contains('fé e obras') || lower.contains('fe e obras')) return 'Fé e Obras';

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
