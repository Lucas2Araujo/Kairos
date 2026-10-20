# Mapeamento Completo de Funcionalidades do Kairós (Legado Flet / Python)

Este documento registra **todas as funcionalidades, regras de negócio, telas, integrações e arquitetura** da versão original em Python/Flet do Kairós (até a tag `v0.6.48-flet-legacy`). Ele serve como o guia canônico para que a migração para **Flutter/Dart puro** mantenha 100% de paridade funcional.

---

## 1. Visão Geral e Arquitetura

O Kairós é um ecossistema cristão com foco em Hinologia, Estudos Bíblicos, Lição da Escola Sabatina e Devocionais Diários, projetado sob o princípio **Offline-First**.

### Bancos de Dados SQLite Embutidos e Dinâmicos:
1. `hinario.db`:
   - Hinário Adventista Novo (600 hinos) e dados base.
   - Tabelas de favoritos, histórico, listas de culto, preferências.
   - Suporte a busca full-text (`hino_fts`, `biblia_fts`, `meditacao_fts`, `licao_fts`).
   - Tabelas da Escola Sabatina (`ss_quarterlies`, `ss_lessons`, `ss_days`, `ss_user_notes`, `ss_mind_maps`, `ss_question_answers`).
   - Gamificação e Quiz (`ss_questions_cache`, `user_quiz_answers`, `user_quiz_stats`, `quiz_reports`, `user_gamification`).
   - Devocionais cacheados (`cached_devotionals`, `cached_devotionals_v2`, `reading_log`).
2. `hinario_antigo.db`:
   - Hinário Adventista Antigo (edição histórica com letras, áudios e vídeos).
3. `hinario_comparativo.db`:
   - Mapeamento e comparativo métrico/textual entre hinos antigos e novos.
4. Bíblias (`ARA.sqlite`, `NTLH.sqlite`, `NVI.sqlite`, `KJA.sqlite`, `AS21.sqlite`, `biblia_leve.sqlite`):
   - Textos bíblicos versículo por versículo com metadados de testamento e livros.
5. Recursos de Estudo Avançado:
   - `commentaries.sqlite`: Comentários exegéticos e devocionais por passagem.
   - `cross_references.sqlite`: Cadeias de referências cruzadas bíblicas.
   - `pericopes.sqlite`: Títulos de seções bíblicas (perícopes).

---

## 2. Mapa de Rotas e Telas

| Rota | View / Classe | Descrição |
| :--- | :--- | :--- |
| `/` | `SelecaoView` | Tela inicial de boas-vindas com cards rápidos, destaques, ofensiva e acesso às seções. |
| `/novo` | `HinarioView` | Hinário Adventista Novo (lista, busca, filtros de temas e favoritos). |
| `/antigo` | `HinarioView` | Hinário Adventista Antigo (edição clássica). |
| `/novo/{id}` ou `/antigo/{id}` | `HinoView` | Tela detalhada do hino com letra, cifra, player de áudio e vídeo, comparativo e ajuste de fonte. |
| `/biblia` | `BibliaView` | Leitor da Bíblia completo com versões múltiplas, perícopes, referências cruzadas e comentários. |
| `/meditacoes` | `MeditacaoView` | Meditação Diária (Jovem, Mulher, Diário) com carrossel dos últimos 7 dias e áudio. |
| `/meditacao/destaque` | `MeditacaoDestaqueView` | Visualização em destaque (modo AndBible / Glassmorphism) com compartilhamento e imagem. |
| `/meditacoes/cache` | `GerenciarCacheView` | Gestor de cache das meditações diárias com limpeza e inspeção offline. |
| `/escola-sabatina` | `EscolaSabatinaView` | Lição da Escola Sabatina diária (Adultos e Jovens), tirinhas, perguntas interativas e notas. |
| `/escola-sabatina/trimestres` | `TrimestresView` | Seletor e navegador de trimestres da Escola Sabatina (atuais e passados). |
| `/escola-sabatina/tirinha` | `TirinhaView` | Visualizador de tela cheia com zoom/pan e download da tirinha/ilustração de domingo. |
| `/downloads` | `DownloadsView` | Gerenciador de downloads offline (Bíblias, lições completas de trimestre e áudios). |
| `/busca` | `BuscaResultadosView` | Busca global unificada (procura em hinos, bíblia, meditações e lições). |
| `/ofensiva` | `OfensivaView` | Gamificação, histórico de leituras consecutivas (streaks), metas e conquistas. |
| `/agente` | `AgenteView` | Assistente inteligente IA (baseado em Gemini) para tirar dúvidas bíblicas e temáticas. |

