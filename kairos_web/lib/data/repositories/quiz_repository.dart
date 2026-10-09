import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';
import '../../models/quiz_question.dart';

class QuizRepository {
  /// Retorna lista de quizzes da Escola Sabatina sincronizados com o Supabase (projeto Auth/Quizzes)
  /// Caso o Supabase retorne perguntas sem `correct_option` (via view pública de segurança),
  /// o cliente cruza ou utiliza os quizzes da lição com feedback estruturado garantido.
  Future<List<QuizQuestion>> getQuestions({String category = 'adultos'}) async {
    final supabaseUrl = AppConfig.authSupabaseUrl;
    final supabaseKey = AppConfig.authSupabaseAnonKey;

    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      try {
        final catFilter = (category == 'todos' || category == 'geral')
            ? 'category=in.(adultos,jovem,jovens)'
            : (category == 'jovens' ? 'category=in.(jovem,jovens)' : 'category=eq.adultos');

        final endpoint = Uri.parse(
          '$supabaseUrl/rest/v1/v_ss_questions_public?$catFilter&order=created_at.desc&limit=25',
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
            final questions = data.map((item) {
              final map = item as Map<String, dynamic>;
              // Mapeia pergunta do Supabase
              return QuizQuestion.fromMap(map);
            }).toList();

            debugPrint('✓ Carregadas ${questions.length} perguntas do Supabase (v_ss_questions_public)');
            return questions;
          }
        }
      } catch (e) {
        debugPrint('Aviso ao carregar quizzes do Supabase: $e');
      }
    }

    // Fallback de perguntas bíblicas com gabarito completo offline
    return _bibleQuizCatalog
        .where((q) => category == 'todos' || q.category == category)
        .toList();
  }

  Future<List<String>> getCategories() async {
    return ['adultos', 'jovens', 'geral', 'todos'];
  }

  static const List<QuizQuestion> _bibleQuizCatalog = [
    QuizQuestion(
      id: 'q_gen_1',
      dayId: 'd1',
      quarterlyId: '2026-q1',
      category: 'adultos',
      question: 'No princípio, o que Deus criou conforme o relato de Gênesis 1:1?',
      options: [
        'Os céus e a terra',
        'Apenas o sol e a lua',
        'Os animais e as plantas',
        'O homem e o jardim',
      ],
      correctOption: 0,
      explanation: 'Gênesis 1:1 declara categoricamente: "No princípio, criou Deus os céus e a terra."',
      verseRef: 'Gênesis 1:1',
    ),
    QuizQuestion(
      id: 'q_gen_2',
      dayId: 'd2',
      quarterlyId: '2026-q1',
      category: 'adultos',
      question: 'Qual dia da criação foi abençoado e santificado por Deus como descanso?',
      options: [
        'Primeiro dia',
        'Sétimo dia (Sábado)',
        'Sexto dia',
        'Quarto dia',
      ],
      correctOption: 1,
      explanation: 'Em Gênesis 2:3 está escrito que Deus abençoou o sétimo dia e o santificou, porque nele descansou de toda a Sua obra.',
      verseRef: 'Gênesis 2:2-3',
    ),
    QuizQuestion(
      id: 'q_nt_1',
      dayId: 'd3',
      quarterlyId: '2026-q1',
      category: 'jovens',
      question: 'Qual é o texto bíblico conhecido como o "Evangelho em resumo"?',
      options: [
        'Romanos 3:23',
        'Salmos 23:1',
        'João 3:16',
        'Filipenses 4:13',
      ],
      correctOption: 2,
      explanation: 'João 3:16 resume o plano da redenção: "Porque Deus amou ao mundo de tal maneira que deu o seu Filho unigênito..."',
      verseRef: 'João 3:16',
    ),
    QuizQuestion(
      id: 'q_fe_1',
      dayId: 'd4',
      quarterlyId: '2026-q1',
      category: 'jovens',
      question: 'Segundo Hebreus 11:1, qual é a definição bíblica de Fé?',
      options: [
        'Um sentimento de esperança passageiro',
        'A certeza de coisas que se esperam e a convicção de fatos que se não veem',
        'A certeza baseada em provas científicas humanas',
        'A ausência de qualquer dúvida e provação',
      ],
      correctOption: 1,
      explanation: 'Hebreus 11:1 afirma: "Ora, a fé é a certeza de coisas que se esperam, a convicção de fatos que se não veem."',
      verseRef: 'Hebreus 11:1',
    ),
    QuizQuestion(
      id: 'q_salmo_1',
      dayId: 'd5',
      quarterlyId: '2026-q1',
      category: 'geral',
      question: 'Quem é declarado como pastor no clássico Salmo 23?',
      options: [
        'Moisés',
        'O Senhor Deus',
        'Davi',
        'Elias',
      ],
      correctOption: 1,
      explanation: 'O Salmo 23:1 afirma com confiança: "O Senhor é o meu pastor; nada me faltará."',
      verseRef: 'Salmos 23:1',
    ),
    QuizQuestion(
      id: 'q_mand_1',
      dayId: 'd6',
      quarterlyId: '2026-q1',
      category: 'adultos',
      question: 'Onde foram entregues a Moisés as tábuas da Lei com os Dez Mandamentos?',
      options: [
        'No Monte Sinai (Horebe)',
        'No Monte Carmelo',
        'No Monte das比较',
        'No Monte Nebo',
      ],
      correctOption: 0,
      explanation: 'Deus proclamou a lei e entregou as tábuas no Monte Sinai conforme Êxodo 19 e 20.',
      verseRef: 'Êxodo 20:1-17',
    ),
    QuizQuestion(
      id: 'q_prof_1',
      dayId: 'd7',
      quarterlyId: '2026-q1',
      category: 'geral',
      question: 'Qual profeta foi engolido por um grande peixe após fugir para Társis?',
      options: [
        'Daniel',
        'Jonas',
        'Jeremias',
        'Isaías',
      ],
      correctOption: 1,
      explanation: 'O livro de Jonas relata a tentativa do profeta de fugir da presença de Deus até ser engolido pelo grande peixe.',
      verseRef: 'Jonas 1:17',
    ),
  ];
}
