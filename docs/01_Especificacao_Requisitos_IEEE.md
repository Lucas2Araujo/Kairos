# 01 — Especificação de Requisitos de Software (ERS) — Kairós

> **Padrão de Referência:** IEEE Std 830 / ISO/IEC/IEEE 29148  
> **Produto:** Kairós — Ecossistema Devocional e Litúrgico Multiplataforma (`package:kairos_web`)  
> **Plataformas-Alvo:** Android (ARM64-v8a, ARMv7-armeabi, x86_64) e Web (PWA / Navegadores modernos)

---

## 1. Introdução

### 1.1 Propósito
Este documento especifica formalmente os requisitos funcionais, não-funcionais, restrições arquiteturais e regras de negócio do aplicativo **Kairós**. O sistema foi projetado como um hub devocional, bíblico, litúrgico e comunitário cristão com operação **offline-first** e sincronização híbrida opcional na nuvem.

### 1.2 Escopo do Produto
O **Kairós** unifica, em uma única base de código **Flutter/Dart** compilada nativamente para Android e Web, os seguintes domínios funcionais:
1. **Dashboard Devocional & Astronomia Solar:** Saudação contextual, versículo diário com exportação gráfica, contagem regressiva para o Pôr do Sol do Sábado (algoritmo NOAA) e atalho para congregações próximas.
2. **Bíblia Sagrada Multiversão:** Leitura offline em múltiplas traduções (`ARA`, `NVI`, `NTLH`, `KJA`, `AS21` e `AVM`), suporte a Deuterocanônicos/Apócrifos (`67..73`) e `1 Enoque` (`book_id = 74`), perícopes literárias, referências cruzadas, comentários expositivos multi-autor, comparador de versões, marca-texto persistente e Modo Livro Imersivo.
3. **Biblioteca Espírito de Profecia (Ellen G. White):** Catálogo completo de **79 obras únicas em Português**, download offline íntegro por obra, detecção automática de citações bíblicas clicáveis e sistema dual de capas (*Clássica EGW* vs. *Nova CPB* com renderização vetorial procedural offline).
4. **Planos de Leitura Integrados:** Jornadas bíblicas com progressão em **2 etapas** (Leitura Bíblica $\rightarrow$ Capítulo exato do Espírito de Profecia) e recompensa gamificada.
5. **Escola Sabatina Interativa & Turmas:** Estudo diário contextualizado por faixa etária, marcadores de parágrafo (`ss_highlights`), notas pessoais, mapa mental (*Mind Map Studio*), *Luz Menor* (resumos EGW), tirinhas semanais, quiz rápido e gestão de turmas/classes com relatórios em planilha (`.xlsx`).
6. **Hinários Adventistas & Agente Litúrgico:** Hinário Novo (2022 — **601 hinos**) e Hinário Antigo (1996 — **613 hinos**), busca FTS5 sem acentuação, reprodução e download em lote de áudios, comparador textual (**873 pares**) e agente determinístico de montagem de cultos.
7. **Meditações Diárias:** Quatro categorias (*Jovens*, *Adultos*, *Mulher* e *Pôr do Sol*) com cache SQLite e acesso offline.
8. **Gamificação, Nuvem, Temas e Acessibilidade:** Sistema *Reserva de Azeite & Ofensiva*, rastreador anti-AFK (`120s`), merge híbrido na nuvem via Supabase, camada configurável de gestos em leitores e motor visual com **11 estilos de tema**.

---

## 2. Descrição Geral e Perfis de Atores

