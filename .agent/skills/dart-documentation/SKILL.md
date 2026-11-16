---
name: dart-documentation
description: Padrão obrigatório de documentação Dartdoc (///) e validação de comment_references no flutter analyze.
---

# Dart Documentation (`///`)

Toda API pública, classe, método, enum ou helper novo/modificado no Kairós deve ser documentado com Dartdoc (`///`).

## Regras
1. **Cobertura:** Documente propósito, parâmetros relevantes, retorno e invariantes/edge cases (ex.: comportamento offline ou `kIsWeb`).
2. **Referências Válidas:** Use colchetes `[NomeDoSimbolo]` apenas para símbolos realmente no escopo.
3. **Validação:** Execute `flutter analyze` nos arquivos alterados e garanta **zero erros** e **zero warnings de `comment_references`**.
