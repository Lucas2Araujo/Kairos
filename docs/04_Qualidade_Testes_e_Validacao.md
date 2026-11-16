# 04 — Engenharia de Qualidade, Testes e Validação — Kairós

> **Metodologia:** Ciclo Agêntico em Malha Fechada (*Planejar $\rightarrow$ Executar $\rightarrow$ Validar com Casos de Borda*) alinhado às diretrizes de [`AGENTS.md`](../AGENTS.md) e ao polimento das 5 Sprints.

---

## 1. Estratégia de Garantia da Qualidade (QA)

O projeto **Kairós** adota práticas rigorosas de verificação automatizada e análise estática antes de qualquer entrega ou release:

1. **Test-Driven Development (TDD) para Regressões e Novos Recursos:** Cada correção crítica ou funcionalidade (cache parcial EGW, aliases de Apócrifos/1 Enoque, perícopes, filtro de comentários por autor, missão EGW em 2 etapas, `ss_highlights`, merge híbrido de nuvem, gestos configuráveis e temas novos) é coberta por casos de teste unitários ou de widget reproduzíveis sem rede.
2. **Análise Estática e Higiene de Código (`flutter analyze`):** Verificação contínua de tipagem estrita, conformidade com `flutter_lints` (`analysis_options.yaml`), ausência de imports diretos de `dart:io` em código compartilhado e verificação de referências cruzadas em comentários (`comment_references`).
3. **Cobertura de Documentação Dartdoc (`///`):** Documentação concisa de APIs públicas, parâmetros entre colchetes (`[param]`), comportamentos de retorno e casos de borda.
4. **Validação de Scripts de Dados Python:** Todos os geradores e auditores SQLite em `scripts/` são validados via `python -m py_compile` e executam `PRAGMA journal_mode=DELETE; VACUUM;` para garantir compatibilidade entre Android (`sqlite3` FFI) e Web (`sql.js`).
5. **Testes de Estresse de Acessibilidade e Viewport:** Renderização automatizada sob `TextScaler.linear(2.0)` em viewports compactos (`320x640`) e verificação das diretrizes `androidTapTargetGuideline` ($\ge 48\text{dp}$) e `labeledTapTargetGuideline`.

---

## 2. Matriz de Rastreabilidade (Requisitos $\times$ Casos de Borda $\times$ Testes)

A tabela abaixo rastreia os cenários críticos de revisão definidos no plano de polimento final até os arquivos de teste que os validam:

