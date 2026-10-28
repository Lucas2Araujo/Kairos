# Skill: CI/CD Workflow & Automation Sync

Esta skill orienta a auditoria, sincronização e resolução de falhas nos pipelines do GitHub Actions, builds multiplataforma do Flutter e scripts Python de automação do Kairós.

---

## 1. Diretrizes de Auditoria de Workflows (`.github/workflows/*.yml`)

### 1.1 Consistência de Versões do Flutter e Python
- **Flutter Action (`subosito/flutter-action@v2`)**:
  - Preferir fixar no canal estável (`channel: 'stable'`) ou em uma versão oficial e válida do Flutter (ex: `3.27.x`, `3.29.x` etc.).
  - **Cuidado Crítico**: Nunca declarar versões inexistentes como `flutter-version: '3.44.8'`. Versões 3.x do Flutter não chegam ao minor 44 (isso confunde versão de engine/Dart SDK com versão do framework).
  - Manter consistência entre o workflow de CI (`ci.yml`), CD (`cd.yml`) e deploy Web (`deploy-pages.yml`).
- **Python Action (`actions/setup-python@v5`)**:
  - Utilizar versão moderna padronizada: `python-version: '3.11'` ou `'3.12'`.
  - Habilitar cache do gerenciador de pacotes: `cache: 'pip'`.
  - Garantir que todas as dependências estejam declaradas no `requirements.txt` da raiz.

### 1.2 Variáveis de Ambiente e GitHub Secrets
- **Nomenclatura Cruzada**:
  - Garantir que toda variável documentada em `.env.example` corresponda exatamente ao secret consumido nos workflows.
  - Verificar aliases de fallback no `env`:
    - `AUTH_SUPABASE_URL` / `SUPABASE_URL`
    - `LOGIN_SERVICE_KEY_SUPABASE` / `SUPABASE_SERVICE_ROLE_KEY` / `DEVOTIONAL_SUPABASE_SERVICE_ROLE_KEY`
    - `GEMINI_API_KEY`
  - NUNCA assumir que segredos com nomes diferentes funcionarão se não houver operador de fallback explícito (ex: `${{ secrets.AUTH_SUPABASE_URL || secrets.SUPABASE_URL }}`).

### 1.3 Permissões do GitHub Token (`permissions:`)
- **Princípio do Menor Privilégio com Acesso Suficiente**:
  - Workflows que publicam releases (`cd.yml`): `permissions: contents: write`.
  - Workflows que fazem deploy no Pages (`deploy-pages.yml`): `permissions: contents: read`, `pages: write`, `id-token: write`.
  - Workflows de teste (`ci.yml`): `permissions: contents: read`.
  - Workflows que realizam operações de ingestão sem commit no repositório (`generate_quizzes.yml`, `pegar_devo.yml`): declarar explicitamente `permissions: contents: read`.

---

## 2. Resiliência e Casos de Borda nos Scripts Python

Ao auditar ou refatorar scripts em `scripts/` (especialmente `generate_quizzes_gemini.py` e `meditacao.py`):

1. **Tratamento de Timeouts e Conexão**:
   - Requisições HTTP (usando `httpx` ou `requests`) **devem ter timeout explícito** (ex: `timeout=30.0`). Nunca deixe requisições sem timeout sob risco de travar o runner do GitHub Actions até atingir o limite de horas do job.
2. **Tratamento de Respostas Malformadas ou Falhas de API**:
   - *API Adventech*: Validar se a lista de lições ou trimestres retornou vazia antes de indexar arrays.
   - *Gemini AI API*: Envolver a chamada e o parsing do JSON em bloco `try/except` com retentativas com backoff exponencial se receber erro 429 (ResourceExhausted) ou 503.
   - *Pydantic Parsing*: Se a resposta do modelo não bater com o schema `DailyQuestionsResponse`, registrar log detalhado do texto bruto e não quebrar a execução completa de outras lições/dias.
   - *Scraping CPB*: Proteger contra alterações na estrutura DOM (tags ausentes, classes alteradas). Ter seletores de fallback para título, autor e versículo bíblico.
3. **Modo Dry-Run Obrigatório**:
   - Scripts de ingestão devem aceitar a flag `--dry-run` para permitir testes em ambientes de CI ou locais sem necessidade de credenciais de escrita do Supabase.

---

## 3. Protocolo de Auditoria e Validação

Antes de concluir qualquer alteração em CI/CD:
1. Validar sintaxe Python: `python -m py_compile scripts/*.py`.
2. Validar sintaxe YAML dos workflows (verificar indentação e mapeamento de chaves).
3. Checar a existência de dependências em `requirements.txt`.
4. Comparar a lista de secrets exigida nos workflows contra `.env.example`.
