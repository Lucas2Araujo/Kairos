class Devotional {
  final String publishedAt; // YYYY-MM-DD
  final String title;
  final String verseText;
  final String verseReference;
  final String content;
  final String category; // 'jovem', 'diario', 'mulher'
  final String author;
  final String sourceUrl;
  final String videoUrl;
  final String? cachedAt;

  const Devotional({
    required this.publishedAt,
    required this.title,
    required this.verseText,
    required this.verseReference,
    required this.content,
    this.category = 'jovem',
    this.author = '',
    this.sourceUrl = '',
    this.videoUrl = '',
    this.cachedAt,
  });

  /// Retorna o link direto do YouTube ou gera link de busca inteligente no canal CPB
  String get effectiveVideoUrl {
    if (videoUrl.trim().isNotEmpty) {
      return videoUrl.trim();
    }
    final catName = switch (category.toLowerCase()) {
      'jovem' => 'Jovem',
      'mulher' => 'Mulher',
      _ => 'Diária',
    };
    final query = Uri.encodeComponent('Meditação $catName $title CPB');
    return 'https://www.youtube.com/results?search_query=$query';
  }

  /// Retorna a URL direta da publicação na CPB ou o portal da categoria
  String get effectiveSourceUrl {
    if (sourceUrl.trim().isNotEmpty) {
      return sourceUrl.trim();
    }
    return switch (category.toLowerCase()) {
      'jovem' => 'https://mais.cpb.com.br/devocional-jovem-ano/',
      'mulher' => 'https://mais.cpb.com.br/devocional-mulher-ano/',
      _ => 'https://mais.cpb.com.br/devocional-diario-ano/',
    };
  }

  factory Devotional.fromMap(Map<String, dynamic> map) {
    return Devotional(
      publishedAt: (map['published_at'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      verseText: (map['verse_text'] ?? '').toString().trim(),
      verseReference: (map['verse_reference'] ?? '').toString().trim(),
      content: (map['content'] ?? '').toString().trim(),
      category: (map['category'] ?? 'jovem').toString().trim().toLowerCase(),
      author: (map['author'] ?? '').toString().trim(),
      sourceUrl: (map['source_url'] ?? '').toString().trim(),
      videoUrl: (map['video_url'] ?? '').toString().trim(),
      cachedAt: map['cached_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'published_at': publishedAt,
      'title': title,
      'verse_text': verseText,
      'verse_reference': verseReference,
      'content': content,
      'category': category,
      'author': author,
      'source_url': sourceUrl,
      'video_url': videoUrl,
      'cached_at': cachedAt ?? DateTime.now().toIso8601String(),
    };
  }
}
