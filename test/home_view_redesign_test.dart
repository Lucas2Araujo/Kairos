import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/bible_controller.dart';
import 'package:kairos_web/controllers/devotional_controller.dart';
import 'package:kairos_web/controllers/hymn_controller.dart';
import 'package:kairos_web/controllers/sabbath_school_controller.dart';
import 'package:kairos_web/data/services/sabbath_school_service.dart';
import 'package:kairos_web/models/devotional.dart';
import 'package:kairos_web/models/sabbath_school_models.dart';
import 'package:kairos_web/services/devotional_service.dart';
import 'package:kairos_web/services/gamification_service.dart';
import 'package:kairos_web/views/devotional/meditacao_destaque_view.dart';
import 'package:kairos_web/views/home/home_view.dart';
import 'package:kairos_web/views/home/widgets/daily_verse_card.dart';
import 'package:kairos_web/views/home/widgets/gamification_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDevotionalService extends DevotionalService {
  @override
  Future<Devotional> getDevotional(String dateStr, {String category = 'jovem'}) async {
    return Devotional(
      publishedAt: dateStr,
      title: 'Devocional $category',
      verseReference: 'Gênesis 1:1',
      verseText: 'No princípio criou Deus...',
      content: 'Conteúdo de teste',
      category: category,
    );
  }
}

