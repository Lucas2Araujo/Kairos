# 03 — Diagramas e Especificações de Casos de Uso (UML 2.5) — Kairós

> **Notação:** Diagramas visuais em Mermaid (renderização nativa no GitHub) acompanhados de modelos formais em PlantUML (`docs/diagramas/*.puml`) e Tabelas de Especificação Completa de Casos de Uso.

---

## 1. Diagrama Geral de Casos de Uso (Ecossistema Completo)

> **Arquivo PlantUML:** [`docs/diagramas/DCU_Geral.puml`](./diagramas/DCU_Geral.puml)

```mermaid
flowchart LR
    Leitor(["Leitor Devocional"])
    AlunoProf(["Aluno / Professor ES"])
    Pastor(["Líder de Louvor / Pastor"])

    Supa(["Supabase Auth & REST"])
    R2(["Cloudflare R2"])
    EGW(["Portal EGW Writings"])
    IASD(["Portal IASD"])
    GH(["GitHub Releases"])

    AlunoProf --> Leitor
    Pastor --> Leitor

    subgraph Sistema["Ecossistema Kairós (Flutter / Dart)"]
        UC01(("UC01 - Ler Bíblia Multiversão"))
        UC02(("UC02 - Consultar Apócrifos e 1 Enoque"))
        UC03(("UC03 - Explorar Perícopes e Comentários"))
        UC04(("UC04 - Ler Acervo EGW ~79 Obras e Dual Covers"))
        UC05(("UC05 - Executar Plano com Missão 2 Etapas"))
        UC06(("UC06 - Estudar Escola Sabatina e Destaques"))
        UC07(("UC07 - Gerenciar Turmas e Relatórios"))
        UC08(("UC08 - Pesquisar Hinários FTS5 e Áudios"))
        UC09(("UC09 - Montar Liturgia de Culto"))
        UC10(("UC10 - Meditações e Pôr do Sol NOAA"))
        UC11(("UC11 - Gamificação Reserva de Azeite"))
        UC12(("UC12 - Login e Sync Híbrido na Nuvem"))
        UC13(("UC13 - Temas 11 Estilos e Gestos/A11y"))
        UC14(("UC14 - Atualização OTA Split APK"))
    end

    Leitor --> UC01
    Leitor --> UC02
    Leitor --> UC03
    Leitor --> UC04
    Leitor --> UC05
    Leitor --> UC10
    Leitor --> UC11
    Leitor --> UC12
    Leitor --> UC13
    Leitor --> UC14

    AlunoProf --> UC06
    AlunoProf --> UC07
    Pastor --> UC08
    Pastor --> UC09

    UC01 -.-> R2
    UC08 -.-> R2
    UC04 -.-> EGW
    UC06 -.-> IASD
    UC07 -.-> Supa
    UC10 -.-> Supa
    UC12 -.-> Supa
    UC14 -.-> GH
```

---

## 2. Diagramas de Casos de Uso por Módulo

### 2.1 DCU 01 — Estudo Bíblico, Apócrifos/1 Enoque, Perícopes e Comentários
> **Arquivo PlantUML:** [`docs/diagramas/DCU01_Biblia_Apocrifos_Estudo.puml`](./diagramas/DCU01_Biblia_Apocrifos_Estudo.puml)

```mermaid
flowchart LR
    U(["Leitor Devocional"])
    R2(["Cloudflare R2"])

    subgraph ModBiblia["Módulo Bíblico Offline-First"]
        A(("Selecionar Versão Bíblica"))
        B(("Baixar Versão .sqlite.gz"))
        C(("Navegar Livro e Capítulo"))
        D(("Filtrar Testamentos TODOS/VT/NT/AP"))
        E(("Buscar Apócrifos e 1 Enoque"))
        F(("Alternar Leitura Normal / Contínua / Imersiva"))
        G(("Exibir Perícopes Literárias"))
        H(("Concluir Capítulo no Cartão Imersivo"))
        I(("Consultar StudyBottomSheet"))
        J(("Filtrar Comentários por Autor"))
        K(("Navegar Referências Cruzadas"))
    end

    U --> A
    U --> C
    U --> F
    U --> I
    B -. "<<extend>>" .-> A
    B -.-> R2
    C -. "<<include>>" .-> D
    E -. "<<extend>>" .-> D
    F -. "<<include>>" .-> G
    H -. "<<extend>>" .-> F
    I -. "<<include>>" .-> K
    J -. "<<extend>>" .-> I
```

