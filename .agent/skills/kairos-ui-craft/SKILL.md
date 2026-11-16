---
name: kairos-ui-craft
description: Design responsivo Flutter, contraste/acessibilidade (WCAG + TextScaler 2.0), fluxo claro e validação anti-"AI slop".
---

# Kairós UI Craft & Anti-"AI Slop"

Garante que toda interface no Kairós seja acessível, responsiva e com acabamento artesanal (sem cara de gerada por IA).

## 1. Anti-"AI Slop"
- **Evite:** gradientes neon genéricos, excesso de cards aninhados com sombras pesadas, emojis decorativos em títulos/botões, ou layouts genéricos desconectados do tema ativo.
- **Respeite:** os tokens de `ThemeService` e os temas nativos do Kairós (incluindo `"Liquid Glass"`, `"Apple Glass"`, `Real Glass`, `Retrô ICS Holo`, `Windows 95`).

## 2. Acessibilidade & Contraste
- Contraste mínimo **WCAG AA** entre texto/ícones e fundo em modo claro e escuro.
- Hierarquia visual clara: ação primária evidente, sem sobrecarga cognitiva em modais/bottom sheets.

## 3. Responsividade & `TextScaler`
- Suporte obrigatório a `TextScaler.linear(2.0)` sem `RenderFlex` overflow (use `Flexible`, `Expanded`, `Wrap`, `SingleChildScrollView` quando necessário).
