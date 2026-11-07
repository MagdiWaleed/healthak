# Phase 14 — Readable workout plan + home training (pull-up bar + 40 kg dumbbells)

User feedback (verbatim intent): the workout plan is overwhelming; make it readable and good UX.
They train AT HOME with only a pull-up bar and a simple 40 kg set (treat as adjustable dumbbells,
40 kg total; no bench, no barbell rack, no cables/machines).

Device screenshots showed why the editor overwhelms: every exercise card shows inline sets stepper,
reps stepper, an active switch and 7 weekday chips at once; a 2-exercise day fills the screen.

## A. Equipment awareness (domain, pure Dart, tests)
1. `enum Equipment { bodyweight, pullUpBar, dumbbells, barbell, bench, cable, machine, cardioMachine }`.
   Tag EVERY library exercise with `Set<Equipment> needs` (e.g. bench_press {barbell, bench},
   pull_up {pullUpBar}, push_up {bodyweight}, dumbbell_row {dumbbells}).
2. Add home exercises missing from the library (Arabic names, ids stable, muscle groups):
   ضغط أرضي بالدمبل (dumbbell floor press, replaces bench), ضغط أرضي ضيق (diamond push-up),
   ضغط أرضي بقدمين مرتفعتين (decline push-up), ضغط بايك للكتف (pike push-up),
   عقلة سلبية (negative pull-up), تعلق على البار (dead hang), رفع الركبتين معلقاً (hanging knee raise),
   رفعة رومانية بالدمبل (DB RDL), اندفاع بالدمبل (DB lunge), سكوات بالدمبل (DB squat),
   تمديد ترايسبس بالدمبل فوق الرأس (if not present), تجديف بالدمبل بانحناء (if needed),
   بيربي (burpee), متسلق الجبال (mountain climber), سكوات قفز (jump squat).
   Keep existing ids unchanged (plans reference them).
3. `bool canDo(Exercise e, Set<Equipment> have)` = e.needs ⊆ have ∪ {bodyweight}.
4. User equipment stored on the profile: `UserProfile.equipment: Set<Equipment>` (absent → all = gym,
   so existing users see no change). Mapper read/write + round-trip test. Record in PROGRESS.md
   Deviations. (If Phase 13 added profile fields, merge carefully — it runs before this phase.)
5. Optional target load per plan item: `WorkoutPlanItem.loadKg` (nullable) and frozen into
   `TrainingItem.loadKg` at materialization (same frozen-history rule). Mapper + tests. Display
   "3 × 10 · 12 كجم" when present.

## B. Readable plan editor (rewrite lib/page/training/plan_editor_screen.dart UX)
1. Week overview first: 7 compact rows (Saturday-first? keep app's Monday-first order), each row:
   day name, focus summary from muscle groups ("صدر · ظهر"), "٥ تمارين", or "راحة". Tap → day view.
   Opens on the weekday passed in (existing behavior).
2. Day view: clean list, ONE line per exercise: name, chip "3 × 10" (+ "12 كجم"), drag handle.
   Tap a row → bottom sheet editor with: sets / reps / load steppers (NumberField-based), which days
   (chips), active switch, delete (confirm). Nothing else inline.
3. Primary actions at the bottom: "إضافة تمرين" (NeonButton) + overflow menu (⋮) holding
   "نسخ إلى أيام أخرى" and "خطط جاهزة". Save stays sticky in SafeArea.
4. Empty day: friendly empty state with two buttons: add exercise / pick a ready plan.
5. Exercise picker: filter chips row "معداتي" (default ON when equipment is set) / "الكل"; muscle
   group chips; search stays; each row shows the needed equipment as a small icon. Custom exercise
   stays.

## C. Home templates (replace/extend "خطط جاهزة")
Ready plans that only use bodyweight + pull-up bar + dumbbells, with sensible sets × reps and
suggested dumbbell loads left empty (user sets them):
- "منزلي — جسم كامل ٣ أيام" (Sat/Mon/Wed in app weekday terms; let the user pick days in a step).
- "منزلي — علوي/سفلي ٤ أيام".
- "مبتدئ — بدون معدات" (bodyweight only).
Template picker shows a short description, days per week, ~minutes per session, and the equipment it
needs; applying asks which weekdays (pre-selected defaults) and confirms replacing existing items.

## D. Equipment setup UX
- First time the user opens the plan editor (or from Me → "معداتي"), a short sheet: "أين تتمرن؟"
  [المنزل] [النادي] → for home, checkboxes: عقلة (pull-up bar), دمبل/أوزان (with max kg field, default 40),
  مقعد (bench), بار (barbell). Save to profile. Me shows the row and lets them change it.

## E. Training tab readability (light touch)
- Checklist rows: name on line 1, "3 × 10 · 12 كجم" on line 2, muscle as small muted text instead of
  the outlined chip; bigger tap target; keep CheckTile.

## Tests
Domain: canDo, library tags complete (every exercise has non-empty needs), new ids unique, templates
only use home-capable exercises, loadKg frozen into TrainingItem. Mapper round-trips (equipment,
loadKg). Widgets: week overview rows render summaries; tapping a row opens day view; tapping an
exercise opens the sheet; picker "معداتي" filter hides barbell/cable exercises; equipment sheet saves;
320px/textScaler 1.6 no overflow for editor + sheet.
Strings at END of app_strings in `// --- Phase 14 training strings ---`.
`dart format` only changed files. Analyzer clean; all tests green.

## F. Findings from Claude using the app on the emulator (fix all; these are the real pain points)
1. "خطط جاهزة" sheet shows three bare names (دفع/سحب/أرجل, علوي/سفلي, جسم كامل ٣ أيام) with no
   description, days, duration or equipment. Applying "جسم كامل" put barbell squat + barbell bench on
   Monday — impossible at home — and SILENTLY EMPTIED Saturday (the user's existing day) without asking
   which days to use. Fix per section C: describe each plan, ask days, show exactly what will be
   replaced, never touch days the user did not pick. Gym templates stay but are labelled "نادي" and
   hidden behind the "معداتي" filter when the user has home equipment.
2. Leaving the editor with the back arrow silently discards unsaved changes (the applied template
   vanished). Add an unsaved-changes guard (PopScope): "حفظ / تجاهل / متابعة التعديل".
3. One exercise card is ~730 px tall (steppers + switch + 7 chips) so a 3-exercise day needs 3 screens.
   Section B fixes this; acceptance: a 6-exercise day fits on one 1080×2280 screen in day view.
4. Empty day shows "إضافة تمرين" and "خطط جاهزة" twice (centre empty state + bottom bar). Show them
   once.
5. Weekday chip row is clipped (Sunday cut off at the edge, no scroll hint). The week overview list
   replaces it; if chips remain anywhere, they must fit or visibly scroll.
6. Training tab: the 100% ring + three stat tiles fill the whole first screen; today's exercises start
   below the fold. Make the header compact (slim progress bar or small ring beside the title, one line
   of stats) so the checklist is visible without scrolling.
7. Training tab: future days (e.g. tomorrow) are greyed and untappable, so the user cannot preview the
   next workout. Allow tapping upcoming days of the current week to see a read-only preview of the
   planned exercises (no ticking, no materialization — derive from the plan).
8. Picker search only matches Arabic names; "dumbbell"/"pull" find nothing. Add English aliases per
   exercise (`aliasesEn`) and match them too (case-insensitive), alongside the Arabic normalization.