| Ator | Tipo | Descrição e Responsabilidades |
| :--- | :--- | :--- |
| **Leitor Devocional** | Ator Primário (Humano) | Usuário comum que utiliza o app para leitura bíblica, meditações diárias, planos de leitura, acervo EGW, acompanhamento do pôr do sol, gamificação e personalização visual/acessibilidade. |
| **Aluno / Professor da Escola Sabatina** | Ator Primário (Especialização de Leitor) | Estuda a lição trimestral, destaca parágrafos, responde perguntas, cria mapas mentais e participa ou gerencia turmas/pequenos grupos (`ClassroomView`). |
| **Líder de Louvor / Pastor** | Ator Primário (Especialização de Leitor) | Pesquisa hinários, reproduz/baixa áudios para uso em cultos, compara edições 1996/2022 e utiliza o Agente Organizador de Cultos (`CultListRecommender`). |
| **Supabase Auth & REST** | Sistema Externo | Provedor de autenticação (Google OAuth 2.0 / E-mail), persistência de metadados do usuário, sincronização de destaques bíblicos, meditações diárias e dados de turmas. |
| **Cloudflare R2** | Sistema Externo | Repositório CDN/S3 público (`AppConfig.r2AudioBaseUrl`) que hospeda áudios MP3 dos hinos e pacotes comprimidos `.sqlite.gz` das traduções bíblicas adicionais. |
| **Portal EGW Writings** | Sistema Externo | Fonte remota (`m.egwwritings.org` / `media4.egwwritings.org`) para resolução dinâmica de IDs numéricos, sumários (TOC), capítulos e capas clássicas. |
| **Portal IASD (Sabbath School API / Igrejas)** | Sistema Externo | Fonte de trimestres, lições diárias, tirinhas semanais (`sabbath-school.adventech.io`) e geolocalização de congregações (`igrejas.adventistas.org`). |
| **GitHub Releases** | Sistema Externo | Provedor de artefatos de atualização OTA (`Split APKs` assinados por ABI) consultado pelo `UpdaterService`. |

---

## 3. Requisitos Funcionais (RF)

### 3.1 Dashboard, Meditações e Pôr do Sol
- **RF01 — Dashboard Home Responsivo:** O sistema deve apresentar em `HomeView` saudação temporal, banner dinâmico (versículo do dia de segunda a quinta ou contagem regressiva de Pôr do Sol na sexta-feira quando faltarem até 3 horas), barra de busca global configurável (cápsula no corpo, ícone no topo ou oculta) e grade de **8 módulos principais** (2 colunas em telas $\ge 340\text{dp}$; 1 coluna em telas menores).
- **RF02 — Meditações Diárias Multi-Categoria:** O sistema deve disponibilizar leitura diária em 4 categorias (*Jovens*, *Adultos*, *Mulher* e *Pôr do Sol*) via `DevotionalService`, com cache local no SQLite, seletor de datas em folha deslizante e exportação de cards gráficos (`VerseCardRenderer`).
- **RF03 — Cálculo Astronômico Solar Offline (NOAA) e Lembrete:** O sistema deve calcular horários locais de pôr do sol para cidades brasileiras predefinidas ou selecionadas pelo usuário via `SolarService.calculateSunset` sem depender de internet, permitindo ativar/desativar lembretes locais de preparação para o Sábado (`NotificationService`).