---

## 3. Módulos e Funcionalidades em Detalhes

### 3.1. Hinário (Novo e Antigo)
- **Visualização de Hinos**:
  - Título, número do hino, autor, compositor e referências bíblicas associadas.
  - Formatação tipográfica customizada (`HymnSerif`, `Montserrat`, `AppSans`, `OpenDyslexic`, `Helvetica`).
  - Modo Cifra / Modo Letra simples.
  - Transposição de tonalidade para músicos.
- **Reprodução Multimídia**:
  - Áudio cantado e playback instrumental.
  - Streaming online e download de áudios para reprodução offline (`MediaService`, `local_audio_server.py`, `audio_player_manager.py`).
  - Vídeos do YouTube integrados com extração leve via `yt-dlp`.
- **Comparativo Entre Edições**:
  - Botão na barra superior que compara lado a lado o hino novo com o correspondente antigo (`hymn_comparativo_dialog`).
- **Listas e Cultos**:
  - Criação de listas de músicas para cultos específicos (Culto de Quarta, Sábado, Jovem, etc.).
  - Favoritar hinos com ordenação e filtros.

### 3.2. Leitor Bíblico Multiversão
- **Versões Suportadas**: ARA (Almeida Revista e Atualizada), NVI, NTLH, KJA, AS21.
- **Navegação Ergonômica**:
  - Seletor de Livro (Antigo e Novo Testamento), Capítulo e Versículo.
  - Navegação fluida de capítulo anterior / próximo.
- **Recursos Exegéticos e de Estudo**:
  - **Perícopes**: Títulos editoriais que agrupam blocos de versículos.
  - **Referências Cruzadas**: Ao tocar num versículo, abre folha inferior com versículos paralelos relacionados.
  - **Comentários Bíblicos**: Acesso a notas de rodapé e comentários explicativos versículo por versículo.
  - **Marcadores e Destaques**: Salvar versículos favoritos com cores e notas de estudo.
  - **Barra de Contexto**: Permite navegar entre referências bíblicas vindas de meditações ou da lição.

### 3.3. Meditação Diária (Devocionais)
- **Categorias Suportadas**:
  - Meditação Jovem.
  - Meditação da Mulher.
  - Meditação Diária geral.
- **Regras Offline-First**:
  - Prioriza cache SQLite local.
  - Busca da nuvem (Supabase REST `daily_devotionals`) por data (`published_at`) e categoria.
  - Salva automaticamente no banco local após download.
  - Fallback automático para a meditação mais recente caso o dia esteja sem conexão.
- **Acessibilidade e Usabilidade**:
  - Carrossel horizontal para transição rápida entre os últimos 7 dias.
  - Versículo-chave em card destacado com abertura de modal bíblico (`VerseDialog`).
  - Botão de marcar leitura concluída (alimenta a ofensiva/streak).
  - Copiar meditação formatada e link direto para a fonte.
  - Modo Destaque (AndBible fullscreen e Glassmorphism).

### 3.4. Escola Sabatina e Trimestres
- **Edições e Categorias**: Adultos e Jovens.
- **Navegação Estruturada**: Trimestre ➔ Lição Semanal ➔ Dia de Estudo (Sábado a Sexta).
- **Tratamento de Imagens e Tirinhas**:
  - Parse de HTML para Markdown de alta legibilidade.
  - Tirinha / Ilustração de Domingo destacada em card interativo.
  - Visualizador de tela cheia com zoom interativo (pinch-to-zoom / double-tap) e botão para salvar imagem no dispositivo.
- **Estudo Interativo**:
  - Links bíblicos automáticos (`bible://livro%20cap:ver`) que abrem o leitor bíblico ou modal rápido com o texto sagrado.
  - Campo de anotações pessoais persistidas localmente por dia de estudo.
  - Respostas a perguntas reflexivas da lição com salvamento automático.
  - Estúdio de Mapa Mental (`mind_map_studio.py` e exportador).
- **Central de Downloads**:
  - Download da semana inteira ou do trimestre completo com 1 clique para leitura 100% offline.

