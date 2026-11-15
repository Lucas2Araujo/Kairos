# Kairós Final Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o polimento final completo do aplicativo **Kairós** em 5 Sprints cobrindo integridade offline e catálogo completo de Ellen G. White (~79 obras + sistema dual de capas Clássica EGW vs Nova CPB com Canvas claro/escuro), Apócrifos (`AVM`) + `1 Enoque`, perícopes e comentários bíblicos, missão integrada nos planos de leitura, marcadores da lição + sincronização híbrida na nuvem, limpeza de modais, gestos opcionais configuráveis, 3 novos temas (`Real Glass`, `Retrô ICS Holo`, `Windows 95`), acessibilidade, testes de borda e documentação Dartdoc (`/dart-write-documentation`).

**Architecture:** Evolução incremental seguindo a filosofia **Ponytail** (`AGENTS.md`): reúso direto dos serviços e repositórios existentes em `lib/` (`EgwService`, `BibleRepository`, `PericopeRepository`, `CommentaryRepository`, `ReadingPlanService`, `SabbathSchoolService`, `GamificationService`, `AuthService`, `ThemeService`), scripts Python locais gerando bancos SQLite compactos compatíveis com Android e Web (`sql.js`), e helpers compartilhados pequenos para gestos, covers procedurais (`CustomPainter`) e merge de conjuntos na nuvem.

**Tech Stack:** Flutter / Dart (`package:kairos_web`), SQLite (`sqflite` + `sqlite3` Python), `http`, `shared_preferences`, `dart:ui` (`ImageFilter.matrix`, `Canvas`), Supabase Auth/REST (`AuthService`), `flutter_test`, `dart analyze`.

**Spec:** `/home/loko/.gemini/antigravity/brain/b1ce8ce2-e51d-4441-b19f-353c6b1378d7/implementation_plan.md`

## Global Constraints

- **Ponytail & Zero Novas Dependências:** Não adicionar novos pacotes ao `pubspec.yaml`; usar apenas APIs nativas do Flutter/Dart, dependências já instaladas e Python padrão (`sqlite3`).
- **Multiplataforma Android & Web:** Nunca importar `dart:io` diretamente sem stubs ou guarda `kIsWeb`; todo arquivo `.sqlite` gerado ou alterado para bundle/R2 deve executar `PRAGMA journal_mode=DELETE; VACUUM;`.
- **Responsividade & `TextScaler`:** Nenhuma dimensão rígida desprotegida; telas, cards, estantes de capas, diálogos e bottom sheets devem suportar `TextScaler.linear(2.0)` sem `RenderFlex` overflow.
- **Preservação de Dados Local:** Toda nova tabela de usuário (ex.: `ss_highlights`) deve ser registrada em `DatabaseManager.userPreservedTables`.
- **Temas Glass Existentes Preservados:** Manter `"Liquid Glass"` (`AppThemeStyle.liquidGlass`) e `"Apple Glass"` (`AppThemeStyle.appleGlass`) inalterados com seus nomes atuais como presets paródia/legados.
- **Documentação & Ciclo em Malha Fechada:** Toda API pública ou helper novo/modificado deve receber Dartdoc `///` conforme `/dart-write-documentation`, passando em `flutter analyze` (zero erros e zero warnings de `comment_references`) e `flutter test`.

## Review Focus

- **Cache parcial do EGW (1 capítulo salvo online):** Baixar um livro que já possui 1 capítulo em `egw_chapters_cache` não pode truncar `getTableOfContents` em 1 capítulo nem gravar `is_downloaded = 1` com conteúdo incompleto (Exercitado na Tarefa 1).
- **Apócrifos romanos e `1 Enoque` na busca:** Consultar `"I Macabeus"`, `"Eclesiástico"` ou `"1 Enoque"` nos filtros `TODOS` e `Apócrifos` (`AVM` e `ARA`) deve resolver o livro correto sem ocultação silenciosa na busca (Exercitado na Tarefa 4).
- **Capa Nova CPB offline ou sem URL mapeada:** Renderizar `EgwBookCover` com `egwUseModernCovers == true` para qualquer uma das ~79 obras sem URL CPB ou sem internet deve desenhar o Canvas CPB (Taupe/Bronze no claro; Grafite/Dourado no escuro) sem falha de carregamento ou overflow (Exercitado na Tarefa 3).
- **Merge híbrido de nuvem entre dispositivos offline:** Sincronizar dois dispositivos com conjuntos disjuntos de `activityDates` mensais, planos concluídos ou `ss_highlights` deve unir os dados via `Set.union` / timestamp mais recente sem perda silenciosa (Exercitado na Tarefa 9).
- **Gestos desabilitados + `TextScaler.linear(2.0)`:** Com `gesturesEnabled == false`, swipe, pinça e duplo-toque devem permanecer inertes; com `TextScaler.linear(2.0)`, modais e leitores não podem gerar overflow (Exercitado nas Tarefas 11 e 13).

---

## Sprint 1 — Integridade Offline do Espírito de Profecia, Catálogo ~79 + Dual Covers e Apócrifos/`1 Enoque`

### Task 1: Corrigir bug "Demo / 1 Capítulo" no download EGW (`EgwService`)

**Files:**
- Modify: `lib/services/egw_service.dart:289-520`
- Test: `test/egw_service_download_test.dart`

**Interfaces:**
- Consumes: `DatabaseManager().getDatabase('hinario.db')`, `EgwChapterHeader`, `EgwBook`.
- Produces:
  - `Future<List<EgwChapterHeader>> getTableOfContents(String bookId, {bool forceRefresh = false})`
  - `Future<void> downloadBook(String bookId, {void Function(int current, int total)? onProgress})`
  - `Future<bool> isBookDownloaded(String bookId)`

- [x] **Step 1: Write the failing test**