### 3.2 Bíblia Sagrada, Apócrifos/1 Enoque e Ferramentas de Estudo
- **RF04 — Leitura Bíblica Multiversão Offline:** O sistema deve suportar alternância entre versões bíblicas locais e baixadas sob demanda (`ARA`, `NVI`, `NTLH`, `KJA`, `AS21` e `AVM`), com modos **Versículo por Versículo**, **Texto Corrido contínuo** e **Livro Imersivo** (`BibleImmersiveView`), além de renderização especial para livros poéticos.
- **RF05 — Suporte a Apócrifos (`AVM`) e `1 Enoque` (`book_id = 74`):** O sistema deve resolver aliases com ou sem acentuação e numerais romanos (`"I Macabeus"` $\leftrightarrow$ `"1 Macabeus"`, `"Eclesiástico"`/`"Sirácida"`, `"Baruc"`/`"Baruque"`, `"Tobias"`, `"Judite"`, `"Sabedoria"`, `"1 Enoque"`/`"Enoque"` via `BibleRepository.resolveBookIdByAlias`) e aplicar filtragem consistente em `BookChapterSelectorSheet.matchesFilter` nas abas `TODOS`, `VT`, `NT` e `AP` (exibindo `1 Enoque` na aba `AP` e em buscas nominais na aba `TODOS`).
- **RF06 — Perícopes Literárias Integradas:** O sistema deve carregar subtítulos temáticos de `assets/pericopes.sqlite` (`PericopeRepository`) e exibi-los antes dos versículos iniciais correspondentes tanto na leitura padrão (`BibleReaderView`) quanto no modo contínuo (`BibleImmersiveView` via `LoadedChapter.pericopes`).
- **RF07 — Comentários Expositivos Multi-Autor e Referências Cruzadas:** Ao selecionar um versículo para estudo (`StudyBottomSheet`), o sistema deve listar referências cruzadas navegáveis (`CrossReferenceRepository`) e comentários expositivos (`CommentaryRepository`), exibindo chips horizontais roláveis de filtro por autor (*Todos*, *Matthew Henry (PT-BR)*, *Notas EGW / Comentário Adventista*, *Jamieson-Fausset-Brown*) derivados dinamicamente dos resultados.
- **RF08 — Comparador de Versículos, Destaques e Cartão de Conclusão:** O sistema deve permitir comparar um ou mais versículos entre todas as versões instaladas localmente, aplicar marca-texto colorido persistido em `verse_highlights` e exibir ao final de cada capítulo no `BibleImmersiveView` um cartão semântico de conclusão para registro diário (`+40` gotas de azeite).
- **RF09 — Fallback de Download Web para Módulos Bíblicos:** Em `ContentManager`, o sistema deve gerar lista ordenada de URLs alternativas (`ContentManager.buildFallbackUrls`) caso o download de módulos `.sqlite.gz` falhe no host primário na plataforma Web.

### 3.3 Espírito de Profecia (EGW) e Planos de Leitura
- **RF10 — Catálogo Completo de 79 Obras EGW em Português:** O sistema deve disponibilizar em `EgwService.defaultCatalog` as **79 obras únicas** de Ellen G. White em português (incluindo a Série Conflito, clássicos devocionais, volumes 1–9 de *Testemunhos para a Igreja*, volumes 1–3 de *Mensagens Escolhidas* e *Testemunhos Seletos*, volumes 1–2 de *Mente, Caráter e Personalidade* e demais títulos únicos), com resolução dinâmica de IDs numéricos online quando necessário.
- **RF11 — Integridade Offline contra Bug de Cache Parcial ("Demo / 1 Capítulo"):** O sistema deve impedir que um livro acessado online anteriormente (com apenas 1 capítulo em `egw_chapters_cache`) seja marcado como `is_downloaded = 1` ou trunque o sumário. `EgwService.shouldBypassTocCache` deve forçar atualização do sumário quando houver suspeita de cache parcial, e `EgwBook.evaluateDownloadCompleteness` deve validar a contagem real de capítulos salvos localmente contra `total_chapters`.
- **RF12 — Sistema Dual de Capas Adaptativo (Clássica EGW vs. Nova CPB):** O sistema deve permitir alternar instantaneamente (via botão na barra superior de `EgwBooksView` ou nas Configurações, persistido em `ThemeService.egwUseModernCovers`) entre a capa *Clássica EGW* (`coverUrl`) e a *Nova CPB*. Quando a capa moderna estiver ativa sem URL mapeada ou offline, `EgwBookCover` deve acionar `EgwCpbCoverPainter` (`CustomPainter`), renderizando:
  - **Modo Claro:** Fundo Taupe `#8E8880`, lombada 3D, três pontos brancos no topo, monograma serifado entrelaçado (`EgwCpbCoverPainter.extractMonogram`) e título em Bronze `#4D3D2E`, com rodapé `"ELLEN G. WHITE"` em branco `#F5F3EF`.
  - **Modo Escuro:** Fundo Grafite `#58595B` e monograma/título em Dourado Champanhe `#C5A680`.
