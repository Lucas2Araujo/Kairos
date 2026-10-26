import 'dart:convert';
import 'package:flutter/material.dart';

/// Referência a um capítulo de um livro bíblico dentro de um plano
class ReadingPlanChapterRef {
  final int bookId;
  final String bookName;
  final String abbrev;
  final int chapter;

  const ReadingPlanChapterRef({
    required this.bookId,
    required this.bookName,
    required this.abbrev,
    required this.chapter,
  });

  String get shortRef => '$abbrev $chapter';
  String get fullRef => '$bookName $chapter';

  Map<String, dynamic> toMap() => {
        'book_id': bookId,
        'book_name': bookName,
        'abbrev': abbrev,
        'chapter': chapter,
      };

  factory ReadingPlanChapterRef.fromMap(Map<String, dynamic> map) =>
      ReadingPlanChapterRef(
        bookId: map['book_id'] as int,
        bookName: map['book_name'] as String,
        abbrev: map['abbrev'] as String,
        chapter: map['chapter'] as int,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPlanChapterRef &&
          runtimeType == other.runtimeType &&
          bookId == other.bookId &&
          chapter == other.chapter;

  @override
  int get hashCode => bookId.hashCode ^ chapter.hashCode;
}

/// Um dia específico dentro do plano de leitura
class ReadingPlanDay {
  final int dayIndex; // 1-based index (1 .. daysCount)
  final String title;
  final List<ReadingPlanChapterRef> chapters;

  const ReadingPlanDay({
    required this.dayIndex,
    required this.title,
    required this.chapters,
  });

  /// Descrição resumida da leitura do dia (ex: "Gênesis 1" ou "Gênesis 34-36" ou "Sl 23, Sl 27")
  String get readingSummary {
    if (chapters.isEmpty) return 'Descanso';
    if (chapters.length == 1) return chapters.first.fullRef;

    final first = chapters.first;
    final last = chapters.last;
    final allSameBook = chapters.every((c) => c.bookId == first.bookId);

    if (allSameBook) {
      if (last.chapter == first.chapter + chapters.length - 1) {
        return '${first.bookName} ${first.chapter}-${last.chapter}';
      }
      return '${first.bookName} ${chapters.map((c) => c.chapter).join(', ')}';
    }
    return chapters.map((c) => c.shortRef).join(', ');
  }
}

/// Definição completa de um Plano de Leitura Bíblica
class ReadingPlan {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String category;
  final int daysCount;
  final List<ReadingPlanDay> days;

  const ReadingPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.category,
    required this.daysCount,
    required this.days,
  });

  ReadingPlanDay? getDay(int dayIndex) {
    if (dayIndex < 1 || dayIndex > days.length) return null;
    return days[dayIndex - 1];
  }
}

/// Progresso do usuário para um plano persistido em SQLite/SharedPreferences
class UserPlanProgress {
  final String planId;
  final bool isActive;
  final bool isPrimary;
  final DateTime startedAt;
  final Set<int> completedDays; // Dias concluídos (1-based: 1, 2, ...)
  final Set<String> currentDayCompletedChapters; // ex: "1:34" (bookId:chapter)
  final String? reminderTime; // ex: "07:00"

  const UserPlanProgress({
    required this.planId,
    required this.isActive,
    required this.isPrimary,
    required this.startedAt,
    required this.completedDays,
    required this.currentDayCompletedChapters,
    this.reminderTime,
  });

