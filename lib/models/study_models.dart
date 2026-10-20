class Pericope {
  final int id;
  final int bookId;
  final int chapter;
  final int verse;
  final String title;

  const Pericope({
    required this.id,
    required this.bookId,
    required this.chapter,
    required this.verse,
    required this.title,
  });

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

class Commentary {
  final int id;
  final int bookId;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final String author;
  final String? title;
  final String text;

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

class CrossReference {
  final int id;
  final int fromBookId;
  final int fromChapter;
  final int fromVerse;
  final int toBookId;
  final int toChapter;
  final int toVerseStart;
  final int toVerseEnd;
  final int votes;
  final String? toBookName;

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

  String get targetReference {
    final book = toBookName ?? 'Livro $toBookId';
    if (toVerseStart == toVerseEnd) {
      return '$book $toChapter:$toVerseStart';
    }
    return '$book $toChapter:$toVerseStart-$toVerseEnd';
  }

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
