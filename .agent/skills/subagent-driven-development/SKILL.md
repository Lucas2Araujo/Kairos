---
name: subagent-driven-development
description: Orquestração autônoma tarefa-a-tarefa com subagentes, TDD e revisão em dois estágios para planos e Sprints com 4+ tarefas.
---

# Subagent-Driven Development (Kairós)

Use esta skill quando o plano tiver **4 ou mais tarefas independentes** ou múltiplos **Sprints**. Para tarefas pontuais (1–3 arquivos), execute diretamente em agente único.

## Fluxo por Tarefa
1. **Despacho do Implementador:**
   - Envie ao subagente apenas a tarefa atual, seus `Files`, `Interfaces` (`Consumes`/`Produces`) e os `Global Constraints` relevantes.
   - Exija o ciclo completo de `.agent/skills/test-driven-development/SKILL.md` e `.agent/skills/dart-documentation/SKILL.md`.
2. **Revisão em Dois Estágios:**
   - **Estágio 1 (Especificação):** Confirme que as interfaces, edge cases do `Review Focus` e testes da tarefa foram atendidos sem desvios.
   - **Estágio 2 (Qualidade & Ponytail):** Verifique ausência de duplicação, zero novas dependências, compatibilidade Android/Web (`kIsWeb`) e `flutter analyze` limpo.
3. **Commit & Avanço:**
   - Faça o commit local da tarefa e avance imediatamente para a próxima até concluir o Sprint.
