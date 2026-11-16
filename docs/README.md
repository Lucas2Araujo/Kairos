# Documentação de Engenharia de Software (TCC) — Kairós

> **Versão da Documentação:** 1.0 (Alinhada à versão `0.7.0+2` / release `v0.7.4.0` do aplicativo Flutter/Dart `kairos_web`)  
> **Escopo:** Documentação acadêmica e técnica completa do ecossistema **Kairós — Tempo de Qualidade com Deus** para apresentação de Trabalho de Conclusão de Curso (TCC), elaborada em conformidade com boas práticas de Engenharia de Software (IEEE 830 / ISO/IEC/IEEE 29148, UML 2.5, Modelo C4 e Engenharia de Qualidade em Malha Fechada).

---

## 📚 Índice da Suíte Documental

| Documento | Padrão / Foco | Conteúdo Principal |
| :--- | :--- | :--- |
| **[01 — Especificação de Requisitos de Software (ERS)](./01_Especificacao_Requisitos_IEEE.md)** | IEEE 830 / ISO/IEC/IEEE 29148 | Visão do produto, caracterização dos atores, Requisitos Funcionais (`RF01`–`RF30`), Requisitos Não-Funcionais (`RNF01`–`RNF12`) e Regras de Negócio/Restrições Globais (*Filosofia Ponytail*). |
| **[02 — Arquitetura e Projeto do Sistema](./02_Arquitetura_e_Projeto_Sistema.md)** | Clean Layered + C4 + DER | Arquitetura em camadas Flutter/Dart, persistência SQLite multiplataforma (`DatabaseManager` IO/Web), diagramas Mermaid (C4, Classes, DER Multi-Banco, Sequência de Sync Híbrido e Dual Covers EGW) e referência aos diagramas UML formais. |
| **[03 — Diagramas e Especificações de Casos de Uso](./03_Diagramas_Casos_de_Uso.md)** | UML 2.5 + Especificação Textual | Visão geral e 5 Diagramas de Casos de Uso modulares em Mermaid + links PlantUML (`.puml`) + tabelas formais com atores, pré-condições, fluxo principal, fluxos alternativos, exceções e pós-condições. |
| **[04 — Engenharia de Qualidade, Testes e Validação](./04_Qualidade_Testes_e_Validacao.md)** | TDD em Malha Fechada | Metodologia de validação, padronização Dartdoc (`///`), inventário completo da suíte de testes (**41 arquivos / 302 casos**) e Matriz de Rastreabilidade (`Requisitos` × `Edge Cases` × `Testes`). |
| **[05 — Manual do Usuário e Guia Técnico](./05_Manual_do_Usuario_e_Guia_Instalacao.md)** | Manual em 4 Perfis | Guias práticos para (1) Leitor Devocional, (2) Aluno/Professor de Escola Sabatina & Turmas, (3) Músico/Pastor (Louvor & Liturgia) e (4) Manual Técnico de Instalação, Scripts SQLite e Deploy. |

---

## 📐 Repositório de Diagramas Formais PlantUML (`.puml`)

Todos os diagramas em notação UML 2.5 e DER formais estão versionados em [`docs/diagramas/`](./diagramas/):

- [`DCU_Geral.puml`](./diagramas/DCU_Geral.puml) — Diagrama Geral de Casos de Uso do Ecossistema Kairós
- [`DCU01_Biblia_Apocrifos_Estudo.puml`](./diagramas/DCU01_Biblia_Apocrifos_Estudo.puml) — Estudo Bíblico, Apócrifos (`AVM`), `1 Enoque`, Perícopes e Comentários Multi-Autor
- [`DCU02_EGW_Planos_Missao.puml`](./diagramas/DCU02_EGW_Planos_Missao.puml) — Espírito de Profecia (~79 obras, Dual Covers Clássica/CPB) e Missão em 2 Etapas
- [`DCU03_Escola_Sabatina_Turmas.puml`](./diagramas/DCU03_Escola_Sabatina_Turmas.puml) — Escola Sabatina Interativa (`ss_highlights`, Mind Map, Luz Menor, Quiz) e Turmas/PGs
- [`DCU04_Hinarios_Cultos_Devocional.puml`](./diagramas/DCU04_Hinarios_Cultos_Devocional.puml) — Hinários 2022/1996 (FTS5), Comparador, Agente de Cultos, Meditações e Pôr do Sol (NOAA)
- [`DCU05_Gamificacao_Sync_Temas.puml`](./diagramas/DCU05_Gamificacao_Sync_Temas.puml) — Gamificação (Reserva de Azeite), Sincronização Híbrida na Nuvem, `ThemeEngine` e Gestos/Acessibilidade
- [`Diagrama_de_Classes.puml`](./diagramas/Diagrama_de_Classes.puml) — Diagrama de Classes da Arquitetura Flutter/Dart
- [`DER_MultiBanco.puml`](./diagramas/DER_MultiBanco.puml) — Diagrama Entidade-Relacionamento Multi-Banco SQLite

---

## 🗂️ Arquivos Históricos e Planos de Implementação

- **Acervo Histórico (Legado Python/Flet):** Preservado em [`docs/legacy_flet/`](./legacy_flet/) para registro da evolução arquitetural do projeto antes da migração nativa para Flutter/Dart.
- **Planos de Engenharia e Polimento Final:** Especificações técnicas e tarefas das 5 Sprints registradas em [`docs/superpowers/plans/`](./superpowers/plans/), com destaque para [`2026-11-15-kairos-final-polish-plan.md`](./superpowers/plans/2026-11-15-kairos-final-polish-plan.md).
