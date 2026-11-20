import 'dart:convert';

/// Modelo de Livro do Espírito de Profecia (Ellen G. White)
class EgwBook {
  /// Identificador único do livro (numérico oficial ou slug `pt_...`)
  final String id;

  /// Título completo em português da obra
  final String title;

  /// Sigla canônica oficial ou de uso comum (ex: DTN, GC, PP, 1TI)
  final String abbreviation;

  /// Breve sinopse temática da obra
  final String description;

  /// URL da capa clássica oficial do portal EGW Writings
  final String coverUrl;

  /// URL opcional da capa moderna estilo Casa Publicadora Brasileira (CPB)
  final String? cpbCoverUrl;

  /// ID numérico oficial resolvido dinamicamente para obras cadastradas via slug
  final String? resolvedId;

  /// Quantidade total de capítulos catalogados no sumário
  final int totalChapters;

  /// Quantidade de capítulos salvos no banco local offline
  final int downloadedChapters;

  /// Indica se a totalidade dos capítulos está baixada e íntegra localmente
  final bool isDownloaded;

  EgwBook({
    required this.id,
    required this.title,
    required this.abbreviation,
    this.description = '',
    String? coverUrl,
    this.cpbCoverUrl,
    this.resolvedId,
    this.totalChapters = 0,
    this.downloadedChapters = 0,
    this.isDownloaded = false,
  }) : coverUrl = coverUrl ??
            ((resolvedId != null && RegExp(r'^\d+$').hasMatch(resolvedId))
                ? 'https://media4.egwwritings.org/covers/${resolvedId}_r.jpg'
                : (RegExp(r'^\d+$').hasMatch(id)
                    ? 'https://media4.egwwritings.org/covers/${id}_r.jpg'
                    : ''));

  EgwBook copyWith({
    String? id,
    String? title,
    String? abbreviation,
    String? description,
    String? coverUrl,
    String? cpbCoverUrl,
    String? resolvedId,
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
      cpbCoverUrl: cpbCoverUrl ?? this.cpbCoverUrl,
      resolvedId: resolvedId ?? this.resolvedId,
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
      'cpb_cover_url': cpbCoverUrl,
      'resolved_id': resolvedId,
      'total_chapters': totalChapters,
      'is_downloaded': isDownloaded ? 1 : 0,
    };
  }

  /// Avalia se o download de um livro está completo com base na contagem real de capítulos em cache.
  ///
  /// Retorna `false` se [cachedChapterCount] for menor ou igual a zero.
  /// Quando [expectedTotalChapters] for maior que zero, retorna `true` se [cachedChapterCount]
  /// for maior ou igual ao total esperado, ignorando [flaggedDownloaded] caso faltem capítulos.
  /// Se [expectedTotalChapters] for menor ou igual a zero, retorna `true` apenas se
  /// [flaggedDownloaded] for verdadeiro e houver mais de um capítulo salvo ([cachedChapterCount] > 1).
  static bool evaluateDownloadCompleteness({
    required int cachedChapterCount,
    required int expectedTotalChapters,
    required bool flaggedDownloaded,
  }) {
    if (cachedChapterCount <= 0) return false;
    if (expectedTotalChapters > 0) {
      return cachedChapterCount >= expectedTotalChapters;
    }
    return flaggedDownloaded && cachedChapterCount > 1;
  }

  /// Cria uma instância de [EgwBook] a partir de um [map] do SQLite.
  ///
  /// O parâmetro opcional [downloaded] indica a quantidade de capítulos
  /// efetivamente salvos localmente. O status [isDownloaded] é avaliado
  /// através de [evaluateDownloadCompleteness] para evitar que downloads parciais
  /// sejam marcados como completos indevidamente.
  factory EgwBook.fromMap(Map<String, dynamic> map, {int downloaded = 0}) {
    final id = (map['id'] ?? '').toString();
    final total = (map['total_chapters'] as int?) ?? 0;
    final flaggedDown = (map['is_downloaded'] as int? ?? 0) == 1;
    final isDown = evaluateDownloadCompleteness(
      cachedChapterCount: downloaded,
      expectedTotalChapters: total,
      flaggedDownloaded: flaggedDown,
    );
    final resolved = map['resolved_id']?.toString();
    final cpbUrl = map['cpb_cover_url']?.toString();
    final rawCover = map['cover_url']?.toString();
    final validCover = (rawCover != null && rawCover.isNotEmpty && !rawCover.contains('pt_'))
        ? rawCover
        : null;

    return EgwBook(
      id: id,
      title: (map['title'] ?? '').toString(),
      abbreviation: (map['abbreviation'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      coverUrl: validCover,
      cpbCoverUrl: cpbUrl,
      resolvedId: resolved,
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

/// Resultado de busca textual por frase/citação dentro dos livros baixados de EGW.
class EgwPhraseMatch {
  final String bookId;
  final String bookTitle;
  final String bookAbbreviation;
  final String chapterId;
  final String chapterTitle;
  final String refcode;
  final String snippet;

  const EgwPhraseMatch({
    required this.bookId,
    required this.bookTitle,
    required this.bookAbbreviation,
    required this.chapterId,
    required this.chapterTitle,
    required this.refcode,
    required this.snippet,
  });
}