### 2.2 DCU 02 — Espírito de Profecia (~79 Obras) & Missão Diária em 2 Etapas
> **Arquivo PlantUML:** [`docs/diagramas/DCU02_EGW_Planos_Missao.puml`](./diagramas/DCU02_EGW_Planos_Missao.puml)

```mermaid
flowchart LR
    U(["Leitor Devocional"])
    EGW(["Portal EGW Writings"])

    subgraph ModEGW["Espírito de Profecia e Planos de Leitura"]
        C1(("Explorar Catálogo ~79 Obras"))
        C2(("Alternar Capa Clássica <-> Nova CPB"))
        C3(("Renderizar Canvas CPB Claro/Escuro"))
        C4(("Baixar Obra Offline Completa"))
        C5(("Bypassar Cache Parcial de TOC"))
        C6(("Ler Capítulo EGW"))
        C7(("Tocar Referência Bíblica Inline"))
        C8(("Abrir BibleVersePreviewModal"))
        P1(("Ativar Plano de Leitura"))
        P2(("Etapa 1: Leitura Bíblica"))
        P3(("Etapa 2: Capítulo Exato EGW"))
        P4(("Receber +25 Gotas Idempotentes"))
    end

    U --> C1
    U --> C2
    U --> C4
    U --> C6
    U --> P1

    C2 -. "<<include>>" .-> C3
    C4 -. "<<include>>" .-> C5
    C4 -.-> EGW
    C6 -.-> EGW
    C7 -. "<<extend>>" .-> C6
    C7 -. "<<include>>" .-> C8

    P1 -. "<<include>>" .-> P2
    P3 -. "<<extend>>" .-> P2
    P3 -. "<<include>>" .-> C6
    P3 -. "<<include>>" .-> P4
```

### 2.3 DCU 03 — Escola Sabatina Interativa & Gestão de Turmas/Classes
> **Arquivo PlantUML:** [`docs/diagramas/DCU03_Escola_Sabatina_Turmas.puml`](./diagramas/DCU03_Escola_Sabatina_Turmas.puml)

```mermaid
flowchart LR
    Aluno(["Aluno / Leitor"])
    Prof(["Professor / Líder PG"])
    IASD(["Portal IASD"])
    Supa(["Supabase REST"])

    Prof --> Aluno

    subgraph ModES["Escola Sabatina & Turmas"]
        L1(("Selecionar Trimestre e Faixa"))
        L2(("Estudar Lição Diária"))
        L3(("Destacar Parágrafos ss_highlights"))
        L4(("Anotar e Responder Perguntas"))
        L5(("Consultar Luz Menor / Mapa Mental / Quiz"))
        L6(("Baixar Trimestre Offline"))
        T1(("Entrar na Turma por Código / Link"))
        T2(("Criar / Editar / Excluir Turma"))
        T3(("Visualizar Frequência e Exportar XLSX"))
    end

    Aluno --> L1
    Aluno --> L2
    Aluno --> L6
    Aluno --> T1
    Prof --> T2
    Prof --> T3

    L3 -. "<<extend>>" .-> L2
    L4 -. "<<extend>>" .-> L2
    L5 -. "<<extend>>" .-> L2
    L1 -.-> IASD
    L6 -.-> IASD
    T1 -.-> Supa
    T2 -.-> Supa
    T3 -.-> Supa
```

### 2.4 DCU 04 — Hinários Adventistas, Agente de Cultos & Devocional
> **Arquivo PlantUML:** [`docs/diagramas/DCU04_Hinarios_Cultos_Devocional.puml`](./diagramas/DCU04_Hinarios_Cultos_Devocional.puml)

```mermaid
flowchart LR
    U(["Leitor Devocional"])
    P(["Líder de Louvor / Pastor"])
    R2(["Cloudflare R2"])
    Supa(["Supabase Devocionais"])

    P --> U

    subgraph ModLouvor["Hinários, Cultos e Devocional"]
        H1(("Alternar Hinário 2022 / 1996"))
        H2(("Pesquisar Hinos via FTS5"))
        H3(("Reproduzir / Baixar Áudios em Lote"))
        H4(("Comparar Hinário Novo vs Antigo"))
        A1(("Gerar Liturgia Determinística de Culto"))
        A2(("Salvar e Gerenciar Cultos"))
        D1(("Ler Meditação Diária"))
        D2(("Acompanhar Pôr do Sol NOAA"))
    end

    U --> H1
    U --> H2
    U --> H4
    U --> D1
    U --> D2
    P --> A1
    P --> A2

    H3 -. "<<extend>>" .-> H1
    H3 -.-> R2
    A1 -. "<<include>>" .-> H1
    A2 -. "<<extend>>" .-> A1
    D1 -.-> Supa
```

