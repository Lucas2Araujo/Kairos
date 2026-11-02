import 'dart:convert';

/// Modelo de Livro do Espírito de Profecia (Ellen G. White)
class EgwBook {
  final String id;
  final String title;
  final String abbreviation;
  final String description;
  final String coverUrl;
  final int totalChapters;
  final int downloadedChapters;
  final bool isDownloaded;

  const EgwBook({
    required this.id,
    required this.title,
    required this.abbreviation,
    this.description = '',
    String? coverUrl,
    this.totalChapters = 0,
    this.downloadedChapters = 0,
    this.isDownloaded = false,
  }) : coverUrl = coverUrl ?? 'https://media4.egwwritings.org/covers/${id}_r.jpg';

  EgwBook copyWith({
    String? id,
    String? title,
    String? abbreviation,
    String? description,
    String? coverUrl,
    int? totalChapters,
    int? downloadedChapters,
    bool? isDownloaded,
  }) {
    return EgwBook(
      id: id ?? this.id,
      title: title ?? this.title,
      abbreviation: abbreviation ?? this.abbreviation,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      totalChapters: totalChapters ?? this.totalChapters,
      downloadedChapters: downloadedChapters ?? this.downloadedChapters,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'abbreviation': abbreviation,
      'description': description,
      'cover_url': coverUrl,
      'total_chapters': totalChapters,
      'is_downloaded': isDownloaded ? 1 : 0,
    };
  }

  factory EgwBook.fromMap(Map<String, dynamic> map, {int downloaded = 0}) {
    final id = (map['id'] ?? '').toString();
    final total = (map['total_chapters'] as int?) ?? 0;
    final isDown = (map['is_downloaded'] as int? ?? 0) == 1 || (total > 0 && downloaded >= total);
    return EgwBook(
      id: id,
      title: (map['title'] ?? '').toString(),
      abbreviation: (map['abbreviation'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: (map['cover_url'] ?? 'https://media4.egwwritings.org/covers/${id}_r.jpg').toString(),
      totalChapters: total,
      downloadedChapters: downloaded,
      isDownloaded: isDown,
    );
  }
}

/// Cabeçalho/Item do Sumário (Table of Contents)
class EgwChapterHeader {
  final String bookId;
  final String chapterId;
  final int chapterIndex;
  final String title;

  const EgwChapterHeader({
    required this.bookId,
    required this.chapterId,
    required this.chapterIndex,
    required this.title,
  });

  Map<String, dynamic> toMap() {
    return {
      'bookId': bookId,
      'chapterId': chapterId,
      'chapterIndex': chapterIndex,
      'title': title,
    };
  }

  factory EgwChapterHeader.fromMap(Map<String, dynamic> map) {
    return EgwChapterHeader(
      bookId: (map['bookId'] ?? '').toString(),
      chapterId: (map['chapterId'] ?? '').toString(),
      chapterIndex: (map['chapterIndex'] as int?) ?? 0,
      title: (map['title'] ?? '').toString(),
    );
  }
}

/// Parágrafo individual de um livro de EGW
class EgwParagraph {
  final String id;
  final String refcode;
  final String text;

  const EgwParagraph({
    required this.id,
    required this.refcode,
    required this.text,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'refcode': refcode,
      'text': text,
    };
  }

  factory EgwParagraph.fromMap(Map<String, dynamic> map) {
    return EgwParagraph(
      id: (map['id'] ?? '').toString(),
      refcode: (map['refcode'] ?? '').toString(),
      text: (map['text'] ?? '').toString(),
    );
  }
}

/// Conteúdo completo de um capítulo de EGW
class EgwChapter {
  final String id;
  final String bookId;
  final String chapterId;
  final int chapterIndex;
  final String title;
  final List<EgwParagraph> paragraphs;

  const EgwChapter({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.chapterIndex,
    required this.title,
    required this.paragraphs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'chapterId': chapterId,
      'chapterIndex': chapterIndex,
      'title': title,
      'paragraphs': paragraphs.map((p) => p.toMap()).toList(),
    };
  }

  String toJson() => json.encode(toMap());

  factory EgwChapter.fromMap(Map<String, dynamic> map) {
    final rawParas = map['paragraphs'] as List? ?? [];
    return EgwChapter(
      id: (map['id'] ?? '').toString(),
      bookId: (map['bookId'] ?? '').toString(),
      chapterId: (map['chapterId'] ?? '').toString(),
      chapterIndex: (map['chapterIndex'] as int?) ?? 0,
      title: (map['title'] ?? '').toString(),
      paragraphs: rawParas
          .map((p) => EgwParagraph.fromMap(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  factory EgwChapter.fromJson(String jsonStr) {
    return EgwChapter.fromMap(json.decode(jsonStr) as Map<String, dynamic>);
  }
}
