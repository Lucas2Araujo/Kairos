# Relatório de Varredura e Diagnóstico (`src/`)

Este documento consolida todos os achados da varredura estática e arquitetural em `src/` (cobrindo `database/`, `models/`, `repositories/`, `services/`, `theme/`, `utils/`, `components/` e `views/`, totalizando ~40.000 linhas de código, excluindo `main.py`).

---

## 1. Bugs Críticos e Potenciais (Crashes, Perda de Dados, Concorrência e Vazamentos)

### 1.1 Crashes e Funcionalidades Quebradas na UI (`src/views/`)
1. **`AttributeError` ao digitar respostas na Escola Sabatina** ([escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L2249-L2252))
   - `_on_question_answer_change` acessa `self._q_debounce_tasks`, mas esse atributo **nunca é inicializado** no `__init__` ([linhas 82-145](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L82-L145)). Digitar qualquer caractere em uma pergunta de estudo lança `AttributeError: 'EscolaSabatinaView' object has no attribute '_q_debounce_tasks'`.
2. **Modal "Versículo do Dia" exibe sempre Salmos 119:105 (Introspecção de UI quebrada)** ([selecao_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L776-L791))
   - `_mostrar_modal_glass_versiculo` tenta extrair o versículo inspecionando `isinstance(self.verse_container.content, ft.Column)`. Porém `_build_verse_card_content` ([linha 610](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L610)) retorna um `ft.Stack`, fazendo com que a condição seja sempre `False` e o modal ignore `self._cached_ref_str` / `self._cached_preview_str` ([linhas 670-672](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L670-L672)).