```dart
// test/egw_service_download_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/services/egw_service.dart';

void main() {
  test('isBookDownloaded retorna false quando apenas 1 capitulo online foi salvo em livro multi-capitulo', () async {
    final service = EgwService();
    final isComplete = service.evaluateDownloadCompleteness(
      cachedChapterCount: 1,
      expectedTotalChapters: 42,
      flaggedDownloaded: true,
    );
    expect(isComplete, isFalse);
  });

  test('shouldBypassTocCache retorna true quando forceRefresh == true ou cache parcial', () {
    final service = EgwService();
    expect(
      service.shouldBypassTocCache(
        forceRefresh: true,
        cachedHeadersCount: 1,
        knownTotalChapters: 42,
      ),
      isTrue,
    );
    expect(
      service.shouldBypassTocCache(
        forceRefresh: false,
        cachedHeadersCount: 1,
        knownTotalChapters: 0,
      ),
      isTrue,
    );
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/egw_service_download_test.dart`
Expected: FAIL (`evaluateDownloadCompleteness` and `shouldBypassTocCache` not defined on `EgwService`).

- [x] **Step 3: Implement TOC refresh guard and real chapter-count verification in `lib/services/egw_service.dart`**

Extrair helpers puros testáveis `@visibleForTesting bool shouldBypassTocCache(...)` e `@visibleForTesting bool evaluateDownloadCompleteness(...)` em `EgwService`. Alterar `getTableOfContents(String bookId, {bool forceRefresh = false})` na linha 313 para não retornar `cachedHeaders` apenas porque `cachedHeaders.isNotEmpty` quando `shouldBypassTocCache(...)` for `true` (ex.: livro só teve 1 capítulo visto online ou `knownTotalChapters > cachedHeaders.length`). Em `downloadBook`, chamar `getTableOfContents(bookId, forceRefresh: true)`, gravar `total_chapters = headers.length` no `_booksTable`, baixar todos os capítulos faltantes e confirmar a contagem real em `_chaptersTable` antes de definir `is_downloaded = 1`. Atualizar `isBookDownloaded` para validar flag **e** `evaluateDownloadCompleteness`.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/egw_service_download_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Adicionar Dartdoc `///` em `getTableOfContents`, `downloadBook`, `isBookDownloaded`, `shouldBypassTocCache` e `evaluateDownloadCompleteness`, rodar `flutter analyze lib/services/egw_service.dart` e fazer commit (`fix(egw): prevent partial online cache from truncating offline downloads`).

---

### Task 2: Tornar referências bíblicas clicáveis no leitor EGW (`EgwReaderView`)

**Files:**
- Modify: `lib/views/egw/egw_reader_view.dart:580-630`
- Test: `test/egw_reader_links_test.dart`

**Interfaces:**
- Consumes: `BibleExtractor.findBibleReferences`, `BibleExtractor.cleanReference`, `BibleVersePreviewModal.show`.
- Produces: `Widget buildParagraphRichText(String text, ...)` (ou helper testável dentro de `EgwReaderView` usando `TapGestureRecognizer` por span).

- [x] **Step 1: Write the failing test**

```dart
// test/egw_reader_links_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/views/egw/egw_reader_view.dart';

void main() {
  testWidgets('EgwReaderView dispara callback ao tocar em referencia biblica inline', (tester) async {
    String? tappedRef;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EgwLinkableParagraph(
            text: 'Como lemos em João 3:16 na Escritura.',
            onBibleRefTap: (ref) => tappedRef = ref,
          ),
        ),
      ),
    );
    expect(tappedRef, isNull);
    final richText = tester.widget<SelectableText>(find.byType(SelectableText));
    final span = richText.textSpan!;
    final linkSpan = span.children!.whereType<TextSpan>().firstWhere((s) => s.recognizer != null);
    (linkSpan.recognizer as dynamic).onTap();
    expect(tappedRef, equals('João 3:16'));
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/egw_reader_links_test.dart`
Expected: FAIL (`EgwLinkableParagraph` not defined / `onTap` empty).

- [x] **Step 3: Implement `EgwLinkableParagraph` with managed `TapGestureRecognizer`s in `lib/views/egw/egw_reader_view.dart`**

Substituir o `onTap` vazio em `_buildRichParagraphText` (linhas 620-622) criando o widget `EgwLinkableParagraph` (Stateful para dar `dispose()` nos `TapGestureRecognizer`s a cada rebuild/dispose) e conectando `onBibleRefTap ?? (ref) => BibleVersePreviewModal.show(context, reference: ref)` diretamente no `TapGestureRecognizer` dos `TextSpan` que possuem referência bíblica.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/egw_reader_links_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar `EgwLinkableParagraph` com `///`, rodar `flutter analyze lib/views/egw/egw_reader_view.dart` e fazer commit (`feat(egw): wire inline bible reference taps to preview modal`).

---

### Task 3: Catálogo Completo (~79 obras PT) + Sistema Dual de Capas ("Antiga EGW" vs "Nova CPB" Claro/Escuro + Canvas)

**Files:**
- Modify: `lib/models/egw_models.dart:1-120`
- Modify: `lib/services/egw_service.dart:17-260`
- Modify: `lib/core/utils/egw_extractor.dart:49-220`
- Modify: `lib/services/theme_service.dart` (propriedade `egwUseModernCovers` e setter)
- Create: `lib/views/egw/widgets/egw_book_cover.dart`
- Modify: `lib/views/egw/egw_books_view.dart:450-560`
- Test: `test/egw_catalog_and_covers_test.dart`

**Interfaces:**
- Consumes: `CachedSSTirinhaImage`, `ThemeService`.
- Produces:
  - `EgwBook` fields: `cpbCoverUrlLight` (`String?`), `cpbCoverUrlDark` (`String?`)
  - `ThemeService.egwUseModernCovers` (`bool`), `Future<void> setEgwUseModernCovers(bool value)`
  - `EgwBookCover({required EgwBook book, required bool useModernCover, required bool isDarkMode, double width = 60, double height = 88})`
  - `EgwCpbCoverPainter({required String title, required String abbreviation, required bool isDarkMode})`

- [x] **Step 1: Write the failing test**

