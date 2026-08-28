# Step 2 — Daily Tracking + Meal Composition

**Goal:** the complete personal loop. Build meals from components, nest a meal inside another,
schedule it, track it day by day, and look back at history.

**Status:** implemented, `flutter analyze`/`flutter test`/`flutter build apk --debug` all clean.
Manual on-device walk of the "Reviewable at the end" loop is the one item not yet run — see
`plans/PROGRESS.md`.

**Depends on:** Step 1 (domain, data, design system, auth, shell)
**Blocks:** Step 3 (needs `MealDefinition` and `DayLog` final)

At the end of this step the app is genuinely usable as a personal tracker, with no marketplace.

---

## 2.1 Food catalog — `lib/page/foods/`

- [x] `FoodCatalogScreen` — browse, search-as-you-type over `searchTokens`, category chips
- [x] **Paginated** — `limit(30)` + `startAfterDocument`, infinite scroll.
      `males_repository.dart:11`'s unbounded full-collection `.get()` is gone (file deleted).
- [x] `FoodPickerSheet` — a glass bottom sheet used by the meal editor and by quick-add
- [x] `FoodDetailScreen` — per-100g macros, micros if present, optional price
- [x] Debounce search input by ~250ms
- [x] Empty / loading / error states — *not* via `AsyncView`. See Deviations in PROGRESS.md:
      pagination needs "has items AND loading more" simultaneously, which `AsyncValue`'s
      three-way loading/data/error switch doesn't model; used `EmptyState`/`ErrorState` directly.

Kills `single_male_screen.dart:32`'s `faker.image.image()` background — the whole file is deleted.

## 2.2 Meal editor — `lib/page/meal_editor/`

The core screen of the app. Replaces both `create_single_meal_details/` and
`add_complete_meal/`, which are near-duplicate parallel flows today.

- [x] `MealEditorScreen` + `MealEditorController`
- [x] Reorderable entry list backed by **`localId`, not list position**
- [x] Per-row: name, grams, kcal, and a menu — [فك التجميع / حذف]. **Deviation:** "تعديل الوزن"
      is not a menu item because the `GramStepper`/`ScaleStepper` is always visible on the row —
      a menu entry for it would just be a slower path to the same control.
- [x] **"إضافة مكوّن"** → `FoodPickerSheet` → appends a `FoodEntry` at 100g
- [x] **"إضافة وجبة"** → meal picker → appends a `MealRefEntry`
- [x] **Cycle and depth guard on add.** Illegal picks are shown greyed out with the Arabic
      refusal reason, via the Step 1 `canNest` guard.
- [x] **Ungroup** — expands a `MealRefEntry` into its scaled leaf `FoodEntry`s in place.
- [x] `GramStepper` — tap to type, long-press to repeat, ±5g. Generalized into
      `lib/ui/components/numeric_stepper.dart`, reused by `ScaleStepper` for `MealRefEntry`
      portions (shown/typed as a percentage).
- [x] Live animated totals header — kcal + P/C/F, re-tweening on every change
- [x] **"موازنة تلقائية"** → the portion solver, with a preview diff, per-entry lock toggles, and
      undo. Runs over food *and* meal-ref entries uniformly via
      `lib/domain/meal/meal_solver_bridge.dart` (a `MealRefEntry` at scale 1.0 presents to the
      solver as "100 units" -- unit-tested in `meal_solver_bridge_test.dart`).
- [x] Save → `MealRepository`, recomputing `descendantMealIds` / `depth` / `leafCount`
- [x] Actions: أضف لليوم / أضف لجدولي / نشر في السوق (نشر shows "coming next", stubbed until
      Step 3)
- [x] **Not in the original checklist, added because it's what "never silent" requires:** editing
      a meal that's on the schedule prompts "تحديث الجدول أيضاً؟" before touching the frozen
      `ScheduleItem` snapshots.

Fixes `create_single_meal_details_controller.dart:144` by construction — the file no longer
exists, and the new controller never builds a second draft object to discard.

