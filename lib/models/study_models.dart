/// Representa uma perícope (subtítulo temático) associada a um versículo bíblico.
class Pericope {
  /// Identificador único do registro.
  final int id;

  /// Identificador do livro bíblico (`1..74`).
  final int bookId;

  /// Número do capítulo.
  final int chapter;

  /// Número do versículo onde a perícope inicia.
  final int verse;

  /// Título descritivo da seção.
  final String title;

  /// Cria uma instância imutável de [Pericope].
  const Pericope({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.title,
  });

  /// Constrói uma [Pericope] a partir de um mapa de linha SQLite.
  factory Pericope.fromMap(Map<String, dynamic> map) {
    return Pericope(
      id: map['id'] as int? ?? 0,
      bookId: map['book_id'] as int? ?? 0,
      chapter: map['chapter'] as int? ?? 0,
      verse: map['verse'] as int? ?? 0,
      title: map['title'] as String? ?? '',
    );
  }
}

/// Representa um comentário expositivo associado a um intervalo de versículos.
class Commentary {
  /// Identificador único do comentário.
  final int id;

  /// Identificador do livro bíblico.
  final int bookId;

  /// Número do capítulo.
  final int chapter;

  /// Primeiro versículo coberto pelo comentário.
  final int verseStart;

  /// Último versículo coberto pelo comentário.
  final int verseEnd;

  /// Nome do autor ou obra expositiva.
  final String author;

  /// Título opcional do comentário.
  final String? title;

  /// Conteúdo expositivo completo em texto.
  final String text;

  /// Cria uma instância imutável de [Commentary].
  const Commentary({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.author,
    this.title,
    required this.text,
  });

  /// Nome do autor expositivo (alias de compatibilidade para [author]).
  String get authorName => author;

  /// Constrói um [Commentary] a partir de um mapa SQLite em esquema PT ou EN.
  factory Commentary.fromMap(Map<String, dynamic> map) {
    return Commentary(
      id: map['id'] as int? ?? 0,
      bookId: map['book_id'] as int? ?? (map['livro_id'] as int? ?? 0),
      chapter: map['chapter'] as int? ?? (map['capitulo'] as int? ?? 0),
      verseStart: map['verse_start'] as int? ?? (map['versiculo_inicio'] as int? ?? 0),
      verseEnd: map['verse_end'] as int? ?? (map['versiculo_fim'] as int? ?? 0),
      author: map['author_name'] as String? ?? (map['author'] as String? ?? (map['autor'] as String? ?? 'Expositor')),
      title: map['title'] as String?,
      text: map['content'] as String? ?? (map['comentario'] as String? ?? (map['texto'] as String? ?? '')),
    );
  }
}

/// Representa uma referência cruzada bíblica entre duas passagens.
class CrossReference {
  /// Identificador único da referência cruzada.
  final int id;

  /// Livro de origem.
  final int fromBookId;

  /// Capítulo de origem.
  final int fromChapter;

  /// Versículo de origem.
  final int fromVerse;

  /// Livro de destino.
  final int toBookId;

  /// Capítulo de destino.
  final int toChapter;

  /// Versículo inicial de destino.
  final int toVerseStart;

  /// Versículo final de destino.
  final int toVerseEnd;

  /// Pontuação de relevância comunitária.
  final int votes;

  /// Nome amigável opcional do livro de destino.
  final String? toBookName;

  /// Cria uma instância imutável de [CrossReference].
  const CrossReference({
    required this.id,
    required this.fromBookId,
    required this.fromChapter,
    required this.fromVerse,
    required this.toBookId,
    required this.toChapter,
    required this.toVerseStart,
    required this.toVerseEnd,
    required this.votes,
    this.toBookName,
  });

  /// Referência formatada para exibição ao usuário (ex.: `João 3:16` ou `Salmos 23:1-3`).
  String get targetReference {
    final book = toBookName ?? 'Livro $toBookId';
    if (toVerseStart == toVerseEnd) {
      return '$book $toChapter:$toVerseStart';
    }
    return '$book $toChapter:$toVerseStart-$toVerseEnd';
  }

  /// Constrói uma [CrossReference] a partir de um mapa SQLite em esquema PT ou EN.
  factory CrossReference.fromMap(Map<String, dynamic> map, {String? targetBookName}) {
    return CrossReference(
      id: map['id'] as int? ?? 0,
      fromBookId: map['from_book_id'] as int? ?? (map['de_livro_id'] as int? ?? 0),
      fromChapter: map['from_chapter'] as int? ?? (map['de_capitulo'] as int? ?? 0),
      fromVerse: map['from_verse'] as int? ?? (map['de_versiculo'] as int? ?? 0),
      toBookId: map['to_book_id'] as int? ?? (map['para_livro_id'] as int? ?? 0),
      toChapter: map['to_chapter'] as int? ?? (map['para_capitulo'] as int? ?? 0),
      toVerseStart: map['to_verse_start'] as int? ?? (map['para_versiculo_inicio'] as int? ?? 0),
      toVerseEnd: map['to_verse_end'] as int? ?? (map['para_versiculo_fim'] as int? ?? 0),
      votes: map['votes'] as int? ?? (map['votos'] as int? ?? 0),
      toBookName: targetBookName ?? map['to_book_name'] as String?,
    );
  }
}