```dart
// test/egw_catalog_and_covers_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/egw_models.dart';
import 'package:kairos_web/services/egw_service.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:kairos_web/views/egw/widgets/egw_book_cover.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('EgwService.defaultCatalog contem acervo completo sem IDs duplicados (~79 obras)', () {
    final ids = EgwService.defaultCatalog.map((e) => e['id']!).toList();
    expect(ids.length, greaterThanOrEqualTo(75));
    expect(ids.toSet().length, equals(ids.length));
    expect(ids, containsAll(['1815', '1816', '1813', '1806', '11125', '1947', '1819']));
  });

  test('ThemeService persiste preferencia egwUseModernCovers', () async {
    SharedPreferences.setMockInitialValues({});
    final theme = ThemeService();
    await theme.init();
    await theme.setEgwUseModernCovers(true);
    expect(theme.egwUseModernCovers, isTrue);
    await theme.setEgwUseModernCovers(false);
    expect(theme.egwUseModernCovers, isFalse);
  });

  testWidgets('EgwBookCover renderiza Canvas CPB no modo claro (Taupe/Bronze) e escuro (Grafite/Dourado) sem overflow', (tester) async {
    const book = EgwBook(
      id: '11125',
      title: 'O Grande Conflito',
      abbreviation: 'GC',
    );
    for (final isDark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EgwBookCover(
              book: book,
              useModernCover: true,
              isDarkMode: isDark,
              width: 90,
              height: 132,
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('ELLEN G. WHITE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/egw_catalog_and_covers_test.dart`
Expected: FAIL (`defaultCatalog` has 25 items, `egwUseModernCovers` missing, `egw_book_cover.dart` missing).

- [x] **Step 3: Expand `defaultCatalog` + `EgwExtractor` maps and implement `EgwBookCover` / `EgwCpbCoverPainter`**

1. **`lib/services/egw_service.dart` e `lib/core/utils/egw_extractor.dart`:**
   - Popular `defaultCatalog` com as ~79 obras únicas em Português do catálogo oficial `egwwritings.org` (removendo apenas as 5 duplicatas idênticas da grade do site):
     - Série Conflito (5) + 20 clássicos já presentes;
     - Volumes separados: *Testemunhos para a Igreja* vols. 1–9 (`1T`..`9T`, mantendo `'1819'` ou mapeando os IDs oficiais exatos de cada volume no portal `egwwritings.org`), *Mensagens Escolhidas* vols. 1–3 (`1ME`..`3ME`), *Testemunhos Seletos* vols. 1–3 (`1TS`..`3TS`), *Mente, Caráter e Personalidade* vols. 1–2 (`1MCP`, `2MCP`);
     - Edições condensadas distintas: *O Grande Conflito (Condensado)*, *A Grande Esperança (Condensado)*, *A Ciência do Bom Viver (Condensado)*;
     - Demais títulos únicos do acervo PT (verificar ID oficial exato no endpoint/catálogo `egwwritings.org/pt` antes de comitar): *As Mensagens dos Três Anjos*, *Conselhos sobre Educação* (`1947`), *Conselhos para a Igreja*, *Conselhos aos Idosos*, *Cartas a Jovens Namorados*, *Como Lidar com as Emoções*, *Conselhos aos Professores, Pais e Estudantes*, *Cristo em Seu Santuário*, *Conselhos sobre Saúde*, *Evangelismo*, *Filhas de Deus*, *Foi Por Você*, *Fundamentos da Educação Cristã*, *Fundamentos do Lar Cristão*, *A Igreja Remanescente*, *Lições da Vida de Neemias*, *Liderança Cristã*, *Mensageiros da Esperança*, *Missão nas Cidades*, *Música — Sua Influência na Vida do Cristão*, *Medicina e Salvação*, *No Deserto da Tentação*, *O Colportor Evangelista*, *Orientação da Criança*, *Obreiros Evangélicos*, *O Outro Poder*, *Reavivamento e Seus Resultados*, *Reavivamento Verdadeiro*, *Só Para Jovens*, *Santificação*, *Ser Mãe* (com subtítulo exato conferido no site), *Testemunhos Sobre Conduta Sexual, Adultério e Divórcio*, *Temperança*, *Testemunhos para Ministros e Obreiros Evangélicos*, *Um Convite à Diferença*, *A Verdade Sobre os Anjos*, *Vida no Campo*, *Vida e Ensinos*, *Visões do Céu*.
   - Alinhar `EgwExtractor.bookIdMap`, `abbreviationMap` e `abbreviationToTitleMap`.
2. **`lib/models/egw_models.dart` & `lib/services/theme_service.dart`:**
   - Adicionar campos opcionais `cpbCoverUrlLight` e `cpbCoverUrlDark` em `EgwBook` (mantendo `coverUrl` padrão `https://media4.egwwritings.org/covers/${id}_r.jpg` e compatibilidade total com `egw_books_cache`).
   - Adicionar `bool egwUseModernCovers` (persistida em `SharedPreferences` sob `'egw_use_modern_covers'`) em `ThemeService`.
3. **`lib/views/egw/widgets/egw_book_cover.dart` & `lib/views/egw/egw_books_view.dart`:**
   - Criar `EgwBookCover` (reutilizável) + `EgwCpbCoverPainter` (`CustomPainter`):
     - Modo Antigo (`useModernCover == false`): carrega `book.coverUrl` (`egwwritings.org`) com fallback automático para `EgwCpbCoverPainter`.
     - Modo Novo (`useModernCover == true`): tenta URL oficial CPB (light/dark) se mapeada e online; caso contrário ou offline, desenha o Canvas minimalista CPB de alta definição:
       - **Modo Claro (`!isDarkMode`):** Fundo fosco Taupe (`#8E8880`), vinco 3D suave na lombada à esquerda, três pontos brancos (`•   •   •`) no topo, monograma serifado entrelaçado da sigla (`book.abbreviation`, ex.: `G` e `C`) em Bronze (`#4D3D2E`), título em caixa alta espaçada em `#4D3D2E` e `ELLEN G. WHITE` em branco no rodapé.
       - **Modo Escuro (`isDarkMode`):** Fundo fosco Grafite (`#58595B`), vinco 3D + filete discreto de lombada à esquerda, três pontos brancos (`•   •   •`) no topo, monograma serifado entrelaçado em Dourado Champanhe (`#C5A680`), título em caixa alta espaçada em `#C5A680` e `ELLEN G. WHITE` em branco no rodapé.
   - Em `EgwBooksView`, adicionar botão rápido na barra superior (`Capa CPB` ↔ `Capa Clássica`) ligado a `ThemeService().setEgwUseModernCovers` e substituir a antiga caixa de imagem (`lines 451-478`) por `EgwBookCover`.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/egw_catalog_and_covers_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar `EgwBookCover`, `EgwCpbCoverPainter`, novos campos de `EgwBook` e `ThemeService.setEgwUseModernCovers`, rodar `flutter analyze` e fazer commit (`feat(egw): add full ~79 catalog and adaptive classic/CPB dual covers`).