- **RF13 — Referências Bíblicas Inline Clicáveis no Leitor EGW:** Em `EgwReaderView`, parágrafos contendo citações bíblicas devem ser renderizados por `EgwLinkableParagraph` com `TapGestureRecognizer`s gerenciados com `dispose()` adequado, abrindo o modal `BibleVersePreviewModal` com a passagem e referências contíguas ao toque.
- **RF14 — Missão Diária Integrada em 2 Etapas nos Planos de Leitura:** O sistema deve interpretar sugestões de leitura complementar (`ReadingPlanDay.parseEgwMission` $\rightarrow$ `EgwPlanMissionRef`), exibindo nos planos o fluxo **Etapa 1 (Leitura Bíblica)** $\rightarrow$ **Etapa 2 (Capítulo exato no EGW via `EgwReaderView(initialChapterNumber: ...)` e `ReadingPlanFloatingPill`)**, contabilizando conclusão idempotente via `ReadingPlanService.completeEgwMissionStep` (`stepKey = 'egw:<CODE>:<CAP>'`) com bônus único de `+25` gotas por dia.

### 3.4 Escola Sabatina Interativa e Turmas
- **RF15 — Estudo Trimestral da Lição e Ferramentas Complementares:** O sistema deve carregar trimestres e lições diárias via `SabbathSchoolService` com suporte a seleção de faixa etária, download de trimestres offline, *Luz Menor* (resumo EGW), *TirinhaView*, *MindMapStudioView* (`ss_mind_maps`), anotações pessoais (`ss_user_notes`), respostas a questões (`ss_question_answers`) e *Quiz Rápido*.
- **RF16 — Marcadores de Parágrafo na Lição (`ss_highlights`):** O sistema deve permitir destacar ou remover destaques coloridos em parágrafos individuais da lição (`SabbathSchoolService.getHighlights`, `saveHighlight`, `removeHighlight`), persistindo `day_id`, `paragraph_index`, `color_hex` e `updated_at` na tabela preservada `ss_highlights`.
- **RF17 — Gestão de Turmas, Classes e Pequenos Grupos:** O sistema deve permitir em `ClassroomView` criar turmas (gerando código de 6 caracteres), editar/excluir turmas (professor), ingressar por código ou link direto (`?join=CODIGO`), sair da turma (aluno), compartilhar convites para WhatsApp, visualizar frequência por período (semana atual, mês atual, trimestre atual) e exportar planilhas `.xlsx` via `XlsxBuilder`.

### 3.5 Hinários Adventistas, Busca Global e Agente de Cultos
- **RF18 — Hinário Novo (2022) e Hinário Antigo (1996) com Busca FTS5:** O sistema deve consultar `hinario.db` (**601 hinos**) e `hinario_antigo.db` (**613 hinos**), oferecendo busca FTS5 insensível a acentuação, favoritos, histórico recente, filtros temáticos, ajuste de formatação textual (`HymnTextFormatSheet`), áudio integrado (`AudioService` + Cloudflare R2) e download em lote (`HymnBatchDownloadDialog`).
- **RF19 — Comparador Entre Edições de Hinários:** O sistema deve comparar hinos entre as edições de 1996 e 2022 através de `ComparativoRepository` e `HymnComparativoDialog` sobre a base `hinario_comparativo.db` (**873 pares catalogados** com índice `comparativo_fts`).
- **RF20 — Agente Organizador de Cultos:** O sistema deve gerar listas litúrgicas determinísticas em 5 momentos (*Introito*, *Oração Pastoral*, *Hino do Sermão*, *Ofertório* e *Despedida*) a partir de um tema pastoral via `CultListRecommender.recommend`, permitindo salvar e gerenciar cultos localmente (`lista_culto` / `item_lista_culto`).
- **RF21 — Busca Global Unificada (`GlobalSearchView`):** O sistema deve pesquisar simultaneamente hinos, versículos bíblicos, meditações e lições via `SearchService` com ranking por correspondência exata/parcial e paginação.