| Foco / Caso de Borda | Requisitos Relacionados | Implementação Verificada | Arquivo(s) de Teste |
| :--- | :--- | :--- | :--- |
| **Cache parcial do EGW (1 capítulo salvo online)** | `RF11` | `EgwService.shouldBypassTocCache` + `EgwBook.evaluateDownloadCompleteness` | `test/egw_service_download_test.dart` |
| **Referências bíblicas inline clicáveis no leitor EGW** | `RF13` | `EgwLinkableParagraph` com `TapGestureRecognizer` gerenciados e `BibleVersePreviewModal` | `test/egw_reader_links_test.dart` |
| **Catálogo ~79 obras PT e Capa Nova CPB offline (Claro/Escuro)** | `RF10`, `RF12` | `EgwService.defaultCatalog` (79 itens) + `EgwBookCover` + `EgwCpbCoverPainter` | `test/egw_catalog_and_covers_test.dart` |
| **Apócrifos (`AVM`) e `1 Enoque` (`book_id = 74`) na busca/filtros** | `RF05`, `RF09` | `BibleRepository.resolveBookIdByAlias`, `BookChapterSelectorSheet.matchesFilter`, `ContentManager.buildFallbackUrls` | `test/apocrypha_enoch_test.dart`, `scripts/audit_avm_and_enoch.py` |
| **Perícopes no Modo Imersivo e filtro por autor no estudo** | `RF06`, `RF07` | `LoadedChapter.pericopes` (`BibleImmersiveView`) + chips de autor em `StudyBottomSheet` | `test/pericope_and_commentary_test.dart` |
| **Missão diária em 2 etapas Bíblia $\rightarrow$ EGW (+25 gotas idempotentes)** | `RF14` | `ReadingPlanDay.parseEgwMission`, `EgwPlanMissionRef`, `ReadingPlanService.completeEgwMissionStep` | `test/reading_plan_egw_mission_test.dart`, `test/reading_plan_and_oil_test.dart` |
| **Preservação de `ss_highlights` em atualizações de assets SQLite** | `RF16`, `RNF02` | `DatabaseManager.userPreservedTables`, `SabbathSchoolService` CRUD & merge | `test/ss_highlights_test.dart`, `test/db_migration_test.dart` |
| **Merge híbrido na nuvem entre dispositivos offline disjuntos** | `RF24`, `RNF10` | `GamificationService.mergeActivityDates` / `mergeCloudMetadata`, `ReadingPlanService.mergeCloudPlans`, `AuthService` | `test/cloud_sync_merge_test.dart`, `test/gamification_and_auth_test.dart` |
| **Botão único de fechamento em modais e alça única em bottom sheets** | `RF25` | `DownloadsDialog`, `SettingsDialog`, `ProfileDialog`, `BibleVersePreviewModal` e 5 sheets | `test/ui_gestures_and_a11y_test.dart` |
| **Gestos inertes quando `gesturesEnabled == false` e `TextScaler.linear(2.0)`** | `RF26`, `RF30`, `RNF07` | `KairosReaderGestureLayer`, `SettingsDialog`, `ProfileDialog`, `EgwBookCover`, `StudyBottomSheet` | `test/ui_gestures_and_a11y_test.dart`, `test/ui_polish_edge_cases_test.dart` |
| **Temas preservados (`Liquid`/`Apple Glass`) + `realGlass`, `holoRetro`, `win95`** | `RF27` | `AppThemeStyle`, `RealGlassSurface`, `Win95BevelBox`, `KairosPalette`, `ThemeService` | `test/themes_test.dart`, `test/theme_engine_test.dart` |
| **Cálculo solar NOAA e lembretes de Pôr do Sol** | `RF03` | `SolarService`, `NotificationService` | `test/sunset_notification_test.dart`, `test/classroom_and_sunset_test.dart` |

---

## 3. Inventário Completo da Suíte de Testes Automatizados

A suíte localizada em `test/` é composta por **41 arquivos de teste**, totalizando **302 casos individuais (`test` e `testWidgets`)**:

