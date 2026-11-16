---
name: verification-before-completion
description: Checklist final obrigatório antes de declarar qualquer tarefa ou Sprint como concluído.
---

# Verification Before Completion

Nunca declare uma tarefa ou Sprint como concluído sem executar e observar os resultados reais após a **última edição**:

1. `flutter analyze` — zero erros e zero warnings nos arquivos alterados.
2. `flutter test` — todos os testes relevantes passando (sem `skip` ou asserções relaxadas).
3. **Edge Cases do Kairós (quando aplicável):**
   - `TextScaler.linear(2.0)` sem `RenderFlex` overflow.
   - Compatibilidade Android & Web (sem `dart:io` direto sem guarda `kIsWeb`).
   - Bancos SQLite com `PRAGMA journal_mode=DELETE; VACUUM;`.
   - Scripts Python validados com `python -m py_compile`.
