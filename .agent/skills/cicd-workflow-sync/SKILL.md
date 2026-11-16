---
name: cicd-workflow-sync
description: Sincronização de workflows de CI/CD, builds multiplataforma e verificações automatizadas.
---

# CI/CD Workflow Sync

1. Garanta que `flutter analyze` e `flutter test` locais reflitam exatamente os checks de CI antes de qualquer push.
2. Em alterações de assets/bancos SQLite, valide que o tamanho e o modo `PRAGMA journal_mode=DELETE; VACUUM;` estejam corretos para bundle/R2.