| Arquivo de Teste | Domínio Coberto | Casos (`test` / `testWidgets`) |
| :--- | :--- | :---: |
| `test/apocrypha_enoch_test.dart` | Aliases deuterocanônicos (`67..73`), `1 Enoque` (`74`), filtros e fallback Web | 15 |
| `test/audio_ui_and_onboarding_test.dart` | UI de áudio e fluxo de boas-vindas (`WelcomeDialog`) | 4 |
| `test/bible_extractor_test.dart` | Expressões regulares e extração de passagens bíblicas em texto | 14 |
| `test/bible_immersive_view_test.dart` | Modo Livro Imersivo, rolagem e seleção de versículos | 6 |
| `test/bible_reader_and_quiz_improvements_test.dart` | Melhorias de leitura bíblica e quizzes | 7 |
| `test/bible_scroll_and_highlight_test.dart` | Rolagem automática e destaques em versículos | 5 |
| `test/classroom_and_sunset_test.dart` | Gestão de turmas (`ClassroomService`) e lógica solar | 9 |
| `test/cloud_sync_merge_test.dart` | Merge híbrido sem regressão (`mergeActivityDates`, planos, nuvem) | 3 |
| `test/data/models_test.dart` | Serialização e integridade dos modelos de domínio | 7 |
| `test/db_migration_test.dart` | Preservação de dados de usuário (`dumpUserTables` / `restoreUserTables`) | 7 |
| `test/egw_catalog_and_covers_test.dart` | Catálogo EGW (~79 obras), `egwUseModernCovers` e `EgwCpbCoverPainter` | 10 |
| `test/egw_extractor_test.dart` | Extrator de citações de Ellen G. White | 6 |
| `test/egw_integration_test.dart` | Integração do acervo EGW e resolução de referências | 11 |
| `test/egw_reader_links_test.dart` | `EgwLinkableParagraph` e abertura de referências bíblicas inline | 4 |
| `test/egw_service_download_test.dart` | Proteção contra truncamento de download por cache parcial (`1 capítulo`) | 3 |
| `test/gamification_and_auth_test.dart` | Reserva de Azeite, XP, ofensiva e fluxos de autenticação | 21 |
| `test/gamification_v2_and_focus_test.dart` | Troféus, calendário mensal e rastreador Anti-AFK (`SpiritualFocusTracker`) | 7 |
| `test/home_view_redesign_test.dart` | Dashboard Home, saudação, banner do dia e grid de módulos | 8 |
| `test/hymn_and_navigation_improvements_test.dart` | Melhorias de navegação principal e leitura de hinos | 9 |
| `test/hymn_audio_native_test.dart` | Player de áudio nativo de hinos | 7 |
| `test/hymn_features_test.dart` | Busca FTS5, favoritos, histórico e comparativo de hinários | 11 |
| `test/living_orbs_and_settings_test.dart` | Efeitos atmosféricos e tela de configurações | 4 |
| `test/mind_map_and_cult_list_test.dart` | Mapa mental (`MindMapStudioView`) e recomendador de cultos (`CultListRecommender`) | 8 |
| `test/overhaul_ui_and_features_test.dart` | Cobertura transversal de UI e fluxos integrados | 12 |
| `test/performance_cache_and_hymn_scroll_test.dart` | Cache em memória e performance de rolagem de hinários | 7 |
| `test/pericope_and_commentary_test.dart` | Decodificação de `Pericope`/`Commentary` e filtro de autores no `StudyBottomSheet` | 2 |
| `test/poetic_books_layout_test.dart` | Layout poético para livros sapienciais/poéticos da Bíblia | 11 |
| `test/reading_plan_and_oil_test.dart` | Planos de leitura e recompensas da Lamparina | 16 |
| `test/reading_plan_egw_mission_test.dart` | Missão em 2 etapas Bíblia $\rightarrow$ EGW (`parseEgwMission`, `EgwPlanMissionRef`) | 2 |
| `test/sabbath_school_and_hymn_download_test.dart` | Downloads offline da Escola Sabatina e hinário | 4 |
| `test/sabbath_school_redesign_test.dart` | Renderização e usabilidade da `SabbathSchoolView` | 2 |
| `test/services/sprint2_audio_services_test.dart` | Serviços de áudio e downloads em lote | 14 |
| `test/splash_view_test.dart` | Animação e modos de velocidade da `SplashView` | 2 |
| `test/sprints_features_test.dart` | Conjunto de funcionalidades evolutivas entre sprints | 8 |
| `test/ss_highlights_test.dart` | Preservação de `ss_highlights` e operações de destaque na lição | 2 |
| `test/sunset_notification_test.dart` | Notificações e cálculos de Pôr do Sol do Sábado | 3 |
| `test/theme_engine_test.dart` | Motor de temas M3, cores customizadas e modos claro/escuro/AMOLED | 6 |
| `test/themes_test.dart` | Validação específica de `Real Glass`, `Retrô ICS Holo` e `Windows 95` | 1 |
| `test/ui_gestures_and_a11y_test.dart` | `KairosReaderGestureLayer`, limpeza de botões e estresse `TextScaler.linear(2.0)` em `320x640` | 7 |
| `test/ui_polish_edge_cases_test.dart` | Todos os 11 estilos, Modo Zen e alvos de toque $\ge 48\text{dp}$ | 4 |
| `test/unified_verse_and_quiz_test.dart` | Referências contíguas, `BibleVersePreviewModal` e fluxo unificado de quiz | 13 |
| **Total Geral** | **41 arquivos em `test/`** | **302 casos** |

---

## 4. Comandos de Validação Contínua

```bash
# 1. Análise estática completa (lints, tipos e referências Dartdoc)
flutter analyze

# 2. Execução integral da suíte de testes unitários e de widget
flutter test

# 3. Compilação sintática e auditoria dos scripts Python de geração/validação SQLite
python3 -m py_compile scripts/generate_pericopes_and_commentaries.py scripts/audit_avm_and_enoch.py
python3 scripts/audit_avm_and_enoch.py --self-test
```
