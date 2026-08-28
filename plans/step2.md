# Step 2 — Daily Tracking + Meal Composition

**Goal:** the complete personal loop. Build meals from components, nest a meal inside another,
schedule it, track it day by day, and look back at history.

**Status:** not started

**Depends on:** Step 1 (domain, data, design system, auth, shell)
**Blocks:** Step 3 (needs `MealDefinition` and `DayLog` final)

At the end of this step the app is genuinely usable as a personal tracker, with no marketplace.

---

## 2.1 Food catalog — `lib/page/foods/`

- [ ] `FoodCatalogScreen` — browse, search-as-you-type over `searchTokens`, category chips
- [ ] **Paginated** — `limit(30)` + `startAfterDocument`, infinite scroll.
      `males_repository.dart:11` currently does an unbounded full-collection `.get()`.
- [ ] `FoodPickerSheet` — a glass bottom sheet used by the meal editor and by quick-add
- [ ] `FoodDetailScreen` — per-100g macros, micros if present, optional price
- [ ] Debounce search input by ~250ms
- [ ] Empty / loading / error states via `AsyncView`

Kills `single_male_screen.dart:32`'s `faker.image.image()` background — a different random photo
on every build.

## 2.2 Meal editor — `lib/page/meal_editor/`

The core screen of the app. Replaces both `create_single_meal_details/` and
`add_complete_meal/`, which are near-duplicate parallel flows today.

- [ ] `MealEditorScreen` + `MealEditorController`
- [ ] Reorderable entry list backed by **`localId`, not list position**
- [ ] Per-row: name, grams, kcal, and a menu — [تعديل الوزن / فك التجميع / حذف]
- [ ] **"إضافة مكوّن"** → `FoodPickerSheet` → appends a `FoodEntry` at 100g
- [ ] **"إضافة وجبة"** → meal picker → appends a `MealRefEntry`
- [ ] **Cycle and depth guard on add.** Reject with a human-readable Arabic reason:
      - self / ancestor: "هذه الوجبة تحتوي بالفعل على هذه الوجبة"
      - depth: "تجاوزت الحد الأقصى للتداخل"
      - leaf count: "عدد المكونات تجاوز الحد"
- [ ] **Ungroup** — expands a `MealRefEntry` into its scaled leaf `FoodEntry`s in place.
      This is what makes "customize the weights of each component" work even for nested meals.
- [ ] `GramStepper` — tap to type, long-press to repeat, ±5g. Replaces the current
      `Get.defaultDialog` that calls `double.parse` on **every keystroke** (a lone `-` or `.`
      throws) and defaults its helper to `0`, so confirming without typing zeroes the component.
- [ ] Live animated totals header — kcal + P/C/F, re-tweening on every change
- [ ] **"موازنة تلقائية"** → the portion solver, with a preview diff (old grams → new grams),
      per-entry lock toggles, and undo
- [ ] Save → `MealRepository`, recomputing `descendantMealIds` / `depth` / `leafCount`
- [ ] Actions: أضف لليوم / أضف لجدولي / نشر في السوق (publish is stubbed until Step 3)

Fixes `create_single_meal_details_controller.dart:144` by construction — that code builds a new
model `ddd` and then passes the *original* to the repository, silently discarding every edit.

## 2.3 My meals — `lib/page/my_meals/`

- [ ] Two tabs: **مكتبتي** (the meal library) and **جدولي** (the schedule)
- [ ] Library: `GlassCard` grid/list with staggered entry, totals, provenance badge on copies,
      swipe to delete, tap to edit
- [ ] Schedule: grouped by `MealSlot`, reorderable, per-item day-of-week chips, an active
      toggle, and an "أضف لليوم" shortcut
- [ ] Editing a meal that is on the schedule prompts explicitly: **"تحديث الجدول أيضاً؟"** —
      never silent

## 2.4 Today — `lib/page/today/`

The screen that replaces the lone network GIF (`MainBody`) and the 555-line
`current_diet_screen.dart`.

- [ ] Greeting + date chip + a horizontal week strip (tap any day to jump)
- [ ] **The hero calorie ring** — remaining kcal in the center, three macro sub-rings, glow that
      shifts hue when over target. Replaces the two static number cards that are currently the
      *only* progress feedback, distinguished from each other by nothing but opacity.
