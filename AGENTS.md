# Diretrizes Gerais de Desenvolvimento - Kairós

Este repositório adota as seguintes regras essenciais para qualquer agente ou colaborador:

1. **Filosofia Ponytail como Padrão Inegociável**:
   - Aplique sempre a "Ladder of Laziness" antes de escrever qualquer código.
   - O melhor código é aquele que você não precisou escrever: priorize YAGNI, reúso do código existente em `lib/` e APIs nativas do Flutter/Dart/Python.
   - Zero dependências extras sem justificativa irrefutável e aprovação.
   - Intervenções cirúrgicas e mínimas.

2. **Compatibilidade Multiplataforma (Android & Web)**:
   - Nunca importe `dart:io` diretamente sem stubs ou checagem `kIsWeb`.

3. **Responsividade Estrita**:
   - Sem dimensões rígidas sem proteção.
   - Suporte a `TextScaler` e múltiplos DPIs sem RenderFlex overflow.

4. **Ciclo Agêntico Obrigatório em Malha Fechada**:
   - Planejar $\rightarrow$ Executar $\rightarrow$ Validar com Edge Cases (`flutter analyze`, `flutter test`, `python -m py_compile`).

Para detalhes completos, consulte `.agent/coding_standards.md` e `.agent/skills/ponytail/SKILL.md`.