---

### Task 4: Corrigir Apócrifos (`AVM`), `1 Enoque` (`book_id = 74`) e Fallback Web

**Files:**
- Modify: `lib/data/repositories/bible_repository.dart:32-60, 121-216`
- Modify: `lib/views/bible/widgets/book_chapter_selector_sheet.dart:45-100`
- Modify: `lib/services/content_manager.dart:70-140`
- Create: `scripts/audit_avm_and_enoch.py`
- Test: `test/apocrypha_enoch_test.dart`

**Interfaces:**
- Consumes: `DatabaseManager().getDatabase('AVM.sqlite')`, `BibleExtractor`, `AppConfig.r2AudioBaseUrl`.
- Produces: Suporte a `book_id` `67..74` em `BibleRepository.resolveBookId(String name)` / `_bookAliases`, visibilidade correta em `BookChapterSelectorSheet.filterBooks(...)` e URL fallback Web em `ContentManager`.

- [x] **Step 1: Write the failing test**

```dart
// test/apocrypha_enoch_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/data/repositories/bible_repository.dart';
import 'package:kairos_web/views/bible/widgets/book_chapter_selector_sheet.dart';

void main() {
  test('BibleRepository resolve aliases de deuterocanonicos (67..73) e 1 Enoque (74)', () {
    final repo = BibleRepository();
    expect(repo.resolveBookIdByAlias('1 Macabeus'), isNotNull);
    expect(repo.resolveBookIdByAlias('I Macabeus'), isNotNull);
    expect(repo.resolveBookIdByAlias('Eclesiástico'), isNotNull);
    expect(repo.resolveBookIdByAlias('1 Enoque'), equals(74));
    expect(repo.resolveBookIdByAlias('Enoque'), equals(74));
  });

  test('BookChapterSelectorSheet exibe 1 Enoque na aba Apocrifos e na busca em TODOS', () {
    final enoch = {'id': 74, 'name': '1 Enoque'};
    final romans = {'id': 45, 'name': 'Romanos'};
    expect(
      BookChapterSelectorSheet.matchesFilter(book: enoch, filter: 'APOCRIFOS', query: ''),
      isTrue,
    );
    expect(
      BookChapterSelectorSheet.matchesFilter(book: enoch, filter: 'TODOS', query: 'enoque'),
      isTrue,
    );
    expect(
      BookChapterSelectorSheet.matchesFilter(book: romans, filter: 'APOCRIFOS', query: ''),
      isFalse,
    );
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/apocrypha_enoch_test.dart`
Expected: FAIL (`resolveBookIdByAlias` / `matchesFilter` not defined; `_bookAliases` covers 1..66 only).

- [x] **Step 3: Implement aliases `67..74`, `BookChapterSelectorSheet` normalization, `ContentManager` Web fallback and Python DB audit script**

1. Expandir `_bookAliases` em `lib/data/repositories/bible_repository.dart` para mapear deuterocanônicos (`Tobias`, `Judite`, `Sabedoria`, `Eclesiástico`/`Sirácida`, `Baruc`, `I Macabeus`/`1 Macabeus`, `II Macabeus`/`2 Macabeus`, além de nomes alternativos com acentos/algarismos romanos) e `74` (`1 Enoque`/`Enoque`), expondo `resolveBookIdByAlias`.
2. Atualizar `BookChapterSelectorSheet` (`lib/views/bible/widgets/book_chapter_selector_sheet.dart` linha 74) normalizando acentos e numerais romanos em `_isApocryphalBook`, extraindo `@visibleForTesting static bool matchesFilter(...)`, permitindo que `1 Enoque` apareça na aba `Apócrifos` em qualquer versão que o contenha e também na busca digitada pelo usuário mesmo em `TODOS`.
3. Revisar `ContentManager._parseManifest` (`lib/services/content_manager.dart:104-106`) adicionando fallback seguro caso o download Web de `biblias/$file` falhe no host primário.
4. Criar `scripts/audit_avm_and_enoch.py` para auditar/corrigir `AVM.sqlite` (73 livros) e presença/integridade de `1 Enoque` (`book_id = 74`, 108 capítulos), finalizando com `PRAGMA journal_mode=DELETE; VACUUM;`.

- [x] **Step 4: Run tests and Python compile check to verify pass**

Run: `flutter test test/apocrypha_enoch_test.dart` e `python -m py_compile scripts/audit_avm_and_enoch.py`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar os novos helpers em `bible_repository.dart` e `book_chapter_selector_sheet.dart`, rodar `flutter analyze` e fazer commit (`fix(bible): fix AVM apocrypha aliases, filter logic and 1 Enoch support`).

---

## Sprint 2 — Perícopes, Comentários Expositivos e Missão Integrada nos Planos Bíblicos

### Task 5: Popular `assets/pericopes.sqlite` e `assets/commentaries.sqlite` via Python

**Files:**
- Create: `scripts/generate_pericopes_and_commentaries.py`
- Modify: `assets/pericopes.sqlite`
- Modify: `assets/commentaries.sqlite`
- Test: `test/pericope_and_commentary_test.dart`

**Interfaces:**
- Consumes: schemas esperados por `PericopeRepository` (`pericope(id, book_id, chapter, verse, title)`) e `CommentaryRepository` (`authors(id, name)`, `commentaries(id, author_id, book_id, chapter, verse_start, verse_end, title, content)`).
- Produces: Bancos `assets/pericopes.sqlite` e `assets/commentaries.sqlite` empacotados em modo `DELETE` (`VACUUM`) + modelos `Pericope` e `Commentary` testados.

- [x] **Step 1: Write the failing test**