### 3.5. Gamificação e Quizzes
- **Perguntas Interativas da Lição**:
  - Quizzes semanais de fixação da lição da Escola Sabatina gerados com base no conteúdo oficial.
  - Validação de respostas imediatas com explicações.
  - Pontuação, histórico de acertos e relatórios de desempenho (`quiz_reports`).
- **Ofensiva (Reading Streaks)**:
  - Registro diário de leituras concluídas (meditação, lição e bíblia).
  - Cálculo de dias consecutivos em sequência (streak).
  - Badges e marcos comemorativos de fidelidade de leitura.

### 3.6. Busca Global Unificada (`search_service.py`)
- Consulta rápida integrada com SQLite FTS (Full-Text Search):
  - Pesquisa simultânea em: Letras de hinos, passagens bíblicas, textos de meditações diárias e lições da Escola Sabatina.
  - Destaque dos termos encontrados nos resultados.

### 3.7. Agente de Inteligência Artificial (`agente_service.py` / `agente_view.py`)
- Chat conversacional alimentado pela API do Google Gemini.
- Contextualizado com as Escrituras e Hinologia:
  - Responde dúvidas sobre passagens, contexto histórico e doutrinário.
  - Recomenda hinos correspondentes a temas de sermões ou meditações.

### 3.8. Sincronização em Nuvem e Autenticação (`auth_service.py` / `cloud_sync_service.py`)
- Supabase Auth:
  - Login / Cadastro de usuário e suporte a OAuth.
  - `nhaapp://login-callback` para autenticação via Deep Link.
- Sincronização automática em segundo plano:
  - Sincronização de hinos favoritos (Novo e Antigo).
  - Histórico de acessos.
  - Ofensiva e progresso devocional (`public.reading_streaks`).

### 3.9. Sistema de Temas e Personalização (`theme_service.py` / `palette.py`)
- Modos: Claro, Escuro, Sistema e **Modo AMOLED / OLED** (preto puro).
- Paletas de Cores:
  - Material You (Dynamic / Monet).
  - Temas clássicos: Ouro/Dourado (Gold), Azul Celeste, Verde Oliva, Carmesim, etc.
  - Estilos especiais: Kids Style (cores lúdicas) e Glassmorphism (efeito vidro translúcido).
- Tamanho e família de fontes persistidas por seção (Bíblia, Hino, Meditação, Lição).

### 3.10. Atualizador Automático Integrado (`updater_service.py`)
- Verificação assíncrona no GitHub Releases em segundo plano.
- Detecção da arquitetura do aparelho (ARM64, ARMv7, x86_64).
- Download e disparo da instalação do APK diretamente dentro do app.

---

## 4. Checklist de Validação para a Migração Flutter

- [ ] **Hinário**:
  - [x] Listagem e busca de hinos (Novo e Antigo).
  - [x] Visualização de letra e cifra.
  - [x] Player de áudio com streaming e cache offline.
  - [x] Comparativo de hinos novo vs antigo.
  - [x] Favoritos e listas de culto.
- [ ] **Bíblia**:
  - [x] Leitor com navegação rápida de livros/capítulos.
  - [x] Seletor de múltiplas versões (ARA, NVI, NTLH, KJA, AS21).
  - [x] Perícopes (títulos de seção).
  - [x] Referências cruzadas e comentários por versículo.
  - [x] Marcadores e destaques.
- [ ] **Meditação**:
  - [x] Categorias Jovem, Mulher e Diário.
  - [x] Integração REST Supabase com cache local offline.
  - [x] Carrossel de datas e cálculo de ofensiva.
  - [x] Modo destaque e compartilhamento.
- [ ] **Escola Sabatina**:
  - [x] Trimestres de Adultos e Jovens.
  - [x] Renderização de conteúdo com links bíblicos clicáveis.
  - [x] Tirinhas e ilustrações com zoom e modo offline.
  - [x] Anotações e respostas de perguntas persistidas.
  - [x] Quizzes e gamificação da lição.
- [ ] **Geral / Sistema**:
  - [x] Temas (Claro, Escuro, AMOLED, Material You).
  - [x] Ajustes de acessibilidade de fontes.
  - [x] Busca global unificada.
  - [x] Sincronização em nuvem e login.
  - [x] Atualizações via GitHub Releases.

