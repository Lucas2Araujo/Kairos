import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import '../models/devotional.dart';

/// Serviço de Meditação Diária com suporte a Supabase REST e fallback rico offline
class DevotionalService {
  final Map<String, Devotional> _cache = {};

  /// Seed/Mock local caso Supabase não esteja configurado ou ocorra falha de rede
  final Map<String, Devotional> _defaultDevotionals = {
    'jovem': const Devotional(
      publishedAt: '2026-10-02',
      title: 'Um Novo Começo com Propósito',
      verseReference: 'Jeremias 29:11',
      verseText: 'Porque eu bem sei os pensamentos que tenho a vosso respeito, diz o Senhor; pensamentos de paz e não de mal, para vos dar o fim que esperais.',
      content: '''
Cada novo dia é um convite divino para recalibrar o nosso coração e alinhar os nossos passos com a vontade do Criador. Frequentemente nos encontramos ansiosos em relação ao amanhã, sobrecarregados com decisões cruciais de estudo, carreira e relacionamentos.

Deus nos lembra que Sua soberania não é uma força distante, mas um cuidado íntimo e pessoal. Ele conhece os planos que traçou para nós. Quando colocamos nossos anseios no altar da oração matinal, a ansiedade perde o domínio e a paz de Cristo assume o controle da nossa mente.

Hoje, dedique alguns minutos para entregar seus maiores dilemas a Ele. Permita que a certeza do amor divino molde as suas escolhas diárias.
''',
      category: 'jovem',
      author: 'Meditações da Juventude',
    ),
    'diario': const Devotional(
      publishedAt: '2026-10-02',
      title: 'Refúgio e Fortaleza Eterna',
      verseReference: 'Salmos 46:1',
      verseText: 'Deus é o nosso refúgio e fortaleza, socorro bem presente nas tribulações.',
      content: '''
Em um mundo marcado pela constante instabilidade e correria, onde podemos encontrar segurança inabalável? Os seres humanos tentam edificar defesas em posses materiais, status ou garantias humanas passageiras. Contudo, nenhuma fortaleza terrena é invulnerável às tempestades da vida.

O salmista nos direciona para a única rocha inabalável: o próprio Deus vivo. Ele não é apenas um refúgio para o qual corremos em desespero, mas uma presença ativa e sustentadora em meio ao calor da batalha.

Aquiete o seu coração. Saber que o Deus do universo é o seu socorro transforma a maneira como você encara os desafios desta jornada.
''',
      category: 'diario',
      author: 'Meditação Matinal Adultos',
    ),
    'mulher': const Devotional(
      publishedAt: '2026-10-02',
      title: 'A Graça que Transforma e Edifica',
      verseReference: 'Provérbios 31:30',
      verseText: 'Enganosa é a graça, e vã, a formosura, mas a mulher que teme ao Senhor, essa será louvada.',
      content: '''
A verdadeira beleza e nobreza da alma não residem nos padrões efêmeros ditados pela sociedade, mas na profundidade de um relacionamento diário com Deus. O temor do Senhor é a reverência que santifica as nossas palavras, gestos e atitudes no lar e no ambiente de trabalho.

A mulher que cultiva a presença de Cristo em sua vida irradia uma luz suave e acolhedora, confortando os aflitos e inspirando a sua família com sabedoria e ternura.

Que a sua oração de hoje seja por um espírito dócil e fortalecido no amor do Pai celeste.
''',
      category: 'mulher',
      author: 'Meditação da Mulher',
    ),
  };

  static const String defaultSupabaseUrl = 'https://opbzivfgfkljqknrdvkq.supabase.co';
  static const String defaultSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9wYnppdmZnZmtsanFrbnJkdmtxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwODQ3MDIsImV4cCI6MjEwNDY2MDcwMn0.ph5gU8NnTGRN-vubHg3VREzomAuZS5g_qk6ZeCSri6s';

  /// Carrega a meditação para a data (YYYY-MM-DD) e categoria ('jovem', 'diario', 'mulher')
  Future<Devotional> getDevotional(String dateStr, {String category = 'jovem'}) async {
    final cacheKey = '${category}_$dateStr';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final supabaseUrl = AppConfig.devotionalSupabaseUrl;
    final supabaseKey = AppConfig.devotionalSupabaseAnonKey;

    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      try {
        final endpoint = Uri.parse(
          '$supabaseUrl/rest/v1/daily_devotionals?published_at=eq.$dateStr&category=eq.$category&select=*&limit=1',
        );
        final response = await http.get(
          endpoint,
          headers: {
            'apikey': supabaseKey,
            'Authorization': 'Bearer $supabaseKey',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          if (data is List && data.isNotEmpty) {
            final item = data.first as Map<String, dynamic>;
            final devotional = Devotional(
              publishedAt: (item['published_at'] ?? dateStr).toString(),
              title: (item['title'] ?? '').toString(),
              verseText: (item['verse_text'] ?? '').toString(),
              verseReference: (item['verse_reference'] ?? '').toString(),
              content: (item['content'] ?? '').toString(),
              category: (item['category'] ?? category).toString(),
              author: (item['author'] ?? '').toString(),
              sourceUrl: (item['source_url'] ?? '').toString(),
              cachedAt: DateTime.now().toIso8601String(),
            );
            _cache[cacheKey] = devotional;
            return devotional;
          }
        }
      } catch (e) {
        debugPrint('[DevotionalService] Erro ao consultar Supabase ($dateStr, $category): $e');
      }
    }

    // Retorna fallback robusto pré-configurado
    final fallback = _defaultDevotionals[category] ?? _defaultDevotionals['jovem']!;
    final result = Devotional(
      publishedAt: dateStr,
      title: fallback.title,
      verseText: fallback.verseText,
      verseReference: fallback.verseReference,
      content: fallback.content,
      category: category,
      author: fallback.author,
      sourceUrl: fallback.sourceUrl,
      cachedAt: DateTime.now().toIso8601String(),
    );

    _cache[cacheKey] = result;
    return result;
  }
}
