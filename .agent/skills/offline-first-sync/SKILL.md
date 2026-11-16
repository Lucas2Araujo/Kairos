---
name: offline-first-sync
description: Padrão de sincronização híbrida offline/nuvem (Set.union/timestamp) e proteção de DatabaseManager.userPreservedTables.
---

# Offline-First & Cloud Sync

Use ao criar ou modificar tabelas de usuário ou lógica de sincronização com Supabase (`AuthService`).

## Regras
1. **Preservação Local:** Toda nova tabela de dados de usuário (ex.: `ss_highlights`) deve ser registrada em `DatabaseManager.userPreservedTables`.
2. **Merge Determinístico:** Ao sincronizar dois dispositivos offline com conjuntos disjuntos (ex.: `activityDates`, planos concluídos, marcadores), faça merge via `Set.union` ou timestamp mais recente — **nunca** sobrescreva dados locais silenciosamente.
3. **Resiliência:** Operações de UI e leitura devem funcionar 100% offline; falhas de rede na nuvem devem degradar graciosamente.
