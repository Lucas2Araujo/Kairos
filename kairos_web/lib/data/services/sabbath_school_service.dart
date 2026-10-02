import '../../models/sabbath_school_models.dart';

/// Serviço offline-first da Escola Sabatina para Web.
/// Fornece trimestres, lições da semana e estudos diários com fallback rico e suporte a anotações locais.
class SabbathSchoolService {
  final Map<String, String> _notes = {};

  /// Mock/Seed realista da Lição da Escola Sabatina para adultos e jovens
  final List<SSQuarterly> _mockQuarterlies = [
    const SSQuarterly(
      id: 'pt-2024-04',
      title: 'Temas do Livro de Hebreus',
      description: 'Jesus, nosso Sumo Sacerdote e Mediador da Nova Aliança.',
      humanDate: '4º Trimestre 2024',
      startDate: '28/09/2024',
      endDate: '27/12/2024',
      category: 'adultos',
    ),
    const SSQuarterly(
      id: 'pt-2024-03',
      title: 'O Evangelho de Marcos',
      description: 'Estudo das boas novas de Jesus através do evangelho mais dinâmico do Novo Testamento.',
      humanDate: '3º Trimestre 2024',
      startDate: '29/06/2024',
      endDate: '27/09/2024',
      category: 'adultos',
    ),
    const SSQuarterly(
      id: 'pt-2024-02',
      title: 'O Grande Conflito',
      description: 'A batalha cósmica entre Cristo e Satanás através da história.',
      humanDate: '2º Trimestre 2024',
      startDate: '30/03/2024',
      endDate: '28/06/2024',
      category: 'adultos',
    ),
    const SSQuarterly(
      id: 'pt-cq-2024-04',
      title: 'Herança Viva (Cartas Paulinas)',
      description: 'Princípios práticos de vida e comunidade cristã para a juventude.',
      humanDate: '4º Trimestre 2024',
      startDate: '28/09/2024',
      endDate: '27/12/2024',
      category: 'jovens',
    ),
    const SSQuarterly(
      id: 'pt-cq-2024-03',
      title: 'A Jornada da Fé (Comunhão e Missão)',
      description: 'Lição Jovem dinâmica sobre discipulado, identidade cristã e evangelismo contemporâneo.',
      humanDate: '3º Trimestre 2024',
      startDate: '29/06/2024',
      endDate: '27/09/2024',
      category: 'jovens',
    ),
  ];

  final Map<String, List<SSLesson>> _mockLessons = {
    'pt-2024-03': [
      const SSLesson(
        id: 'pt-2024-03-01',
        quarterlyId: 'pt-2024-03',
        index: '1',
        title: 'O Começo do Evangelho',
        startDate: '29/06/2024',
        endDate: '05/07/2024',
      ),
      const SSLesson(
        id: 'pt-2024-03-02',
        quarterlyId: 'pt-2024-03',
        index: '2',
        title: 'Um Dia na Vida de Jesus',
        startDate: '06/07/2024',
        endDate: '12/07/2024',
      ),
      const SSLesson(
        id: 'pt-2024-03-03',
        quarterlyId: 'pt-2024-03',
        index: '3',
        title: 'Controvérsias e Parábolas',
        startDate: '13/07/2024',
        endDate: '19/07/2024',
      ),
    ],
    'pt-cq-2024-03': [
      const SSLesson(
        id: 'pt-cq-2024-03-01',
        quarterlyId: 'pt-cq-2024-03',
        index: '1',
        title: 'Identidade e Propósito em Cristo',
        startDate: '29/06/2024',
        endDate: '05/07/2024',
      ),
      const SSLesson(
        id: 'pt-cq-2024-03-02',
        quarterlyId: 'pt-cq-2024-03',
        index: '2',
        title: 'Conexão Real num Mundo Digital',
        startDate: '06/07/2024',
        endDate: '12/07/2024',
      ),
    ],
  };

