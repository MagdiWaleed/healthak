# Healthak redesign v2: dark neon UI, weight tracking, gym checklists

## Context

Healthak is a Flutter + GetX + Firestore calorie tracker with an Arabic RTL UI.

Current state:
- `lib/page` is now the new feature layer. The legacy code is gone.
- Steps 0–2 are done. Step 3 (the marketplace) is partial. Step 5 A–C are done.
- The UI is light only, with 4 tabs: Today / My Meals / Explore / Account.
- There is no chart library. Tests: 209 green.

The user wants a "standard, catchy" health-tracker experience, with full freedom to redo the UI, UX and user journey. Two new features are wanted:
1. **Body weight tracking.**
2. **Gym training checkboxes.**

Codex does the coding. Claude writes the spec for each phase, then reviews and verifies the result.

### Decisions from the grill session
| Topic | Choice |
|---|---|
| Gym | Weekly workout plan by weekday. Each day shows that day's exercises as checkboxes with a sets × reps target. |
| Exercises | Bundled offline Arabic library of about 60 exercises grouped by muscle, plus custom entries. |
| Weight | One entry per day, a trend chart (7/30/90 days) with a smoothed trend and a goal line. The latest weigh-in auto-updates `profile.weightKg`, and the targets are recomputed. |
| Nav | Today · Nutrition · Training · Progress · Me |
| Look | Bold dark base with neon accents (emerald/lime + coral) |
| Gamify | Streaks, 3 activity rings on Today, celebrations, weekly recap card |
| Git | First commit the dirty `cline-UI` tree as a checkpoint, then branch `redesign-v2` |
| Codex split | Claude writes the spec and reviews; Codex codes each phase |

## Phase 0: Setup (Claude)
1. Run `flutter analyze` and `flutter test` on the dirty tree. Commit it as a checkpoint on `cline-UI`, then create branch `redesign-v2`.
2. Install the skills:
   - `npx skills add mattpocock/skills` (grill-me).
   - Run `npx skills find flutter` and `npx skills find "ui ux design"`, then install the top-ranked Flutter and UI/UX skills.
   - `frontend-design` and `emil-design-eng` are already present.
3. **Codex skill.** No codex skill exists, so create `.claude/skills/codex-delegate/SKILL.md`. It encodes this loop:
   - Write the spec to the scratchpad.
   - Run `codex exec -C <repo> -s workspace-write -o <scratch>/phaseN-result.md - < spec.md`.
   - Run `git diff`, review it, then run analyze and tests.
   - If fixes are needed, use `codex exec resume --last "<fixes>"`.
4. **Fix the stale `AGENTS.md`.** Codex reads it. Its table still says `data/ui/app` are "Not started" and that `lib/page` is legacy. Sync it with `CLAUDE.md`, and add the Codex workflow section.

## Phase 1: Domain and data (Codex, pure Dart and tests first)

New files in `lib/domain/`. Nothing here imports Flutter.
- **`body/body_weight.dart`**
  - `BodyWeightEntry {dateKey, kg, createdAt}`.
  - A trend helper: exponential moving average with α = 0.1, plus 7-day delta and goal ETA.
  - The doc id comes from `DayLog.keyFor()` (`lib/domain/day/day_log.dart:209`).
- **`training/exercise.dart`**
  - `Exercise {id, nameAr, muscle (enum), isCustom}`.
  - `kExerciseLibrary`, a const list of about 60 entries.
- **`training/workout_plan_item.dart`**
  - `{id, exerciseId, nameAr, muscle, sets, reps, daysOfWeek:Set<int>, order, active}`.
  - Reuse the `appliesTo(date)` and `everyDay` pattern from `ScheduleItem` (`lib/domain/schedule/schedule_item.dart:48-58`).
- **`training/training_day.dart`**
  - A frozen snapshot of the day's plan items, each with a `done` flag.
  - `progress` gives the fraction done.
  - Uses the same frozen-at-insert principle as `DayLog`, so editing the plan never rewrites history.
- **`progress/streaks.dart`**
  - Pure functions that compute current and best streaks for three things: calorie target hit, all training done, and a weigh-in logged.
  - Also `WeeklyRecap` (average kcal, sessions, weight delta).
- **`UserProfile`:** add an optional `goalWeightKg`, and update `copyWith`.

Data layer:
- **Firestore paths:**
  - `users/{uid}/bodyWeights/{dateKey}` (already reserved)
  - `users/{uid}/workoutPlan/{itemId}`
  - `users/{uid}/trainingDays/{dateKey}`
  - Existing rules `match /{document=**}` (`firestore.rules:14-20`) already cover all three, so no deploy is needed.
- **Mappers:** in `lib/data/mappers/`, following the `day_mapper.dart` and `mapper_utils.dart` pattern. Add the `goalWeightKg` read/write to `profile_mapper.dart`.
- **Refs:** add getters to `lib/data/firestore_refs.dart` with `withConverter`.
- **Repositories:** `body_weight_repository.dart`, `workout_plan_repository.dart` and `training_day_repository.dart`.
  - Range queries on `FieldPath.documentId`, like `day_repository.dart:30-49`.
  - `ensureTrainingDay` mirrors `ensureDay` (`day_repository.dart:62-124`): it materializes from the active plan items for that weekday and carries over `done` flags.
  - Toggles run in a transaction.
