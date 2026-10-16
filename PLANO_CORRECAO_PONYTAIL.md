# Plano de Correção e Simplificação (`/ponytail`)

Filosofia aplicada: **O melhor código é o código que não precisa existir.**
1. **Bug fix = causa raiz, não sintoma**: Corrigir uma vez onde todos os chamadores passam.
2. **Deleção antes de adição**: Remover código morto e wrappers inúteis antes de refatorar.
3. **Stdlib e recursos existentes no repositório primeiro**: Usar `DatabaseConnection`, `storage_manager` e `pathlib`/`hashlib`/`dataclasses` nativos.
4. **Zero abstrações especulativas**: Sem criar "frameworks internos" novos; apenas funções diretas e enxutas.

---

## Fase 1: Correções Cirúrgicas de Bugs (Root-Cause Fixes, Menor Diff)

| # | Alvo | O que vamos fazer (Solução Ponytail) |
|---|------|--------------------------------------|
| **1.1** | [escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L124) | **Crash ao digitar resposta**: Adicionar `self._q_debounce_tasks: dict[str, asyncio.Task] = {}` no `__init__` (1 linha). |
| **1.2** | [escola_sabatina_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/escola_sabatina_service.py#L834-L857) | **IDs de perguntas mudando a cada boot**: Trocar `abs(hash(text)) % 100000` por `hashlib.sha256(text.encode()).hexdigest()[:8]` (determinístico entre reinícios). |
| **1.3** | [selecao_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L776-L791) | **Modal Versículo do Dia preso em Sl 119:105**: Deletar as 15 linhas de introspecção de `ft.Column` e ler direto `self._cached_ref_str or "Salmos 119:105"` e `self._cached_preview_str` (-13 linhas). |
| **1.4** | [theme_engine.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/theme/theme_engine.py#L9) | **`NameError: os` no Linux Dark Mode**: Adicionar `import os` no topo de `theme_engine.py` (1 linha). |
| **1.5** | [quiz_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/quiz_view.py#L120-L121) | **Botão do Quiz travado em "Verificar"**: Guardar `self._action_btn_text = ft.Text("Verificar")` e atualizar `self._action_btn_text.value` em `_render_question` e `_check_answer`. |
| **1.6** | [quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L262-L269) & [#L387-L392](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L387-L392) | **Quiz Offline**: (a) Não persistir perguntas mock `[DEV]` no SQLite (`ss_questions_cache`), apenas retorná-las em memória; (b) Usar `calculate_streak` de `src/utils/gamification.py` (que já existe no repo!) em vez de incrementar `curr_streak + 1` cegamente. |
| **1.7** | [search_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/search_service.py#L193) | **Hinos duplicados na busca**: Padronizar a chave do dicionário na etapa 1 para `results[f"hino_{hid}"] = ...` (1 linha). |
| **1.8** | [connection.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/database/connection.py#L290-L295) & [#L592-L627](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/database/connection.py#L592-L627) | **Banco de dados**: (a) Aplicar `HINARIO_DB_PATH` apenas quando `db_path` for o banco principal (`hinario.db`); (b) Em `_sync_user_data_and_replace`, copiar usando interseção de nomes de colunas (`PRAGMA table_info`) em vez de `SELECT *` posicional. |
| **1.9** | [meditacao_destaque_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/meditacao_destaque_view.py#L220-L221) & [mind_map_studio.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/components/mind_map_studio.py#L21) | **Paths quebrados + UI congelada**: Resolver caminho das fontes via `Path(__file__).resolve().parents[1] / "assets" / "fonts"`, corrigir `_project_root` (3 `parent`s em vez de 4), usar contador incremental para IDs de nós do mapa mental e rodar `_generate_and_save_image` via `asyncio.to_thread`. |
| **1.10** | [storage_manager.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/utils/storage_manager.py#L17) & [wallpaper_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/wallpaper_service.py#L17) | **Crash de permissão no Android**: Usar `DatabaseConnection._get_user_data_dir()` em vez de `Path.home() / ".config" / "kairos"`. |
| **1.11** | [escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L647), [gerenciar_cache_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/gerenciar_cache_view.py#L203), [downloads_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/downloads_view.py#L400), [agente_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/agente_view.py#L693) | **Flet Coroutines & Rotas**: Usar `page.run_task(page.launch_url, url)`, corrigir rota `/novo/hino/{h_id}` no `AgenteView`, e usar `page.on_view_pop` padrão no `_go_back`. |
| **1.12** | [quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L88) & [notification_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/notification_service.py#L85) | **Vazamento de conexões SQLite**: Envolver `sqlite3.connect(...)` com `contextlib.closing(...)` (ou usar `DatabaseConnection`), garantindo `conn.close()` imediato. |

---

## Fase 2: Faxina Ponytail — Deleção de Código Morto (`delete:`)

Zero mudança de comportamento; apenas remoção de peso morto que hoje consome CPU/memória ou polui a leitura:

1. **Em [src/views/hino_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/hino_view.py#L1939-L2508)**: Deletar os ~510 lines de visualização bíblica inline desativada e chips comparativos nunca chamados (`_carregar_biblia_passagem`, `_build_biblia_content`, `_build_biblia_inline_*`, `_build_comparativo_chip`, `_build_edition_feedback_banner`).
2. **Em [src/views/selecao_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L1123-L1292)**: Deletar `_build_edition_card`, `_update_weekly_dots` e a instanciação inútil de `card_hinarios`, `card_biblia`, `card_meditacao`, `card_escola_sabatina` ([linhas 1490-1593](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L1490-L1593)) que são criados a cada `build()` e descartados sem entrar na tela (~300 linhas).
3. **Em [src/views/biblia_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/biblia_view.py#L2637-L2769)**: Deletar `_show_verse_context_menu` e os controles órfãos `version_dropdown`, `prev_btn`, `next_btn`, `prev_chip_btn`, `next_chip_btn` (~160 linhas).
4. **Em [src/services/theme_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/theme_service.py#L503-L555)**: Deletar `_apply_novo_theme` (nunca chamado) e a redefinição duplicada de `COLOR_SEEDS` ([linhas 30-38](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/theme_service.py#L30-L38)).
5. **Shims e Aliases mortos**:
   - Remover `src/views/components/mind_map_studio.py`, `src/views/components/__init__.py` e `src/database/devotional_repo.py` (atualizando os 3 imports diretos para os módulos reais).
   - Remover os ~30 aliases em Português/Inglês sem nenhum chamador em `src/models/__init__.py`, `src/repositories/__init__.py` e `src/services/__init__.py` *(mantendo apenas os que são importados por `main.py` ou `tests/`)*.

---

## Fase 3: Padronização e Deduplicação (`stdlib:` & `shrink:`)

Seguindo o degrau 2 e 3 da escada Ponytail (*"Already in this codebase? Reuse it. Stdlib does it? Use it."*):

1. **Substituições por Stdlib de 1 linha (`stdlib:`)**:
   - [media_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/media_service.py#L79-L94): `path_to_file_uri` → `return Path(filepath).resolve().as_uri()`.
   - [updater_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/updater_service.py#L334-L340): `calculate_sha256` → `hashlib.file_digest(f, "sha256").hexdigest().lower()`.
   - [mind_map_exporter.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/utils/mind_map_exporter.py#L65-L76): `_normalize_char` → `unicodedata.normalize("NFD", text)`.
   - [escola_sabatina.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/models/escola_sabatina.py#L46-L167): `to_dict()` nas 4 dataclasses → `dataclasses.asdict(self)`.
2. **Deduplicação de Repositórios e Serviços (`shrink:`)**:
   - **`BibliaRepository.buscar_capitulo_completo`** ([biblia_repository.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/biblia_repository.py#L873-L939)): Delegar para `await self.buscar_capitulo(parsed["book_id"], parsed["chapter"], versao=versao)` (-45 linhas).
   - **`CommentaryRepository`, `CrossReferenceRepository`, `PericopeRepository`**: Remover `_candidate_dirs()` e `_resolve_db_connection()` triplicados e passar apenas o nome do `.sqlite` para `DatabaseConnection(self.db_path, read_only=True)` (-120 linhas).
   - **`QuizService.get_unified_user_stats`** ([quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L500-L575)): Extrair a query unificada em um único helper compartilhado com `ReadingService.get_unified_user_stats` (-70 linhas).
   - **`MediaService`** ([media_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/media_service.py#L465-L682)): Unificar `download_library_batch` / `download_audio_batch` e `get_storage_usage` / `get_audio_storage_usage` parametrizando o diretório/função de download (-60 linhas).
   - **`ThemeEngine.apply_theme`** ([theme_engine.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/theme/theme_engine.py#L506-L694)): Extrair helper `_palette_to_scheme(pal: ThemePalette) -> ft.ColorScheme` em vez de montar `ft.ColorScheme` 7 vezes (-130 linhas).
   - **`AgenteService._montar_ordem_culto`** ([agente_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/agente_service.py#L277-L498)): Substituir os 3 blocos imperativos de 220 linhas por montagem declarativa + numeração `enumerate` no final (-150 linhas).
3. **Deduplicação de Componentes de UI (`shrink:`)**:
   - Mover `_show_floating_verse_dialog` (idêntico em `MeditacaoView` e `EscolaSabatinaView`) para dentro de [src/components/verse_dialog.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/components/verse_dialog.py) (-125 linhas).

---

## Como Sugiro Executarmos Isso

Para manter tudo seguro, testável e sem quebrar o contrato com o `main.py` nem com a suíte de testes existente (`pytest`):

1. **Execução em 3 lotes curtos (por Fase)** com validação via `pytest` ao final de cada lote:
   - **Lote 1 (Fase 1 — Bugs)**: Aplicamos os 12 fixes cirúrgicos de causa raiz e rodamos os testes.
   - **Lote 2 (Fase 2 — Deleção Ponytail)**: Removemos o código morto de `HinoView`, `SelecaoView`, `BibliaView`, `ThemeService` e shims desnecessários, mantendo `pytest` verde.
   - **Lote 3 (Fase 3 — Shrink & Stdlib)**: Aplicamos as reduções de stdlib e deduplicações nos repositórios, serviços e `verse_dialog.py`.
2. **O que deixamos de fora de propósito (YAGNI)**:
   - **Não** vamos quebrar `BibliaView` ou `HinoView` em dezenas de micro-arquivos novos só por "arquitetura limpa" — deletar as ~970 linhas de código morto dentro delas e extrair o que já é duplicado resolve o problema real com metade do risco.
   - **Não** vamos tocar no `main.py` (conforme solicitado).

