# Project Context - Kairós

Este documento serve como mapa de arquitetura e contexto de engenharia para agentes e desenvolvedores trabalhando no repositório **Kairós**.

---

## 1. Visão Geral da Arquitetura do App

O **Kairós** é uma aplicação multiplataforma (foco primário: **Android** e **Web/PWA**) voltada para leitura bíblica, hinários comparativos, lições da Escola Sabatina, devocionais diários e quizzes interativos.

### 1.1 Gerenciamento de Estado
- **Arquitetura Reativa Nativa**: Não depende de pacotes externos pesados (sem Provider, Bloc, Riverpod ou GetX no `pubspec.yaml`).
- **Padrão Utilizado**:
  - `ChangeNotifier` em controladores de domínio (`lib/controllers/`).
  - `ValueNotifier` para estados atômicos de tela.
  - Reatividade na UI via `AnimatedBuilder`, `ListenableBuilder` e `StatefulWidget`.
  - Serviços transversais organizados como Singletons ou instâncias injetadas (`lib/services/`).

### 1.2 Estrutura de Diretórios (`lib/`)
```
lib/
├── controllers/          # Controladores de negócio com ChangeNotifier
│   ├── bible_controller.dart
│   ├── devotional_controller.dart
│   ├── hymn_controller.dart
│   ├── quiz_controller.dart
│   └── sabbath_school_controller.dart
├── core/
│   ├── config/           # Configurações globais e injeção de env (app_config.dart)
│   ├── constants/        # Nomes de bancos, constantes de sistema (app_constants.dart)
│   ├── database/         # Abstração de banco SQLite multiplataforma
│   │   ├── database_manager.dart       # Fachada e preservação de dados de usuário
│   │   ├── database_manager_stub.dart  # Stub para compilador Dart
│   │   ├── database_manager_io.dart    # SQLite FFI para Android/Desktop
│   │   └── database_manager_web.dart   # SQLite Wasm + IndexedDB para Web
│   ├── theme/            # Temas light/dark, paletas cromáticas e TextScaler responsivo
│   └── utils/            # Utilitários de parsing bíblico e extração de texto
├── data/
│   ├── repositories/     # Camada de acesso a dados (SQL e APIs remotas)
│   └── services/         # Clientes de dados externos (ex: sabbath_school_service.dart)
├── models/               # Modelos imutáveis e serialização
├── services/             # Serviços globais (Auth, ContentManager, Theme, Audio, etc.)
│   ├── audio_file_handler_*.dart # Tratamento condicional de áudio (stub, io, web)
│   ├── auth_service.dart         # Integração Supabase Auth e Google Sign-In
│   ├── content_manager.dart      # Download dinâmico de módulos remotos (R2/CDN)
│   └── devotional_service.dart   # Leitura de devocionais
└── views/                # Telas e componentes visuais organizados por domínio
    ├── bible/            # Leitor bíblico, sheets de contexto e referências
    ├── devotional/       # Visualização diária de meditações
    ├── downloads/        # Gerenciamento de módulos e downloads de Bíblias
    ├── gamification/     # Streaks e progresso
    ├── home/             # Dashboard principal
    ├── hymns/            # Hinário Adventista clássico e novo com áudio
    ├── lesson/           # Lição da Escola Sabatina e estúdio de mapas mentais
    ├── quiz/             # Quizzes diários gamificados
    ├── settings/         # Ajustes de tema, paleta cromática e configurações
    └── splash/           # Inicialização e checagem de integridade
```

---

## 2. Estratégia de Bancos de Dados SQLite

O repositório opera com bancos SQLite tanto localmente no dispositivo (via SQLite FFI em Android) quanto na Web (via SQLite Wasm com VFS sobre IndexedDB):

### 2.1 Bancos Empacotados vs. Sob Demanda
- **Empacotados diretamente no bundle (`pubspec.yaml` assets)**:
  - `assets/ARA.sqlite` (Versão Bíblica Almeida Revista e Atualizada - padrão inicial offline).
  - `assets/commentaries.sqlite` (Comentários bíblicos).
  - `assets/cross_references.sqlite` (Referências cruzadas).
  - `assets/pericopes.sqlite` (Títulos e subtítulos de seções bíblicas).
  - `assets/hinario.db`, `assets/hinario_antigo.db`, `assets/hinario_comparativo.db`.
- **Bancos Opcionais / Sob Demanda**:
  - `assets/AS21.sqlite`, `assets/KJA.sqlite`, `assets/NTLH.sqlite`, `assets/NVI.sqlite` estão presentes no repositório de dados, mas **NÃO** são empacotados no APK/Web bundle via `pubspec.yaml` para manter o tamanho do aplicativo leve.
  - Ao serem requisitados pelo usuário, o `database_manager` detecta a ausência no `rootBundle` e aciona o `ContentManager` para realizar o download remoto descompactando do Cloudflare R2 ou CDN.
- **Preservação de Dados de Usuário**:
  - `database_manager.dart` possui a lista `userPreservedTables` que protege anotações, favoritos, histórico e progresso do usuário contra sobreposição durante atualizações de schemas de assets.

---

## 3. Ecossistema de Scripts Python (`scripts/`)

O repositório contém uma suíte de automação em Python utilizada para preparação de conteúdo e ingestão diária:
- `meditacao.py`: Faz o scraping das meditações diárias da CPB (jovem, diário, mulher), limpa a estrutura de texto/HTML, extrai referências bíblicas e executa o `upsert` no Supabase.
- `generate_quizzes_gemini.py`: Conecta à Adventech API (`sabbath-school.adventech.io`), obtém o conteúdo das lições ativas e gera quizzes de múltipla escolha com 4 opções e validações estritas usando a API Google Gemini (via SDK `google-genai` e validação com `pydantic`), salvando no Supabase.
- `build_search_index.py`, `generate_biblia_leve.py`, `package_web_db.py`: Scripts utilitários de compressão e indexação SQLite para otimização de distribuição Web e mobile.

---

## 4. Pipelines CI/CD no GitHub Actions (`.github/workflows/`)

O projeto conta com 5 pipelines automatizados:
1. `ci.yml`:
   - Gatilho: `push` e `pull_request` em `main` e `master`.
   - Propósito: Executa `flutter analyze` e `flutter test` para garantir integridade contínua do código Dart.
2. `cd.yml`:
   - Gatilho: Tags `v*` ou disparo manual via `workflow_dispatch`.
   - Propósito: Prepara os bancos SQLite (modo `DELETE`), injeta variáveis de ambiente no `.env`, compila split APKs para Android (`arm64-v8a`, `armeabi-v7a`, `x86_64`), assina opcionalmente com Keystore e publica GitHub Release.
3. `deploy-pages.yml`:
   - Gatilho: Após conclusão com sucesso do CI (`workflow_run`) em branches principais ou `workflow_dispatch`.
   - Propósito: Compila o Flutter Web com release flags e implanta no GitHub Pages.
4. `generate_quizzes.yml`:
   - Gatilho: Agendado semanalmente (domingos às 23:00 UTC) e manual via `workflow_dispatch`.
   - Propósito: Executa `scripts/generate_quizzes_gemini.py` com credenciais Gemini e Supabase.
5. `pegar_devo.yml`:
   - Gatilho: Agendado diariamente (03:30 UTC) e manual via `workflow_dispatch`.
   - Propósito: Executa `scripts/meditacao.py` para sincronizar as meditações diárias no Supabase.