### 2.5 DCU 05 — Gamificação, Sync Híbrido na Nuvem, Temas & Acessibilidade
> **Arquivo PlantUML:** [`docs/diagramas/DCU05_Gamificacao_Sync_Temas.puml`](./diagramas/DCU05_Gamificacao_Sync_Temas.puml)

```mermaid
flowchart LR
    U(["Leitor Devocional"])
    Supa(["Supabase Auth / REST"])
    GH(["GitHub Releases"])

    subgraph ModUX["Engajamento, Nuvem e UX"]
        G1(("Acumular Gotas e Ofensiva"))
        G2(("Rastrear Foco Anti-AFK 120s"))
        S1(("Autenticar via Google / E-mail"))
        S2(("Mesclar Dados Híbridos na Nuvem"))
        T1(("Selecionar Tema entre 11 Estilos"))
        T2(("Configurar OpenDyslexic e Escala"))
        T3(("Configurar Gestos nos 5 Leitores"))
        O1(("Atualizar App via OTA"))
    end

    U --> G1
    U --> S1
    U --> T1
    U --> T2
    U --> T3
    U --> O1

    G1 -. "<<include>>" .-> G2
    S2 -. "<<extend>>" .-> S1
    S1 -.-> Supa
    S2 -.-> Supa
    O1 -.-> GH
```

---

## 3. Especificações Textuais Formais dos Casos de Uso Críticos

### 3.1 UC-02: Buscar e Ler Livros Deuterocanônicos (`AVM`) e `1 Enoque` (`book_id = 74`)
| Campo | Descrição |
| :--- | :--- |
| **Identificador / Nome** | UC-02 — Consultar Livros Deuterocanônicos (`AVM`) e `1 Enoque` |
| **Atores** | Leitor Devocional (Primário) |
| **Pré-condições** | Versão bíblica `AVM.sqlite` (ou versão contendo Enoque) instalada localmente ou disponível via `ContentManager`. |
| **Fluxo Principal** | 1. O usuário abre o seletor `BookChapterSelectorSheet` na tela da Bíblia.<br>2. O usuário seleciona a aba de filtro `Apócrifos` (`AP`) ou digita o nome do livro (ex.: `"I Macabeus"`, `"Eclesiástico"`, `"1 Enoque"`).<br>3. `BookChapterSelectorSheet.normalizeText` remove diacríticos e normaliza numerais romanos (`I` $\rightarrow$ `1`, `II` $\rightarrow$ `2`).<br>4. `BookChapterSelectorSheet.matchesFilter` valida que o livro pertence ao conjunto apócrifo/extra-canônico (`isApocryphalBook` / `isEnoch`) ou corresponde à busca em `TODOS`.<br>5. O usuário toca no livro e escolhe o capítulo desejado; `BibleRepository.getVerses` carrega o texto no leitor. |
| **Fluxos Alternativos** | **FA01 (Busca por referência textual):** Ao clicar em uma referência de texto como `"Sirácida 2:1"`, `BibleRepository.resolveBookIdByAlias` resolve o ID correto (`67..74`).<br>**FA02 (Aba TODOS sem consulta):** Com o campo de busca vazio na aba `TODOS`, `isEnoch` mantém `1 Enoque` oculto para preservar a ordenação canônica padrão, exibindo-o assim que o usuário pesquisa `"enoque"` ou entra na aba `AP`. |
| **Fluxos de Exceção** | **FE01 (Módulo não baixado):** Se a versão `AVM` não estiver instalada na Web/Android, `ContentManager` inicia o download e, caso o host primário falhe na Web, tenta as URLs alternativas de `buildFallbackUrls`. |
| **Pós-condições** | O capítulo selecionado é renderizado com perícopes e suporte a grifos e estudo. |

---

