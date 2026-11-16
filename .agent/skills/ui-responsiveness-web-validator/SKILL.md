---
name: ui-responsiveness-web-validator
description: Validação de responsividade multiplataforma (Android & Web) e proteção contra RenderFlex overflow.
---

# UI Responsiveness & Web Validator

1. **Multiplataforma:** Nunca importe `dart:io` diretamente sem stubs ou guarda `kIsWeb`.
2. **Layout Fluido:** Evite dimensões rígidas (`width`/`height` fixos) em containers com texto dinâmico.
3. **Teste de Estresse:** Valide telas, diálogos e bottom sheets com `TextScaler.linear(2.0)` e diferentes larguras de viewport (mobile e Web).
