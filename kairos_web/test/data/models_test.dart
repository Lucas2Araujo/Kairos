import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/bible_verse.dart';
import 'package:kairos_web/models/hymn.dart';
import 'package:kairos_web/models/study_models.dart';

void main() {
  group('Bible & Hymn Models Serialization Test', () {
    test('BibleVerse.fromMap parses valid row', () {
      final map = {
        'id': 1,
        'livro_id': 1,
        'livro_nome': 'Gênesis',
        'capitulo': 1,
        'versiculo': 1,
        'texto': 'No princípio criou Deus os céus e a terra.',
      };

      final verse = BibleVerse.fromMap(map);

      expect(verse.id, 1);
      expect(verse.bookId, 1);
      expect(verse.bookName, 'Gênesis');
      expect(verse.chapter, 1);
      expect(verse.verse, 1);
      expect(verse.text, 'No princípio criou Deus os céus e a terra.');
    });

    test('BibleBook.fromMap parses valid row', () {
      final map = {
        'id': 1,
        'nome': 'Gênesis',
        'abreviacao': 'Gn',
        'testamento': 'VT',
        'total_capitulos': 50,
      };

      final book = BibleBook.fromMap(map);

      expect(book.id, 1);
      expect(book.name, 'Gênesis');
      expect(book.testament, 'VT');
      expect(book.chaptersCount, 50);
    });

    test('Commentary.fromMap parses valid row', () {
      final map = {
        'id': 10,
        'livro_id': 1,
        'capitulo': 1,
        'versiculo_inicio': 1,
        'versiculo_fim': 3,
        'autor': 'Moody',
        'comentario': 'Comentário sobre a criação.',
      };

      final comm = Commentary.fromMap(map);

      expect(comm.id, 10);
      expect(comm.author, 'Moody');
      expect(comm.verseStart, 1);
      expect(comm.verseEnd, 3);
    });
    test('Hymn.fromMap parses valid row', () {
      final map = {
        'id': 1,
        'numero': '001',
        'titulo': 'Ó Deus de Amor',
        'letra': 'Ó Deus de amor, nós vimos Te adorar...',
        'autor_letra': 'Autor Desconhecido',
        'autor_musica': 'Compositor',
        'texto_base': 'Salmos 100',
        'categoria': 'Adoração',
        'subcategoria': 'Louvor',
        'autores': 'Vários',
      };

      final hymn = Hymn.fromMap(map);

      expect(hymn.id, 1);
      expect(hymn.numero, '001');
      expect(hymn.titulo, 'Ó Deus de Amor');
      expect(hymn.letra, 'Ó Deus de amor, nós vimos Te adorar...');
      expect(hymn.autorLetra, 'Autor Desconhecido');
      expect(hymn.autorMusica, 'Compositor');
      expect(hymn.textoBase, 'Salmos 100');
      expect(hymn.categoria, 'Adoração');
      expect(hymn.subcategoria, 'Louvor');
      expect(hymn.autores, 'Vários');
    });

    test('Hymn.fromMap handles null and default values', () {
      final map = <String, dynamic>{
        'id': null,
        'numero': null,
        'titulo': null,
      };

      final hymn = Hymn.fromMap(map);

      expect(hymn.id, 0);
      expect(hymn.numero, '');
      expect(hymn.titulo, '');
      expect(hymn.letra, isNull);
      expect(hymn.autorLetra, isNull);
    });

    test('Hymn.toMap roundtrip preserves properties', () {
      const hymn = Hymn(
        id: 42,
        numero: '42',
        titulo: 'Castelo Forte',
        letra: 'Castelo forte é nosso Deus...',
        autorLetra: 'Martinho Lutero',
        autorMusica: 'Martinho Lutero',
        textoBase: 'Salmo 46',
        categoria: 'Confiança',
        subcategoria: 'Refúgio',
        autores: 'Lutero',
      );

      final map = hymn.toMap();
      final reconstructed = Hymn.fromMap(map);

      expect(reconstructed.id, 42);
      expect(reconstructed.numero, '42');
      expect(reconstructed.titulo, 'Castelo Forte');
      expect(reconstructed.letra, 'Castelo forte é nosso Deus...');
      expect(reconstructed.autorLetra, 'Martinho Lutero');
      expect(reconstructed.autorMusica, 'Martinho Lutero');
      expect(reconstructed.textoBase, 'Salmo 46');
      expect(reconstructed.categoria, 'Confiança');
      expect(reconstructed.subcategoria, 'Refúgio');
      expect(reconstructed.autores, 'Lutero');
    });
  });
}
