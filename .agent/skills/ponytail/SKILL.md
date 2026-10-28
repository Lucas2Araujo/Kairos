---
name: ponytail
description: >-
  Pragmatic, minimalist development skill (the "Lazy Senior Developer" philosophy).
  Enforces writing the absolute minimum amount of code, avoiding over-engineering,
  reusing existing solutions, and climbing the Ladder of Laziness before writing any new code.
---

# Ponytail Skill: The Minimalist & Pragmatic Developer

> **Mantra:** *"The best code is the code you never wrote."*  
> Em todas as implementações no projeto Kairós, aplique rigorosamente a filosofia Ponytail. Evite over-engineering, pacotes desnecessários e abstrações prematuras.

---

## 1. A Escada da Preguiça (Ladder of Laziness)

Antes de escrever qualquer linha de código, suba degrau por degrau nesta ordem:

1. **Isso realmente precisa existir? (YAGNI)**
   - Questione se o requisito é essencial agora ou se é uma antecipação desnecessária. Se não for indispensável para a tarefa atual, corte.
2. **Isso já existe na base de código? (Reúso)**
   - Procure nos `controllers/`, `services/`, `core/utils/` ou widgets compartilhados antes de criar uma nova função ou componente.
3. **A biblioteca padrão/SDK resolve nativamente?**
   - Utilize as APIs padrão do Dart/Flutter (ou da biblioteca padrão do Python) em vez de utilitários manuais.
4. **Existe recurso nativo da plataforma/framework?**
   - Prefira widgets nativos simples do Flutter (`LayoutBuilder`, `Flexible`, `Scrollbar`, `Wrap`) a soluções customizadas complexas.
5. **Existe dependência já instalada no `pubspec.yaml` ou `requirements.txt`?**
   - Se já existe uma biblioteca no projeto capaz de resolver, use-a. **Nunca** adicione novas dependências externas sem aprovação explícita e justificativa irrefutável.
6. **Dá para resolver em 1 a 3 linhas claras?**
   - Não crie classes, adaptadores ou fábricas se uma função pura ou expressão direta resolve o problema.
7. **Último caso: Escreva o mínimo de código estritamente necessário.**
   - Simples, legível, testável e direto ao ponto.

---

## 2. Pisos de Segurança Inegociáveis (Não Negociáveis pela Preguiça)

A preguiça pragmática **NUNCA** compromete:
- **Segurança e Isolamento**: Validação de inputs, proteção de credenciais e sanitização.
- **Tratamento de Exceções**: Timeouts em chamadas de rede e prevenção de falhas silenciosas.
- **Acessibilidade e Usabilidade**: Tamanhos mínimos de toque, suporte a `TextScaler` e prevenção de overflow.
- **Integridade da Base**: Não quebrar `flutter analyze`, `flutter test` ou compilação de scripts.

---

## 3. Comportamento Padrão para Implementações

1. **Zero Boilerplate Desnecessário**: Não crie arquivos vazios, interfaces desnecessárias com uma única implementação ou wrappers supérfluos.
2. **Edição Cirúrgica**: Ao corrigir um bug ou implementar uma feature, altere apenas as linhas essenciais. Não refatore código não relacionado sem pedido explícito.
3. **Simplicidade Visual e de Fluxo**: Mantenha widgets desacoplados e fáceis de ler.
