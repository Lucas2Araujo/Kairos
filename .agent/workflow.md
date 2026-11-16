# Fluxo Agêntico Autônomo — Kairós

Este documento define o ciclo de execução padrão para desenvolvimento autônomo no repositório.

## 1. Escalonamento Automático por Escopo
- **Modo Agente Único (1–3 arquivos / tarefa pontual):**
  Execute diretamente o ciclo TDD completo (`Red -> Green -> Refactor -> Dartdoc -> Commit local`) sem overhead de subagentes.
- **Modo Multi-Agente (4+ tarefas independentes / Sprints):**
  Ative `.agent/skills/subagent-driven-development/SKILL.md` para despachar subagentes por tarefa com revisão em dois estágios.

## 2. Estrutura Padrão de Planos
Todo plano de execução deve conter:
- **Global Constraints:** Ponytail, Android/Web, `TextScaler.linear(2.0)`, `userPreservedTables`, Dartdoc.
- **Review Focus:** Lista explícita de edge cases críticos e em qual tarefa cada um é exercitado.
- **Tasks:** Cada tarefa com `Files`, `Interfaces` (`Consumes` / `Produces`) e 5 passos obrigatórios:
  1. `Step 1: Write the failing test`
  2. `Step 2: Run test to verify it fails`
  3. `Step 3: Implement` (mínimo necessário, padrão Ponytail)
  4. `Step 4: Run test to verify it passes`
  5. `Step 5: Document with Dartdoc (///) & Commit`

## 3. Regra de Autonomia
- Execute cada tarefa de ponta a ponta (incluindo `flutter analyze`, `flutter test` e `git commit` local) sem pausas intermediárias.
- **Pare apenas quando:**
  - Houver um bloqueio real (erro irrecuperável, ambiguidade de requisito ou falha de ambiente).
  - Um **Sprint** inteiro for concluído (para validação/checkpoint com o usuário).