### 3.2 UC-04: Download Offline Íntegro e Sistema Dual de Capas no Acervo EGW
| Campo | Descrição |
| :--- | :--- |
| **Identificador / Nome** | UC-04 — Baixar Obra EGW Offline com Validação Real e Alternar Capas Clássica/CPB |
| **Atores** | Leitor Devocional (Primário), Portal EGW Writings (Externo) |
| **Pré-condições** | Catálogo carregado com as 79 obras de `EgwService.defaultCatalog`. |
| **Fluxo Principal** | 1. O usuário acessa *Espírito de Profecia* (`EgwBooksView`).<br>2. O sistema renderiza cada obra usando `EgwBookCover`, observando `ThemeService.egwUseModernCovers`.<br>3. O usuário alterna o modo de capas (*Capa Clássica* $\leftrightarrow$ *Capa CPB*) na barra superior.<br>4. Se o modo *Nova CPB* estiver ativo sem URL remota ou sem conexão, `EgwCpbCoverPainter` desenha a capa procedural minimalista adaptada ao tema claro (Taupe `#8E8880` / Bronze `#4D3D2E`) ou escuro (Grafite `#58595B` / Champanhe `#C5A680`).<br>5. O usuário solicita o download offline de uma obra.<br>6. `EgwService.downloadBook` chama `getTableOfContents(bookId, forceRefresh: true)` aplicando `shouldBypassTocCache` para evitar truncamento por cache online parcial de 1 capítulo.<br>7. O sistema grava `total_chapters` em `egw_books_cache`, baixa todos os capítulos faltantes para `egw_chapters_cache` e valida via `EgwBook.evaluateDownloadCompleteness` antes de marcar `is_downloaded = 1`. |
| **Fluxos Alternativos** | **FA01 (Referência bíblica durante a leitura):** Ao ler qualquer capítulo em `EgwReaderView`, o usuário toca em uma citação bíblica sublinhada (`EgwLinkableParagraph`), abrindo `BibleVersePreviewModal` sem sair do livro. |
| **Fluxos de Exceção** | **FE01 (Queda de conexão durante download):** Capítulos faltantes impedem a gravação de `is_downloaded = 1`; `isBookDownloaded` retorna `false` até o término completo. |
| **Pós-condições** | A obra completa torna-se acessível 100% offline e sua preferência visual de capa é sincronizada em `ThemeService`. |

---

### 3.3 UC-05: Missão Diária Integrada em 2 Etapas nos Planos de Leitura
| Campo | Descrição |
| :--- | :--- |
| **Identificador / Nome** | UC-05 — Cumprir Missão Diária em 2 Etapas (Bíblia $\rightarrow$ Capítulo Exato EGW) |
| **Atores** | Leitor Devocional (Primário) |
| **Pré-condições** | Plano de leitura ativo em `ReadingPlanService` cujo dia possua sugestão ou nota EGW válida. |
| **Fluxo Principal** | 1. O usuário abre os detalhes do plano (`_PlanDetailsBottomSheet`) ou acompanha pela pílula flutuante (`ReadingPlanFloatingPill`).<br>2. O sistema exibe **Etapa 1 (Leitura Bíblica)** e **Etapa 2 (Espírito de Profecia — Cap. X)** derivadas por `ReadingPlanDay.parseEgwMission()`.<br>3. O usuário conclui os capítulos bíblicos da Etapa 1.<br>4. O usuário toca na Etapa 2; o sistema abre `EgwReaderView(bookId: mission.bookId, initialChapterNumber: mission.chapterNumber)` posicionado diretamente no capítulo alvo do sumário.<br>5. Ao concluir a leitura, o usuário aciona a conclusão da missão.<br>6. `ReadingPlanService.completeEgwMissionStep` registra `mission.stepKey` (`egw:<CODE>:<CAP>`) em `currentDayCompletedChapters` e concede `+25` gotas via `GamificationService.addOilDrops`. |
| **Fluxos Alternativos** | **FA01 (Re-execução no mesmo dia):** Se `mission.stepKey` já constar em `currentDayCompletedChapters`, o método retorna de forma idempotente sem duplicar XP. |
| **Fluxos de Exceção** | **FE01 (Livro EGW ainda não cacheado e usuário offline):** `EgwReaderView` exibe estado amigável informando a necessidade de conexão para o primeiro carregamento do capítulo. |
| **Pós-condições** | Etapa 2 marcada no progresso diário (`user_reading_plans`) e bônus contabilizado na Reserva de Azeite. |

---