- **Weigh-in service:**
  - Saving the newest-dated entry also updates `profile.weightKg`.
  - Targets are recomputed via `NutritionTargets.compute` (`lib/domain/nutrition/energy.dart:253`), the same way `ProfileController.previewTargets` does (`lib/page/profile/profile_controller.dart:85-99`).
  - The profile save then flows to Today through the existing `ever(_session.profile)` listener.
- **Tests:**
  - Domain: EMA, streaks, `appliesTo`, materialization and carry-over.
  - Mapper round-trips, in the same style as `test/data/profile_mapper_test.dart`.

## Phase 2: Dark neon design system (Codex)

**Theme files:**
- Rework `lib/ui/theme/app_colors.dart` `AppPalette` as a dark base:
  - Base: ink `#0B0F0E`, surface `#141A18`, raised `#1C2421`.
  - Accents: neon emerald `#2EE6A6`, lime `#C6F432`, coral `#FF6B5B`, violet `#9B8CFF`.
  - Text: `#ECF5F1`, muted `#8A9A94`.
- Set `app_theme.dart` to dark brightness and `main.dart:74` to `ThemeMode.dark`.
- Keep Cairo. Use bigger hero numbers in `app_typography.dart`.

**Glass:** the dark path re-enables `BackdropFilter`. Keep the limit of 2 live filters and its debug counter (`glass_surface.dart:44-70`). Lists still use filter-free `GlassCard`.

**New components** in `lib/ui/components/`:
- `activity_rings.dart`: 3 concentric animated rings, hand-painted with `CustomPainter`.
- `streak_chip.dart`, `stat_tile.dart`, `section_header.dart`.
- `weight_chart.dart`: uses `fl_chart` (the only new dependency, recorded as a deviation).
- `check_tile.dart`: an animated checkbox row that reuses `ui/motion/eat_toggle/*` and `ui/feedback/haptics.dart`.

**Celebrations:** reuse `ui/motion/celebration.dart` and burst particles when a ring closes, a workout completes, or a new low weight is logged. Gate them on `MotionSettings`.

## Phase 3: Navigation and journey (Codex)

**5 tabs** in `lib/page/home/home_shell.dart`, always labelled:
- **Today**
- **Nutrition:** a segmented control for My Meals / Market, reusing `MyMealsTab` and `MarketplaceTab` as they are.
- **Training:** new.
- **Progress:** new.
- **Me:** today's `_AccountTab`, extracted to `lib/page/me/` and restyled. It adds a goal weight row.

**Global quick-add:** a sheet reachable from Today's header with three actions: log food (the existing flow), log weight, start workout.

**Routes and bindings:** follow the `app_routes.dart`, `app_pages.dart:29-42` and `bindings/cost_binding.dart` patterns. Register controllers in `home_binding.dart`.

**Onboarding:** add an optional goal-weight step to the existing onboarding.

## Phase 4: Today redesign (Codex, Claude reviews screenshots closely)

Changes to `lib/page/today/today_tab.dart`. Keep the `ValueKey` sections list, `readOnly`, week strip, unlock guard and eat toggles. New order:
1. Header with the date and a streak chip.
2. Week strip.
3. **Activity rings hero:** kcal vs target, training %, protein vs target. Legend beside it.
4. Macro cards. This replaces the `TodaySummary` layout; `TodaySummary` itself is kept.
5. **Weigh-in card:** today's weight, or a "log weight" CTA, plus the 7-day delta.
6. **Today's workout card:** the first 4 checkboxes and "open full".
7. Meals by slot (the existing cards, restyled).
8. Assistant banner and planned details.

**`TodayController`:** add an Rx for the training day and the weight. Subscribe and resubscribe them in `selectDate`, following the `_watchSub` pattern (`today_controller.dart:293`).

## Phase 5: Training tab (Codex)

Path: `lib/page/training/`.
- **Today view:** the day's checklist, with sets × reps per item. A progress bar on top. Read-only for past days unless unlocked, same rule as Today.
- **Weekly plan editor:**
  - A weekday selector and a reorderable list.
  - Add an exercise through a picker: library grouped by muscle, a search field, and a "custom" option.
  - Edit sets/reps, copy a day to other days, pause an item.

## Phase 6: Progress tab (Codex)

Path: `lib/page/progress/`.
- **Weight chart:** 7/30/90-day toggle, raw dots plus the EMA line, a dashed goal line, current, delta and ETA tiles, and a log/edit/delete entry sheet.
- **Streak cards:** calories, training, weigh-in.
- **Weekly recap card.**
- **History:** link to the existing history screen.

## Phase 7: Restyle sweep and polish (Codex)

Bring all remaining screens onto the dark tokens:
- meal editor, foods, market detail
- assistant, profile, cost, onboarding, splash, guest