  UserPlanProgress copyWith({
    String? planId,
    bool? isActive,
    bool? isPrimary,
    DateTime? startedAt,
    Set<int>? completedDays,
    Set<String>? currentDayCompletedChapters,
    String? reminderTime,
  }) {
    return UserPlanProgress(
      planId: planId ?? this.planId,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
      startedAt: startedAt ?? this.startedAt,
      completedDays: completedDays ?? this.completedDays,
      currentDayCompletedChapters:
          currentDayCompletedChapters ?? this.currentDayCompletedChapters,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  /// Calcula o dia atual do plano (1-based), baseado na data de início e nos dias completados
  int calculateCurrentDay(int totalDays) {
    if (!isActive) return 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startedAt.year, startedAt.month, startedAt.day);
    final diffDays = today.difference(start).inDays;

    // Se o usuário está em dia pelo calendário
    final calendarDay = diffDays + 1;

    // Se concluiu dias futuros ou se atrasou, garante dia coerente dentro de 1..totalDays
    if (calendarDay > totalDays) return totalDays;
    return calendarDay < 1 ? 1 : calendarDay;
  }

  /// Porcentagem de conclusão do plano (0.0 a 1.0)
  double getProgressPercentage(int totalDays) {
    if (totalDays <= 0) return 0.0;
    return (completedDays.length / totalDays).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toMap() => {
        'plan_id': planId,
        'is_active': isActive ? 1 : 0,
        'is_primary': isPrimary ? 1 : 0,
        'started_at': startedAt.toIso8601String(),
        'completed_days_json': jsonEncode(completedDays.toList()..sort()),
        'current_chapters_json':
            jsonEncode(currentDayCompletedChapters.toList()..sort()),
        'reminder_time': reminderTime,
      };

  factory UserPlanProgress.fromMap(Map<String, dynamic> map) {
    final compDaysList = map['completed_days_json'] != null
        ? List<int>.from(jsonDecode(map['completed_days_json'] as String) as List)
        : <int>[];
    final compChaptersList = map['current_chapters_json'] != null
        ? List<String>.from(
            jsonDecode(map['current_chapters_json'] as String) as List)
        : <String>[];

    return UserPlanProgress(
      planId: map['plan_id'] as String,
      isActive: (map['is_active'] as int? ?? 0) == 1,
      isPrimary: (map['is_primary'] as int? ?? 0) == 1,
      startedAt: DateTime.tryParse(map['started_at'] as String? ?? '') ??
          DateTime.now(),
      completedDays: compDaysList.toSet(),
      currentDayCompletedChapters: compChaptersList.toSet(),
      reminderTime: map['reminder_time'] as String?,
    );
  }
}

/// Catálogo nativo e gerador determinístico dos 6 planos pré-carregados
class NativeReadingPlans {
  static const List<(int id, String name, String abbrev, int chapters)>
      _allBooks = [
    (1, 'Gênesis', 'Gn', 50),
    (2, 'Êxodo', 'Êx', 40),
    (3, 'Levítico', 'Lv', 27),
    (4, 'Números', 'Nm', 36),
    (5, 'Deuteronômio', 'Dt', 34),
    (6, 'Josué', 'Js', 24),
    (7, 'Juízes', 'Jz', 21),
    (8, 'Rute', 'Rt', 4),
    (9, '1 Samuel', '1Sm', 31),
    (10, '2 Samuel', '2Sm', 24),
    (11, '1 Reis', '1Rs', 22),
    (12, '2 Reis', '2Rs', 25),
    (13, '1 Crônicas', '1Cr', 29),
    (14, '2 Crônicas', '2Cr', 36),
    (15, 'Esdras', 'Ed', 10),
    (16, 'Neemias', 'Ne', 13),
    (17, 'Ester', 'Et', 10),
    (18, 'Jó', 'Jó', 42),
    (19, 'Salmos', 'Sl', 150),
    (20, 'Provérbios', 'Pv', 31),
    (21, 'Eclesiastes', 'Ec', 12),
    (22, 'Cânticos', 'Ct', 8),
    (23, 'Isaías', 'Is', 66),
    (24, 'Jeremias', 'Jr', 52),
    (25, 'Lamentações', 'Lm', 5),
    (26, 'Ezequiel', 'Ez', 48),
    (27, 'Daniel', 'Dn', 12),
    (28, 'Oseias', 'Os', 14),
    (29, 'Joel', 'Jl', 3),
    (30, 'Amós', 'Am', 9),
    (31, 'Obadias', 'Ob', 1),
    (32, 'Jonas', 'Jn', 4),
    (33, 'Miqueias', 'Mq', 7),
    (34, 'Naum', 'Na', 3),
    (35, 'Habacuque', 'Hc', 3),
    (36, 'Sofonias', 'Sf', 3),
    (37, 'Ageu', 'Ag', 2),
    (38, 'Zacarias', 'Zc', 14),
    (39, 'Malaquias', 'Ml', 4),
    (40, 'Mateus', 'Mt', 28),
    (41, 'Marcos', 'Mc', 16),
    (42, 'Lucas', 'Lc', 24),
    (43, 'João', 'Jo', 21),
    (44, 'Atos', 'At', 28),
    (45, 'Romanos', 'Rm', 16),
    (46, '1 Coríntios', '1Co', 16),
    (47, '2 Coríntios', '2Co', 13),
    (48, 'Gálatas', 'Gl', 6),
    (49, 'Efésios', 'Ef', 6),
    (50, 'Filipenses', 'Fp', 4),
    (51, 'Colossenses', 'Cl', 4),
    (52, '1 Tessalonicenses', '1Ts', 5),
    (53, '2 Tessalonicenses', '2Ts', 3),
    (54, '1 Timóteo', '1Tm', 6),
    (55, '2 Timóteo', '2Tm', 4),
    (56, 'Tito', 'Tt', 3),
    (57, 'Filemom', 'Fm', 1),
    (58, 'Hebreus', 'Hb', 13),
    (59, 'Tiago', 'Tg', 5),
    (60, '1 Pedro', '1Pe', 5),
    (61, '2 Pedro', '2Pe', 3),
    (62, '1 João', '1Jo', 5),
    (63, '2 João', '2Jo', 1),
    (64, '3 João', '3Jo', 1),
    (65, 'Judas', 'Jd', 1),
    (66, 'Apocalipse', 'Ap', 22),
  ];

  /// Lista ordenada de todos os 1.189 capítulos da Bíblia
  static List<ReadingPlanChapterRef> get allBibleChapters {
    final list = <ReadingPlanChapterRef>[];
    for (final b in _allBooks) {
      for (int c = 1; c <= b.$4; c++) {
        list.add(ReadingPlanChapterRef(
          bookId: b.$1,
          bookName: b.$2,
          abbrev: b.$3,
          chapter: c,
        ));
      }
    }
    return list;
  }

  /// Retorna os 6 planos pré-carregados de fábrica
  static List<ReadingPlan> getPlans() {
    return [
      _createRpspPlan(),
      _createAnoBiblicoPlan(),
      _createProverbiosPlan(),
      _createVidaJesusPlan(),
      _createConflitoEsperancaPlan(),
      _createPazAnsiedadePlan(),
    ];
  }

  // 1. RPSP (1.189 dias, 1 capítulo/dia)
  static ReadingPlan _createRpspPlan() {
    final all = allBibleChapters;
    final days = <ReadingPlanDay>[];
    for (int i = 0; i < all.length; i++) {
      final ch = all[i];
      days.add(ReadingPlanDay(
        dayIndex: i + 1,
        title: 'Dia ${i + 1}',
        chapters: [ch],
      ));
    }

    return ReadingPlan(
      id: 'rpsp',
      title: 'Reavivados por Sua Palavra',
      subtitle: '1 capítulo por dia • Bíblia de Gênesis a Apocalipse',
      description:
          'O plano oficial da Igreja Adventista a nível mundial: um banquete diário de comunhão lendo um capítulo por dia.',
      icon: Icons.menu_book_rounded,
      accentColor: const Color(0xFF2E7D32),
      category: 'Bíblia Completa',
      daysCount: days.length,
      days: days,
    );
  }

  // 2. Ano Bíblico Clássico (365 dias, ~3 a 4 capítulos/dia)
  static ReadingPlan _createAnoBiblicoPlan() {
    final all = allBibleChapters;
    final days = <ReadingPlanDay>[];

    // 1189 capítulos divididos em 365 dias
    int chIdx = 0;
    for (int d = 1; d <= 365; d++) {
      // 94 dias recebem 4 capítulos (365 * 3 + 94 = 1189)
      final count = d <= 94 ? 4 : 3;
      final dayChapters = <ReadingPlanChapterRef>[];
      for (int k = 0; k < count && chIdx < all.length; k++) {
        dayChapters.add(all[chIdx++]);
      }
      days.add(ReadingPlanDay(
        dayIndex: d,
        title: 'Dia $d',
        chapters: dayChapters,
      ));
    }

    return ReadingPlan(
      id: 'ano_biblico',
      title: 'Ano Bíblico Clássico',
      subtitle: 'Toda a Bíblia em 365 dias (~3 a 4 capítulos/dia)',
      description:
          'O plano tradicional de leitura para percorrer todo o Antigo e Novo Testamento no decorrer de um ano.',
      icon: Icons.calendar_month_rounded,
      accentColor: const Color(0xFF1565C0),
      category: 'Bíblia Completa',
      daysCount: days.length,
      days: days,
    );
  }

  // 3. Sabedoria Diária (31 dias, Provérbios)
  static ReadingPlan _createProverbiosPlan() {
    final days = <ReadingPlanDay>[];
    for (int i = 1; i <= 31; i++) {
      days.add(ReadingPlanDay(
        dayIndex: i,
        title: 'Dia $i',
        chapters: [
          ReadingPlanChapterRef(
            bookId: 20,
            bookName: 'Provérbios',
            abbrev: 'Pv',
            chapter: i,
          ),
        ],
      ));
    }

    return ReadingPlan(
      id: 'proverbios_31',
      title: 'Sabedoria Diária',
      subtitle: '1 capítulo de Provérbios por dia (31 dias)',
      description:
          'Instrução prática, prudência e sabedoria divina para as decisões de cada dia do mês.',
      icon: Icons.wb_sunny_rounded,
      accentColor: const Color(0xFFE65100),
      category: 'Sabedoria',
      daysCount: 31,
      days: days,
    );
  }

  // 4. Vida de Jesus nos Evangelhos (40 dias)
  static ReadingPlan _createVidaJesusPlan() {
    // Mt (28), Mc (16), Lc (24), Jo (21) = 89 capítulos
    final gospels = allBibleChapters.where((c) => c.bookId >= 40 && c.bookId <= 43).toList();
    final days = <ReadingPlanDay>[];

    int chIdx = 0;
    for (int d = 1; d <= 40; d++) {
      // 89 capítulos em 40 dias: 9 dias com 3 capítulos, 31 dias com 2 capítulos (9*3 + 31*2 = 89)
      final count = d <= 9 ? 3 : 2;
      final dayChapters = <ReadingPlanChapterRef>[];
      for (int k = 0; k < count && chIdx < gospels.length; k++) {
        dayChapters.add(gospels[chIdx++]);
      }
      days.add(ReadingPlanDay(
        dayIndex: d,
        title: 'Dia $d',
        chapters: dayChapters,
      ));
    }

    return ReadingPlan(
      id: 'vida_jesus_40',
      title: 'Vida de Jesus nos Evangelhos',
      subtitle: 'Mateus, Marcos, Lucas e João em 40 dias',
      description:
          'Caminhe lado a lado com o Salvador através das narrativas dos quatro evangelistas.',
      icon: Icons.favorite_rounded,
      accentColor: const Color(0xFFC2185B),
      category: 'Evangelhos',
      daysCount: 40,
      days: days,
    );
  }

  // 5. Conflito & Esperança (Daniel e Apocalipse - 30 dias)
  static ReadingPlan _createConflitoEsperancaPlan() {
    // Dn (12) + Ap (22) = 34 capítulos
    final profecias = allBibleChapters
        .where((c) => c.bookId == 27 || c.bookId == 66)
        .toList();
    final days = <ReadingPlanDay>[];

    int chIdx = 0;
    for (int d = 1; d <= 30; d++) {
      // 34 capítulos em 30 dias: 4 dias com 2 capítulos, 26 com 1 capítulo
      final count = d <= 4 ? 2 : 1;
      final dayChapters = <ReadingPlanChapterRef>[];
      for (int k = 0; k < count && chIdx < profecias.length; k++) {
        dayChapters.add(profecias[chIdx++]);
      }
      days.add(ReadingPlanDay(
        dayIndex: d,
        title: 'Dia $d',
        chapters: dayChapters,
      ));
    }

    return ReadingPlan(
      id: 'conflito_esperanca',
      title: 'Conflito & Esperança',
      subtitle: 'Profecias de Daniel e Apocalipse em 30 dias',
      description:
          'Compreenda o panorama do grande conflito cósmico e as revelações proféticas para o tempo do fim.',
      icon: Icons.shield_rounded,
      accentColor: const Color(0xFF6A1B9A),
      category: 'Profecias',
      daysCount: 30,
      days: days,
    );
  }

  // 6. Paz na Ansiedade & Promessas (14 dias, Salmos Selecionados)
  static ReadingPlan _createPazAnsiedadePlan() {
    const selectedPsalms = [
      (23, 'O Bom Pastor e o refrigério'),
      (27, 'O Senhor é a minha luz e salvação'),
      (34, 'O livramento dos que buscam a Deus'),
      (37, 'Descansa no Senhor e espera nele'),
      (46, 'Refúgio e fortaleza nas tribulações'),
      (91, 'O esconderijo do Altíssimo'),
      (103, 'Bendize, ó minha alma, e não te esqueças dos benefícios'),
      (121, 'O guarda de Israel não dormita'),
      (125, 'Inabaláveis como o monte Sião'),
      (130, 'Das profundezas clamo a ti, com redenção plena'),
      (139, 'Sondas-me e conheces-me por inteiro'),
      (145, 'Grande é o Senhor e mui digno de ser louvado'),
      (146, 'Louvor ao Deus que liberta e cuida'),
      (150, 'Tudo quanto tem fôlego louve ao Senhor!'),
    ];

    final days = <ReadingPlanDay>[];
    for (int i = 0; i < selectedPsalms.length; i++) {
      final p = selectedPsalms[i];
      days.add(ReadingPlanDay(
        dayIndex: i + 1,
        title: p.$2,
        chapters: [
          ReadingPlanChapterRef(
            bookId: 19,
            bookName: 'Salmos',
            abbrev: 'Sl',
            chapter: p.$1,
          ),
        ],
      ));
    }

    return ReadingPlan(
      id: 'paz_ansiedade_14',
      title: 'Paz na Ansiedade & Promessas',
      subtitle: '14 dias com Salmos reconfortantes de fé e refúgio',
      description:
          'Cure a ansiedade com doses diárias de louvor, segurança e confiança na providência divina.',
      icon: Icons.spa_rounded,
      accentColor: const Color(0xFF00838F),
      category: 'Temáticos',
      daysCount: 14,
      days: days,
    );
  }
}
