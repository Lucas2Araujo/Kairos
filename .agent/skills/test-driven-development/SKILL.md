---
name: test-driven-development
description: Ciclo estrito Red -> Green -> Refactor antes de escrever qualquer código de produção no Kairós.
---

# Test-Driven Development (TDD)

Nenhum código de produção deve ser escrito antes de existir um teste que falhe.

## Ciclo Obrigatório
1. **RED (Teste Falhando):**
   - Escreva o teste unitário ou de widget (`test/..._test.dart`) cobrindo o comportamento esperado e o edge case.
   - Execute `flutter test <arquivo_de_teste>` e **confirme que falha** pelo motivo esperado (ex.: símbolo ausente ou asserção falhando).
2. **GREEN (Implementação Mínima):**
   - Aplique a filosofia **Ponytail**: escreva apenas o código mínimo necessário para fazer o teste passar.
   - Execute `flutter test <arquivo_de_teste>` e confirme `PASS`.
3. **REFACTOR (Limpeza):**
   - Extraia helpers pequenos se houver duplicação, mantendo os testes verdes.
   - Rode `flutter analyze` nos arquivos tocados.
