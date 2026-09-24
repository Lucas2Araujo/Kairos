# Sprint Gamification & Polish Plan

- [x] **Step 0: Protocol & Tracking**
  - [x] Initialize `.agents/plans/sprint_gamification_polish_todo.md` <!-- id: 0.1 -->

- [x] **Critical Bugfix: Quiz Second Question False-Negative (`src/views/quiz_view.py`, `src/services/quiz_service.py`)**
  - [x] Audit question transition handler (`_next_question` / `_check_answer` / `on_continue`) in `quiz_view.py` <!-- id: c.1 -->
  - [x] Ensure selected options, button states, and indices reset explicitly on next question <!-- id: c.2 -->
  - [x] Ensure submission binds dynamically to current question ID without stale closures <!-- id: c.3 -->
  - [x] Add regression test in `tests/test_quiz_service.py` verifying multi-question sequential answers <!-- id: c.4 -->

- [x] **Step 1: Global Typography (Helvetica as default)**
  - [x] Update `src/utils/font_manager.py` to set `DEFAULT_FONT_FAMILY = "Helvetica"` <!-- id: 1.1 -->
  - [x] Update `src/theme/theme_engine.py` and `palette.py` to default font family to Helvetica across views <!-- id: 1.2 -->

- [/] **Step 2: Unified Streak & Devotional XP (+10 XP once/day)**
  - [/] Update `src/services/reading_service.py` and `src/services/quiz_service.py` to unify streak (quiz OR devotional) <!-- id: 2.1 -->
  - [ ] Implement +10 XP once per calendar day for devotional reading <!-- id: 2.2 -->
  - [ ] Expose `get_unified_user_stats(user_id, device_id)` returning `{total_xp, current_streak, completed_today}` <!-- id: 2.3 -->

- [ ] **Step 3: Home Screen Gamification Banner (`src/views/home_view.py`)**
  - [ ] Build card banner with `border_radius=16`, `palette.surface_container_high` below greeting <!-- id: 3.1 -->
  - [ ] Display streak (`🔥 X dias seguidos`), XP (`⭐ Y XP`), and mini weekly dot indicators (Dom a Sáb) <!-- id: 3.2 -->
  - [ ] Click navigation to Sabbath School / Gamification <!-- id: 3.3 -->

- [ ] **Step 4: Sabbath School Auto-Focus on Today & Media (`src/views/escola_sabatina_view.py`, `src/services/escola_sabatina_service.py`)**
  - [ ] Auto-resolve `date.today()`, select matching `SSDay`, center scroll `days_row` <!-- id: 4.1 -->
  - [ ] Auto-display today's content without manual click <!-- id: 4.2 -->
  - [ ] Add "Vídeos da Lição" collapsible/tabbed media card ("Vídeo do Dia", "Resumo da Semana") <!-- id: 4.3 -->
  - [ ] Persist `preferred_ss_category` ("jovens" / "adultos") in client storage and apply default <!-- id: 4.4 -->

- [ ] **Step 5: Visual Quarterly Selection Carousel (`src/views/quarterlies_view.py`)**
  - [ ] Implement cover gallery with sections: "Lição Adultos" & "Lição Jovens (ComTexto)" <!-- id: 5.1 -->
  - [ ] Horizontal scrollable cover cards (aspect ratio ~1:1.4) <!-- id: 5.2 -->
  - [ ] Cover click selects quarterly and opens lessons <!-- id: 5.3 -->

- [x] **Step 6: Quiz UI Theme Engine Compliance & Personalization (`src/views/quiz_view.py`)**
  - [x] Replace static colors with dynamic theme engine tokens for correct/incorrect feedback <!-- id: 6.1 -->
  - [x] Full width bottom feedback sheet (`expand=True`, `border_radius=16`, M3 pill button) <!-- id: 6.2 -->
  - [x] Personalized motivational streak messages with user first name (`profile.full_name`) <!-- id: 6.3 -->

- [ ] **Step 7: Local Notifications & Sunset Reminder (`src/services/notification_service.py`)**
  - [ ] Verify/complete notification scheduler for Sabbath School, Devotional, Bible <!-- id: 7.1 -->
  - [ ] Friday 16:00 reminder with deep link `/hinario?filtro=sabado` <!-- id: 7.2 -->

- [ ] **Step 8: Verification & Audit**
  - [ ] Run `pytest tests/test_quiz_service.py` and `tests/test_escola_sabatina.py` <!-- id: 8.1 -->
  - [ ] Run full test suite <!-- id: 8.2 -->
