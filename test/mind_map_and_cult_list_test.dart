import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/hymn.dart';
import 'package:kairos_web/models/sabbath_school_models.dart';
import 'package:kairos_web/views/hymns/widgets/cult_list_sheet.dart';
import 'package:kairos_web/views/lesson/mind_map_studio_view.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(OperatingSystem.linux, () {
        try {
          return DynamicLibrary.open('libsqlite3.so');
        } catch (_) {
          return DynamicLibrary.open('libsqlite3.so.0');
        }
      });
    }
  });

  group('CultListRecommender Tests', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE hino (
          id INTEGER PRIMARY KEY,
          numero TEXT NOT NULL,
          titulo TEXT NOT NULL,
          letra TEXT,
          autor_letra TEXT,
          autor_musica TEXT,
          texto_base TEXT,
          categoria TEXT,
          subcategoria TEXT,
          autores TEXT,
          link_video TEXT
        );
      ''');

      // Inserção de dados litúrgicos de teste
      db.execute('''
        INSERT INTO hino (id, numero, titulo, categoria, subcategoria) VALUES
        (1, '558', 'Pai Nosso', 'Louvor', 'Introito'),
        (2, '559', 'Santo, Santo', 'Louvor', 'Introito'),
        (3, '586', 'Ouve Senhor', 'Oração', 'Oração Pastoral'),
        (4, '587', 'Prece Silenciosa', 'Oração', 'Oração Pastoral'),
        (5, '572', 'Tudo Que Tenho', 'Consagração', 'Ofertório'),
        (6, '573', 'Dons e Talentos', 'Consagração', 'Ofertório'),
        (7, '592', 'Fica Conosco', 'Despedida', 'Despedida'),
        (8, '593', 'Vêm Despedir-nos', 'Despedida', 'Despedida'),
        (9, '250', 'Nas Águas do Batismo', 'Doutrinas', 'O Batismo'),
        (10, '300', 'Graça Infinita', 'Salvação', 'A Experiência da Salvação');
      ''');
    });

    tearDown(() {
      db.dispose();
    });

    test('recommend generates 5 liturgical sections in correct order', () {
      final recs = CultListRecommender.recommend(db: db, theme: 'Batismo');

      expect(recs.length, equals(5));
      expect(recs[0].section, equals('Introito'));
      expect(recs[0].order, equals(1));
      expect(recs[0].hymn.subcategoria, equals('Introito'));

      expect(recs[1].section, equals('Oração Pastoral'));
      expect(recs[1].order, equals(2));
      expect(recs[1].hymn.subcategoria, equals('Oração Pastoral'));

      expect(recs[2].section, equals('Hino do Sermão'));
      expect(recs[2].order, equals(3));
      // Deve ter priorizado o hino com tema Batismo
      expect(recs[2].hymn.titulo, contains('Batismo'));

      expect(recs[3].section, equals('Ofertório'));
      expect(recs[3].order, equals(4));
      expect(recs[3].hymn.subcategoria, equals('Ofertório'));

      expect(recs[4].section, equals('Despedida'));
      expect(recs[4].order, equals(5));
      expect(recs[4].hymn.subcategoria, equals('Despedida'));
    });

    test('recommend is completely deterministic for the same theme', () {
      final recs1 = CultListRecommender.recommend(db: db, theme: 'Graça');
      final recs2 = CultListRecommender.recommend(db: db, theme: 'Graça');

      expect(recs1.length, equals(recs2.length));
      for (int i = 0; i < recs1.length; i++) {
        expect(recs1[i].hymn.id, equals(recs2[i].hymn.id));
        expect(recs1[i].hymn.numero, equals(recs2[i].hymn.numero));
      }
    });

    test('createList, getLists, and deleteList persist correctly in SQLite', () {
      final listId = CultListRecommender.createList(
        db,
        tema: 'Culto Jovem de Sábado',
        hymnIds: [1, 3, 10, 5, 7],
      );
      expect(listId, isPositive);

      final lists = CultListRecommender.getLists(db);
      expect(lists.length, equals(1));
      expect(lists.first.temaGerador, equals('Culto Jovem de Sábado'));
      expect(lists.first.hymns.length, equals(5));
      expect(lists.first.hymns.map((h) => h.id).toList(), equals([1, 3, 10, 5, 7]));

      // Deletar a lista
      CultListRecommender.deleteList(db, listId);
      final remainingLists = CultListRecommender.getLists(db);
      expect(remainingLists.isEmpty, isTrue);
    });
  });

  group('MindMapStudioView Unit & Painter Tests', () {
    test('MindMapNode serialization and deserialization roundtrip', () {
      final node = MindMapNode(
        id: 'node_1',
        parentId: 'root',
        text: 'Conceito Teológico',
        position: const Offset(120.5, 340.25),
      );

      final json = node.toJson();
      final restored = MindMapNode.fromJson(json);

      expect(restored.id, equals(node.id));
      expect(restored.parentId, equals(node.parentId));
      expect(restored.text, equals(node.text));
      expect(restored.position.dx, equals(120.5));
      expect(restored.position.dy, equals(340.25));
    });

    test('MindMapConnectionsPainter executes without crashing', () {
      final nodes = [
        MindMapNode(id: 'root', text: 'Raiz', position: const Offset(100, 100)),
        MindMapNode(id: 'c1', parentId: 'root', text: 'Filho 1', position: const Offset(300, 50)),
        MindMapNode(id: 'c2', parentId: 'root', text: 'Filho 2', position: const Offset(50, 250)),
      ];

      final painter = MindMapConnectionsPainter(
        nodes: nodes,
        lineColor: Colors.blue,
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(1000, 1000));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('ss_mind_maps table loads and saves node JSON in SQLite', () {
      final db = sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE ss_mind_maps (
          day_id TEXT PRIMARY KEY,
          root_word TEXT NOT NULL,
          nodes_json TEXT NOT NULL,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ''');

      final nodes = [
        MindMapNode(id: 'root', text: 'O Grande Conflito', position: const Offset(1000, 1000)),
        MindMapNode(id: 'c1', parentId: 'root', text: 'Vitória na Cruz', position: const Offset(1250, 950)),
      ];

      final encoded = jsonEncode(nodes.map((n) => n.toJson()).toList());
      db.execute('''
        INSERT INTO ss_mind_maps (day_id, root_word, nodes_json)
        VALUES ('day_42', 'O Grande Conflito', ?);
      ''', [encoded]);

      final rows = db.select('SELECT root_word, nodes_json FROM ss_mind_maps WHERE day_id = ?;', ['day_42']);
      expect(rows.length, equals(1));
      expect(rows.first['root_word'], equals('O Grande Conflito'));

      final List<dynamic> loaded = jsonDecode(rows.first['nodes_json'] as String);
      final restoredNodes = loaded.map((i) => MindMapNode.fromJson(i as Map<String, dynamic>)).toList();
      expect(restoredNodes.length, equals(2));
      expect(restoredNodes[1].text, equals('Vitória na Cruz'));

      db.dispose();
    });
  });

  group('MindMapStudioView Widget Tests', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE ss_mind_maps (
          day_id TEXT PRIMARY KEY,
          root_word TEXT NOT NULL,
          nodes_json TEXT NOT NULL,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ''');
    });

    tearDown(() {
      db.dispose();
    });

    testWidgets('renders MindMapStudioView, InteractiveViewer, and default nodes', (tester) async {
      const day = SSDay(
        id: 'day_test',
        lessonId: 'lesson_1',
        title: 'Fé e Obras',
        date: '22 Out',
        content: 'Conteúdo da lição de teste',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MindMapStudioView(
            day: day,
            db: db,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifica App Bar
      expect(find.textContaining('Fé e Obras'), findsWidgets);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Verifica presença dos nós padrão
      expect(find.text('Ponto Principal'), findsOneWidget);
      expect(find.text('Aplicação Prática'), findsOneWidget);

      // Adiciona um novo nó tocando no botão '+' do nó raiz
      final addButtons = find.byIcon(Icons.add_circle_outline);
      expect(addButtons, findsWidgets);

      await tester.tap(addButtons.first);
      await tester.pumpAndSettle();

      expect(find.text('Novo Tópico'), findsOneWidget);
    });
  });

  group('CultListSheet Widget Tests', () {
    late Database db;

    setUp(() {
      db = sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE hino (
          id INTEGER PRIMARY KEY,
          numero TEXT NOT NULL,
          titulo TEXT NOT NULL,
          letra TEXT,
          autor_letra TEXT,
          autor_musica TEXT,
          texto_base TEXT,
          categoria TEXT,
          subcategoria TEXT,
          autores TEXT,
          link_video TEXT
        );
      ''');
      db.execute('''
        INSERT INTO hino (id, numero, titulo, categoria, subcategoria) VALUES
        (1, '558', 'Pai Nosso', 'Louvor', 'Introito'),
        (2, '586', 'Ouve Senhor', 'Oração', 'Oração Pastoral'),
        (3, '100', 'Maravilhosa Graça', 'Salvação', 'A Experiência da Salvação'),
        (4, '572', 'Tudo Que Tenho', 'Consagração', 'Ofertório'),
        (5, '592', 'Fica Conosco', 'Despedida', 'Despedida');
      ''');
    });

    tearDown(() {
      db.dispose();
    });

    testWidgets('renders CultListSheet and allows creating and opening hymns', (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Hymn? selectedHymn;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CultListSheet(
              db: db,
              onSelectHymn: (h) => selectedHymn = h,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Inicialmente sem listas salvas
      expect(find.text('Listas de Culto'), findsOneWidget);
      expect(find.text('Nenhuma lista de culto salva'), findsOneWidget);

      // Toca em '+ Nova Lista'
      await tester.tap(find.text('+ Nova Lista'));
      await tester.pumpAndSettle();

      expect(find.text('Recomendador Litúrgico Local'), findsOneWidget);
      expect(find.text('Ordem Litúrgica Recomendada (5 hinos)'), findsOneWidget);
      expect(find.textContaining('Introito'), findsWidgets);
      expect(find.textContaining('Oração Pastoral'), findsWidgets);

      // Toca em 'Salvar Esta Programação de Culto'
      final saveBtn = find.text('Salvar Esta Programação de Culto');
      await tester.ensureVisible(saveBtn);
      await tester.pumpAndSettle();
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Agora a lista salva deve estar presente na tela
      expect(find.text('Listas de Culto'), findsOneWidget);
      expect(find.text('Culto de Louvor'), findsOneWidget);

      // Expande a lista tocando no tema
      await tester.tap(find.text('Culto de Louvor'));
      await tester.pumpAndSettle();

      // Toca em um hino da lista
      expect(find.textContaining('558. Pai Nosso'), findsOneWidget);
      await tester.tap(find.textContaining('558. Pai Nosso'));
      await tester.pumpAndSettle();

      expect(selectedHymn, isNotNull);
      expect(selectedHymn!.numero, equals('558'));
    });
  });
}