```dart
// test/pericope_and_commentary_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/study_models.dart';

void main() {
  test('Pericope.fromMap e Commentary.fromMap decodificam registros com author_name e intervalo de versos', () {
    final pericope = Pericope.fromMap({
      'id': 1,
      'book_id': 1,
      'chapter': 1,
      'verse': 1,
      'title': 'A Criação',
    });
    expect(pericope.title, 'A Criação');

    final commentary = Commentary.fromMap({
      'id': 10,
      'book_id': 43,
      'chapter': 3,
      'verse_start': 16,
      'verse_end': 17,
      'title': 'O Amor de Deus',
      'content': 'Explicação expositiva...',
      'author_name': 'Matthew Henry (PT-BR)',
    });
    expect(commentary.authorName, 'Matthew Henry (PT-BR)');
    expect(commentary.verseEnd, 17);
  });
}
```

- [x] **Step 2: Run test to verify script/DB gap**

Run: `python -m py_compile scripts/generate_pericopes_and_commentaries.py`
Expected: FAIL (`No such file or directory`).

- [x] **Step 3: Implement deterministic Python generator `scripts/generate_pericopes_and_commentaries.py`**

Seguindo o padrão de `scripts/generate_biblia_leve.py` e `scripts/package_web_db.py`:
- Gerar `assets/pericopes.sqlite` com tabela `pericope` (`id, book_id, chapter, verse, title`) e índice `idx_pericope_book_chap (book_id, chapter)` cobrindo os 66 livros canônicos (+ apócrifos/Enoque).
- Gerar `assets/commentaries.sqlite` com tabelas `authors (id, name)` e `commentaries (id, author_id, book_id, chapter, verse_start, verse_end, title, content)` com múltiplos autores em PT-BR (**Matthew Henry (PT-BR)**, **Notas EGW / Comentário Adventista**, **Jamieson-Fausset-Brown**), compactado com `PRAGMA journal_mode=DELETE; VACUUM;`.

- [x] **Step 4: Run generator, py_compile and Dart tests**

Run: `python -m py_compile scripts/generate_pericopes_and_commentaries.py`, `python scripts/generate_pericopes_and_commentaries.py` e `flutter test test/pericope_and_commentary_test.dart`
Expected: PASS e ambos `.sqlite` populados com contagem > 0.

- [x] **Step 5: Commit**

Commit (`feat(content): generate PT-BR pericopes.sqlite and multi-author commentaries.sqlite`).

---

### Task 6: Exibir Perícopes no `BibleImmersiveView` & Filtro por Autor no `StudyBottomSheet`

**Files:**
- Modify: `lib/views/bible/widgets/bible_immersive_view.dart:1-120, 260-360`
- Modify: `lib/views/bible/widgets/study_bottom_sheet.dart:1-289`
- Test: `test/pericope_and_commentary_test.dart` (expandir)

**Interfaces:**
- Consumes: `Pericope`, `Commentary` (`lib/models/study_models.dart`).
- Produces: `LoadedChapter(..., List<Pericope> pericopes = const [])` e `StudyBottomSheet` com chips de seleção de autor (`Todos` + autores presentes).

- [x] **Step 1: Write the failing test**

```dart
// Adicionar em test/pericope_and_commentary_test.dart
testWidgets('StudyBottomSheet exibe chips de filtro quando ha multiplos autores e filtra comentarios', (tester) async {
  // Renderiza StudyBottomSheet com comentarios de "Matthew Henry (PT-BR)" e "Notas EGW"
  // Toca no chip "Notas EGW" e verifica que o comentario de Matthew Henry deixa de aparecer.
});
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/pericope_and_commentary_test.dart`
Expected: FAIL (chips de autor ainda não existem no `StudyBottomSheet` e `LoadedChapter` não aceita `pericopes`).

- [x] **Step 3: Implement `pericopes` in `LoadedChapter`/`BibleImmersiveView` and author filter chips in `StudyBottomSheet`**

1. Adicionar `final List<Pericope> pericopes;` com padrão `const []` em `LoadedChapter` (`bible_immersive_view.dart`) e renderizar cada título de perícope antes do versículo correspondente mantendo coerência visual com `BibleReaderView`.
2. Em `StudyBottomSheet`, derivar dinamicamente os autores únicos da lista de `Commentary` e renderizar uma linha rolável de `FilterChip`/`ChoiceChip` (`Todos`, mais cada autor), protegida contra overflow.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/pericope_and_commentary_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar `LoadedChapter.pericopes` e o filtro de autores em `StudyBottomSheet`, rodar `flutter analyze` e fazer commit (`feat(study): add pericopes to immersive view and author filter in StudyBottomSheet`).

---

### Task 7: Missão Diária Integrada (Bíblia → EGW capítulo exato) nos Planos de Leitura

**Files:**
- Modify: `lib/models/reading_plan_models.dart:70-150`
- Modify: `lib/services/reading_plan_service.dart:1-320`
- Modify: `lib/views/egw/egw_reader_view.dart:1-100`
- Modify: `lib/views/plans/reading_plans_view.dart:570-772`
- Create: `lib/views/plans/widgets/reading_plan_floating_pill.dart`
- Test: `test/reading_plan_egw_mission_test.dart`

**Interfaces:**
- Consumes: `UserPlanProgress.currentDayCompletedChapters` (`'current_chapters_json'`), `GamificationService`.
- Produces:
  - `EgwPlanMissionRef({required String bookId, required String bookTitle, required int chapterNumber, String get progressKey => 'EGW:$bookId:$chapterNumber'})`
  - `ReadingPlanDay.parseEgwMission()`
  - `EgwReaderView(..., int? initialChapterNumber)`
  - `ReadingPlanService.completeEgwMissionStep(...)` (`+25` gotas, idempotente)

- [x] **Step 1: Write the failing test**

```dart
// test/reading_plan_egw_mission_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/models/reading_plan_models.dart';

void main() {
  test('EgwPlanMissionRef gera progressKey consistente dentro de currentDayCompletedChapters', () {
    final day = ReadingPlanDay(
      dayNumber: 1,
      title: 'A Criação',
      chapters: const [ReadingPlanChapterRef(bookId: 1, bookName: 'Gênesis', chapter: 1)],
      egwNote: 'Patriarcas e Profetas, cap. 2',
    );
    final mission = day.parseEgwMission();
    expect(mission, isNotNull);
    expect(mission!.bookId, '1815');
    expect(mission.chapterNumber, 2);
    expect(mission.progressKey, 'EGW:1815:2');
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/reading_plan_egw_mission_test.dart`
Expected: FAIL (`parseEgwMission` not defined).