### 3.4 UC-06: Destaque de Parágrafos (`ss_highlights`) e Estudo na Escola Sabatina
| Campo | Descrição |
| :--- | :--- |
| **Identificador / Nome** | UC-06 — Destacar Parágrafos na Lição da Escola Sabatina |
| **Atores** | Aluno / Professor (Primário) |
| **Pré-condições** | Lição diária carregada em `SabbathSchoolView`. |
| **Fluxo Principal** | 1. Durante a leitura da lição em `SabbathSchoolView`, o usuário seleciona um parágrafo.<br>2. O sistema exibe a paleta de cores de marca-texto.<br>3. O usuário escolhe uma cor; `SabbathSchoolService.saveHighlight` grava/atualiza `(day_id, paragraph_index, color_hex, updated_at)` na tabela `ss_highlights` (com fallback em memória caso necessário).<br>4. O parágrafo é exibido imediatamente com fundo destacado acessível conforme o tema ativo. |
| **Fluxos Alternativos** | **FA01 (Remoção de destaque):** Ao tocar na opção de limpar destaque, `SabbathSchoolService.removeHighlight` exclui o registro correspondente em `ss_highlights`. |
| **Fluxos de Exceção** | **FE01 (Atualização do banco de assets):** Como `'ss_highlights'` integra `DatabaseManager.userPreservedTables`, atualizações futuras de `hinario.db` preservam integralmente todos os destaques do usuário. |
| **Pós-condições** | Os destaques permanecem salvos offline e prontos para exportação em `exportHighlightsForSync()`. |

---

### 3.5 UC-12: Sincronização Híbrida Bidirecional sem Perda entre Dispositivos
| Campo | Descrição |
| :--- | :--- |
| **Identificador / Nome** | UC-12 — Executar Merge Híbrido de Estado Offline entre Múltiplos Dispositivos |
| **Atores** | Leitor Devocional (Primário), Supabase Auth & REST (Externo) |
| **Pré-condições** | Usuário possui conta autenticada no `AuthService` e utilizou o app offline em dois dispositivos (ex.: Android e Web) com histórico disjunto. |
| **Fluxo Principal** | 1. Ao abrir o app online ou autenticar, `AuthService._applyUserCloudPreferences` baixa os metadados remotos do usuário.<br>2. `GamificationService.mergeCloudMetadata` une `activityDates` via `mergeActivityDates` (`Set.union`), une `unlockedTrophies` e mantém o maior valor para `totalXp`, `currentStreak` e contadores.<br>3. `ReadingPlanService.mergeCloudPlans` une `completedDays` e `currentDayCompletedChapters` via união de conjuntos mantendo o `startedAt` mais antigo.<br>4. `SabbathSchoolService.importHighlightsWithMerge` mescla `ss_highlights` comparando `updated_at` (*last-write-wins*).<br>5. `BibleRepository.syncHighlightsFromCloud` baixa e mescla `verse_highlights` do endpoint REST.<br>6. `AuthService.syncPreferencesToCloud` envia o estado consolidado (incluindo `egw_use_modern_covers`, toggles de gestos, `solar_city_name` e `sunset_reminder_enabled`) de volta ao Supabase. |
| **Fluxos Alternativos** | **FA01 (Token expirado - HTTP 401):** `AuthService.syncPreferencesToCloud` invoca `refreshSession()` automaticamente e reenvia a requisição `PUT`. |
| **Fluxos de Exceção** | **FE01 (Dispositivo offline ou falha HTTP):** A sincronização falha graciosamente sem alterar ou sobrescrever os dados locais no SQLite ou `SharedPreferences`. |
| **Pós-condições** | Ambos os dispositivos convergem para a união completa do progresso devocional sem perda silenciosa de dias ou destaques. |

---

### 3.6 UC-13: Configuração de Gestos Opcionais, Modais Limpos e Temas
| Campo | Descrição |
| :--- | :--- |
| **Identificador / Nome** | UC-13 — Configurar Gestos nos Leitores e Alternar Temas Visuais |
| **Atores** | Leitor Devocional (Primário) |
| **Pré-condições** | Aplicativo inicializado com `ThemeService`. |
| **Fluxo Principal** | 1. O usuário abre `SettingsDialog` (que exibe um único ícone `Icons.close_rounded` no cabeçalho).<br>2. Na aba *Aparência*, escolhe entre os 11 estilos de `AppThemeStyle` (incluindo `Real Glass`, `Retrô ICS Holo` e `Windows 95`).<br>3. Na aba *Leitura*, configura o switch mestre de gestos (`gesturesEnabled`) e os sub-switches (`gestureSwipeChapters`, `gesturePinchFont`, `gestureDoubleTapHighlight`), além do estilo de capa EGW (`egwUseModernCovers`).<br>4. Ao retornar a qualquer um dos 5 leitores envolvidos por `KairosReaderGestureLayer`, os gestos obedecem em tempo real às preferências persistidas. |
| **Fluxos Alternativos** | **FA01 (Gestos desativados para acessibilidade):** Com `gesturesEnabled == false`, `KairosReaderGestureLayer` devolve o widget filho puro sem interceptadores de deslize ou pinça. |
| **Pós-condições** | Preferências visuais e motoras persistidas localmente e prontas para sincronização em nuvem. |