- [ ] Entries grouped by slot as `GlassCard`s. **No `BackdropFilter` in this list.**
- [ ] Check-to-eat: strike + fade + ring re-tween + `HapticFeedback.selectionClick()`
- [ ] Swipe to delete, long-press → gram editor sheet.
      *(Long-press currently calls a method that is 60 lines of fully commented-out code and
      silently does nothing — `current_diet_controller.dart:96-157`.)*
- [ ] `+` FAB → [أضف وجبة من مكتبتي / أضف مكوّناً سريعاً / أنشئ وجبة جديدة] — all one-shot
- [ ] `DayService.ensureDay` on open: materialize from the schedule in an idempotent transaction
- [ ] Real empty state with a CTA
- [ ] Totals recomputed from **one** source. The current controller reads eaten flags from
      `appData.getUserModel().myDietMales` but macros from its own `compeletMealsModel` — two
      object graphs indexed positionally, which can and do desync. It also never calls
      `_reCalculatTheWholeCalories()` in `onInit`, so totals show 0 on first open.

## 2.5 History — `lib/page/history/`

- [ ] Month calendar, each day tinted by adherence to target
- [ ] Tap a day → read-only day detail
- [ ] A 7/30-day kcal trend line and macro averages
- [ ] Optional bodyweight logging + trend (`users/{uid}/bodyWeights`)

**If time compresses, this is the piece to defer to Step 4.** It is the least load-bearing.

## 2.6 Profile — `lib/page/profile/`

- [ ] Replaces `my_informations_screen.dart`. Fixes the AppBar typo **"معلواتي"**.
- [ ] Edit body stats → shows a **before/after diff of your targets** before saving
- [ ] `MyCriteriaScreen`'s two `RadioListTile`s are rewritten. They currently hardcode
      `groupValue: true` with an argument-ignoring `onChanged` — abused as toggles, so a
      straight deprecation migration would not work. They become a proper segmented control.
- [ ] Delete account behind a **typed confirmation**. There is currently no confirmation at all,
      and it orphans the `"myDiet"` key.

## 2.7 Deletions

Once the above are live:

- [ ] `lib/page/current_diet/`, `lib/page/main_screen/`, `lib/page/my_informations/`,
      `lib/page/sign_in/`, `lib/page/loading/`, `lib/page/setting/`,
      `lib/page/single_male_screen/`, `lib/page/add_complete_meal/`,
      `lib/page/diet_details/` *(the cost screen — dropped per the locked decision; half of it
      is a hardcoded `"250"` / `"الوجبة الاولى"` mockup)*
- [ ] `lib/appData.dart`, `lib/model/`, `lib/service/user_service.dart`,
      `lib/service/males_repository.dart`, `lib/service/main_repository.dart`,
      `lib/service/statistics_repository.dart`, `lib/model/statistics.dart`
- [ ] `lib/widget/` (all 5), `lib/theme/app_colors.dart`
- [ ] `lib/ui/legacy_ltr_shim.dart` usage for every screen deleted here
- [ ] Drop `quickalert`, `expandable`, `loading_indicator`, `faker` from `pubspec.yaml`
- [ ] The ~235 `CustomText` call sites die with their screens — no separate migration pass

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

## Exit criteria

- [ ] All of the above verified manually on `emulator-5554`
- [ ] `flutter test` green
- [ ] `flutter analyze` clean — legacy warnings are gone because the legacy files are gone
- [ ] No `BackdropFilter` inside any scrolling list (the debug assert stays silent)
- [ ] All Step 2 screens are RTL-correct with no `LegacyLtrShim`

## Risks

1. **The meal editor is the single largest screen in the app.** Nesting + cycle guard + ungroup
   + solver + reorder is a lot in one controller. Build the domain operations first (they are
   already unit-tested from Step 1) and keep the controller thin.
2. **Day materialization races.** Two rapid opens must not double-materialize. The transaction
   keyed on `materializedFromScheduleVersion` handles it — test it explicitly.
3. **Timezone.** `dateKey` is local-time `yyyy-MM-dd`. Crossing a timezone mid-trip can produce
   an odd day boundary. Store `tzOffsetMinutes` on the day; do not attempt to be clever.
4. **The big deletion.** Do it in one commit, after the replacements are verified, so reverting
   is a single step.