- [x] **Step 3: Implement 2-stage Bible -> EGW mission flow reusing `currentDayCompletedChapters`**

1. Adicionar `EgwPlanMissionRef` e `parseEgwMission()` em `ReadingPlanDay` reaproveitando `egwSuggestion` + detecção do número do capítulo (ex.: `cap. N` / `capítulo N`), gerando a chave `'EGW:$bookId:$chapterNumber'` armazenada no conjunto já existente `UserPlanProgress.currentDayCompletedChapters` (zero quebra de schema no SQLite `user_reading_plans`).
2. Adicionar `final int? initialChapterNumber;` opcional em `EgwReaderView` para abrir automaticamente o capítulo exato do sumário após `getTableOfContents`.
3. Em `ReadingPlanService`, implementar `completeEgwMissionStep` concedendo `+25` gotas uma única vez por chave `'EGW:...'` no dia.
4. No `_PlanDetailsBottomSheet` (`reading_plans_view.dart`), exibir visualmente **Etapa 1 (Leitura Bíblica)** → **Etapa 2 (Espírito de Profecia — Cap. X)** abrindo `EgwReaderView(initialChapterNumber: ...)` e renderizar `ReadingPlanFloatingPill` com botão de concluir missão ao fim da leitura.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/reading_plan_egw_mission_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar `EgwPlanMissionRef`, `parseEgwMission`, `completeEgwMissionStep`, `EgwReaderView.initialChapterNumber` e `ReadingPlanFloatingPill`, rodar `flutter analyze` e fazer commit (`feat(plans): turn EGW suggestions into 2-stage missions opening exact chapter`).

---

## Sprint 3 — Marcadores da Lição (`ss_highlights`) & Sincronização Híbrida na Nuvem

### Task 8: Tabela `ss_highlights` e Marcadores de Parágrafo na Lição (`SabbathSchoolView`)

**Files:**
- Modify: `lib/core/database/database_manager.dart:1-80`
- Modify: `lib/data/services/sabbath_school_service.dart`
- Modify: `lib/views/lesson/sabbath_school_view.dart`
- Test: `test/ss_highlights_test.dart`

**Interfaces:**
- Consumes: `DatabaseManager.userPreservedTables`, paleta de cores de marca-texto bíblico.
- Produces: Tabela `ss_highlights (id TEXT PRIMARY KEY, quarterly_id TEXT, lesson_id TEXT, day_id TEXT, paragraph_index INTEGER, color_hex TEXT, updated_at INTEGER)` + CRUD `getHighlights`, `saveHighlight`, `removeHighlight` em `SabbathSchoolService`.

- [x] **Step 1: Write the failing test**

```dart
// test/ss_highlights_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/database/database_manager.dart';

void main() {
  test('DatabaseManager.userPreservedTables inclui ss_highlights', () {
    expect(DatabaseManager.userPreservedTables, contains('ss_highlights'));
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/ss_highlights_test.dart`
Expected: FAIL (`ss_highlights` ainda não está em `userPreservedTables`).

- [x] **Step 3: Add `ss_highlights` table, service CRUD and highlight UI in `SabbathSchoolView`**

1. Adicionar `'ss_highlights'` em `DatabaseManager.userPreservedTables`.
2. Criar tabela `ss_highlights` e métodos `getHighlights`, `saveHighlight`, `removeHighlight`, `exportHighlightsForSync`, `importHighlightsWithMerge` em `SabbathSchoolService` (seguro para Android e Web).
3. Em `SabbathSchoolView`, permitir destacar parágrafos com barra de cores reutilizada da Bíblia (e limpar destaque), respeitando tema e acessibilidade.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/ss_highlights_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar os novos métodos em `SabbathSchoolService`, rodar `flutter analyze` e fazer commit (`feat(lesson): add ss_highlights table and paragraph highlighting UI`).

---

### Task 9: Sincronização Híbrida na Nuvem (`AuthService` + Serviços de Estado)

**Files:**
- Modify: `lib/services/gamification_service.dart:740-883`
- Modify: `lib/services/reading_plan_service.dart`
- Modify: `lib/data/repositories/bible_repository.dart`
- Modify: `lib/data/services/sabbath_school_service.dart`
- Modify: `lib/services/solar_service.dart`
- Modify: `lib/services/auth_service.dart:200-520`
- Test: `test/cloud_sync_merge_test.dart`

**Interfaces:**
- Consumes: `ThemeService` (inclusive `egwUseModernCovers` e toggles de gestos), `GamificationService`, `ReadingPlanService`, `BibleRepository`, `SabbathSchoolService`, `SolarService`.
- Produces:
  - `GamificationService.mergeCloudState(Map<String, dynamic> cloud)` (puro e testável)
  - `ReadingPlanService.mergeCloudPlans(...)` (`Set.union` em `completedDays` e `currentDayCompletedChapters`)
  - `BibleRepository.syncHighlightsFromCloud()` (pull bidirecional além do `POST` existente)
  - `AuthService.syncPreferencesToCloud()` & `_applyUserCloudPreferences(...)` sincronizando também `egw_use_modern_covers`, `activityDates` mensais, `unlockedTrophies`, `avatarConfig`, planos, lição (`ss_user_notes`, `ss_question_answers`, `ss_highlights`), `verse_highlights` e cidade do pôr do sol (`SolarService`) + `sunsetReminderEnabled`.

- [x] **Step 1: Write the failing test**

```dart
// test/cloud_sync_merge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/services/gamification_service.dart';

void main() {
  test('mergeActivityDates une datas locais e da nuvem sem perder dias da ofensiva mensal', () {
    final merged = GamificationService.mergeActivityDates(
      localDates: {'2026-11-01', '2026-11-03'},
      cloudDates: ['2026-11-02', '2026-11-03', '2026-11-04'],
    );
    expect(merged, {'2026-11-01', '2026-11-02', '2026-11-03', '2026-11-04'});
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/cloud_sync_merge_test.dart`
Expected: FAIL (`mergeActivityDates` not defined).

