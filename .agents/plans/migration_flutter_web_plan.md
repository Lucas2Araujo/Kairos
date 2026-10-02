# Planejamento de Acabamentos e Funcionalidades: Kairós Web vs App (Flet)

> **Documento gerado via orquestração /boost** comparando o app Flet (`src/`, `main.py`) com o Flutter Web (`kairos_web/`).

---

## 1. Resumo do Diagnóstico de Gaps

| Recurso | App Desktop (Flet) | App Web Atual (Flutter) | Status / O que falta |
| :--- | :--- | :--- | :--- |
| **Recursos de Estudo Bíblico** | Perícopes, Comentários bíblicos e Referências cruzadas completas | Modelos criados (`study_models.dart`), mas sem repositórios nem UI no leitor | **Pendente**: Repositórios + BottomSheet de Estudo + Títulos de perícopes |
| **Áudio do Hinário** | Player de áudio cantado e instrumental integrado | Sem dependência de áudio e sem player de controle | **Pendente**: Adicionar `audioplayers`, player flutuante e URLs de CDN |
| **Hinário Comparativo** | Comparação lado a lado (HA1996 vs HA2022) com resumo de alterações | Ausente | **Pendente**: Adicionar `hinario_comparativo.db` no `pubspec.yaml`, criar repositório e tela/modal |
| **Atalhos Bíblicos no Hino** | `make_hymn_context_bar` com chips para versículos relacionados | Apenas texto simples do hino | **Pendente**: Chips de textos bíblicos correlacionados com clique para abrir Bíblia |
| **Personalização & Acessibilidade** | Seletor de fontes (`OpenDyslexic`, `Montserrat`, etc.) e zoom de fonte | Fontes no asset, mas sem controle no `SettingsDialog` ou `ThemeService` | **Pendente**: Seleção de fonte e tamanho persistidos nas preferências |
| **Persistência de Preferências** | Flet client storage / settings | Apenas VFS SQLite IndexedDB; sem `shared_preferences` ativo | **Pendente**: Persistência de tema, favoritos e última leitura |
| **Meditação Diária (Devocional)** | Devocionais (Jovem, Diário, Mulher) via Supabase + Cache SQLite local + Carrossel de datas | Ausente na versão Web | **Pendente**: Modelo, Repositório/Service REST, Controller e View com carrossel |
| **Hub Inicial (Home View)** | Dashboard com versículo do dia, atalhos rápidos e status de culto | Abre direto no Hinário/Bíblia | **Pendente**: Tela inicial de acolhimento |

---

## 2. Plano de Ação por Arquivos (Plan with Files)

### Fase 1: Recursos de Estudo Bíblico (Comentários, Perícopes, Referências)

- [x] **`kairos_web/lib/data/repositories/pericope_repository.dart`** (Novo)
  - Consultar banco `pericopes.sqlite` (`pericope` com `book_id`, `chapter`, `verse`, `title`).
  - Carregar títulos de seções para interpolar no `BibleReaderView`.
- [x] **`kairos_web/lib/data/repositories/cross_reference_repository.dart`** (Novo)
  - Consultar `cross_references.sqlite` por versículo de origem (`from_book_id`, `from_chapter`, `from_verse`).
  - Retornar listas de referências ordenadas por relevância/votos.
- [x] **`kairos_web/lib/data/repositories/commentary_repository.dart`** (Novo)
  - Consultar `commentaries.sqlite` unindo comentários com autores.
  - Métodos `getCommentariesForVerse(bookId, chapter, verse)`.
- [x] **`kairos_web/lib/controllers/bible_controller.dart`**
  - Integrar os novos repositórios.
  - Adicionar estados: `selectedVerseForStudy`, `isLoadingStudyData`, `currentPericopes`.
- [x] **`kairos_web/lib/views/bible/bible_reader_view.dart`**
  - Renderizar títulos de perícopes antes dos versículos correspondentes.
  - Adicionar clique/toque no versículo para abrir `StudyDrawer` ou `ModalBottomSheet`.
- [x] **`kairos_web/lib/views/bible/widgets/study_bottom_sheet.dart`** (Novo)
  - Abas: "Referências Cruzadas" e "Comentários Expositivos".

---

### Fase 2: Hinário - Áudio, Comparativo e Navegação Cruzada

- [x] **`kairos_web/pubspec.yaml`**
  - Registrar asset `assets/hinario_comparativo.db`.
