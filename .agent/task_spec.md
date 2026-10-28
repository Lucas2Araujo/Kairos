# Especificação da Tarefa Atual (Task Spec)

> **Status:** Concluído com Sucesso  
> **Foco:** Estabilização do CI/CD, Skill Ponytail, Quizzes no Estilo Kahoot, Correção da Interface da Bíblia e Sincronização em Nuvem do Usuário  
> **Data:** 28/10/2026  

---

## 1. Descrição do Objetivo
1. Estabilizar os 5 workflows do GitHub Actions (`ci.yml`, `cd.yml`, `deploy-pages.yml`, `generate_quizzes.yml`, `pegar_devo.yml`).
2. Integrar a skill do **Ponytail** como diretriz e padrão inegociável de desenvolvimento.
3. Reformular o prompt e schema do gerador de quizzes com IA para o estilo **Kahoot** (dinâmico, balanceado e ágil).
4. Corrigir a quebra da interface da Bíblia (eliminação de loop de `init()` e limpeza de `targetVerse`).
5. Corrigir as variáveis do `cd.yml`/`deploy-pages.yml` e implementar persistência em nuvem de preferências e temas no Supabase via `AuthService`.

---

## 2. Arquivos Modificados / Criados

| Arquivo | Ação | Descrição |
| :--- | :--- | :--- |
| `.agent/skills/ponytail/SKILL.md` | Criado | Skill canônica do Ponytail ("Lazy Senior Developer" / Ladder of Laziness) |
| `AGENTS.md` | Criado | Regras universais do workspace adotando Ponytail como padrão |
| `.agent/coding_standards.md` | Atualizado | Incluída a Regra 0 (Filosofia Ponytail como padrão inegociável) |
| `.env.example` | Atualizado | Documentadas todas as variáveis e papéis (`LOGIN_SERVICE_KEY_SUPABASE`, `DEVOTIONAL_SUPABASE_SERVICE_ROLE_KEY`) |
| `.github/workflows/deploy-pages.yml` | Atualizado | Corrigida versão inválida do Flutter (`3.44.8` $\rightarrow$ `channel: 'stable'`) e fallbacks de segredos |
| `.github/workflows/generate_quizzes.yml` | Atualizado | Adicionado bloco `permissions: contents: read` |
| `.github/workflows/pegar_devo.yml` | Atualizado | Adicionado bloco `permissions: contents: read` |
| `.github/workflows/cd.yml` | Atualizado | Adicionado fallback `${{ secrets.AUTH_SUPABASE_URL \|\| secrets.SUPABASE_URL }}` |
| `scripts/meditacao.py` | Atualizado | Resiliência contra falsos positivos: `sys.exit(1)` se nenhuma categoria persistir |
| `scripts/generate_quizzes_gemini.py` | Atualizado | Prompt estilo Kahoot balanceado (fácil, médio, desafiador), limites de caracteres e schema Pydantic refinado |
| `lib/controllers/bible_controller.dart` | Atualizado | Reset de `_targetVerse` na navegação de capítulos e limpeza no `SharedPreferences` |
| `lib/views/bible/bible_reader_view.dart` | Atualizado | Removido `init()` redundante no `initState` e chamada de `clearTargetVerse()` pós-scroll |
| `lib/services/auth_service.dart` | Atualizado | Sincronização em nuvem de temas, preferências e última posição bíblica no Supabase |

---

## 3. Validação Executada
- Compilação de sintaxe Python com `python -m py_compile scripts/generate_quizzes_gemini.py scripts/meditacao.py`: **100% OK**.
- Validação estrutural do schema Pydantic e limites de texto: **100% OK**.
- Resolução de dependências circulares em Dart através de listeners desacoplados (`ThemeService` $\rightarrow$ `AuthService`): **100% OK**.