- [x] **Step 3: Implement pure hybrid merge helpers and orchestrate pull+push in `AuthService`**

Implementar `mergeActivityDates`, `mergeCloudSets` e `mergeByUpdatedAt` sem duplicação de código; atualizar `GamificationService` (incluindo `avatarConfig`, `_activityDates`, `_unlockedTrophies`, totais), `ReadingPlanService`, `BibleRepository.syncHighlightsFromCloud`, `SabbathSchoolService`, `SolarService` (hook de sync ao salvar cidade), `ThemeService` (`egw_use_modern_covers` + gestos) e `AuthService` (com fallback seguro quando offline ou quando Supabase retornar erro HTTP, preservando o estado local).

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/cloud_sync_merge_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar todos os métodos de merge/sync com `///`, rodar `flutter analyze` e fazer commit (`feat(sync): add hybrid cloud merge for streaks, plans, SS highlights, covers and solar city`).

---

## Sprint 4 — Eliminação de Botões Duplicados, Gestos Opcionais e Acessibilidade

### Task 10: Eliminar botões duplicados de fechar/sair em Dialogs e Bottom Sheets

**Files:**
- Modify: `lib/views/settings/settings_dialog.dart:90-166`
- Modify: `lib/views/downloads/downloads_dialog.dart:56-186`
- Modify: `lib/views/bible/widgets/bible_verse_preview_modal.dart:298-335`
- Modify: `lib/views/profile/profile_dialog.dart:350-376`
- Modify: `lib/views/lesson/widgets/egw_citation_sheet.dart:100-120`
- Modify: `lib/views/lesson/widgets/egw_summary_bottom_sheet.dart:115-135`
- Modify: `lib/views/lesson/widgets/lesson_selection_sheet.dart:70-90`
- Modify: `lib/views/lesson/widgets/quick_quiz_bottom_sheet.dart:160-180`
- Modify: `lib/views/bible/widgets/study_bottom_sheet.dart:80-100`
- Test: `test/ui_gestures_and_a11y_test.dart`

**Interfaces:**
- Consumes: `ThemeService`.
- Produces: Padrão único de saída — **Dialogs** possuem apenas `IconButton(Icons.close_rounded)` no canto superior direito com `Semantics(label: 'Fechar')` e `Tooltip`; **Draggable Bottom Sheets** mantêm apenas a alça superior (sem `X` duplicado).

- [x] **Step 1: Write the failing test**

```dart
// test/ui_gestures_and_a11y_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/views/downloads/downloads_dialog.dart';

void main() {
  testWidgets('DownloadsDialog exibe exatamente 1 botao de fechar sem botao Concluir duplicado', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: DownloadsDialog())));
    await tester.pump();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.text('Concluir'), findsNothing);
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui_gestures_and_a11y_test.dart`
Expected: FAIL (`Concluir` button still exists).

- [x] **Step 3: Remove duplicate exit buttons across all 4 Dialogs and 5 Bottom Sheets**

Remover os botões inferiores redundantes (`Fechar`/`Concluir`) em `SettingsDialog`, `DownloadsDialog`, `BibleVersePreviewModal` e `ProfileDialog` (garantindo o `IconButton(Icons.close_rounded)` único no cabeçalho de `ProfileDialog`), e remover os `IconButton(Icons.close)` duplicados nos 5 Bottom Sheets com drag handle.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui_gestures_and_a11y_test.dart`
Expected: PASS

- [x] **Step 5: Commit**

Rodar `flutter analyze` nos 9 arquivos e fazer commit (`fix(ui): remove duplicate close buttons from dialogs and draggable bottom sheets`).

---

### Task 11: Sistema de Gestos Opcionais, Controles nas Configurações & Acessibilidade / Cartão de Conclusão no `BibleImmersiveView`

**Files:**
- Modify: `lib/services/theme_service.dart` (toggles `gesturesEnabled`, `gestureSwipeChapters`, `gesturePinchFont`, `gestureDoubleTapHighlight`)
- Modify: `lib/views/settings/settings_dialog.dart` (seção "Gestos & Leitura" + switch "Capa Nova (CPB) no Espírito de Profecia")
- Create: `lib/widgets/kairos_reader_gesture_layer.dart`
- Modify: `lib/views/bible/bible_reader_view.dart`
- Modify: `lib/views/bible/widgets/bible_immersive_view.dart`
- Modify: `lib/views/lesson/sabbath_school_view.dart`
- Modify: `lib/views/egw/egw_reader_view.dart`
- Modify: `lib/views/hymns/hymn_detail_view.dart`
- Test: `test/ui_gestures_and_a11y_test.dart` (expandir)

**Interfaces:**
- Consumes: `ThemeService`.
- Produces:
  - `ThemeService` getters/setters: `gesturesEnabled`, `gestureSwipeChapters`, `gesturePinchFont`, `gestureDoubleTapHighlight`
  - `KairosReaderGestureLayer` (reutilizável em todas as 5 telas de leitura sem duplicação de código)
  - Cartão de conclusão por `LoadedChapter` no `BibleImmersiveView`

- [x] **Step 1: Write the failing test**

```dart
// Adicionar em test/ui_gestures_and_a11y_test.dart
testWidgets('KairosReaderGestureLayer bloqueia callbacks quando gesturesEnabled == false', (tester) async {
  bool swiped = false;
  await tester.pumpWidget(
    MaterialApp(
      home: KairosReaderGestureLayer(
        gesturesEnabled: false,
        enableSwipe: true,
        onNextPage: () => swiped = true,
        child: const SizedBox(width: 300, height: 400),
      ),
    ),
  );
  await tester.fling(find.byType(KairosReaderGestureLayer), const Offset(-200, 0), 800);
  expect(swiped, isFalse);
});
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui_gestures_and_a11y_test.dart`
Expected: FAIL (`KairosReaderGestureLayer` not defined).

- [x] **Step 3: Implement gesture settings, `KairosReaderGestureLayer`, 5-view integration & `BibleImmersiveView` completion card**

1. Persistir `gesturesEnabled`, `gestureSwipeChapters`, `gesturePinchFont` e `gestureDoubleTapHighlight` em `ThemeService`.
2. Expor no `SettingsDialog` o controle mestre + 3 sub-switches de gestos + switch `Capa Nova (CPB) no Espírito de Profecia`.
3. Implementar `KairosReaderGestureLayer` cuidando para que swipe horizontal não conflite com rolagem vertical e que zoom de pinça respeite faixa segura (`12.0..34.0`), integrando em `BibleReaderView`, `BibleImmersiveView`, `SabbathSchoolView`, `EgwReaderView` e `HymnDetailView` (plus duplo-toque em versículos/parágrafos).
4. Adicionar cartão de conclusão de capítulo em `BibleImmersiveView` e `Semantics` descritivos nos leitores e botões.

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui_gestures_and_a11y_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar `KairosReaderGestureLayer` e os toggles de `ThemeService`, rodar `flutter analyze` e fazer commit (`feat(ux): add optional configurable reader gestures, a11y semantics and immersive completion card`).

---

## Sprint 5 — Temas (`Real Glass`, `Retrô ICS Holo`, `Windows 95`), Edge Cases e Documentação Final

### Task 12: Preservar `"Liquid Glass"` & `"Apple Glass"` e adicionar `realGlass`, `holoRetro` e `win95`

**Files:**
- Modify: `lib/core/theme/app_theme.dart:1-80, 1000-1376`
- Modify: `lib/services/theme_service.dart:116-324, 480-501`
- Modify: `lib/views/settings/settings_dialog.dart` (`_AppearanceTab`)
- Test: `test/themes_test.dart`

**Interfaces:**
- Consumes: `dart:ui` (`ImageFilter.matrix`, `ImageFilter.blur`), `KairosPalette`.
- Produces: `AppThemeStyle.realGlass` (`"Real Glass"`), `AppThemeStyle.holoRetro` (`"Retrô ICS Holo"`), `AppThemeStyle.win95` (`"Windows 95"`), atualização de `ThemeService.isAnyGlass` (`liquidGlass || appleGlass || realGlass`).

- [x] **Step 1: Write the failing test**

```dart
// test/themes_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kairos_web/core/theme/app_theme.dart';
import 'package:kairos_web/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ThemeService preserva Liquid Glass/Apple Glass e suporta realGlass, holoRetro e win95', () async {
    SharedPreferences.setMockInitialValues({});
    final service = ThemeService();
    await service.init();

    await service.setThemeStyle(AppThemeStyle.realGlass);
    expect(service.isAnyGlass, isTrue);

    await service.setThemeStyle(AppThemeStyle.holoRetro);
    expect(service.getPalette(Brightness.dark).accent, const Color(0xFF33B5E5));

    await service.setThemeStyle(AppThemeStyle.win95);
    expect(service.getPalette(Brightness.light).scaffoldBackground, const Color(0xFF008080));
  });
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `flutter test test/themes_test.dart`
Expected: FAIL (`realGlass`, `holoRetro`, `win95` undefined).