### 3.6 Gamificação, Sincronização Híbrida na Nuvem, Temas e UX
- **RF22 — Reserva de Azeite, Ofensiva, Troféus e Avatar:** O sistema deve gerenciar XP ("gotas de azeite"), chamas da ofensiva diária/semanal/mensal (`MonthlyStreakView`), troféus desbloqueáveis (`AchievementUnlockBanner`), mascote da Lamparina Kairós e avatar customizável (`AvatarBuilderModal`) via `GamificationService`.
- **RF23 — Rastreador de Foco Espiritual Anti-AFK:** `SpiritualFocusTracker` deve contabilizar segundos ativos de estudo e pausar automaticamente após **120 segundos** sem interação do usuário, exceto enquanto `AudioService.isPlaying` for verdadeiro.
- **RF24 — Sincronização Híbrida Bidirecional na Nuvem:** `AuthService` deve autenticar usuários (Google OAuth 2.0 / E-mail) e orquestrar pull + push sem regressão de dados entre dispositivos offline:
  - União de conjuntos (`Set.union`) para `activityDates` (`GamificationService.mergeActivityDates`), troféus, dias e capítulos de planos (`ReadingPlanService.mergeCloudPlans`);
  - Preservação do maior valor para contadores acumulados (`totalXp`, `currentStreak`, `fullFlameStreak`, `totalChaptersRead`);
  - Resolução *last-write-wins* por `updated_at` para `ss_highlights` (`SabbathSchoolService.importHighlightsWithMerge`) e pull/merge de `verse_highlights` (`BibleRepository.syncHighlightsFromCloud`);
  - Sincronização de preferências (`egw_use_modern_covers`, toggles de gestos, `solar_city_name`, `sunset_reminder_enabled`, estilo/cor/fonte do tema).
- **RF25 — Padronização de Saída em Modais e Folhas Deslizantes:** Dialogs (`SettingsDialog`, `DownloadsDialog`, `BibleVersePreviewModal`, `ProfileDialog`) devem possuir apenas um botão de fechamento (`Icons.close_rounded`) no cabeçalho com `Tooltip` e `Semantics`, enquanto Draggable Bottom Sheets devem usar exclusivamente a alça superior de arraste sem botões duplicados.
- **RF26 — Sistema de Gestos Opcionais Configuráveis:** O sistema deve fornecer a camada reutilizável `KairosReaderGestureLayer` aplicada aos 5 leitores (`BibleReaderView`, `BibleImmersiveView`, `SabbathSchoolView`, `EgwReaderView`, `HymnDetailView`), governada por um controle mestre (`gesturesEnabled`) e três controles granulares (`gestureSwipeChapters`, `gesturePinchFont` com clamp `0.8..1.6` e `gestureDoubleTapHighlight`), totalmente inertes quando desativados.
- **RF27 — Motor de Temas (`ThemeEngine`) com 11 Estilos Visuais:** O sistema deve prover em `AppThemeStyle` os 11 estilos: `materialYou`, `liquidGlass`, `appleGlass`, `realGlass`, `classicBook`, `classicBookNew`, `aurora`, `oledVivid`, `zen`, `holoRetro` e `win95`, preservando `"Liquid Glass"` e `"Apple Glass"` e adicionando:
  - **`realGlass` ("Real Glass"):** Placa óptica `RealGlassSurface` combinando `ImageFilter.blur` e `ImageFilter.matrix` (refração), bordas especulares e sombras prismáticas;
  - **`holoRetro` ("Retrô ICS Holo"):** Estética Android 4.0 ICS com azul `#33B5E5`, `BorderRadius.zero` e fundo `#000000` $\rightarrow$ `#101824`;
  - **`win95` ("Windows 95"):** Desktop `#008080`, superfícies `#C0C0C0`, barras `#000080` e componente `Win95BevelBox` com chanfros 3D `#FFFFFF` / `#808080` e quinas retas.
