# Plano de Refatoração, Auditoria e Correções (Sistema de Quizzes & Gamificação Kairos)

## Resumo Executivo
Auditoria de segurança, concorrência Flet, consistência SQLite/Supabase e resiliência mobile nos módulos de Quiz da Escola Sabatina.
Todas as correções foram implementadas com testes TDD aprovados sem regressões.

---

## 1. Alta Prioridade (Segurança, Concorrência e Integridade de Dados)

- [x] **[ALTA - Segurança / Trail of Bits] Falta de validação estrita da resposta da RPC Supabase e tipo de retorno**
  - **Ficheiro:** `src/services/quiz_service.py` (L217-230)
  - **Defeito:** `submit_quiz_answer` confiava cegamente em `rpc_res.data`.
  - **Solução:** Adicionada validação de dicionário com chaves obrigatórias (`is_correct`, `correct_option`), isolamento de exceção de rede e espelhamento no SQLite local.

- [x] **[ALTA - Lógica & Concorrência] Race Condition de duplo clique no envio e transição de questões**
  - **Ficheiro:** `src/views/quiz_view.py` (L223-236, L241-248)
  - **Defeito:** Cliques rápidos no botão "Verificar" despachavam tarefas assíncronas concorrentes.
  - **Solução:** Adicionada flag síncrona imediata `self._is_submitting = True` e travamento dos cards de alternativa e botão antes de `run_task`.

- [x] **[ALTA - Consistência de Dados & Cache Offline] Dessincronização do cálculo de Streak e Respostas entre SQLite local e Supabase**
  - **Ficheiro:** `src/services/quiz_service.py` (L224-230, L263-310)
  - **Defeito:** Resposta online da RPC no Supabase não replicava o registro em `user_quiz_answers` e `user_quiz_stats`.
  - **Solução:** Criado método `_sync_online_result_to_cache` gravando imediatamente a resposta e novos stats no SQLite local.

- [x] **[ALTA - Resiliência Mobile] Timeout ou queda de rede durante submissão ou carregamento**
  - **Ficheiro:** `src/services/quiz_service.py` (L140-149, L218-230)
  - **Defeito:** Falta de tratamento resiliente para queda repentina de rede no envio de quiz ou busca de questões.
  - **Solução:** Fallback transparente para cache SQLite local tanto em busca quanto em submissão offline se o Supabase falhar.

---

## 2. Média Prioridade (Robustez de Modelos, Sanitização e DI)

- [x] **[MÉDIA - Segurança / Validação] Validação de comprimentos e sanitização no Pydantic `QuizReport` e `QuizQuestion`**
  - **Ficheiro:** `src/models/quiz.py`
  - **Defeito:** Sanitização fraca em `QuizReport` e ausência de limites em `QuizQuestion.question`.
  - **Solução:** `min_length=5, max_length=1000` em `question`, remoção de caracteres de controle e strip obrigatório em `QuizReport`.

- [x] **[MÉDIA - Arquitetura & DI] Injeção de dependência do Supabase no `EscolaSabatinaView` e `AppRouter`**
  - **Ficheiro:** `src/views/escola_sabatina_view.py` e `main.py`
  - **Defeito:** Instanciação estática sem repasse de `devotional_client` ou `db_path`.
  - **Solução:** Injeção de dependência configurada em `EscolaSabatinaView` e cabeada em `AppRouter` em `main.py`.

- [x] **[MÉDIA - Flet Concorrência & Lifecycle] Fechamento e desalocação do Dialog no Flet**
  - **Ficheiro:** `src/views/quiz_view.py` e `src/views/escola_sabatina_view.py`
  - **Defeito:** `dialog.open = False` sem desalocar de `page.overlay`.
  - **Solução:** Limpeza explícita do diálogo da coleção `page.overlay` e atualização segura com `ft.Padding`.

- [x] **[MÉDIA - Tratamento de Erro no Gerador Gemini] Recuperação de falha do JSON Parser na IA**
  - **Ficheiro:** `scripts/generate_quizzes_gemini.py`
  - **Defeito:** Blocos de código markdown quebravam o `json.loads`.
  - **Solução:** Sanitização regex `re.sub(r"^```(?:json)?\s*", ...)` antes de carregar JSON.

- [x] **[MÉDIA - Segurança / Trail of Bits] Script `scripts/generate_quizzes_gemini.py` sem verificação de sanidade do `service_role_key`**
  - **Ficheiro:** `scripts/generate_quizzes_gemini.py`
  - **Defeito:** Ausência de validação do formato do token de service role.
  - **Solução:** Verificação de comprimento e formato da chave JWT/Supabase antes de criar cliente admin.

---

## 3. Baixa Prioridade (Over-engineering & Limpeza de Código / Ponytail)

- [x] **[BAIXA - Over-engineering / Ponytail] Redundância de containers vazios para espaçamento no Flet**
  - **Ficheiro:** `src/views/quiz_view.py`
  - **Defeito:** Múltiplos `ft.Container(height=12)` e `ft.Container(width=8)` como espaçadores redundantes.
  - **Solução:** Removidos espaçadores manuais e adotado `spacing` nativo nas colunas e linhas. Modernizados botões para `ft.Button`.

- [x] **[BAIXA - Over-engineering / Ponytail] Verificação redundante de opções em dois modelos**
  - **Ficheiro:** `src/models/quiz.py`
  - **Defeito:** Dupla checagem de tamanho de opções.
  - **Solução:** Delegado tamanho ao Pydantic `Field(min_length=4, max_length=4)` mantendo validador focado em alternativas não vazias.

- [x] **[BAIXA - Testes & Cobertura] Ausência de testes de UI do Quiz e integração com Escola Sabatina**
  - **Ficheiro:** `tests/test_escola_sabatina.py` e `tests/test_quiz_service.py`
  - **Defeito:** Falta de testes de integração ponta a ponta do modal de quiz na view.
  - **Solução:** Adicionado `test_escola_sabatina_quiz_modal_integration` validando o fluxo assíncrono com sucesso.

---

## Status dos Testes
- `tests/test_quiz_service.py`: 7/7 PASSED
- `tests/test_escola_sabatina.py`: 21/21 PASSED (Total: 28/28 PASSED)
