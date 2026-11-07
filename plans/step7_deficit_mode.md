# Phase 13 — Deficit mode ("وضع العجز": eat less than usual, no diet plan)

User request: when the user can't follow the diet right now, offer a mode that replaces the plan with
"just eat less than usual". Decisions (from the user, final):
- Baseline "usual" = maintenance (TDEE) from the profile (BMR Mifflin × activity). No history needed.
- Cut = user picks light 10% / medium 15% / strong 20%. Budget = max(energyFloor(bmr, sex), TDEE × (1 − p)).
  Reuse `bmrMifflinStJeor`, `tdee`, `energyFloor` in lib/domain/nutrition/energy.dart. Do not change
  their math.
- While ON:
  a) Today shows ONE simple calorie budget ("كُل أقل من X سعرة") instead of the plan targets; logging food
     works as now.
  b) Planned meals/schedule are NOT materialized into the day; the user logs only what they eat.
  c) Relaxed macros: only kcal + protein matter. Carb and fat targets/cards/rings are hidden. Protein
     target stays the computed protein (proteinPerKg × weight) so the protein ring still works.
  d) Calorie streak day = ate > 0 and ≤ the deficit budget (instead of within ±10% of target).
- Toggle: a clear switch on Today (header/menu entry) AND in Me; it stays on until turned off.

## Design (follow it; it reuses the frozen-day architecture)
1. Domain (`lib/domain`, pure Dart, tests first):
   - `enum DeficitLevel { light(0.10), medium(0.15), strong(0.20) }` with Arabic labels in l10n, not domain.
   - Add `TargetMode.deficit`. `NutritionTargets.deficit({weightKg, heightCm, ageYears, sex, activity,
     level, proteinPerKg})` → mode deficit, kcal = budget, macros = protein-only (carbs/fat 0 are fine
     because UI hides them; document that). Keep `fromJson/toJson` round-trip (mode name) — older docs
     without the value still parse as before.
   - `UserProfile`: add `DeficitMode? deficit` (null = off) holding `level` and `startedAt`;
     `effectiveTargets` getter: deficit != null ? NutritionTargets.deficit(...) : targets.
     Do NOT overwrite the user's normal `targets` — turning the mode off restores them exactly.
   - `isCalorieHit(DayLog)`: if `day.targets.mode == TargetMode.deficit` → consumed > 0 && consumed ≤
     targets.kcal; otherwise unchanged ±10% rule. Day docs freeze targets, so history keeps the rule
     that applied that day. Tests both modes.
2. Data: `profile_mapper` reads/writes `deficit: {level, startedAt}` (absent → off). Mapper round-trip
   tests. Firestore rules unchanged (users/{uid} wildcard). Record in PROGRESS.md Deviations: new
   profile field + TargetMode.deficit.
3. Everywhere today's targets come from the profile (TodayController `_materializeToday` /
   `ensureDay(date:, targets:)`, the `ever(_session.profile, ...)` refresh, WeighInService recompute,
   ProfileController previews, assistant snapshot) use `profile.effectiveTargets`. Weigh-in still
   recomputes normal `targets`; deficit budget follows automatically because it is derived.
4. Skip schedule while ON: `ensureDay` (day_repository) gets `includeSchedule` (default true);
   TodayController passes `false` when deficit is on. Entries already in today's doc are never deleted:
   uneaten schedule-origin entries are hidden on Today while deficit is on (eaten ones stay visible and
   count). Turning the mode off shows them again. Past days untouched.
5. UI:
   - Today: in deficit mode the hero shows budget ring (consumed vs budget, "المتبقي" = budget −
     consumed, over-budget shown in coral with "تجاوزت الميزانية بـ X"), protein ring, training ring;
     macro cards show protein only; a small chip "وضع العجز ١٥٪" with tap → settings sheet.
   - A sheet (`lib/page/deficit/deficit_mode_sheet.dart`) shared by Today and Me: explains in one line
     ("بدل الخطة: كُل أقل من المعتاد"), SegmentedButton 10/15/20 with resulting kcal preview
     (TDEE → budget), switch on/off, NeonButton save. Shows floor note when the floor applied.
   - Me: row "وضع العجز" with current state (off / level + kcal) opening the same sheet.
   - Header menu/entry on Today to open the sheet even when off.
   - Strings in Arabic at END of app_strings in `// --- Phase 13 deficit strings ---`.
6. Assistant: snapshot/prompt context mentions deficit mode + budget when on (one line); keep
   agent_prompt.dart and functions/index.js prompt parity if you touch the prompt (prefer snapshot only).

## Tests
- Domain: budget for each level, floor clamp (sedentary + strong hits BMR floor), effectiveTargets
  on/off restores normal targets, isCalorieHit deficit rule (under, over, zero), JSON round-trip.
- Mapper round-trip with and without deficit.
- TodayController: deficit on → ensureDay called with includeSchedule false and deficit targets;
  toggling off → normal targets; uneaten scheduled entries hidden, eaten shown.
- Widget: Today in deficit shows budget + protein only (no carbs/fat cards); sheet changes level and
  previews kcal; Me row shows state. 320px / textScaler 1.6 no overflow.
`dart format` only changed files. Analyzer clean; all tests green.
