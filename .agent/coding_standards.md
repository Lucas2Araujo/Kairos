# Diretrizes de Código — Kairós

Este documento define os padrões técnicos inegociáveis para qualquer agente ou colaborador neste repositório.

## 1. Filosofia Ponytail (Padrão Inegociável)
- **Ladder of Laziness:** Antes de escrever qualquer código, verifique se já existe solução nativa no Flutter/Dart/Python ou helper reutilizável em `lib/`.
- **YAGNI & Minimalismo:** Escreva apenas o código necessário para satisfazer os testes e requisitos atuais. Intervenções cirúrgicas e mínimas.
- **Zero Novas Dependências:** Não adicione pacotes ao `pubspec.yaml` sem justificativa irrefutável e aprovação explícita do usuário.

## 2. Compatibilidade Multiplataforma (Android & Web)
- Nunca importe `dart:io` diretamente sem stubs ou guarda `kIsWeb`.
- Todo banco SQLite (`.sqlite`) gerado ou alterado para bundle/R2 deve executar:
  ```sql
  PRAGMA journal_mode=DELETE;
  VACUUM;
  ```

## 3. Responsividade & Acessibilidade Estrita
- Nenhuma dimensão rígida desprotegida (`SizedBox`/`Container` fixos que causem overflow).
- Telas, cards, estantes de capas, diálogos e bottom sheets devem suportar `TextScaler.linear(2.0)` sem `RenderFlex` overflow.
- Contraste adequado (WCAG AA mínimo) e respeito integral aos temas do Kairós (incluindo presets legados `"Liquid Glass"` e `"Apple Glass"`).

## 4. Preservação de Dados Locais
- Toda nova tabela de dados de usuário (ex.: `ss_highlights`) deve ser registrada em `DatabaseManager.userPreservedTables`.
- Sincronização híbrida na nuvem deve usar merge determinístico (`Set.union` ou timestamp mais recente), nunca sobrescrevendo dados offline silenciosamente.

## 5. Documentação & Ciclo em Malha Fechada
- Toda API pública ou helper novo/modificado deve receber Dartdoc (`///`) conforme `.agent/skills/dart-documentation/SKILL.md`.
- Nenhuma tarefa é considerada concluída sem passar em `flutter analyze` (zero erros e zero warnings de `comment_references`) e `flutter test`.