3. **Caminho absoluto da máquina do dev hardcoded + Bloqueio do Event Loop na geração de imagem** ([meditacao_destaque_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/meditacao_destaque_view.py#L188-L274))
   - As linhas 220–221 usam `/home/loko/Documentos/ufMA/Hinário_App/assets/fonts/HymnSerif-Regular.ttf` hardcoded (falha no Android/Windows/outros PCs). Além disso, `_handle_download` e `_handle_share` rodam `urllib.request.urlopen` e composição PIL 1080×1920 de forma síncrona na thread principal da UI.
4. **Mutação de rótulo de botão sem efeito no Quiz (Flet 0.85+)** ([quiz_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/quiz_view.py#L120-L121))
   - `self.action_button = ft.Button(content=ft.Text("Verificar"))` define `content`, mas nas [linhas 206 e 381](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/quiz_view.py#L206) o código altera `self.action_button.text = "Continuar"`. Quando `content` está definido, `.text` é ignorado pelo Flet.
5. **Coroutine `page.launch_url` chamada sem `await` / `run_task`** ([escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L647))
   - `_on_tap_link` chama `self.page.launch_url(url)` de forma síncrona, gerando `RuntimeWarning: coroutine 'Page.launch_url' was never awaited` e não abrindo o link.
6. **Uso inválido de `page.run_task(lambda: res)`** ([gerenciar_cache_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/gerenciar_cache_view.py#L203-L205))
   - Nas linhas 203–205 e 250–252, `self.page.run_task(lambda: res)` passa uma `lambda` síncrona em vez de uma função `async def`, falhando na checagem `asyncio.iscoroutinefunction` do Flet.
7. **Navegação `_go_back` corrompe pilha de views no Flet** ([downloads_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/downloads_view.py#L400-L406), [agente_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/agente_view.py#L1090-L1096))
   - Faz `page.views.pop()` seguido de `await page.push_route(top_view.route)`, disparando `on_route_change` novamente para a rota anterior sem passar pelo `on_view_pop` do `AppRouter`.

### 1.2 Perda de Dados, Estado Inconsistente e Bugs de Negócio (`src/services/`, `src/database/`, `src/theme/`)
8. **Perda de respostas salvas da Escola Sabatina a cada reinício do app** ([escola_sabatina_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/escola_sabatina_service.py#L834-L857))
   - Os IDs das perguntas (`q_id = f"q_sec_{abs(hash(clean)) % 100000}"`) usam `hash()` nativo do Python, que possui *salt* aleatório por processo (`PYTHONHASHSEED`). A cada reinicialização do app, o `q_id` muda e as respostas salvas no SQLite deixam de casar com as perguntas da lição.
9. **`NameError: name 'os' is not defined` silenciado no detector de Dark Mode no Linux** ([theme_engine.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/theme/theme_engine.py#L48-L52))
   - `_sync_detect_system_dark_mode()` usa `os.environ.get(...)` na linha 49, mas `import os` não existe em `theme_engine.py`. O `NameError` cai no `except Exception: pass` ([linha 88](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/theme/theme_engine.py#L88)), fazendo `detect_system_dark_mode()` retornar sempre `False` no Linux.
10. **Cálculo de Ofensiva (Streak) quebrado no modo offline do Quiz** ([quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L387-L392))
    - Verifica apenas `if last_date == today_str: new_streak = curr_streak else: new_streak = curr_streak + 1`, sem checar se `last_date` foi ontem (`today - 1 day`). Se o usuário ficar 30 dias sem jogar, a ofensiva incrementa em vez de resetar para 1.
11. **Contaminação permanente do banco local com perguntas `[DEV]` mockadas** ([quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L262-L269))
    - Quando offline e sem cache para o `day_id`, `get_daily_quiz` gera perguntas falsas `[DEV Adultos]` e chama `await self.save_question_to_cache(mq)`, gravando-as permanentemente na tabela SQLite `ss_questions_cache`.
12. **Duplicação de hinos nos resultados de busca por chave divergente** ([search_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/search_service.py#L193-L224))
    - A busca exata por número insere no dicionário `results` usando a chave `hid` (ex: `"10"`), enquanto a busca FTS5 verifica `item_key = f"hino_{hid}"` (ex: `"hino_10"`). O mesmo hino entra duas vezes.
13. **Sobrescrita global de todos os bancos quando `HINARIO_DB_PATH` / `DB_PATH` está definido** ([connection.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/database/connection.py#L290-L295))
    - `_resolve_db_path(db_path)` retorna a variável de ambiente antes de checar qual arquivo foi solicitado, fazendo conexões de `ARA.sqlite`, `hinario_antigo.db`, `commentaries.sqlite`, etc., apontarem todas para `hinario.db`.
14. **Perda silenciosa de dados de usuário em migração de seed (`SELECT *`)** ([connection.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/database/connection.py#L592-L627))
    - `_sync_user_data_and_replace` faz `SELECT * FROM {tbl}` e `INSERT OR IGNORE INTO {tbl} VALUES (...)` posicional, engolindo `sqlite3.Error: pass`. Se uma tabela ganhar uma coluna nova na atualização, o `INSERT` falha silenciosamente e os dados do usuário naquela tabela são perdidos.
15. **Corrupção de código ao exportar PNG no `MindMapStudio` (diretório raiz errado + colisão de IDs)** ([mind_map_studio.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/components/mind_map_studio.py#L21))
    - `_project_root = Path(__file__).resolve().parent.parent.parent.parent` sobe **4 níveis** (saindo da pasta do repositório para `/home/loko/Documentos/ufMA/downloads`). E na [linha 262](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/components/mind_map_studio.py#L262), `f"node_{len(self.nodes)+1}"` gera IDs duplicados após deletar um nó intermediário.
16. **Falha de caminho de armazenamento no Android (`Path.home() / ".config" / "kairos"`)** ([storage_manager.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/utils/storage_manager.py#L17-L18), [wallpaper_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/wallpaper_service.py#L17))
    - No Android, `Path.home()` resolve para `/data` (somente leitura), fazendo o fallback de preferências e o cache de wallpapers falharem por `PermissionError`, enquanto `DatabaseConnection._get_user_data_dir()` já resolve o diretório correto multiplataforma.

### 1.3 Vazamentos de Recursos e Concorrência
17. **Conexões SQLite vazadas em `QuizService` e `NotificationService`** ([quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L88-L93), [notification_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/notification_service.py#L85-L91))
    - Ambos usam `with sqlite3.connect(self.db_path) as conn:` dentro de threads. No `sqlite3` padrão do Python, o context manager `with conn:` **apenas faz commit/rollback da transação, mas NÃO fecha a conexão**! Isso vaza descritores de arquivo a cada chamada e contorna o `DatabaseConnection` central.
18. **Vazamento de listeners do `AudioPlayerManager` e `page.on_resize` em `HinoView`** ([hino_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/hino_view.py#L1299-L1320))
    - `self.audio_manager.remove_listener` só é chamado no clique do botão voltar da AppBar (`_go_back`). Se o usuário sair pelo gesto/botão Voltar do Android (`on_view_pop`), chip de filtro ou link bíblico, o listener e a árvore inteira da `HinoView` ficam retidos em memória.
19. **Acúmulo infinito de controles em `page.overlay`** ([agente_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/agente_view.py#L344-L347), [meditacao_destaque_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/meditacao_destaque_view.py#L283), [quiz_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/quiz_view.py#L505))
    - Fazem `page.overlay.append(snack/dialog)` a cada clique sem reutilizar instância ou remover do `overlay`.
20. **Processos `ffplay` órfãos/zumbis e `ffprobe` bloqueando a UI** ([audio_player_manager.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/audio_player_manager.py#L358-L438))
    - `_probe_duration` roda `subprocess.run(..., timeout=5)` de forma síncrona dentro de `async def play_hino`, travando a UI por até 5s em streams remotos; e `_kill_proc` chama `terminate()` sem `wait()` nem `atexit`.

---

## 2. Código Duplicado e Arquivos Shim Redundantes

1. **6 Arquivos Shim de Re-exportação Pura (Sem lógica própria)**
   - [src/database/devotional_repo.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/database/devotional_repo.py) (10 linhas — re-exporta `src/repositories/meditacao_repository.py`)
   - [src/views/home_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/home_view.py) (23 linhas — re-exporta `src/views/hinario_view.py`)
   - [src/views/atualizacao_dialog.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/atualizacao_dialog.py) (19 linhas — re-exporta `src/views/update_dialog.py`)
   - [src/views/boas_vindas_dialog.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/boas_vindas_dialog.py) (23 linhas — re-exporta `src/views/welcome_dialog.py`)
   - [src/views/configuracoes_dialog.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/configuracoes_dialog.py) (33 linhas — re-exporta `src/views/settings_dialog.py`)
   - [src/views/components/mind_map_studio.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/components/mind_map_studio.py) + `__init__.py` (14 linhas — re-exporta `src/components/mind_map_studio.py`)
2. **Mais de 30 Aliases Bilíngues Não Utilizados em `__init__.py`**
   - Definidos em [src/models/__init__.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/models/__init__.py#L18-L27), [src/repositories/__init__.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/__init__.py#L19-L20), [src/services/__init__.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/__init__.py#L30-L40) e [src/views/__init__.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/__init__.py#L7-L34) (`AutorComentario`, `ItemComentario`, `PerguntaQuiz`, `AutenticacaoService`, `SincronizacaoNuvemService`, `PapelDeParedeService`, etc.) com **zero** referências em todo o projeto e testes.
3. **Duplicação de Estado e Aplicação de Tema (`ThemeService` vs `ThemeEngine`)**
   - [theme_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/theme_service.py#L21-L38) importa `COLOR_SEEDS` de `theme_engine.py` na linha 21 e o redefine literalmente na linha 30. Espelha todos os 6 atributos do `ThemeEngine`, sincroniza manualmente via `_sync_to_engine()` e mantém o método morto `_apply_novo_theme` ([linhas 503-555](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/theme_service.py#L503-L555)).
4. **Estatísticas de Gamificação Duplicadas (`QuizService` vs `ReadingService`)**
   - `get_unified_user_stats` (~75 linhas de SQL e agregação) está copiado e colado entre [quiz_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/quiz_service.py#L500-L575) e [reading_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/reading_service.py#L245-L295).
5. **Diálogo Flutuante de Versículos e Parser de Referências Duplicados nas Views (~250 linhas)**
   - `_show_floating_verse_dialog` é copiado linha por linha entre [meditacao_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/meditacao_view.py#L893-L1024) e [escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L651-L765), quando deveria residir em [verse_dialog.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/components/verse_dialog.py).
6. **BottomSheet de Tipografia/Acessibilidade Quadruplicado (~800 linhas no total)**
   - Reimplementado em [meditacao_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/meditacao_view.py#L313-L510), [escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py#L273-L463), [hino_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/hino_view.py#L3035-L3125) e [biblia_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/biblia_view.py#L3474-L3722).
7. **Resolução de Diretório de Banco Triplicada nos Repositórios**
   - `_candidate_dirs()` e `_resolve_db_connection()` (~45 linhas cada) copiados em [commentary_repository.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/commentary_repository.py#L18-L63), [cross_reference_repository.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/cross_reference_repository.py#L18-L62) e [pericope_repository.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/pericope_repository.py#L15-L61), apesar de `DatabaseConnection._resolve_db_path` já fazer esse trabalho.
8. **Busca de Capítulo Completo Duplicada no `BibliaRepository`**
   - `buscar_capitulo_completo` ([biblia_repository.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/biblia_repository.py#L873-L939)) repete as mesmas 45 linhas de query SQL, montagem de `Versiculo` e cache de `buscar_capitulo` ([linhas 1029-1086](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/repositories/biblia_repository.py#L1029-L1086)).
9. **Download em Lote e Cálculo de Espaço Duplicados (Vídeo vs Áudio) no `MediaService`**
   - `_download_batch_item`, `download_library_batch` e `get_storage_usage` ([media_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/media_service.py#L465-L539)) são 95% idênticos às versões de áudio ([linhas 618-682](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/media_service.py#L618-L682)).

---

## 3. Code Smells, Código Morto e Auditoria `/ponytail`

Seguindo a taxonomia do **Ponytail** (`delete:`, `stdlib:`, `native:`, `yagni:`, `shrink:`), ranqueado pelo tamanho do corte:

### `delete:` (Código 100% morto — construído e nunca exibido ou nunca chamado)
- `delete:` **~510 linhas de Bíblia inline e chips comparativos mortos em `HinoView`** ([hino_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/hino_view.py#L1939-L2508)): `_carregar_biblia_passagem`, `_build_biblia_content`, `_build_biblia_inline_toolbar`, `_build_biblia_inline_chips`, `_build_biblia_inline_verses_content`, `_build_comparativo_chip`, `_on_chip_comparativo_click`, `_build_edition_feedback_banner` e `_update_edition_feedback_banner` nunca são acionados (`selected_view_mode` só assume `"novo"` ou `"antigo"`).
- `delete:` **~300 linhas de Cards e Dots mortos construídos a cada renderização da Home (`SelecaoView`)** ([selecao_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L1123-L1292)): `_build_edition_card`, `_update_weekly_dots` e os 4 cards (`card_hinarios`, `card_biblia`, `card_meditacao`, `card_escola_sabatina` nas [linhas 1490-1593](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/selecao_view.py#L1490-L1593)) são instanciados no `build()`, mas **nunca são adicionados ao `content_column`** (foram substituídos por `acesso_rapido_section`).
- `delete:` **~160 linhas de menu de contexto e botões órfãos em `BibliaView`** ([biblia_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/biblia_view.py#L2637-L2769)): `_show_verse_context_menu` nunca é chamado; `version_dropdown`, `prev_btn`, `next_btn`, `prev_chip_btn`, `next_chip_btn` ([linhas 3869-3904](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/biblia_view.py#L3869-L3904)) nunca são montados na árvore.
- `delete:` **~85 linhas de `create_gamification_banner` em `hinario_view.py`** ([hinario_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/hinario_view.py#L1340-L1425)): Função legada substituída pelo banner de `SelecaoView`.
- `delete:` **~55 linhas de `_apply_novo_theme` e `COLOR_SEEDS` duplicado em `ThemeService`** ([theme_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/theme_service.py#L503-L555)).
- `delete:` **6 arquivos shim e ~30 aliases não utilizados nos `__init__.py`**.

### `stdlib:` (Reinvenção da Biblioteca Padrão do Python)
- `stdlib:` `path_to_file_uri` manual em [media_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/media_service.py#L79-L94) → Substituir por `Path(filepath).resolve().as_uri()`.
- `stdlib:` `calculate_sha256` em loop manual de blocos em [updater_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/updater_service.py#L334-L340) → Substituir por `hashlib.file_digest(f, "sha256").hexdigest()`.
- `stdlib:` `_normalize_char` com dicionário manual de 23 letras acentuadas em [mind_map_exporter.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/utils/mind_map_exporter.py#L65-L76) → Substituir por `unicodedata.normalize("NFD", s)`.
- `stdlib:` `to_dict()` manual em 4 dataclasses em [escola_sabatina.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/models/escola_sabatina.py#L46-L167) → Substituir por `dataclasses.asdict(self)`.
- `stdlib:` `format_time_ms` em [audio_player_manager.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/audio_player_manager.py#L70-L77) → Simplificar com `divmod(max(0, int(ms // 1000)), 60)`.

### `yagni:` / `shrink:` (Complexidade Desnecessária e God Classes)
- `yagni:` Parâmetros e atributos armazenados e nunca usados: `content_manager` em `AgenteService.__init__` ([agente_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/agente_service.py#L38)); `fav_repo_antigo`, `hist_repo_novo`, `hist_repo_antigo` em `CloudSyncService.__init__` ([cloud_sync_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/cloud_sync_service.py#L36-L44)); `module_info` em `ContentManager.is_module_outdated` ([content_manager.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/content_manager.py#L324)).
- `shrink:` `_montar_ordem_culto` em [agente_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/agente_service.py#L277-L498) (220 linhas imperativas incrementando `ordem_idx += 1` passo a passo) → Reduzir para listas declarativas de etapas + `enumerate(itens, 1)` (~45 linhas).
- `shrink:` `ThemeEngine.apply_theme` em [theme_engine.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/theme/theme_engine.py#L506-L694) constrói `ft.ColorScheme` 7 vezes repetindo os mesmos 13 campos → Extrair `_palette_to_color_scheme(pal)` (-130 linhas).
- `shrink:` `_search_hinos`, `_search_biblia`, `_search_meditacao`, `_search_licao` em [search_service.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/services/search_service.py#L208-L436) repetem o mesmo loop de tiers FTS5 4 vezes → Extrair `_run_fts_tiers` (-100 linhas).
- `shrink:` God Files em `src/views/`: [biblia_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/biblia_view.py) (4.229 linhas), [hino_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/hino_view.py) (3.470 linhas), [escola_sabatina_view.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/escola_sabatina_view.py) (2.551 linhas), [settings_dialog.py](file:///home/loko/Documentos/ufMA/Hin%C3%A1rio_App/src/views/settings_dialog.py) (1.960 linhas).

**Saldo estimado Ponytail (`net`)**: **-2.800+ linhas de código e -6 arquivos shim possíveis**, sem perder nenhuma funcionalidade.