class _FakeSabbathSchoolService extends SabbathSchoolService {
  @override
  Future<List<SSQuarterly>> getQuarterlies({String category = 'adultos'}) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GamificationService().resetForTesting();
  });

  group('DailyVerseCard Widget Tests', () {
    testWidgets('renders daily verse card with fallback verse and opens MeditacaoDestaqueView on tap', (tester) async {
      final bibleController = BibleController();
      final devoController = DevotionalController();
      int navigatedTab = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyVerseCard(
              bibleController: bibleController,
              onNavigateToTab: (index) => navigatedTab = index,
              devotionalController: devoController,
              isGlass: false,
            ),
          ),
        ),
      );

      // Verifica cabeçalho
      expect(find.text('VERSÍCULO DO DIA'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);

      // Versículo fallback
      expect(
        find.textContaining('Porque nenhum de nós vive para si mesmo'),
        findsOneWidget,
      );
      expect(find.text('Romanos 14:7'), findsOneWidget);
      expect(find.text('Toque para ler a meditação completa'), findsOneWidget);

      // Toca no card e verifica que abre MeditacaoDestaqueView
      await tester.tap(find.byType(DailyVerseCard));
      await tester.pumpAndSettle();

      expect(find.byType(MeditacaoDestaqueView), findsOneWidget);
      expect(find.text('Favoritar'), findsOneWidget);
      expect(find.text('Compartilhar'), findsOneWidget);
      expect(find.text('Ler Meditação'), findsOneWidget);

      // Toca em Ler Meditação
      await tester.tap(find.text('Ler Meditação'));
      await tester.pumpAndSettle();

      expect(navigatedTab, 3);
    });

    testWidgets('renders custom devotional verse in DailyVerseCard and MeditacaoDestaqueView', (tester) async {
      final bibleController = BibleController();
      final devoController = DevotionalController();

      devoController.currentDevotional = const Devotional(
        publishedAt: '2026-10-22',
        title: 'Manhã de Paz',
        author: 'Pr. Teste',
        verseReference: 'João 3:16',
        verseText: 'Porque Deus amou o mundo de tal maneira...',
        content: 'Conteúdo de teste',
        category: 'Jovem',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyVerseCard(
              bibleController: bibleController,
              onNavigateToTab: (_) {},
              devotionalController: devoController,
              isGlass: true,
            ),
          ),
        ),
      );

      expect(find.text('JOVEM'), findsOneWidget);
      expect(
        find.textContaining('Porque Deus amou o mundo de tal maneira...'),
        findsOneWidget,
      );
      expect(find.text('João 3:16'), findsOneWidget);
    });

    testWidgets('renders download icon button and exports card image with SnackBar feedback', (tester) async {
      final bibleController = BibleController();
      final devoController = DevotionalController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyVerseCard(
              bibleController: bibleController,
              onNavigateToTab: (_) {},
              devotionalController: devoController,
              isGlass: false,
            ),
          ),
        ),
      );

      final downloadButton = find.byIcon(Icons.download_rounded);
      expect(downloadButton, findsOneWidget);

      await tester.tap(downloadButton);
      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      expect(find.text('Card de versículo exportado com sucesso!'), findsOneWidget);
      // Ensure MeditacaoDestaqueView is NOT opened by download tap
      expect(find.byType(MeditacaoDestaqueView), findsNothing);
    });
  });

  group('GamificationBanner Widget Tests', () {
    testWidgets('renders initial streak, 0 XP and opens info dialog on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationBanner(isGlass: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comece sua sequência!'), findsOneWidget);
      expect(find.text('0 XP'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
      expect(find.byIcon(Icons.bolt), findsOneWidget);

      // Verifica os 7 indicadores dos dias da semana
      for (final letter in ['D', 'S', 'T', 'Q']) {
        expect(find.text(letter), findsWidgets);
      }

      // Toca no banner para abrir diálogo explicativo
      await tester.tap(find.byType(GamificationBanner));
      await tester.pumpAndSettle();

      expect(find.text('Ofensiva & XP Kairós'), findsOneWidget);
      expect(find.text('Entendi'), findsOneWidget);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('Ofensiva & XP Kairós'), findsNothing);
    });

    testWidgets('reflects active streak and weekly check indicators after recording reading', (tester) async {
      final service = GamificationService();
      await service.recordReading(category: 'biblia');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GamificationBanner(isGlass: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 dia seguido'), findsOneWidget);
      expect(find.text('10 XP'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });

  group('HomeView Integration Tests', () {
    testWidgets('renders all main sections in order: greeting, banner, verse card, quick access', (tester) async {
      final bibleController = BibleController();
      final hymnController = HymnController();
      final devoController = DevotionalController(service: _FakeDevotionalService());
      final ssController = SabbathSchoolController(service: _FakeSabbathSchoolService());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeView(
            bibleController: bibleController,
            hymnController: hymnController,
            devotionalController: devoController,
            sabbathSchoolController: ssController,
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifica acolhida dinâmica
      expect(find.byType(GamificationBanner), findsOneWidget);
      expect(find.byType(DailyVerseCard), findsOneWidget);

      // Verifica os 4 tiles de acesso rápido com seus badges e subtítulos personalizados
      expect(find.text('Acesso Rápido'), findsOneWidget);

      // Bíblia
      expect(find.text('Bíblia'), findsOneWidget);
      expect(find.text('ARA'), findsOneWidget);
      expect(find.text('Estudo com notas'), findsOneWidget);

      // Hinários
      expect(find.text('Hinários'), findsOneWidget);
      expect(find.text('2022/96'), findsOneWidget);
      expect(find.text('Letras e áudios'), findsOneWidget);

      // Meditação
      expect(find.text('Meditação'), findsOneWidget);
      expect(find.text('JOVENS'), findsOneWidget);
      expect(find.text('Devocional de hoje'), findsOneWidget);

      // Escola Sabatina
      expect(find.text('Escola Sabatina'), findsOneWidget);
      expect(find.text('ADULTOS'), findsOneWidget);
      expect(find.text('Lição da semana'), findsOneWidget);
    });

    testWidgets('dynamically updates quick access badges when controllers change state', (tester) async {
      final bibleController = BibleController();
      final hymnController = HymnController();
      final devoController = DevotionalController(service: _FakeDevotionalService());
      final ssController = SabbathSchoolController(service: _FakeSabbathSchoolService());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeView(
            bibleController: bibleController,
            hymnController: hymnController,
            devotionalController: devoController,
            sabbathSchoolController: ssController,
            onNavigateToTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder tileBadge(String title, String badgeText) {
        return find.descendant(
          of: find.ancestor(
            of: find.text(title),
            matching: find.byType(InkWell),
          ),
          matching: find.text(badgeText),
        );
      }

      // Verificações iniciais
      expect(tileBadge('Bíblia', 'ARA'), findsOneWidget);
      expect(tileBadge('Hinários', '2022/96'), findsOneWidget);
      expect(tileBadge('Meditação', 'JOVENS'), findsOneWidget);
      expect(tileBadge('Escola Sabatina', 'ADULTOS'), findsOneWidget);

      // 1. Altera versão da Bíblia para NVI
      await bibleController.selectVersion('NVI');
      await tester.pumpAndSettle();
      expect(tileBadge('Bíblia', 'NVI'), findsOneWidget);
      expect(tileBadge('Bíblia', 'ARA'), findsNothing);

      // 2. Altera categoria da meditação para Mulher e Adultos
      await devoController.selectCategory('mulher');
      await tester.pumpAndSettle();
      expect(tileBadge('Meditação', 'MULHER'), findsOneWidget);
      expect(tileBadge('Meditação', 'JOVENS'), findsNothing);

      await devoController.selectCategory('diario');
      await tester.pumpAndSettle();
      expect(tileBadge('Meditação', 'ADULTOS'), findsOneWidget);

      // 3. Altera categoria da Escola Sabatina para jovens
      await ssController.setCategory('jovens');
      await tester.pumpAndSettle();
      expect(tileBadge('Escola Sabatina', 'JOVENS'), findsOneWidget);
      expect(tileBadge('Escola Sabatina', 'ADULTOS'), findsNothing);
    });

    testWidgets('executes staggered entry animation and settles cleanly', (tester) async {
      final bibleController = BibleController();
      final hymnController = HymnController();
      final devoController = DevotionalController(service: _FakeDevotionalService());
      final ssController = SabbathSchoolController(service: _FakeSabbathSchoolService());

      await tester.pumpWidget(
        MaterialApp(
          home: HomeView(
            bibleController: bibleController,
            hymnController: hymnController,
            devotionalController: devoController,
            sabbathSchoolController: ssController,
            onNavigateToTab: (_) {},
          ),
        ),
      );

      // Frame inicial (t = 0)
      await tester.pump();
      // Meio da animação (~300ms)
      await tester.pump(const Duration(milliseconds: 300));
      // Conclui e estabiliza (~600ms total)
      await tester.pumpAndSettle();

      expect(find.byType(GamificationBanner), findsOneWidget);
      expect(find.byType(DailyVerseCard), findsOneWidget);
      expect(find.text('Acesso Rápido'), findsOneWidget);
    });
  });
}
