class SSQuarterly {
  final String id;
  final String title;
  final String description;
  final String humanDate;
  final String startDate;
  final String endDate;
  final String cover;
  final String category;

  const SSQuarterly({
    required this.id,
    required this.title,
    this.description = '',
    this.humanDate = '',
    this.startDate = '',
    this.endDate = '',
    this.cover = '',
    this.category = 'adultos',
  });

  factory SSQuarterly.fromJson(Map<String, dynamic> json, {String defaultCategory = 'adultos'}) {
    final qid = (json['id'] ?? '').toString();
    final title = (json['title'] ?? '').toString();

    String category = defaultCategory;
    final lid = qid.toLowerCase();
    final ltitle = title.toLowerCase();
    if (lid.contains('cq') || ltitle.contains('jovem') || lid.contains('jovens')) {
      category = 'jovens';
    } else if (!ltitle.contains('portugal') && !lid.contains('-pt')) {
      category = 'adultos';
    }

    return SSQuarterly(
      id: qid,
      title: title,
      description: (json['description'] ?? '').toString(),
      humanDate: (json['human_date'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      endDate: (json['end_date'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      category: json['category']?.toString() ?? category,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'human_date': humanDate,
    'start_date': startDate,
    'end_date': endDate,
    'cover': cover,
    'category': category,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSQuarterly && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SSLesson {
  final String id;
  final String quarterlyId;
  final String index;
  final String title;
  final String startDate;
  final String endDate;
  final String cover;
  final String path;

  const SSLesson({
    required this.id,
    required this.quarterlyId,
    this.index = '',
    this.title = '',
    this.startDate = '',
    this.endDate = '',
    this.cover = '',
    this.path = '',
  });

  factory SSLesson.fromJson(Map<String, dynamic> json, {String quarterlyId = ''}) {
    final rawIndex = (json['index'] ?? '').toString().trim();
    final rawId = (json['id'] ?? '').toString().trim();
    String cleanIdx = rawIndex;
    if (int.tryParse(rawId) != null) {
      cleanIdx = int.parse(rawId).toString();
    } else if (rawIndex.contains('-')) {
      final match = RegExp(r'(\d+)$').firstMatch(rawIndex);
      if (match != null) {
        cleanIdx = int.parse(match.group(1)!).toString();
      }
    } else if (int.tryParse(rawIndex) != null) {
      cleanIdx = int.parse(rawIndex).toString();
    }

    return SSLesson(
      id: rawId,
      quarterlyId: (json['quarterly_id'] ?? quarterlyId).toString(),
      index: cleanIdx.isNotEmpty ? cleanIdx : rawIndex,
      title: (json['title'] ?? '').toString(),
      startDate: (json['start_date'] ?? '').toString(),
      endDate: (json['end_date'] ?? '').toString(),
      cover: (json['cover'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'quarterly_id': quarterlyId,
    'index': index,
    'title': title,
    'start_date': startDate,
    'end_date': endDate,
    'cover': cover,
    'path': path,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSLesson && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SSDay {
  final String id;
  final String lessonId;
  final String index;
  final String title;
  final String date;
  final String content;
  final String readPath;

  const SSDay({
    required this.id,
    required this.lessonId,
    this.index = '',
    this.title = '',
    this.date = '',
    this.content = '',
    this.readPath = '',
  });

  factory SSDay.fromJson(Map<String, dynamic> json, {String lessonId = ''}) {
    return SSDay(
      id: (json['id'] ?? '').toString(),
      lessonId: (json['lesson_id'] ?? lessonId).toString(),
      index: (json['index'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      readPath: (json['read_path'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lesson_id': lessonId,
    'index': index,
    'title': title,
    'date': date,
    'content': content,
    'read_path': readPath,
  };

  SSDay copyWith({
    String? id,
    String? lessonId,
    String? index,
    String? title,
    String? date,
    String? content,
    String? readPath,
  }) {
    return SSDay(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      index: index ?? this.index,
      title: title ?? this.title,
      date: date ?? this.date,
      content: content ?? this.content,
      readPath: readPath ?? this.readPath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSDay && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class SSUserNote {
  final String dayId;
  final String noteText;
  final String updatedAt;

  const SSUserNote({
    required this.dayId,
    required this.noteText,
    this.updatedAt = '',
  });

  factory SSUserNote.fromJson(Map<String, dynamic> json) {
    return SSUserNote(
      dayId: (json['day_id'] ?? '').toString(),
      noteText: (json['note_text'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'day_id': dayId,
    'note_text': noteText,
    'updated_at': updatedAt,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSUserNote && runtimeType == other.runtimeType && dayId == other.dayId;

  @override
  int get hashCode => dayId.hashCode;
}