- **RF28 — Personalização Cromática e Tipografia Inclusiva:** O usuário deve poder alternar modos Claro/Escuro/Sistema/AMOLED/Sépia, selecionar sementes M3 ou qualquer cor no círculo cromático 360° (`ChromaticColorPickerDialog`), ajustar escala de fonte/UI e escolher a fonte **OpenDyslexic**.
- **RF29 — Atualizador OTA Automático (`UpdaterService`):** No Android, o sistema deve consultar `githubLatestReleaseUrl`, comparar versionamento semântico (`isNewerVersion`), casar o asset APK compatível com a ABI do dispositivo (`arm64-v8a`, `armeabi-v7a`, `x86_64`) e disparar download/instalação nativa via `MethodChannel('kairos.app/system')`.
- **RF30 — Acessibilidade Semântica e Compatibilidade `TextScaler`:** Todas as telas críticas, diálogos, modais, listas e capas procedurais devem manter alvos de toque $\ge 48\text{dp}$, rótulos `Semantics` descritivos e zero `RenderFlex` overflow sob `TextScaler.linear(2.0)` em viewports compactos (`320x640`).

---

## 4. Requisitos Não-Funcionais (RNF)

| Código | Categoria | Requisito | Critério de Verificação |
| :--- | :--- | :--- | :--- |
| **RNF01** | **Portabilidade** | Compatibilidade estrita Android & Web sem importação direta de `dart:io` em código compartilhado. | Uso obrigatório de imports condicionais (`*_stub.dart` / `*_io.dart` / `*_web.dart`) e guardas `kIsWeb`. |
| **RNF02** | **Integridade de Dados** | Preservação automática de dados do usuário durante atualizações de bancos empacotados em `assets/`. | `DatabaseManager.userPreservedTables` e `dumpUserTables`/`restoreUserTables` verificados em `test/db_migration_test.dart` e `test/ss_highlights_test.dart`. |
| **RNF03** | **Compatibilidade SQLite Web/Mobile** | Todos os bancos empacotados ou gerados para distribuição devem operar sem arquivos auxiliares `-wal`/`-shm` no bundle. | Execução de `PRAGMA journal_mode=DELETE; VACUUM;` nos scripts Python e pipeline `.github/workflows/cd.yml`. |
| **RNF04** | **Manutenibilidade & Minimalismo (Ponytail)** | Zero novas dependências externas sem justificativa irrefutável; reúso máximo de APIs nativas do Flutter/Dart e helpers compartilhados. | Auditoria do `pubspec.yaml` e aderência às diretrizes de `AGENTS.md`. |
| **RNF05** | **Performance de Busca** | Pesquisas em hinários (601/613 registros) e acervo indexado devem responder instantaneamente offline. | Tabelas virtuais FTS5 com tokenizador `unicode61 remove_diacritics 2`. |
| **RNF06** | **Resiliência Offline** | Nenhuma operação local pode travar ou perder estado por ausência de rede ou erro HTTP do Supabase/EGW/R2. | Fallbacks locais em `AuthService`, `EgwCpbCoverPainter`, `SabbathSchoolService` e `ContentManager`. |
| **RNF07** | **Responsividade e Escala** | Layouts adaptativos para smartphones (`320dp`), tablets (`>600dp` com `NavigationRail`) e desktop Web. | Testes de widget em `320x640` e `1280x800` com `TextScaler` até `2.0x` sem exceções. |
| **RNF08** | **Segurança de Consultas** | Prevenção total contra injeção SQL em operações locais. | 100% das queries em repositórios utilizam *prepared statements* parametrizados (`?`). |
| **RNF09** | **Qualidade Estática e Documentação** | Código-fonte limpo, sem warnings de análise estática e APIs públicas documentadas com Dartdoc (`///`). | Validação via `flutter analyze` e `python -m py_compile` nos scripts auxiliares. |
| **RNF10** | **Determinismo de Sincronização** | Merge de dados entre dispositivos deve ser comutativo e livre de regressões silenciosas. | Helpers puros e idempotentes testados em `test/cloud_sync_merge_test.dart`. |
