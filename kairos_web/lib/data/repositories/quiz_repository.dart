import '../../models/quiz_question.dart';

class QuizRepository {
  /// Retorna lista de quizzes bíblicos categorizados
  Future<List<QuizQuestion>> getQuestions({String category = 'adultos'}) async {
    // Simulação assíncrona imediata com perguntas bíblicas essenciais
    return _bibleQuizCatalog
        .where((q) => category == 'todos' || q.category == category)
        .toList();
  }

  Future<List<String>> getCategories() async {
    return ['adultos', 'jovens', 'geral'];
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
        'No Monte das Oliveiras',
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