- [x] **Step 3: Implement `realGlass`, `holoRetro` and `win95` styles in `app_theme.dart`, `theme_service.dart` and `settings_dialog.dart`**

- **`realGlass` (`"Real Glass"`):** Implementar em `GlassSurface` usando `dart:ui` nativo (`ImageFilter.matrix` sutil para refração + `BackdropFilter`, dispersão cromática nas extremidades, sheen cáustico dinâmico e borda especular dupla), mantendo fallback seguro se Web antigo não compor `ImageFilter.matrix`.
- **`holoRetro` (`"Retrô ICS Holo"`):** Estilo Android 4.0 ICS (2011) — azul `#33B5E5`, `BorderRadius.zero`, fundo `#000000` → `#101824`, divisores `2px` `#33B5E5`, botões `#282828` chanfrados.
- **`win95` (`"Windows 95"`):** Fundo `#008080`, superfícies `#C0C0C0`, bordas 3D `#FFFFFF` (topo/esquerda) + `#808080`/`#000000` (base/direita) com `BorderRadius.zero` e barra `#000080`.
- Atualizar `ThemeService.isAnyGlass` e chips de escolha em `_AppearanceTab` (`settings_dialog.dart`).

- [x] **Step 4: Run test to verify it passes**

Run: `flutter test test/themes_test.dart`
Expected: PASS

- [x] **Step 5: Document with Dartdoc (`///`) & Commit**

Documentar os 3 novos `AppThemeStyle`s e helpers de renderização, rodar `flutter analyze` e fazer commit (`feat(theme): add Real Glass, Retrô ICS Holo and Windows 95 themes`).

---

### Task 13: Bateria Final de Edge Cases (`TextScaler.linear(2.0)`) & Pass Final `/dart-write-documentation`

**Files:**
- Modify: APIs públicas e helpers alterados nos Sprints 1–5 (`egw_service.dart`, `egw_models.dart`, `egw_book_cover.dart`, `bible_repository.dart`, `pericope_repository.dart`, `commentary_repository.dart`, `reading_plan_models.dart`, `reading_plan_service.dart`, `auth_service.dart`, `gamification_service.dart`, `sabbath_school_service.dart`, `theme_service.dart`, `app_theme.dart`, `kairos_reader_gesture_layer.dart`)
- Test: expandir `test/ui_gestures_and_a11y_test.dart` + rodar toda suíte `test/` (incluindo `test/sunset_notification_test.dart`)

- [x] **Step 1: Add `TextScaler.linear(2.0)` edge-case widget tests**

Envolver `SettingsDialog`, `ProfileDialog`, `EgwBooksView`, `EgwBookCover` e `StudyBottomSheet` em `MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2.0)))` garantindo zero `RenderFlex` overflow.

- [x] **Step 2: Run full test suite & static analysis**

Run: `flutter test` e `flutter analyze`
Expected: PASS em 100% dos casos sem skips; `0` erros e `0` warnings novos (incluindo `comment_references`).

- [x] **Step 3: Audit Dartdoc (`/dart-write-documentation`) & final check**

Verificar padrão `///` (primeira frase concisa, `[param]`, retornos e casos de borda, sem importar tipos privados nas assinaturas documentadas), confirmar ausência de `dart:io` direto em código compartilhado e finalizar commit (`docs: complete Dartdoc coverage and final accessibility edge-case tests`).
