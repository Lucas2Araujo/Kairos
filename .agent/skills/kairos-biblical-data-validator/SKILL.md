---
name: kairos-biblical-data-validator
description: Validação bíblica e de dados offline (referências bíblicas, Apócrifos/1 Enoque, catálogo EGW e SQLite DELETE+VACUUM).
---

# Kairós Biblical & Offline Data Validator

Use ao alterar repositórios bíblicos, catálogo EGW, perícopes, comentários ou scripts Python geradores de SQLite.

## Regras de Integridade
1. **Referências Bíblicas & Busca:**
   - Queries como `"I Macabeus"`, `"Eclesiástico"` ou `"1 Enoque"` nos filtros `TODOS` e `Apócrifos` (`AVM` e `ARA`) devem resolver o livro correto sem ocultação silenciosa.
2. **Catálogo & Cache EGW:**
   - Cache parcial (ex.: 1 capítulo salvo online em `egw_chapters_cache`) **nunca** pode truncar `getTableOfContents` nem marcar `is_downloaded = 1` com conteúdo incompleto.
3. **Bancos SQLite Offline:**
   - Todo `.sqlite` gerado ou alterado para bundle/R2 deve executar `PRAGMA journal_mode=DELETE; VACUUM;`.
   - Scripts Python devem passar em `python -m py_compile`.
