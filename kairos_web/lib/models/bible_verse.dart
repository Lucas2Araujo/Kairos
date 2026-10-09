class BibleVerse {
  final int id;
  final int bookId;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;

  const BibleVerse({
    required this.id,
    required this.bookId,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
  });

  factory BibleVerse.fromMap(Map<String, dynamic> map, {String bookName = ''}) {
    return BibleVerse(
      id: map['id'] as int? ?? 0,
      bookId: map['book_id'] as int? ?? (map['livro_id'] as int? ?? 0),
      bookName: bookName.isNotEmpty ? bookName : (map['book_name'] as String? ?? (map['livro_nome'] as String? ?? '')),
      chapter: map['chapter'] as int? ?? (map['capitulo'] as int? ?? 0),
      verse: map['verse'] as int? ?? (map['versiculo'] as int? ?? 0),
      text: map['text'] as String? ?? (map['texto'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'book_name': bookName,
      'chapter': chapter,
      'verse': verse,
      'text': text,
    };
  }
}

class BibleBook {
  final int id;
  final String name;
  final String testament;
  final int chaptersCount;

  const BibleBook({
    required this.id,
    required this.name,
    required this.testament,
    required this.chaptersCount,
  });

  factory BibleBook.fromMap(Map<String, dynamic> map, {int chaptersCount = 1}) {
    final testamentRef = map['testament_reference_id'] as int? ?? 1;
    final testament = map['testamento'] as String? ?? (testamentRef == 1 ? 'VT' : 'NT');
    final totalChapters = map['total_capitulos'] as int? ?? (map['chapters_count'] as int? ?? chaptersCount);
    return BibleBook(
      id: map['id'] as int? ?? 0,
      name: map['name'] as String? ?? (map['nome'] as String? ?? ''),
      testament: testament,
      chaptersCount: totalChapters,
    );
  }
}
