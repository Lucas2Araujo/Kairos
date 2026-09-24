# Sprint: Gamificação e Quizzes Diários da Escola Sabatina (Kairos)

## Checklist de Execução

- [x] **0. Planejamento Persistente & Estrutura**
  - [x] Criar `.agents/plans/quiz_gamification_todo.md` com tarefas atômicas.

- [x] **1. Contrato de Dados & Modelos (`src/models/quiz.py`)**
  - [x] Criar `QuizQuestion` (modelo público seguro, sem `correct_option`).
  - [x] Criar `QuizQuestionInternal` (modelo com `correct_option` para IA/scripts/admin).
  - [x] Criar `QuizAnswerSubmission`, `QuizResult`, `QuizReport`, `UserQuizStats`.
  - [x] Validadores Pydantic estritos para garantir integridade.

- [x] **2. TDD & Testes de Unidade (`tests/test_quiz_service.py`)**
  - [x] Testar validação de respostas offline vs online (RPC mock / fallback local).
  - [x] Testar trava anti-speedhack (< 2 segundos rejeitado).
  - [x] Testar sanitização de denúncias (`quiz_reports`).
  - [x] Testar idempotência na carga de perguntas da IA.

- [x] **3. Camada de Serviço & Repositório (`src/services/quiz_service.py`)**
  - [x] Tabelas locais SQLite `ss_questions_cache`, `user_quiz_answers`, `user_quiz_stats`, `quiz_reports`.
  - [x] `get_daily_quiz(day_id, category)`: busca online no Supabase com fallback offline no SQLite local.
  - [x] `has_user_answered(question_id, user_id)`: verificação de resposta prévia.
  - [x] `submit_answer(question_id, selected_option, time_spent)`: RPC `submit_quiz_answer` ou validação offline + anti-speedhack.
  - [x] `report_question(question_id, reason, comment)`: sanitização e envio seguro para `quiz_reports`.
  - [x] `get_user_stats(user_id)`: retorno de XP e ofensiva (streak).

- [x] **4. Automação com IA (`scripts/generate_quizzes_gemini.py`)**
  - [x] CLI aceitando `--quarterly` e `--category`.
  - [x] Integração com API Adventech para coletar lições e dias (`SSDay`).
  - [x] Geração estruturada via `google-genai` (2-3 perguntas/dia: `question`, 4 `options`, `correct_option`, `explanation`, `verse_ref`).
  - [x] Upsert idempotente no Supabase com `SUPABASE_SERVICE_ROLE_KEY` isolada.

- [x] **5. Interface Reativa no Flet (`src/views/quiz_view.py`)**
  - [x] Barra de progresso com streak (🔥) e botão de denúncia (flag).
  - [x] Cards de 4 alternativas com feedback visual (`#E8F5E9` verde para acerto, `#FFEBEE` vermelho com gabarito para erro).
  - [x] BottomSheet/Dialog para reportar erro/denúncia na questão.
  - [x] Tela de conclusão: resumo de acertos, XP ganho e celebração de streak.

- [x] **6. Ponto de Entrada na Lição (`src/views/escola_sabatina_view.py`)**
  - [x] Chip de ofensiva diária no cabeçalho.
  - [x] Card de ação no rodapé do dia (`SSDay`): destacado para quiz diário.
  - [x] Modal responsivo `_open_quiz_modal` integrado ao fluxo de leitura.

- [x] **7. Verificação Final & Auditoria de Segurança**
  - [x] Testes unitários com pytest 100% aprovados.
  - [x] Auditoria de segurança: sem vazamento de `SERVICE_ROLE_KEY` no client mobile e sanitização ativa.