## 2.3 My meals — `lib/page/my_meals/`

- [x] Two tabs: **مكتبتي** (the meal library) and **جدولي** (the schedule)
- [x] Library: `GlassCard` list with staggered entry, totals, provenance badge on copies
      (`meal.isCopy`), swipe to delete (with a confirm dialog), tap to edit
- [x] Schedule: grouped by `MealSlot`, per-item day-of-week chips, an active toggle, and an
      "أضف لليوم" shortcut. **Deviation:** reordering is up/down buttons, not drag-and-drop —
      `ReorderableListView` doesn't nest per-slot inside one scroll view. See PROGRESS.md.
- [x] Editing a meal that is on the schedule prompts explicitly: **"تحديث الجدول أيضاً؟"** —
      never silent

## 2.4 Today — `lib/page/today/`

The screen that replaces the lone network GIF (`MainBody`) and the 555-line
`current_diet_screen.dart` (both deleted).

- [x] Greeting + a horizontal week strip (tap any day to jump; future days disabled)
- [x] **The hero calorie ring** — remaining kcal in the center, three macro sub-rings, an
      over-target ring in the danger hue. (Hue-shift-on-glow was folded into the Step 1 design
      polish pass on `CalorieRing` rather than redone here.)
- [x] Entries grouped by slot as `GlassCard`s. **No `BackdropFilter` in this list** —
      `test/ui/glass_card_test.dart` asserts it structurally.
