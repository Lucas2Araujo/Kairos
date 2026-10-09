import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:sqlite3/common.dart';
import '../../core/constants/app_constants.dart';
import '../../core/database/database_manager.dart';
import '../../models/sabbath_school_models.dart';

/// Serviço offline-first da Escola Sabatina para Web.
/// Fornece trimestres, lições da semana e estudos diários consultando a API Adventech
/// com timeout e fallback local para o banco SQLite (ss_quarterlies, ss_lessons, ss_days)
/// via [DatabaseManager].
class SabbathSchoolService {
  final DatabaseManager _dbManager;
  final Duration timeout;
  final Map<String, String> _notes = {};

  static const String adventechBaseUrl = 'https://sabbath-school.adventech.io/api/v2';

  SabbathSchoolService({
    DatabaseManager? dbManager,
    this.timeout = const Duration(seconds: 4),
  }) : _dbManager = dbManager ?? DatabaseManager();

  Future<CommonDatabase> _getDb() async {
    return await _dbManager.getDatabase(AppConstants.dbHymns);
  }

  // ---------------------------------------------------------------------------
  // Utilitário de Requisição HTTP (compatível com Flutter Web via package:http)
  // ---------------------------------------------------------------------------

  Future<dynamic> _fetchJson(String url) async {
    final uri = Uri.parse(url);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(utf8.decode(response.bodyBytes));
      }
      return null;
    } catch (e) {
      debugPrint('[SabbathSchoolService] Falha na requisição online ($url): $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Trimestres (Quarterlies)
  // ---------------------------------------------------------------------------

  /// Retorna os trimestres disponíveis para a categoria ('adultos' ou 'jovens').
  /// Tenta buscar online via Adventech API com timeout, persistindo no SQLite.
  /// Em caso de timeout/erro de rede ou indisponibilidade, recorre a `ss_quarterlies`.
  Future<List<SSQuarterly>> getQuarterlies({String category = 'adultos'}) async {
    try {
      final onlineData = await _fetchJson('$adventechBaseUrl/pt/quarterlies/index.json');
      if (onlineData is List && onlineData.isNotEmpty) {
        final List<SSQuarterly> fetchedList = [];
        final db = await _getDb();

        for (final item in onlineData) {
          if (item is Map<String, dynamic>) {
            final q = SSQuarterly.fromJson(item);
            if (q.title.toLowerCase().contains('portugal') || q.id.toLowerCase().contains('-pt')) {
              continue;
            }

            try {
              db.execute(
                '''
                INSERT INTO ss_quarterlies (id, title, description, human_date, start_date, end_date, cover, category)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                  title = excluded.title,
                  description = excluded.description,
                  human_date = excluded.human_date,
                  start_date = excluded.start_date,
                  end_date = excluded.end_date,
                  cover = excluded.cover,
                  category = excluded.category;
                ''',
                [q.id, q.title, q.description, q.humanDate, q.startDate, q.endDate, q.cover, q.category],
              );
            } catch (dbErr) {
              debugPrint('[SabbathSchoolService] Erro ao sincronizar trimestre no banco: $dbErr');
            }

            if (q.category == category) {
              fetchedList.add(q);
            }
          }
        }

        if (fetchedList.isNotEmpty) {
          return fetchedList;
        }
      }
    } catch (e) {
      debugPrint('[SabbathSchoolService] Fallback para banco local em getQuarterlies: $e');
    }

    return await _getQuarterliesFromDb(category);
  }

  Future<List<SSQuarterly>> _getQuarterliesFromDb(String category) async {
    try {
      final db = await _getDb();
      final ResultSet results = db.select(
        '''
        SELECT id, title, description, human_date, start_date, end_date, cover, category
        FROM ss_quarterlies
        WHERE category = ?
        ORDER BY id DESC;
        ''',
        [category],
      );

      return results.map((row) {
        return SSQuarterly(
          id: (row['id'] ?? '').toString(),
          title: (row['title'] ?? '').toString(),
          description: (row['description'] ?? '').toString(),
          humanDate: (row['human_date'] ?? '').toString(),
          startDate: (row['start_date'] ?? '').toString(),
          endDate: (row['end_date'] ?? '').toString(),
          cover: (row['cover'] ?? '').toString(),
          category: (row['category'] ?? category).toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SabbathSchoolService] Erro ao consultar ss_quarterlies local: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Lições (Lessons)
  // ---------------------------------------------------------------------------

  /// Retorna a lista de lições do trimestre.
  /// Tenta online com timeout; fallback para `ss_lessons`.
  Future<List<SSLesson>> getLessons(String quarterlyId) async {
    try {
      final onlineData = await _fetchJson('$adventechBaseUrl/pt/quarterlies/$quarterlyId/index.json');
      if (onlineData is Map<String, dynamic> && onlineData.containsKey('lessons')) {
        final lessonsRaw = onlineData['lessons'];
        if (lessonsRaw is List && lessonsRaw.isNotEmpty) {
          final List<SSLesson> fetchedLessons = [];
          final db = await _getDb();

          for (final item in lessonsRaw) {
            if (item is Map<String, dynamic>) {
              final lesson = SSLesson.fromJson(item, quarterlyId: quarterlyId);
              try {
                db.execute(
                  '''
                  INSERT INTO ss_lessons (id, quarterly_id, lesson_index, title, start_date, end_date, cover, path)
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                  ON CONFLICT(id) DO UPDATE SET
                    quarterly_id = excluded.quarterly_id,
                    lesson_index = excluded.lesson_index,
                    title = excluded.title,
                    start_date = excluded.start_date,
                    end_date = excluded.end_date,
                    cover = excluded.cover,
                    path = excluded.path;
                  ''',
                  [
                    lesson.id,
                    lesson.quarterlyId,
                    lesson.index,
                    lesson.title,
                    lesson.startDate,
                    lesson.endDate,
                    lesson.cover,
                    lesson.path,
                  ],
                );
              } catch (dbErr) {
                debugPrint('[SabbathSchoolService] Erro ao sincronizar lição no banco: $dbErr');
              }
              fetchedLessons.add(lesson);
            }
          }

          if (fetchedLessons.isNotEmpty) {
            _sortLessons(fetchedLessons);
            return fetchedLessons;
          }
        }
      }
    } catch (e) {
      debugPrint('[SabbathSchoolService] Fallback para banco local em getLessons: $e');
    }

    return await _getLessonsFromDb(quarterlyId);
  }

  Future<List<SSLesson>> _getLessonsFromDb(String quarterlyId) async {
    try {
      final db = await _getDb();
      final ResultSet results = db.select(
        '''
        SELECT id, quarterly_id, lesson_index, title, start_date, end_date, cover, path
        FROM ss_lessons
        WHERE quarterly_id = ?
        ORDER BY 
          CASE WHEN CAST(lesson_index AS INTEGER) > 0 THEN CAST(lesson_index AS INTEGER)
               WHEN CAST(id AS INTEGER) > 0 THEN CAST(id AS INTEGER)
               ELSE 9999 END ASC,
          id ASC;
        ''',
        [quarterlyId],
      );

      final lessons = results.map((row) {
        return SSLesson(
          id: (row['id'] ?? '').toString(),
          quarterlyId: (row['quarterly_id'] ?? quarterlyId).toString(),
          index: (row['lesson_index'] ?? '').toString(),
          title: (row['title'] ?? '').toString(),
          startDate: (row['start_date'] ?? '').toString(),
          endDate: (row['end_date'] ?? '').toString(),
          cover: (row['cover'] ?? '').toString(),
          path: (row['path'] ?? '').toString(),
        );
      }).toList();

      _sortLessons(lessons);
      return lessons;
    } catch (e) {
      debugPrint('[SabbathSchoolService] Erro ao consultar ss_lessons local: $e');
      return [];
    }
  }

  void _sortLessons(List<SSLesson> lessons) {
    lessons.sort((a, b) {
      final intA = int.tryParse(a.index) ?? int.tryParse(a.id) ?? 999;
      final intB = int.tryParse(b.index) ?? int.tryParse(b.id) ?? 999;
      return intA.compareTo(intB);
    });
  }

  // ---------------------------------------------------------------------------
  // Dias de Estudo (Lesson Days)
  // ---------------------------------------------------------------------------

  /// Retorna os dias de estudo de uma lição.
  /// Tenta online com timeout; fallback para `ss_days`.
  Future<List<SSDay>> getLessonDays(String lessonId, {String quarterlyId = ''}) async {
    String qId = quarterlyId;
    if (qId.isEmpty) {
      try {
        final db = await _getDb();
        final ResultSet rows = db.select('SELECT quarterly_id FROM ss_lessons WHERE id = ? LIMIT 1', [lessonId]);
        if (rows.isNotEmpty) {
          qId = (rows.first['quarterly_id'] ?? '').toString();
        }
      } catch (_) {}
    }

    if (qId.isNotEmpty) {
      try {
        final onlineData = await _fetchJson(
          '$adventechBaseUrl/pt/quarterlies/$qId/lessons/$lessonId/index.json',
        );
        if (onlineData is Map<String, dynamic> && onlineData.containsKey('days')) {
          final daysRaw = onlineData['days'];
          if (daysRaw is List && daysRaw.isNotEmpty) {
            final List<SSDay> fetchedDays = [];
            final db = await _getDb();

            for (final item in daysRaw) {
              if (item is Map<String, dynamic>) {
                final day = SSDay.fromJson(item, lessonId: lessonId);
                try {
                  db.execute(
                    '''
                    INSERT INTO ss_days (id, lesson_id, day_index, title, date, content, read_path)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(id) DO UPDATE SET
                      lesson_id = excluded.lesson_id,
                      day_index = excluded.day_index,
                      title = excluded.title,
                      date = excluded.date,
                      content = CASE WHEN excluded.content != '' THEN excluded.content ELSE ss_days.content END,
                      read_path = excluded.read_path;
                    ''',
                    [day.id, day.lessonId, day.index, day.title, day.date, day.content, day.readPath],
                  );
                } catch (dbErr) {
                  debugPrint('[SabbathSchoolService] Erro ao sincronizar dia no banco: $dbErr');
                }
                fetchedDays.add(day);
              }
            }

            if (fetchedDays.isNotEmpty) {
              return fetchedDays;
            }
          }
        }
      } catch (e) {
        debugPrint('[SabbathSchoolService] Fallback para banco local em getLessonDays: $e');
      }
    }

    return await _getLessonDaysFromDb(lessonId);
  }

  Future<List<SSDay>> _getLessonDaysFromDb(String lessonId) async {
    try {
      final db = await _getDb();
      final ResultSet results = db.select(
        '''
        SELECT id, lesson_id, day_index, title, date, content, read_path
        FROM ss_days
        WHERE lesson_id = ?
        ORDER BY 
          CASE WHEN CAST(day_index AS INTEGER) > 0 THEN CAST(day_index AS INTEGER)
               WHEN CAST(id AS INTEGER) > 0 THEN CAST(id AS INTEGER)
               ELSE 9999 END ASC,
          id ASC;
        ''',
        [lessonId],
      );

      return results.map((row) {
        return SSDay(
          id: (row['id'] ?? '').toString(),
          lessonId: (row['lesson_id'] ?? lessonId).toString(),
          index: (row['day_index'] ?? '').toString(),
          title: (row['title'] ?? '').toString(),
          date: (row['date'] ?? '').toString(),
          content: (row['content'] ?? '').toString(),
          readPath: (row['read_path'] ?? '').toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[SabbathSchoolService] Erro ao consultar ss_days local: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Conteúdo do Dia
  // ---------------------------------------------------------------------------

  /// Converte HTML simples da Adventech para Markdown limpo
  static String formatHtmlToMarkdown(String content) {
    if (content.isEmpty) return '';

    String text = content;

    // Blockquotes
    text = text.replaceAllMapped(
      RegExp(r'<blockquote>\s*(.*?)\s*</blockquote>', caseSensitive: false, dotAll: true),
      (m) => '\n\n> ${m[1]!.replaceAll('\n', ' ')}\n\n',
    );

    // Headings (h1 a h6)
    for (int h = 6; h >= 1; h--) {
      final hashes = '#' * h;
      text = text.replaceAllMapped(
        RegExp('<h$h\\b[^>]*>(.*?)</h$h>', caseSensitive: false, dotAll: true),
        (m) => '\n\n$hashes ${m[1]}\n\n',
      );
    }

    // Negrito e Itálico
    text = text.replaceAllMapped(
      RegExp(r'<(?:strong|b)\b[^>]*>(.*?)</(?:strong|b)>', caseSensitive: false, dotAll: true),
      (m) => '**${m[1]}**',
    );
    text = text.replaceAllMapped(
      RegExp(r'<(?:em|i)\b[^>]*>(.*?)</(?:em|i)>', caseSensitive: false, dotAll: true),
      (m) => '*${m[1]}*',
    );

    // Links de versículo ou genéricos: extrai texto limpo
    text = text.replaceAllMapped(
      RegExp(r'<a\b[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true),
      (m) => m[1] ?? '',
    );

    // Listas
    text = text.replaceAllMapped(
      RegExp(r'<li\b[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (m) => '\n- ${m[1]}',
    );
    text = text.replaceAll(RegExp(r'</?(?:ul|ol)\b[^>]*>', caseSensitive: false), '\n\n');

    // Parágrafos e quebras de linha
    text = text.replaceAllMapped(
      RegExp(r'<p\b[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (m) => '\n\n${m[1]}\n\n',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Remove tags residuais
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decodifica entidades HTML comuns
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–');

    // Normaliza quebras de linha excessivas
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

    return text;
  }

  /// Retorna ou atualiza o conteúdo do dia
  Future<SSDay?> getDayContent(String dayId, {String lessonId = '', String readPath = ''}) async {
    // 1. Verifica banco local primeiro
    try {
      final db = await _getDb();
      final ResultSet results = db.select(
        '''
        SELECT id, lesson_id, day_index, title, date, content, read_path
        FROM ss_days
        WHERE id = ? ${lessonId.isNotEmpty ? "AND lesson_id = '$lessonId'" : ''}
        LIMIT 1;
        ''',
        [dayId],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        final rawContent = (row['content'] ?? '').toString();
        final path = (row['read_path'] ?? readPath).toString();

        if (rawContent.isNotEmpty) {
          final formatted = rawContent.contains('<') ? formatHtmlToMarkdown(rawContent) : rawContent;
          return SSDay(
            id: (row['id'] ?? '').toString(),
            lessonId: (row['lesson_id'] ?? lessonId).toString(),
            index: (row['day_index'] ?? '').toString(),
            title: (row['title'] ?? '').toString(),
            date: (row['date'] ?? '').toString(),
            content: formatted,
            readPath: path,
          );
        }
      }
    } catch (e) {
      debugPrint('[SabbathSchoolService] Erro ao buscar conteúdo no banco: $e');
    }

    // 2. Se vazio e tiver readPath, tenta buscar online
    if (readPath.isNotEmpty) {
      try {
        final cleanPath = readPath.replaceAll(RegExp(r'^/|/$'), '');
        final url = cleanPath.endsWith('.json')
            ? '$adventechBaseUrl/$cleanPath'
            : '$adventechBaseUrl/$cleanPath/index.json';

        final onlineData = await _fetchJson(url);
        if (onlineData is Map<String, dynamic> && onlineData.containsKey('content')) {
          final fetchedContent = (onlineData['content'] ?? '').toString();
          final formattedContent = formatHtmlToMarkdown(fetchedContent);
          final title = (onlineData['title'] ?? '').toString();
          final date = (onlineData['date'] ?? '').toString();

          try {
            final db = await _getDb();
            db.execute(
              '''
              UPDATE ss_days
              SET content = ?, title = CASE WHEN ? != '' THEN ? ELSE title END,
                  date = CASE WHEN ? != '' THEN ? ELSE date END
              WHERE id = ? ${lessonId.isNotEmpty ? "AND lesson_id = '$lessonId'" : ''};
              ''',
              [formattedContent, title, title, date, date, dayId],
            );
          } catch (dbErr) {
            debugPrint('[SabbathSchoolService] Erro ao atualizar ss_days: $dbErr');
          }

          return SSDay(
            id: dayId,
            lessonId: lessonId,
            index: (onlineData['index'] ?? '').toString(),
            title: title,
            date: date,
            content: formattedContent,
            readPath: readPath,
          );
        }
      } catch (e) {
        debugPrint('[SabbathSchoolService] Erro ao buscar conteúdo online: $e');
      }
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // Anotações Pessoais (User Notes)
  // ---------------------------------------------------------------------------

  /// Retorna anotação do dia salva localmente
  Future<String> getNote(String dayId) async {
    if (_notes.containsKey(dayId)) {
      return _notes[dayId]!;
    }

    try {
      final db = await _getDb();
      final ResultSet results = db.select(
        'SELECT note_text FROM ss_user_notes WHERE day_id = ? LIMIT 1;',
        [dayId],
      );
      if (results.isNotEmpty) {
        final text = (results.first['note_text'] ?? '').toString();
        _notes[dayId] = text;
        return text;
      }
    } catch (e) {
      debugPrint('[SabbathSchoolService] Erro ao ler anotação: $e');
    }

    return '';
  }

  /// Salva anotação do dia localmente
  Future<void> saveNote(String dayId, String noteText) async {
    _notes[dayId] = noteText;
    try {
      final db = await _getDb();
      db.execute(
        '''
        INSERT INTO ss_user_notes (day_id, note_text, updated_at)
        VALUES (?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(day_id) DO UPDATE SET
          note_text = excluded.note_text,
          updated_at = CURRENT_TIMESTAMP;
        ''',
        [dayId, noteText],
      );
    } catch (e) {
      debugPrint('[SabbathSchoolService] Erro ao persistir anotação: $e');
    }
  }
}
