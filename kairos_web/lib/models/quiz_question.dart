class QuizQuestion {
  final String id;
  final String dayId;
  final String quarterlyId;
  final String category;
  final String question;
  final List<String> options;
  final int correctOption;
  final String explanation;
  final String? verseRef;
  final String? createdAt;

  const QuizQuestion({
    required this.id,
    required this.dayId,
    required this.quarterlyId,
    this.category = 'adultos',
    required this.question,
    required this.options,
    required this.correctOption,
    required this.explanation,
    this.verseRef,
    this.createdAt,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    List<String> parsedOptions = [];
    if (map['options'] is List) {
      parsedOptions = (map['options'] as List).map((e) => e.toString()).toList();
    }

    return QuizQuestion(
      id: (map['id'] ?? '').toString(),
      dayId: (map['day_id'] ?? '').toString(),
      quarterlyId: (map['quarterly_id'] ?? '').toString(),
      category: (map['category'] ?? 'adultos').toString(),
      question: (map['question'] ?? '').toString(),
      options: parsedOptions,
      correctOption: map['correct_option'] as int? ?? 0,
      explanation: (map['explanation'] ?? '').toString(),
      verseRef: map['verse_ref'] as String?,
      createdAt: map['created_at'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'day_id': dayId,
      'quarterly_id': quarterlyId,
      'category': category,
      'question': question,
      'options': options,
      'correct_option': correctOption,
      'explanation': explanation,
      'verse_ref': verseRef,
      'created_at': createdAt,
    };
  }
}

class QuizResult {
  final bool isCorrect;
  final int correctOption;
  final String explanation;
  final int xpEarned;
  final int newStreak;

  const QuizResult({
    required this.isCorrect,
    required this.correctOption,
    required this.explanation,
    this.xpEarned = 0,
    this.newStreak = 0,
  });
}