Also check RTL (`PositionedDirectional`), 320px width and large text.

## Animations (added mid-session, applies to Phases 2–7)
- Add `flutter_animate` (a deviation from Kimi's "no animation packages" rule; the user asked for animations).
- Use it for staggered list entrances, card fade-and-slide, number tickers (`ticker_number.dart`), and a shimmer on loading states.
- Rings: animated sweep from the old value to the new one, never from 0 again.
- Check toggles: scale, then a glow, then haptics.
- Tab switches: shared-axis fades.
- Celebrations: particle burst (`ui/motion/eat_toggle/burst_particles.dart`).
- Respect `MotionSettings` (reduced motion means no animation).

## Phase 8: Assistant upgrade (added mid-session)

Problems found:
- **Broken system prompt.** `lib/service/agent/agent_prompt.dart:22` ends mid-sentence ("بعد استدعاء").
- **Narrow web search.** It only covers food macros (`web_food_search_client.dart`, a single hardcoded prompt).
- **No tools** for weight or training.

Fixes:
- **Prompt:** rewrite it cleanly, including when to search the web and how to cite.
- **General `search_web` tool:**
  - Calls the xAI `/v1/responses` endpoint with `web_search`.
  - Accepts a free query for nutrition, fitness or exercise questions.
  - Returns the text plus sources.
  - Keep `search_food_online` for macros.
- **Weight tools:** `get_weight_history`, `propose_log_weight`.
- **Training tools:** `get_training_today`, `get_workout_plan`, `propose_toggle_exercise`, `propose_add_plan_item`.
- All `propose_*` tools keep confirmation cards.
- **UI and journey:**
  - Live tool-activity chips ("searching the web…", "reading your day…").
  - Clickable source chips (`url_launcher`).
  - Context-aware suggested prompts on the empty state (time of day, remaining kcal, today's workout).
  - Typing shimmer.
  - Dark restyle.
- **Tests:** in `test/service/chat_orchestrator_test.dart` style, using fake clients.
- **CLI live check:** run with `--dart-define-from-file=ai_secrets.json`. The key file is gitignored and is never read into the chat.

## Codex loop per phase

Claude writes `<scratch>/specN.md` containing:
- the goal, and the files to touch or create
- the patterns to reuse, with paths
- constraints:
  - nothing in `lib/domain` imports Flutter
  - all strings go in `lib/l10n/app_strings.dart` in Arabic
  - no `print`
  - stay within the blur limit
  - entries are keyed by `localId`
  - no `google_sign_in`
  - no Gradle downgrades
- acceptance: analyzer clean and tests added

Then:
1. Run `codex exec -s workspace-write`.
2. Claude reviews `git diff` for correctness and the architecture rules, and runs `flutter analyze --no-pub` and `flutter test` itself.
3. Send fixes back with `codex exec resume --last`.
4. Commit each phase separately.

Claude hand-edits only small corrections.

## Docs
- `plans/PROGRESS.md`: a new top section, updated per phase.
- Deviations table, with these entries:
  - dark theme reverses `ui_refresh.md`
  - the 5-tab nav
  - `fl_chart`
  - the new `workoutPlan` and `trainingDays` collections
  - `goalWeightKg`
- New `plans/step6_training_weight.md` with the domain and schema detail.
- Add the three new collections to the schema section of `plans/general.md`.

## Verification (always from the command line, after every phase)
User rule: always test the app from the command line. Every phase ends with this CLI gate, run by Claude, before its commit:
1. `flutter analyze --no-pub` is clean, and `flutter test` is green (209 tests plus the new ones).
2. `flutter build apk --debug`. If the emulator isn't running, launch `Pixel_4` visibly (command in `AGENTS.md`).
3. Install and launch:
   - `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
   - `adb shell am start -n com.example.diet_app2/.MainActivity`
   - `adb` lives at `~/AppData/Local/Android/sdk/platform-tools/adb.exe`.
4. Drive the phase's flow with `adb shell input tap/swipe/text`. Find the coordinates with `adb shell uiautomator dump` plus `adb pull`.
5. Capture `adb exec-out screencap -p > output/emulator-ux/<phase>-<step>.png` (gitignored) and inspect each image.
6. Check `adb logcat -d *:E | grep -i flutter` for exceptions.
7. Record what was exercised in `PROGRESS.md`.

Also add a project memory note: "always test the app via CLI (adb) after changes".

Other checks:
- Widget tests:
  - Today renders the rings, weight card and workout card, including the read-only past day.
  - Toggling a training checkbox.
  - Weight sheet validation.
  - 320px and large-text layouts.
- Screenshots: `CAPTURE_REVIEW=true` renders to `output/review/` for Today, Training, Progress and Nutrition. Claude inspects them.
- Device:
  - Build the debug APK, launch `Pixel_4` visibly (command in `AGENTS.md`), and install.
  - Walk the journey: build a plan, tick exercises, log a weight (check that the targets on Today update), view the chart, change the date (check that checks reset on a new day and history stays frozen).
  - Then clean up the test data.
