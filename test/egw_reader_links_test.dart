import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/views/egw/egw_reader_view.dart';

void main() {
  testWidgets('EgwLinkableParagraph dispara callback exato ao acionar TapGestureRecognizer da referencia biblica', (tester) async {
    String? tappedRef;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Como lemos em João 3:16 e Romanos 8:1 na Escritura.',
            onBibleRefTap: (ref) => tappedRef = ref,
          ),
        ),
      ),
    );
    expect(tappedRef, isNull);
    final richText = tester.widget<SelectableText>(find.byType(SelectableText));
    final span = richText.textSpan!;
    final linkSpans = span.children!
        .whereType<TextSpan>()
        .where((s) => s.recognizer is TapGestureRecognizer)
        .toList();
    expect(linkSpans.length, greaterThanOrEqualTo(2));
    (linkSpans.first.recognizer as TapGestureRecognizer).onTap?.call();
    expect(tappedRef, contains('João 3:16'));
  });

  testWidgets('EgwLinkableParagraph sem referencias renderiza texto puro sem recognizers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Este é um texto comum sem nenhuma menção bíblica.',
          ),
        ),
      ),
    );
    final selectableText = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(selectableText.data, equals('Este é um texto comum sem nenhuma menção bíblica.'));
    expect(selectableText.textSpan, isNull);
  });

  testWidgets('EgwLinkableParagraph atualiza recognizers corretamente ao alterar o texto', (tester) async {
    String? tappedRef;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Texto com Gênesis 1:1 inicial.',
            onBibleRefTap: (ref) => tappedRef = ref,
          ),
        ),
      ),
    );

    var richText = tester.widget<SelectableText>(find.byType(SelectableText));
    var linkSpans = richText.textSpan!.children!
        .whereType<TextSpan>()
        .where((s) => s.recognizer is TapGestureRecognizer)
        .toList();
    expect(linkSpans.length, equals(1));
    (linkSpans.first.recognizer as TapGestureRecognizer).onTap?.call();
    expect(tappedRef, contains('Gênesis 1:1'));

    // Atualiza widget com novo texto
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Texto atualizado com Salmos 23:1 e Mateus 5:3.',
            onBibleRefTap: (ref) => tappedRef = ref,
          ),
        ),
      ),
    );

    richText = tester.widget<SelectableText>(find.byType(SelectableText));
    linkSpans = richText.textSpan!.children!
        .whereType<TextSpan>()
        .where((s) => s.recognizer is TapGestureRecognizer)
        .toList();
    expect(linkSpans.length, equals(2));
    (linkSpans.first.recognizer as TapGestureRecognizer).onTap?.call();
    expect(tappedRef, contains('Salmos 23:1'));
  });

  testWidgets('EgwLinkableParagraph nao recria recognizers ao alterar apenas propriedades visuais (evita churn)', (tester) async {
    String? tappedRef;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Texto estavel com Hebreus 11:1 na leitura.',
            fontSize: 16.0,
            onBibleRefTap: (ref) => tappedRef = ref,
          ),
        ),
      ),
    );

    var richText = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(richText.textSpan!.style?.fontSize, equals(16.0));
    final initialRecognizer = richText.textSpan!.children!
        .whereType<TextSpan>()
        .firstWhere((s) => s.recognizer is TapGestureRecognizer)
        .recognizer;

    // Rebuild mudando apenas fontSize e callback closure
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Texto estavel com Hebreus 11:1 na leitura.',
            fontSize: 22.0,
            onBibleRefTap: (ref) => tappedRef = 'NOVO: $ref',
          ),
        ),
      ),
    );

    richText = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(richText.textSpan!.style?.fontSize, equals(22.0));
    final updatedRecognizer = richText.textSpan!.children!
        .whereType<TextSpan>()
        .firstWhere((s) => s.recognizer is TapGestureRecognizer)
        .recognizer;

    // Mesma instância do recognizer foi mantida sem churn desnecessário
    expect(identical(initialRecognizer, updatedRecognizer), isTrue);

    // E o callback acionado reflete a versão atualizada lida em tempo de execução
    (updatedRecognizer as TapGestureRecognizer).onTap?.call();
    expect(tappedRef, contains('NOVO: Hebreus 11:1'));
  });
}
