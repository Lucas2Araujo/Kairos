import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/utils/egw_extractor.dart';
import 'package:kairos_web/models/egw_models.dart';

void main() {
  group('EgwExtractor Tests', () {
    test('Extrai títulos completos com acento e sem autor', () {
      const text = 'Como lemos em O Desejado de Todas as Nações, p. 123, Cristo é o centro.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, equals(1));
      expect(citations.first.bookTitle, equals('O Desejado de Todas as Nações'));
      expect(citations.first.bookId, equals('1813'));
      expect(citations.first.details, equals('p. 123'));
    });

    test('Extrai títulos desacentuados', () {
      const text = 'Ver Educacao, p. 50 e tambem Historia da Redencao, p. 15.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, equals(2));
      expect(citations[0].bookTitle, equals('Educação'));
      expect(citations[0].bookId, equals('1948'));
      expect(citations[1].bookTitle, equals('História da Redenção'));
      expect(citations[1].bookId, equals('1949'));
    });

    test('Extrai siglas populares com número de página (DTN, PP, GC, CC)', () {
      const text = 'Conforme DTN, p. 50 e PP 45, além de GC 640 e CC, pág. 12.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, equals(4));
      expect(citations[0].abbreviation, equals('DTN'));
      expect(citations[0].bookTitle, equals('O Desejado de Todas as Nações'));
      expect(citations[0].bookId, equals('1813'));

      expect(citations[1].abbreviation, equals('PP'));
      expect(citations[1].bookTitle, equals('Patriarcas e Profetas'));
      expect(citations[1].bookId, equals('1815'));

      expect(citations[2].abbreviation, equals('GC'));
      expect(citations[2].bookTitle, equals('O Grande Conflito'));
      expect(citations[2].bookId, equals('11125'));

      expect(citations[3].abbreviation, equals('CC'));
      expect(citations[3].bookTitle, equals('Caminho a Cristo'));
      expect(citations[3].bookId, equals('11121'));
    });

    test('Extrai volumes de Testemunhos e Mensagens Escolhidas (1T, 1ME)', () {
      const text = 'Veja 1T, p. 100 e também 1ME, p. 30.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, equals(2));
      expect(citations[0].abbreviation, equals('1T'));
      expect(citations[0].bookId, equals('1819'));
      expect(citations[1].abbreviation, equals('1ME'));
      expect(citations[1].bookId, equals('11246'));
    });

    test('Extrai citação precedida por autor explícito', () {
      const text = 'Como escreveu Ellen G. White, DTN fala sobre o amor de Deus.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations.length, equals(1));
      expect(citations.first.bookTitle, equals('O Desejado de Todas as Nações'));
      expect(citations.first.bookId, equals('1813'));
    });

    test('Não gera falsos positivos em texto normal sem referências', () {
      const text = 'O Senhor é o meu pastor e nada me faltará. Pedro e João foram ao templo.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations, isEmpty);
    });

    test('Não gera falso positivo em sigla isolada sem número ou autor', () {
      const text = 'A conferência do DTN não foi citada.';
      final citations = EgwExtractor.extractCitations(text);

      expect(citations, isEmpty);
    });

    test('Segmenta texto corretamente com splitTextByEgwCitations', () {
      const text = 'Início do texto. DTN, p. 100. Fim do texto.';
      final segments = EgwExtractor.splitTextByEgwCitations(text);

      expect(segments.length, equals(3));
      expect(segments[0].isCitation, isFalse);
      expect(segments[1].isCitation, isTrue);
      expect(segments[1].citation?.bookTitle, equals('O Desejado de Todas as Nações'));
      expect(segments[2].isCitation, isFalse);
    });
  });

  group('EgwModels Serialization Tests', () {
    test('EgwBook toMap e fromMap', () {
      final book = EgwBook(
        id: '1813',
        title: 'O Desejado de Todas as Nações',
        abbreviation: 'DTN',
        totalChapters: 87,
        downloadedChapters: 87,
        isDownloaded: true,
      );

      final map = book.toMap();
      final fromMap = EgwBook.fromMap(map, downloaded: 87);

      expect(fromMap.id, equals('1813'));
      expect(fromMap.title, equals('O Desejado de Todas as Nações'));
      expect(fromMap.abbreviation, equals('DTN'));
      expect(fromMap.isDownloaded, isTrue);
    });

    test('EgwChapter toJson e fromJson', () {
      final chapter = EgwChapter(
        id: '1813.68',
        bookId: '1813',
        chapterId: '68',
        chapterIndex: 1,
        title: 'Capítulo 1 — “Deus conosco”',
        paragraphs: const [
          EgwParagraph(
            id: '69',
            refcode: 'DTN 9.1',
            text: 'Ele será chamado pelo nome de Emanuel.',
          ),
        ],
      );

      final jsonStr = chapter.toJson();
      final fromJson = EgwChapter.fromJson(jsonStr);

      expect(fromJson.id, equals('1813.68'));
      expect(fromJson.bookId, equals('1813'));
      expect(fromJson.title, equals('Capítulo 1 — “Deus conosco”'));
      expect(fromJson.paragraphs.length, equals(1));
      expect(fromJson.paragraphs.first.refcode, equals('DTN 9.1'));
    });
  });
}
