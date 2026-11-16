import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';

class ComplementaryResource {
  final String type; // 'bible', 'egw', 'external'
  final String title;
  final String subtitle;
  final String reference;
  final String url;

  const ComplementaryResource({
    required this.type,
    required this.title,
    required this.subtitle,
    this.reference = '',
    this.url = '',
  });

  factory ComplementaryResource.fromMap(Map<String, dynamic> map) {
    return ComplementaryResource(
      type: (map['type'] ?? 'external').toString(),
      title: (map['title'] ?? '').toString(),
      subtitle: (map['subtitle'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      url: (map['url'] ?? '').toString(),
    );
  }
}

class ComplementaryTextData {
  final String lessonDayId;
  final String bibleReference;
  final String summary;
  final List<ComplementaryResource> resources;

  const ComplementaryTextData({
    required this.lessonDayId,
    required this.bibleReference,
    required this.summary,
    required this.resources,
  });

  factory ComplementaryTextData.fromMap(Map<String, dynamic> map) {
    final rawResources = map['resources'];
    final list = <ComplementaryResource>[];
    if (rawResources is List) {
      for (final item in rawResources) {
        if (item is Map<String, dynamic>) {
          list.add(ComplementaryResource.fromMap(item));
        } else if (item is Map) {
          list.add(ComplementaryResource.fromMap(Map<String, dynamic>.from(item)));
        }
      }
    }

    return ComplementaryTextData(
      lessonDayId: (map['lesson_day_id'] ?? '').toString(),
      bibleReference: (map['bible_reference'] ?? '').toString(),
      summary: (map['summary'] ?? '').toString(),
      resources: list,
    );
  }
}

/// Serviço para buscar os Textos Complementares semanais (Domingo) no Supabase.
class ComplementaryTextsService {
  static final ComplementaryTextsService _instance =
      ComplementaryTextsService._internal();
  factory ComplementaryTextsService() => _instance;
  ComplementaryTextsService._internal();

  final Map<String, ComplementaryTextData?> _cache = {};

  Future<ComplementaryTextData?> getForDay(String lessonDayId) async {
    if (_cache.containsKey(lessonDayId)) {
      return _cache[lessonDayId];
    }

    try {
      final baseUrl = AppConfig.authSupabaseUrl;
      final apiKey = AppConfig.authSupabaseAnonKey;
      if (baseUrl.isEmpty || apiKey.isEmpty) return null;

      final uri = Uri.parse(
        '$baseUrl/rest/v1/lesson_complementary_texts'
        '?lesson_day_id=eq.${Uri.encodeComponent(lessonDayId)}'
        '&select=*&limit=1',
      );
      final response = await http.get(
        uri,
        headers: {
          'apikey': apiKey,
          'Authorization': 'Bearer $apiKey',
        },
      );

      if (response.statusCode != 200) {
        _cache[lessonDayId] = null;
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List || decoded.isEmpty) {
        _cache[lessonDayId] = null;
        return null;
      }

      final data = ComplementaryTextData.fromMap(
        Map<String, dynamic>.from(decoded.first as Map),
      );
      _cache[lessonDayId] = data;
      return data;
    } catch (e) {
      debugPrint('Erro ao buscar textos complementares ($lessonDayId): $e');
      return null;
    }
  }
}