- [x] Check-to-eat: strike-through animates in, opacity fade, ring re-tweens, haptic
      (`GlassCard`'s `Pressable` fires `selectionClick` on every tap automatically)
- [x] Swipe to delete, long-press → gram editor sheet (`EditEntrySheet`, replacing the
      60-line commented-out dead method)
- [x] `+` FAB → [أضف وجبة من مكتبتي / أضف مكوّناً سريعاً / أنشئ وجبة جديدة] — all one-shot
- [x] `DayRepository.ensureDay` on open: materializes from the schedule in an idempotent
      transaction, keyed on a content-fingerprint version (see the 2.4-adjacent note in
      PROGRESS.md on `scheduleVersionOf`), tested in `schedule_version_test.dart`
- [x] Real empty state with a CTA ("إضافة الآن" opens the quick-add sheet)
- [x] Totals recomputed from **one** source — `DayLog.consumedTotals`, a plain getter over
      `entries.where((e) => e.eaten)`. No second object graph exists to desync from.

## 2.5 History — `lib/page/history/`

- [x] Month calendar, each day tinted by adherence to target (one range query per month via
      `DayRepository.getRange`, not per-day reads)
- [x] Tap a day → read-only day detail (bottom sheet)
- [ ] A 7/30-day kcal trend line and macro averages — **deferred to Step 4**, per this file's own
      note below that History is "the piece to defer" if time compresses
- [ ] Optional bodyweight logging + trend — **deferred to Step 4**, same reason

**If time compresses, this is the piece to defer to Step 4. It is the least load-bearing.** —
taken up on exactly that allowance; the calendar and day detail (the load-bearing half) are done.

## 2.6 Profile — `lib/page/profile/`

- [x] Replaces `my_informations_screen.dart` (deleted). No more "معلواتي" typo.
- [x] Edit body stats → shows a **before/after diff of your targets** before saving
- [x] The old `MyCriteriaScreen` radio-toggle bug is moot — the file is deleted. Sex/activity/goal
      are `GlassChip` selection groups in the new screen, not `RadioListTile`s.
- [x] Delete account behind a **typed confirmation** (must type "حذف"). Deletes both the
      Firestore profile doc and the Firebase Auth user, so neither is left orphaned — see
      `ProfileRepository.delete`'s doc comment.

## 2.7 Deletions

- [x] `lib/page/current_diet/`, `lib/page/main_screen/`, `lib/page/my_informations/`,
      `lib/page/sign_in/`, `lib/page/loading/`, `lib/page/setting/`,
      `lib/page/single_male_screen/`, `lib/page/add_complete_meal/`, `lib/page/diet_details/`
- [x] `lib/appData.dart`, `lib/model/` (incl. `statistics.dart`), `lib/service/user_service.dart`,
      `lib/service/males_repository.dart`, `lib/service/main_repository.dart`,
      `lib/service/statistics_repository.dart`
- [x] `lib/widget/` (all 6 — `custom_background.dart` too, not just the 5 named), `lib/theme/`
      (the directory only ever held `app_colors.dart`)
- [x] The `/legacy` route and every `LegacyLtrShim` usage — removed with `main_screen.dart`, the
      screen it wrapped. `lib/ui/legacy_ltr_shim.dart` the *file* is kept; Step 4 owns deleting it
      per the plan's own phase split.
- [x] Dropped `quickalert`, `expandable`, `loading_indicator`, `faker` from `pubspec.yaml`
- [x] The ~235 `CustomText` call sites died with their screens — no separate migration pass needed
- [x] **Not in the original list, found orphaned by dependency analysis and deleted along with
      the rest:** `lib/service/create_meals_repository.dart` (only importers were three files
      already being deleted) and `lib/service/user_auth_repository.dart` (zero importers anywhere
      — fully superseded by Step 1's `AuthService`, never migrated over).

---

## Reviewable at the end

The complete personal loop, end to end:

1. Browse the food catalog, search it
2. Build a meal from components, set grams
3. **Nest a meal inside another meal**, then ungroup it and edit the leaves
4. Auto-balance to a calorie target with some components locked
5. Add it to the schedule as permanent
6. Add something else to today only as one-shot
7. **Close the app, change the device date to tomorrow, reopen** — the permanent meal is there
   and unchecked, the one-shot is gone
8. Tick items off, watch the ring fill and glow
9. Scroll back through history

All nine are implemented and internally consistent (domain math unit-tested, repositories
analyzer-clean, screens wired end to end) but **not yet walked by hand on a device** — see
Exit criteria below.

## Exit criteria

- [ ] All of the above verified manually on a device or `emulator-5554` — **not yet run**
- [x] `flutter test` green — **96 passed**, 0 failed
- [x] `flutter analyze` clean — **0 issues** across all of `lib/` (legacy files are gone, not just
      quiet)
- [x] No `BackdropFilter` inside any scrolling list — enforced structurally (`GlassCard` has none)
      and asserted in `test/ui/glass_card_test.dart`
- [x] All Step 2 screens are RTL-correct with no `LegacyLtrShim` — none of the new screens ever
      used it; `Directionality` is inherited from `MaterialApp`'s locale as it was from Step 1

## Risks

1. **The meal editor is the single largest screen in the app.** Nesting + cycle guard + ungroup
   + solver + reorder is a lot in one controller. Build the domain operations first (they are
   already unit-tested from Step 1) and keep the controller thin.
   **Resolution:** held. `MealEditorController` calls into `meal_math.dart` and
   `meal_solver_bridge.dart` for every structural rule; it holds UI state and orchestrates, and
   nothing else.
2. **Day materialization races.** Two rapid opens must not double-materialize. The transaction
   keyed on `materializedFromScheduleVersion` handles it — test it explicitly.
   **Resolution:** `scheduleVersionOf` (a content fingerprint, not a stored counter — see
   PROGRESS.md) plus `DayRepository.ensureDay`'s transaction; covered by
   `test/domain/schedule_version_test.dart`.
3. **Timezone.** `dateKey` is local-time `yyyy-MM-dd`. Crossing a timezone mid-trip can produce
   an odd day boundary. Store `tzOffsetMinutes` on the day; do not attempt to be clever.
   **Status:** as specified, from Step 1's `DayLog`. Unchanged.
4. **The big deletion.** Do it in one commit, after the replacements are verified, so reverting
   is a single step.
   **Status:** done as one pass, after `flutter analyze`/`flutter test`/`flutter build apk --debug`
   all passed on the replacements. Not yet committed to git — see PROGRESS.md.
