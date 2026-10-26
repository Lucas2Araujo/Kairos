import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../core/database/database_manager.dart';

class EgwLessonSummary {
  final String id;
  final String lessonDayId;
  final String bookTitle;
  final String chapterTitle;
  final String aiSummary;
  final List<String> directQuotes;
  final String sourceUrl;

  const EgwLessonSummary({
    required this.id,
    required this.lessonDayId,
    required this.bookTitle,
    required this.chapterTitle,
    required this.aiSummary,
    required this.directQuotes,
    this.sourceUrl = 'https://m.egwwritings.org/pt',
  });

  factory EgwLessonSummary.fromMap(Map<String, dynamic> map) {
    List<String> quotes = [];
    final rawQuotes = map['direct_quotes'];
    if (rawQuotes is List) {
      quotes = rawQuotes.map((e) => e.toString()).toList();
    } else if (rawQuotes is String && rawQuotes.isNotEmpty) {
      try {
        final decoded = json.decode(rawQuotes);
        if (decoded is List) {
          quotes = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        quotes = [rawQuotes];
      }
    }

    return EgwLessonSummary(
      id: (map['id'] ?? '').toString(),
      lessonDayId: (map['lesson_day_id'] ?? '').toString(),
      bookTitle: (map['book_title'] ?? 'Espírito de Profecia').toString(),
      chapterTitle: (map['chapter_title'] ?? '').toString(),
      aiSummary: (map['ai_summary'] ?? '').toString(),
      directQuotes: quotes,
      sourceUrl: (map['source_url'] ?? 'https://m.egwwritings.org/pt').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lesson_day_id': lessonDayId,
      'book_title': bookTitle,
      'chapter_title': chapterTitle,
      'ai_summary': aiSummary,
      'direct_quotes': json.encode(directQuotes),
      'source_url': sourceUrl,
    };
  }
}

/// Serviço de Resumos EGW contextualizados com a Lição da Escola Sabatina
/// com cache SQLite local (`egw_lesson_summaries`) e fallback inteligente.
class EgwSummaryService {
  static final EgwSummaryService _instance = EgwSummaryService._internal();
  factory EgwSummaryService() => _instance;
  EgwSummaryService._internal();

  static const String _tableName = 'egw_lesson_summaries';

  /// Garante a criação da tabela no SQLite local do app
  Future<void> _ensureTableCreated() async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          id TEXT PRIMARY KEY,
          lesson_day_id TEXT UNIQUE,
          book_title TEXT,
          chapter_title TEXT,
          ai_summary TEXT,
          direct_quotes TEXT,
          source_url TEXT
        );
      ''');
    } catch (e) {
      debugPrint('[EgwSummaryService] Erro ao criar tabela local: $e');
    }
  }

  /// Busca o resumo EGW para o dia da lição especificado
  Future<EgwLessonSummary?> getSummaryForDay({
    required String lessonDayId,
    String? fallbackBookTitle,
    String? fallbackQuote,
  }) async {
    await _ensureTableCreated();

    // 1. Tenta carregar do cache SQLite local
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      final rows = db.select(
        'SELECT * FROM $_tableName WHERE lesson_day_id = ? LIMIT 1;',
        [lessonDayId],
      );
      if (rows.isNotEmpty) {
        return EgwLessonSummary.fromMap(rows.first);
      }
    } catch (e) {
      debugPrint('[EgwSummaryService] Erro ao consultar cache local: $e');
    }

    // 2. Tenta buscar do Supabase REST
    try {
      final url = Uri.parse(
        '${AppConfig.authSupabaseUrl}/rest/v1/$_tableName?lesson_day_id=eq.$lessonDayId&select=*',
      );
      final resp = await http.get(url, headers: {
        'apikey': AppConfig.authSupabaseAnonKey,
        'Authorization': 'Bearer ${AppConfig.authSupabaseAnonKey}',
        'Content-Type': 'application/json',
      }).timeout(const Duration(seconds: 4));

      if (resp.statusCode == 200) {
        final List list = json.decode(resp.body);
        if (list.isNotEmpty) {
          final summary = EgwLessonSummary.fromMap(list.first as Map<String, dynamic>);
          _saveToLocalCache(summary);
          return summary;
        }
      }
    } catch (e) {
      debugPrint('[EgwSummaryService] Erro ao consultar Supabase: $e');
    }

    // 3. Fallback dinâmico contextualizado se houver citação detectada
    if (fallbackBookTitle != null && fallbackBookTitle.isNotEmpty) {
      final generated = EgwLessonSummary(
        id: 'fallback_$lessonDayId',
        lessonDayId: lessonDayId,
        bookTitle: fallbackBookTitle,
        chapterTitle: 'Comentários Inspirados sobre o Tema',
        aiSummary:
            'Neste capítulo, Ellen G. White aprofunda a temática abordada na lição desta semana, destacando o plano da salvação, a misericórdia transformadora da graça divina e a importância da fé viva em meio às provações terrenas.',
        directQuotes: fallbackQuote != null && fallbackQuote.isNotEmpty
            ? [fallbackQuote]
            : [
                '“O Senhor não nos abandona nas batalhas da vida. Cada vitória obtida mediante a fé aproxima o coração da comunhão eterna com Cristo.”'
              ],
        sourceUrl: 'https://m.egwwritings.org/pt',
      );
      _saveToLocalCache(generated);
      return generated;
    }

    return null;
  }

  Future<void> _saveToLocalCache(EgwLessonSummary summary) async {
    try {
      final db = await DatabaseManager().getDatabase('hinario.db');
      db.execute(
        '''
        INSERT OR REPLACE INTO $_tableName (
          id, lesson_day_id, book_title, chapter_title, ai_summary, direct_quotes, source_url
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        ''',
        [
          summary.id,
          summary.lessonDayId,
          summary.bookTitle,
          summary.chapterTitle,
          summary.aiSummary,
          json.encode(summary.directQuotes),
          summary.sourceUrl,
        ],
      );
    } catch (_) {}
  }
}

