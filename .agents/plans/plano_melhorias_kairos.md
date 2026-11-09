# Plano de Implementação: Melhorias no Kairós

Este documento estabelece o plano técnico detalhado para as 4 demandas solicitadas no Kairós, respeitando as diretrizes do repositório (`AGENTS.md`, `.agent/coding_standards.md` e a filosofia **Ponytail**).

---

## 1. Item 1: Correção do Ciclo de Geração de Quizzes e Resiliência no Workflow

### 1.1 Causa Raiz
1. **Modelos Inexistentes ou Obsoletos**:
   - A lista de modelos em `scripts/generate_quizzes_gemini.py` tentava:
     - `gemini-flash-latest` (inexistente).
     - `gemini-2.5-flash` (inexistente).
     - `gemini-2.0-flash` e `gemini-1.5-flash` chamados no endpoint `v1` (onde retornam 404 se não roteados via `v1beta`).
   - Na API Google GenAI atual, os modelos vigentes e estáveis para tarefas rápidas e estruturadas são `gemini-3.8-flash`, `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite` e `gemini-2.0-flash` via `v1beta`.
2. **Falso Positivo no CI/CD**:
   - Quando todos os modelos falhavam para todos os dias, a variável `total_generated` continuava `0`.
   - O método `main()` simplesmente logava `Total de perguntas persistidas: 0` e finalizava sem código de erro (`sys.exit(0)`).
   - O step do GitHub Actions com `set -e` considerava o comando bem-sucedido, gerando um checkmark verde ilusório.

### 1.2 Proposta Técnica
- **Atualização dos Modelos**:
  - Configurar `http_options = types.HttpOptions(api_version="v1beta")` na inicialização do `genai.Client`.
  - Definir a cadeia de modelos oficial: `['gemini-3.8-flash', 'gemini-3.5-flash-lite', 'gemini-3.1-flash-lite', 'gemini-2.0-flash']`.
- **Falha Explícita em Caso de Erro**:
  - Adicionar controle de dias processados vs. dias com falha.
  - Se `total_generated == 0` (e não estiver em modo de teste sem dias) ou se todos os dias falharem, logar `[FALHA CRÍTICA]` e invocar `sys.exit(1)`.
  - Dessa forma, o workflow no GitHub Actions falha imediatamente e alerta os mantenedores.

---

## 2. Item 2: Customização da Barra Lateral em Tablets (Posição & Gestos)

### 2.1 Causa Raiz
- Em telas maiores ($\ge 720\text{dp}$), `lib/views/navigation/main_navigation_view.dart` renderiza uma `Row` fixa com `[rail, Expanded(screens)]`.
- A barra fica obrigatoriamente ancorada à esquerda, gerando desconforto ergonômico para usuários destros segurando o tablet.
- Não há opção de ocultação ou retração por gestos.

### 2.2 Proposta Técnica
- **Armazenamento de Preferências no `ThemeService`**:
  - `tabletNavPosition`: `'left'` (padrão) vs `'right'` (destro).
  - `tabletNavMode`: `'fixed'` (fixa visível) vs `'collapsible'` (recolhível por gesto de borda ou toque no header).
- **Interface e Interação em `MainNavigationView`**:
  - Se `tabletNavPosition == 'right'`, inverter a ordem no `Row`: `[Expanded(screens), rail]`.
  - Se `tabletNavMode == 'collapsible'`:
    - Adicionar suporte a animação suave de recolhimento (`AnimatedContainer` ou `SizeTransition`).
    - Permitir abrir/fechar através de um puxão da borda (`GestureDetector` / `HorizontalDrag`) ou um botão elegante e discreto no topo da tela.
- **Configuração no `SettingsDialog`**:
  - Nova subseção: "Navegação em Tablets / Telas Grandes", permitindo alternar a posição (Esquerda/Direita) e o comportamento (Fixa/Retrátil).

---

## 3. Item 3: Dinamismo e Avanço no Plano de Leitura

### 3.1 Causa Raiz
- O `ReadingPlanService` calcula o dia atual (`calculateCurrentDay`) puramente pela diferença de dias entre `today` e a data em que o plano foi iniciado (`startedAt`).
- Se o usuário lê capítulos à frente (ex: do Salmo 136 ao Salmo 139), o plano permanece preso ao dia original (ex: Dia 614).
- O botão "Concluir Leitura" apenas conclui o dia calculado pelo calendário, sem reconhecer que o usuário avançou vários capítulos em um único dia.

### 3.2 Proposta Técnica
- **Detecção do Capítulo Aberto no Leitor Bíblico**:
  - O leitor bíblico tem o estado `currentBookId` e `currentChapter` em `BibleController`.
  - Implementar no `ReadingPlan` o método `findDayForChapter(bookId, chapter)`, que mapeia instantaneamente o capítulo da tela para o dia correspondente do plano (ex: Salmo 139 $\rightarrow$ Dia 617 no RPSP).
- **Sincronização Dinâmica**:
  - Se o usuário estiver em um capítulo à frente do dia atual do plano:
    - A pílula de leitura e o banner identificam: *"Você está no Salmo 139 (Dia 617)"*.
    - Ao confirmar a leitura, oferece/executa a conclusão em lote dos dias intermediários (`614..617`) e recalibra a data base (`startedAt`) para que o plano passe a apontar para o Dia 617, mantendo o dinamismo e a consistência da ofensiva.

---

## 4. Item 4: Ajuste na Pílula Flutuante no Leitor Bíblico (Perícopes Cobertas)

### 4.1 Causa Raiz
- Em `lib/views/bible/bible_reader_view.dart`, o `ReadingPlanFloatingPill` está dentro de um `Positioned(left: 0, right: 0, top: 8)` sobre o `mainLayout`.
- O `ListView` dos versículos começa no topo da tela, ficando exatamente atrás da pílula. Logo, a primeira perícope (título da seção) e os primeiros versículos ficam visualmente obstruídos.

### 4.2 Proposta Técnica & Opções
- **Solução Recomendada (Ponytail & UX Fluida)**:
  1. **Top Inset Compensatório**: Adicionar padding superior automático na lista de versículos equivalente à altura da pílula colapsada (~44dp), de modo que, ao abrir o capítulo, o título da perícope e o primeiro versículo fiquem 100% visíveis abaixo da pílula.
  2. **Auto-Recolhimento com o Scroll**: Ao rolar para baixo durante a leitura, a pílula recolhe ou translada suavemente para fora (`SlideTransition`), reaparecendo ao rolar de volta para o topo.
  3. **Opção de Ancoragem**: Permitir ao usuário ou ao sistema exibir a pílula como um sub-cabeçalho integrado em vez de sobreposto.

---

## 5. Arquivos Envolvidos

1. `scripts/generate_quizzes_gemini.py`
2. `lib/services/theme_service.dart`
3. `lib/views/navigation/main_navigation_view.dart`
4. `lib/views/settings/settings_dialog.dart`
5. `lib/models/reading_plan_models.dart`
6. `lib/services/reading_plan_service.dart`
7. `lib/views/bible/widgets/reading_plan_floating_pill.dart`
8. `lib/views/bible/bible_reader_view.dart`
9. `test/reading_plan_service_test.dart` (validação de regressão)
