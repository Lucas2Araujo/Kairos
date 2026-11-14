import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/controllers/hymn_controller.dart';
import 'package:kairos_web/models/hymn.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/hymns/hymn_list_view.dart';
import 'package:kairos_web/views/lesson/widgets/cached_ss_tirinha_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 1x1 PNG transparente válido para testes de Image.memory sem rede.
final Uint8List _kTransparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

class _FakeHymnController extends HymnController {
  final List<Hymn> _fakeHymns;

  _FakeHymnController(this._fakeHymns);

  @override
  List<Hymn> get hymns => _fakeHymns;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  Future<void> init() async {}
}

List<Hymn> _generateHymns(int count) {
  return List<Hymn>.generate(count, (i) {
    final num = i + 1;
    return Hymn(
      id: num,
      numero: '$num',
      titulo: 'Hino de Teste $num',
      categoria: i.isEven ? 'Adoração' : null,
    );
  });
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeService().init();
    CachedSSTirinhaImage.clearMemoryCache();
  });

  group('CachedSSTirinhaImage - Cache em Memória e Edge Cases', () {
    testWidgets('renderiza instantaneamente da RAM sem CircularProgressIndicator', (tester) async {
      const url = 'https://example.com/tirinha_01.png';
      CachedSSTirinhaImage.seedMemoryCacheForTest(url, _kTransparentPng);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CachedSSTirinhaImage(imageUrl: url),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('URL vazia ou com espaços aciona errorBuilder imediatamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CachedSSTirinhaImage(
              imageUrl: '   ',
              errorBuilder: (_, __, ___) => const Text('SEM_IMAGEM'),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('SEM_IMAGEM'), findsOneWidget);
    });

    test('respeita limite LRU de maxMemoryCacheEntries (60)', () {
      for (var i = 0; i < CachedSSTirinhaImage.maxMemoryCacheEntries + 15; i++) {
        CachedSSTirinhaImage.seedMemoryCacheForTest(
          'https://example.com/img_$i.png',
          _kTransparentPng,
        );
      }

      expect(
        CachedSSTirinhaImage.memoryCacheLength,
        CachedSSTirinhaImage.maxMemoryCacheEntries,
      );
    });

    testWidgets('atualização de imageUrl para outra URL em cache troca sem loading', (tester) async {
      const urlA = 'https://example.com/a.png';
      const urlB = 'https://example.com/b.png';
      CachedSSTirinhaImage.seedMemoryCacheForTest(urlA, _kTransparentPng);
      CachedSSTirinhaImage.seedMemoryCacheForTest(urlB, _kTransparentPng);

      var currentUrl = urlA;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    CachedSSTirinhaImage(imageUrl: currentUrl, width: 40, height: 40),
                    TextButton(
                      onPressed: () => setState(() => currentUrl = urlB),
                      child: const Text('Trocar'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      await tester.tap(find.text('Trocar'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('HymnListView - Rolagem Rápida (1 a 600) e Edge Cases', () {
    testWidgets('arrastar barra lateral de 1 até 600 atualiza balão sem travar ou dar overflow',
        (tester) async {
      final controller = _FakeHymnController(_generateHymns(600));

      await tester.pumpWidget(
        MaterialApp(
          home: HymnListView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Localiza a barra lateral pelo GestureDetector dentro da área de lista
      final listFinder = find.byType(ListView);
      expect(listFinder, findsOneWidget);

      final scrollbarFinder = find.byKey(const Key('hymn_fast_scrollbar'));
      expect(scrollbarFinder, findsOneWidget);

      final rect = tester.getRect(scrollbarFinder);
      final gesture = await tester.startGesture(Offset(rect.center.dx, rect.top + 2));
      // Cruza o kTouchSlop para iniciar o VerticalDrag e volta ao topo (Hino 1)
      await gesture.moveBy(const Offset(0, 24));
      await gesture.moveTo(Offset(rect.center.dx, rect.top));
      await tester.pump();
      expect(find.text('Hino 1'), findsOneWidget);

      // Arrasta rapidamente até o final (Hino 600)
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom));
      await tester.pump();
      expect(find.text('Hino 600'), findsOneWidget);

      // Volta rapidamente para o meio
      await gesture.moveTo(Offset(rect.center.dx, rect.center.dy));
      await tester.pump();
      expect(find.byKey(const Key('hymn_fast_scroll_bubble')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('hymn_fast_scroll_bubble')),
          matching: find.text('Hino 301'),
        ),
        findsOneWidget,
      );

      await gesture.up();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('suporta TextScaler extremo (1.8x) com 600 hinos sem RenderFlex overflow',
        (tester) async {
      final controller = _FakeHymnController(_generateHymns(600));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: HymnListView(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollbarFinder = find.byKey(const Key('hymn_fast_scrollbar'));
      final rect = tester.getRect(scrollbarFinder);
      final gesture = await tester.startGesture(Offset(rect.center.dx, rect.top + 8));
      await tester.pump();
      await gesture.moveTo(Offset(rect.center.dx, rect.bottom - 2));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('oculta barra lateral de rolagem rápida quando há 20 hinos ou menos',
        (tester) async {
      final controller = _FakeHymnController(_generateHymns(15));

      await tester.pumpWidget(
        MaterialApp(
          home: HymnListView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final scrollbarFinder = find.byKey(const Key('hymn_fast_scrollbar'));
      expect(scrollbarFinder, findsNothing);
    });
  });
}