  final Map<String, List<SSDay>> _mockDays = {
    'pt-2024-03-01': [
      const SSDay(
        id: 'pt-2024-03-01-01',
        lessonId: 'pt-2024-03-01',
        index: '1',
        title: 'Sábado à Tarde',
        date: '29 de Junho',
        content: '''### Texto para Estudo
Mc 1:1-15; Is 40:1-11; Ml 3:1; Lv 16:21; At 13:2-5.

> "Princípio do evangelho de Jesus Cristo, Filho de Deus." (Mc 1:1)

O Evangelho de Marcos é rápido, vívido e direto ao ponto. Ele nos convida imediatamente a contemplar Jesus como o Messias prometido e o Filho do Deus vivo. Marcos não perde tempo com genealogias detalhadas; ele mergulha de imediato na proclamação do precursor, João Batista, e na chegada do Reino de Deus.

Ao longo desta semana, examinaremos os primeiros passos do ministério público de Jesus e o significado de Seu batismo e tentação no deserto.''',
      ),
      const SSDay(
        id: 'pt-2024-03-01-02',
        lessonId: 'pt-2024-03-01',
        index: '2',
        title: 'Domingo: O Precursor',
        date: '30 de Junho',
        content: '''### A Voz que Clama no Deserto
Leia Mc 1:1-8 e compare com Is 40:3 e Ml 3:1.

Marcos inicia citando dois profetas do Antigo Testamento para demonstrar que o aparecimento de Jesus não foi um evento acidental ou desprovido de contexto, mas o cumprimento deliberado e fiel das profecias messiânicas.

João Batista apareceu no deserto pregando o batismo de arrependimento para a remissão dos pecados. O deserto tem profundo significado bíblico: é lugar de provação, de renovação da aliança e de dependência exclusiva de Deus.

#### Para Reflexão
Como você pode preparar o caminho do Senhor no coração de sua família e vizinhança nesta semana?''',
      ),
      const SSDay(
        id: 'pt-2024-03-01-03',
        lessonId: 'pt-2024-03-01',
        index: '3',
        title: 'Segunda: O Batismo',
        date: '01 de Julho',
        content: '''### Os Céus se Abrem
Leia Mc 1:9-11.

No momento em que Jesus saía da água, Ele viu os céus rasgando-se e o Espírito Santo descendo sobre Ele em forma de pomba. A voz do Pai ecoou da eternidade: *"Tu és o Meu Filho amado, em Ti Me comprazo."*

Neste ato sublime, as três pessoas da Divindade Se manifestam harmoniosamente, sancionando o início do ministério redentor de Cristo para toda a humanidade. Jesus não tinha pecados para confessar, mas Se identificou inteiramente conosco na jornada da obediência.''',
      ),
      const SSDay(
        id: 'pt-2024-03-01-04',
        lessonId: 'pt-2024-03-01',
        index: '4',
        title: 'Terça: Provado no Deserto',
        date: '02 de Julho',
        content: '''### O Confronto Cósmico
Leia Mc 1:12-13.

Imediatamente após a unção triunfante do batismo, o Espírito impeliu Jesus para o deserto. Ali Ele permaneceu por quarenta dias, sendo tentado por Satanás; estava entre as feras, e os anjos O serviam.

Ao contrário de Adão no Éden fértil, Jesus enfrentou o tentador no deserto árido e desolado. Onde Adão caiu em fraqueza, Cristo permaneceu inabalável, assegurando nossa redenção pela Palavra.''',
      ),
      const SSDay(
        id: 'pt-2024-03-01-05',
        lessonId: 'pt-2024-03-01',
        index: '5',
        title: 'Quarta: O Chamado',
        date: '03 de Julho',
        content: '''### Pescadores de Homens
Leia Mc 1:16-20.

Caminhando junto ao mar da Galileia, Jesus viu Simão e seu irmão André lançando redes ao mar, pois eram pescadores. Disse-lhes Jesus: *"Vinde após Mim, e Eu vos farei pescadores de homens."* E eles imediatamente deixaram suas redes e O seguiram.

O discipulado genuíno envolve um chamado irresistível, uma renúncia consciente e uma nova direção para os talentos práticos da vida cotidiana.''',
      ),
      const SSDay(
        id: 'pt-2024-03-01-06',
        lessonId: 'pt-2024-03-01',
        index: '6',
        title: 'Quinta: Autoridade Real',
        date: '04 de Julho',
        content: '''### Ensinando com Autoridade
Leia Mc 1:21-28.

Em Cafarnaum, Jesus entrou na sinagoga em dia de sábado e começou a ensinar. O povo maravilhava-se da Sua doutrina, porque os ensinava como quem tem autoridade e não como os escribas.

Mesmo os espíritos imundos reconheceram Sua santidade e obedeceram à Sua voz soberana. A palavra de Jesus liberta e restaura a dignidade humana ferida pelo pecado.''',
      ),
      const SSDay(
        id: 'pt-2024-03-01-07',
        lessonId: 'pt-2024-03-01',
        index: '7',
        title: 'Sexta: Conclusão e Estudo Adicional',
        date: '05 de Julho',
        content: '''### Estudo Adicional
Leia de Ellen G. White no livro *O Desejado de Todas as Nações*, os capítulos: "A Voz no Deserto" e "O Batismo".

> "O ministério terrestre de Cristo foi uma revelação contínua do infinito amor e da graça do Céu para com os seres humanos caídos."

#### Questões para Discussão
1. De que maneiras o batismo de Jesus fortalece nossa convicção na certeza da nossa adoção por Deus?
2. Como lidar com o deserto da vida após momentos de consagração e vitória espiritual?''',
      ),
    ],
    'pt-cq-2024-03-01': [
      const SSDay(
        id: 'pt-cq-2024-03-01-01',
        lessonId: 'pt-cq-2024-03-01',
        index: '1',
        title: 'Sábado: Conexão Inicial',
        date: '29 de Junho',
        content: '''### Qual é o Seu Norte?
Texto-chave: Rm 12:1-2.

Quem define quem você é? Numa cultura que vive de likes, métricas e aprovação passageira, Jesus nos convida a fundamentar nossa identidade naquilo que a Cruz diz a nosso respeito: amados, perdoados e vocacionados para a eternidade.''',
      ),
      const SSDay(
        id: 'pt-cq-2024-03-01-02',
        lessonId: 'pt-cq-2024-03-01',
        index: '2',
        title: 'Domingo: Desafio Prático',
        date: '30 de Junho',
        content: '''### Vivendo com Propósito
Texto-chave: 1Pe 2:9-10.

Você é raça eleita, sacerdócio real, nação santa, povo de propriedade exclusiva de Deus, a fim de proclamar as virtudes dAquele que o chamou das trevas para a Sua maravilhosa luz.''',
      ),
    ],
  };

  /// Retorna os trimestres disponíveis para a categoria
  Future<List<SSQuarterly>> getQuarterlies({String category = 'adultos'}) async {
    return _mockQuarterlies.where((q) => q.category == category).toList();
  }

  /// Retorna a lista de lições do trimestre
  Future<List<SSLesson>> getLessons(String quarterlyId) async {
    return _mockLessons[quarterlyId] ?? [];
  }

  /// Retorna os dias de estudo de uma lição
  Future<List<SSDay>> getLessonDays(String lessonId) async {
    return _mockDays[lessonId] ?? [];
  }

  /// Retorna ou atualiza o conteúdo do dia
  Future<SSDay?> getDayContent(String dayId) async {
    for (final daysList in _mockDays.values) {
      for (final d in daysList) {
        if (d.id == dayId) return d;
      }
    }
    return null;
  }

  /// Retorna anotação do dia salva localmente
  Future<String> getNote(String dayId) async {
    return _notes[dayId] ?? '';
  }

  /// Salva anotação do dia localmente
  Future<void> saveNote(String dayId, String noteText) async {
    _notes[dayId] = noteText;
  }
}
