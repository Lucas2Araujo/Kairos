# Contexto e Arquitetura do Repositório: Kairós (Hinário & Meditações)

Este documento reúne a visão técnica atualizada, arquitetural e operacional do projeto Kairós. Serve como guia de referência técnica para desenvolvedores e agentes de IA em manutenções e evoluções futuras.

---

## 1. Visão Geral do Projeto

* **Nome do App**: Kairós (Hinário Adventista, Bíblia, Meditações e Lições)
* **Stack Principal**:
  * **Framework de Interface**: [Flet](https://flet.dev/) (Python sobre Flutter / Serious Python).
  * **Linguagem**: Python 3.12+ (compatível e testado em Python 3.14).
  * **Banco de Dados Local**: SQLite3 com WAL mode (`PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;`).
  * **Sincronização em Nuvem / Autenticação**: Supabase (via `httpx` e cliente oficial).
  * **Empacotamento Mobile**: Serious Python (`serious_python_android`) + Flutter Build APK.
  * **Gerenciador de Dependências**: Poetry / UV (`pyproject.toml`).
  * **Testes**: Pytest (411+ testes automatizados cobrindo views, repositórios, serviços e conexões).

---

## 2. Estrutura de Diretórios e Módulos

```text
Hinário_App/
├── .github/
│   └── workflows/
│       ├── ci.yml               # Execução de 411 testes Pytest + atualização de badge
│       └── cd.yml               # Bump SemVer, injeção de versão, split APKs, assinatura e releases
├── assets/                      # Ícones, fontes personalizadas, splash screens e áudios
├── src/
│   ├── components/              # Componentes visuais desacoplados (ex: verse_dialog.py)
│   ├── config/                  # Constantes globais, temas e clientes Supabase
│   ├── database/                # Conexões SQLite, compatibilidade async/WASM e repositórios core
│   │   ├── connection.py        # DatabaseConnection, migrações de seed e ALLOWED_USER_TABLES
│   │   └── devotional_repo.py   # Persistência de meditações diárias
│   ├── repositories/            # Camada de acesso a dados por domínio (hinos, favoritos, histórico, culto, escola sabatina)
│   ├── services/                # Regras de negócio e integrações assíncronas
│   │   ├── updater_service.py   # Checagem de atualizações no GitHub Releases e download com SHA-256
│   │   ├── audio_player_manager.py # Gestão unificada de playback de áudio no Desktop e Mobile
│   │   ├── auth_service.py      # Autenticação Supabase, OAuth desktop/deep linking
│   │   ├── agente_service.py    # Agente litúrgico inteligente e recomendador de hinos
│   │   └── reading_service.py   # Gamificação, streaks de leitura e sync de progresso
│   ├── utils/                   # Utilitários puros sem dependências pesadas
│   │   ├── bible_extractor.py   # Extração e normalização de referências bíblicas via regex
│   │   ├── mind_map_exporter.py # Geração direta de PNG (binário puro zlib/struct sem Pillow)
│   │   ├── storage_manager.py   # Persistência em cascata (client_storage -> prefs -> RAM)
│   │   └── font_manager.py      # Gestão de tipografia dinâmica
│   ├── views/                   # Telas Flet e controladores de navegação
│   │   ├── home_view.py         # Tela inicial unificada
│   │   ├── hinario_view.py      # Navegação e busca de hinos (Novo e Antigo)
│   │   ├── biblia_view.py       # Leitor bíblico completo (ARA, NVI, etc.)
│   │   ├── meditacao_view.py    # Meditações matinais diárias com suporte a áudio
│   │   ├── escola_sabatina_view.py # Lição da Escola Sabatina com notas e mapas mentais
│   │   ├── settings_dialog.py   # Preferências de fonte, tema, cache e downloads
│   │   └── update_dialog.py     # Diálogo de download e instalação de APK via FileProvider
│   └── version.py               # Ponto canônico de versão da aplicação (__version__)
├── tests/                       # Suíte completa de testes unitários e de integração
├── main.py                      # Ponto de entrada da aplicação, AppRouter e injeção de dependências
└── pyproject.toml               # Metadados do projeto, dependências e configurações de ferramentas
```

---

## 3. Banco de Dados Local e Ciclo de Vida do SQLite

### 3.1 Conexões e Concorrência
* Abertura gerenciada via `DatabaseConnection` ([`src/database/connection.py`](file:///home/loko/Documentos/ufMA/Hinário_App/src/database/connection.py)).
* No Android e Desktop nativo, utiliza conexões com thread pools assíncronas (`asyncio.to_thread` ou `aiosqlite`), aplicando sempre `PRAGMA journal_mode = WAL;` e `PRAGMA busy_timeout = 5000;` para mitigar travamentos (`database is locked`).

### 3.2 Migração de Sementes e Preservação de Dados (`ALLOWED_USER_TABLES`)
* O aplicativo distribui um banco SQLite de semente inicial (`hinario.db`, `hinario_antigo.db`, `ARA.sqlite`).
* Ao lançar atualizações com novas letras de hinos, o banco é substituído pelo método `_sync_user_data_and_replace`.
* **Ponto Crítico de Integridade**: Dados do usuário que devem **sempre** ser preservados durante a substituição constam na lista canônica `ALLOWED_USER_TABLES`:
  1. `favoritos`
  2. `historico`
  3. `lista_culto` / `lista_culto_item`
  4. `user_preferences` / `user_notes`
  5. `cached_devotionals` / `reading_log`
  6. `verse_highlights`
  7. `hinos_personalizados`
  8. `offline_downloads`
  9. `ss_mind_maps` (mapas mentais de lição)
  10. `ss_question_answers` (respostas das lições)
  11. `user_gamification` (progresso, XP e streaks)
  12. `notification_reminders` (lembretes agendados)

---

## 4. Pipeline CI/CD e Histórico de Resolução de Bugs

### 4.1 CI ([`.github/workflows/ci.yml`](file:///home/loko/Documentos/ufMA/Hinário_App/.github/workflows/ci.yml))
* Executa a cada push e pull request para as branches principais.
* Roda `pytest tests/` em ambiente Python virtualizado.
* Atualiza dinamicamente o badge de aprovação de testes no `README.md`.

### 4.2 CD ([`.github/workflows/cd.yml`](file:///home/loko/Documentos/ufMA/Hinário_App/.github/workflows/cd.yml))
* Acionado após a conclusão bem-sucedida do CI na branch `main`.
* **Job `check-and-tag`**: Analisa commits para cálculo de SemVer automático via `mathieudutour/github-tag-action`.
* **Job `build-and-release-android`**:
  * Injeta a versão calculada em `src/version.py` e `pyproject.toml`.
  * Prepara os assets SQLite e executa `flet build apk`.
  * **Fallback do Serious Python (Resolvido)**:
    * Se o `flet build apk` falhar por incompatibilidade de JNI (`jni: 1.0.0` vs `^1.1.0`), o fallback aciona o `flutter build apk` diretamente em `build/flutter`.
    * **Bug Histórico**: O fallback definia a variável incorreta `SERIOUS_PYTHON_APP_DIR`. O plugin Gradle do Serious Python consome estritamente **`SERIOUS_PYTHON_APP`**.
    * **Solução Canônica**:
      ```bash
      # Garante a versão injetada na pasta de staging do Serious Python
      mkdir -p "$GITHUB_WORKSPACE/build/python-app"
      cp -r src assets main.py "$GITHUB_WORKSPACE/build/python-app/" 2>/dev/null || true
      cp -f src/version.py "$GITHUB_WORKSPACE/build/python-app/src/version.py"

      # Exporta ambas as variáveis para compatibilidade
      export SERIOUS_PYTHON_SITE_PACKAGES="$GITHUB_WORKSPACE/build/site-packages"
      export SERIOUS_PYTHON_APP="$GITHUB_WORKSPACE/build/python-app"
      export SERIOUS_PYTHON_APP_DIR="$GITHUB_WORKSPACE/build/python-app"
      ```
  * Gera split APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`), assina com keystore e publica no GitHub Releases com changelog automático.

---

## 5. Serviços e Padrões de Arquitetura

1. **Atualizador (`UpdaterService`)**:
   * Consulta a API do GitHub Releases com cache em memória (TTL: 10 min).
   * Mapeia a arquitetura do processador (`os.uname().machine`) para baixar o APK exato para a ABI do dispositivo.
   * Validação de integridade atômica via SHA-256 e acionamento de `FileProvider` via PyJNIus no Android.
2. **Reprodutor de Áudio (`AudioPlayerManager`)**:
   * Controla a reprodução de hinos cantados e instrumentais.
   * No desktop, utiliza controle de áudio assíncrono; no mobile, conecta-se ao controle `ft.Audio` garantindo cleanup de instâncias antigas em `page.overlay`.
3. **Desacoplamento e Performance (/ponytail)**:
   * **Geração de Imagens**: `mind_map_exporter.py` evita bibliotecas C pesadas (Pillow/PIL), escrevendo arquivos PNG com chunks `IHDR`, `IDAT`, `IEND` nativos via `zlib` e `struct`.
   * **Extração de Texto**: `bible_extractor.py` centraliza expressões regulares para identificar referências bíblicas, evitandoparsers duplicados na UI.
   * **Throttling de Scroll**: Telas com pull-to-refresh (`meditacao_view.py`, `selecao_view.py`) validam a trava síncrona de refresh **antes** de instanciar tarefas assíncronas no loop de eventos.

---

## 6. Comandos e Procedimentos de Desenvolvimento

* **Ativar Ambiente Virtual**:
  ```bash
  source .venv/bin/activate
  ```
* **Executar App Localmente**:
  ```bash
  flet run main.py
  ```
* **Executar Testes**:
  ```bash
  pytest tests/
  ```
* **Rodar Testes Específicos**:
  ```bash
  pytest tests/test_updater_service.py tests/test_database_connection.py
  ```
