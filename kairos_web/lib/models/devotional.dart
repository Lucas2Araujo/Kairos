class Devotional {
  final String publishedAt; // YYYY-MM-DD
  final String title;
  final String verseText;
  final String verseReference;
  final String content;
  final String category; // 'jovem', 'diario', 'mulher'
  final String author;
  final String sourceUrl;
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
    this.cachedAt,
  });

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
      'cached_at': cachedAt ?? DateTime.now().toIso8601String(),
    };
  }
}
