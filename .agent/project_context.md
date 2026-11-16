# Contexto do Projeto — Kairós

## Visão Geral
**Kairós** (`package:kairos_web`) é um aplicativo multiplataforma (Android & Web) em Flutter/Dart focado em estudo bíblico, Espírito de Profecia (Ellen G. White), Lição da Escola Sabatina, hinário, planos de leitura e gamificação, com arquitetura **offline-first** e sincronização híbrida na nuvem.

## Stack Tecnológica
- **Frontend:** Flutter / Dart (`dart:ui`, `http`, `shared_preferences`).
- **Persistência Local:** SQLite (`sqflite` no Android + `sql.js` na Web) gerenciado por `DatabaseManager`.
- **Backend / Nuvem:** Supabase Auth/REST (`AuthService`).
- **Scripts de Dados:** Python padrão (`sqlite3`) para geração e compactação de bancos SQLite offline.
- **Qualidade:** `flutter test`, `flutter analyze`, `python -m py_compile`.

## Arquitetura Principal (`lib/`)
- `lib/services/`: Serviços de domínio e sincronização (`EgwService`, `ReadingPlanService`, `SabbathSchoolService`, `GamificationService`, `AuthService`, `ThemeService`, `DatabaseManager`).
- `lib/repositories/`: Repositórios de dados (`BibleRepository`, `PericopeRepository`, `CommentaryRepository`).
- `lib/views/`: Telas, leitores e componentes visuais organizados por módulo.