- [x] **`kairos_web/lib/data/repositories/comparativo_repository.dart`** (Novo)
  - Ler banco `hinario_comparativo.db` tabela `comparativo_hinos` (`diff_texto`, `diff_json`, `resumo_alteracoes`).
- [x] **`kairos_web/lib/controllers/hymn_controller.dart`**
  - Buscar referências bíblicas correlatas do hino.
- [x] **`kairos_web/lib/views/hymns/widgets/hymn_audio_player_widget.dart`** (Novo)
  - Barra de áudio flutuante compacta no rodapé com play/pause, slider de tempo e seletor de faixa.
- [x] **`kairos_web/lib/views/hymns/widgets/hymn_comparativo_dialog.dart`** (Novo)
  - Visualização comparativa lado a lado com destaques de alterações entre versões de 1996 e 2022.
- [x] **`kairos_web/lib/views/hymns/hymn_detail_view.dart`**
  - Inserir barra de contexto bíblico (`make_hymn_context_bar`): chips clicáveis que navegam direto para o leitor bíblico.
  - Integrar o widget de áudio e botão para abrir o comparativo.

---

### Fase 3: Configurações, Acessibilidade e Persistência

- [x] **`kairos_web/lib/core/theme/theme_service.dart`**
  - Adicionar variáveis reativas: `selectedFontFamily` (`AppSans`, `HymnSerif`, `Montserrat`, `OpenDyslexic`) e `fontSizeMultiplier` (0.8 a 1.6).
  - Aplicar tema tipográfico dinâmico nos `TextTheme`.
- [x] **`kairos_web/lib/views/settings/settings_dialog.dart`**
  - Adicionar Dropdown de fonte e Slider de tamanho de fonte.
  - Alternância de tema claro/escuro com feedback imediato.

---

### Fase 4: Meditação Diária (Devocional)

- [x] **`kairos_web/lib/models/devotional.dart`** (Novo)
  - Modelo `Devotional` (`published_at`, `title`, `verse_text`, `verse_reference`, `content`, `category`, `author`, `source_url`).
- [x] **`kairos_web/lib/services/devotional_service.dart`** (Novo)
  - Integração com Supabase REST via `AppConfig` e cache com fallback local completo.
  - Suporte a categorias: `jovem`, `diario`, `mulher`.
- [x] **`kairos_web/lib/controllers/devotional_controller.dart`** (Novo)
  - Controle de data selecionada (hoje ou últimos 7 dias via carrossel).
  - Categoria ativa e gerenciamento de estado de carregamento/erro.
- [x] **`kairos_web/lib/views/devotional/devotional_view.dart`** (Novo)
  - Seletor de categoria em chips (`Jovem`, `Adultos`, `Mulher`).
  - Carrossel horizontal de seleção dos últimos 7 dias com indicador de leitura.
  - Card estilizado do versículo-chave com clique para abrir no leitor bíblico.
  - Visualizador de conteúdo com suporte às fontes e zoom do leitor.
- [x] **`kairos_web/lib/views/navigation/main_navigation_view.dart`**
  - Adicionar aba "Meditação" na barra de navegação/rail.

---

### Fase 5: Hub Inicial / Home View

- [x] **`kairos_web/lib/views/home/home_view.dart`** (Novo)
  - Card de boas-vindas com saudação dinâmica.
  - "Versículo do Dia" com salto para leitura bíblica.
  - Card de destaque da Meditação de Hoje.
  - Atalhos rápidos em cards: "Bíblia Sagrada", "Hinário", "Meditação", "Escola Sabatina".
- [x] **`kairos_web/lib/views/navigation/main_navigation_view.dart`**
  - Inserir aba "Início" como primeira opção no `NavigationBar` / `NavigationRail`.

---

## 3. Ordem Recomendada de Implementação

1. **Acessibilidade e Fontes**: Ajuste rápido e alto ganho imediato de usabilidade (`SettingsDialog` + `ThemeService`).
2. **Estudo Bíblico**: Implementar repositórios e `StudyBottomSheet` no `BibleReaderView`.
3. **Meditação Diária (Devocional)**: Conectar REST Supabase, carrossel de 7 dias e visualizador devocional.
4. **Áudio e Comparativo no Hinário**: Incluir pacote `audioplayers`, player flutuante e comparativo.
5. **Chips Bíblicos nos Hinos**: Integração fluida entre Hinário e Bíblia.
6. **Home View**: Polimento final da experiência de entrada do usuário.
