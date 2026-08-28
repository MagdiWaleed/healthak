# PROGRESS — handoff

**Last updated:** 2026-08-28
**Current position:** Step 0 COMPLETE. Step 1 implementation COMPLETE and emulator-verified.
One release gate remains: profile-mode raster profiling on a real mid-range Android device.

**Side Plan 1:** the first-launch guest preview is complete. It is local and read-only; see
`sideplan1_guest_mode.md`.

Read this first, then `general.md`, then the `stepN.md` for whatever step is current.
If you are a fresh agent picking this up: **everything you need is in this directory.** Do not
re-derive the architecture — it is already decided and written down in `general.md`.

---

## TL;DR for whoever picks this up next

**Step 0 is complete and verified.** Rules deployed, `foods` collection migrated and populated,
app builds and runs.

**Step 1 code is complete.** Domain, typed data repositories, services, the glass design system,
auth/onboarding, routes, shell, gallery, and guest mode are implemented. **82 tests pass** and
focused analysis is clean. Debug and profile APKs build, and emulator relaunch reaches `/home`
without Firestore permission or Flutter runtime errors.

**Do this next:** run the profile APK on a real mid-range Android and record the DevTools raster
p95. Step 1 requires p95 under budget and no more than two live blur surfaces. After that gate,
commit Step 1 and begin Step 2.

Do **not** re-derive the architecture. It is decided and written down in `general.md`.


---

## Done

### Earlier in the session (before the overhaul plan existed)

These were fixes to get the app building at all. Do not undo them.

- Gradle wrapper 7.5 → **8.12** (the Flutter Gradle plugin fails to compile below 8.3 —
  `Unresolved reference: filePermissions`)
- Android Gradle Plugin 7.3.0 → **8.7.3**, Kotlin 1.7.10 → **2.1.0**, Java/`jvmTarget` 8 → **17**
- `compileSdkVersion`/`minSdkVersion`/`targetSdkVersion` → `compileSdk`/`minSdk`/`targetSdk`
- `tflite_flutter` 0.10.4 → 0.12.1 (0.10.4 used `UnmodifiableUint8ListView`, removed in Dart 3.4).
  *Since removed entirely in Step 0.*
- Applied `com.google.gms.google-services` 4.4.2. **This matters:** without it, native Firebase
  init fails with `Default FirebaseApp failed to initialize because no default options were
  found` and only the Dart-side init works.
- `google_sign_in` was added and then **removed at the user's explicit request.**
  **Do not reintroduce it.**

### Step 0 — housekeeping

| Item | File | Note |
|---|---|---|
| Deps restructured | `pubspec.yaml` | `build_runner` → dev_deps; `build_web_compilers` deleted (no `build.yaml` exists, and Flutter web doesn't use it); added `flutter_localizations`, `intl ^0.20.2`, `uuid`, `collection` |
| `tflite_flutter` removed | `pubspec.yaml` | see below |
| All 8 Cairo weights registered | `pubspec.yaml` | was only 2 of 8, so w500/w600 were being synthesized |
| Assets block fixed | `pubspec.yaml` | the bare `- asset/` entry matched **zero** files — Flutter's directory-asset syntax is non-recursive and `asset/` holds only subdirs. Now `- asset/image/` |
| `lib/logic/auto_calculate.dart` deleted | — | TFLite solver: hardcoded to exactly 3 components, index bugs in `swap_indexes`, shallow-copied its caller's list and mutated it, compared against the wrong target |
| `asset/model/` deleted | — | the `.tflite` file and its awkward space-and-parens filename |
| TFLite caller replaced | `complete_male_controller.dart:87` | interim proportional-scale solver, ~15 lines. Actually *more* correct than the model was. Real solver with locks lands in Step 2 |
| Security rules written | `firestore.rules` | full new schema; see "the copyCount rule" below |
| Indexes written | `firestore.indexes.json` | 4 on `marketMeals`, 2 on `foods` |
| `firebase.json` written | — | points at both |
| Migration script written | `tool/migrate_foods.js` | **Node, not Dart** — see deviation below |
| Tool docs | `tool/README.md` | how to get a service account key and run it |
| Lints tightened | `analysis_options.yaml` | `avoid_print`, `use_super_parameters`, `prefer_const_constructors`, `unawaited_futures`, etc. Legacy noise downgraded to `info` so it doesn't drown out real problems |
| Baseline captured | `plans/analyze-baseline.txt` | **584 issues: 0 errors, 66 warnings, 518 info** — all in legacy files. This is the migration checklist |

**Verified:** `flutter pub get` resolves, `flutter build apk --debug` succeeds, app installs and
launches on `emulator-5554`, logcat shows `FirebaseInitProvider: FirebaseApp initialization
successful` with no crash.

---

## Previously blocked -- both now DONE

### Rules and indexes: deployed

The user deployed via `npx firebase-tools`. Verified live by REST: an unauthenticated read of
`appConfig` returns **200** (this ruleset makes it public) while `foods` returns **403**. That
combination is only true of the new ruleset, so it is definitely the one that is live.

### Food catalog: migrated

`node tool/migrate_foods.js --commit` ran successfully. **8 foods** written, 0 skipped, no
all-zero-macro warnings. `single_male` left intact at 8 docs as the rollback.

Verified doc shape: `per100:{protein,carbs,fat}`, `kcalPer100`, `searchTokens`, `active`,
`nameNormalized`, server timestamps.

Credentials setup, for any future run:

- `.env` (gitignored) holds `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_PROJECT_ID`.
  It stores only the **path** to the key, never the key itself.
- `.env.example` is committed as the template.
- `.gitignore` also blocks `node_modules/`, `*serviceAccount*.json`, and
  `*-firebase-adminsdk-*.json` defensively.
- `tool/migrate_foods.js` reads `.env` itself -- nothing needs exporting by hand.
- `package.json` at the repo root is **tooling only**. It is not part of the Flutter build.
- The service account key lives at `Documents/GitHub/`, i.e. outside the repo. Confirmed by
  `git check-ignore`, which reports it as outside the repository entirely.

> **Flag for the user:** the catalog has only **8 components**. That is thin for building meals
> from. Step 2's catalog screen will work, but the app will feel empty. Worth seeding more foods,
> or pulling the "add a custom food" screen earlier than planned.


---

## Step 1 -- what is done

### Domain layer: COMPLETE, `flutter analyze` clean, **72 domain tests green**

Pure Dart, zero Flutter imports, as designed.

| File | Contents |
|---|---|
| `lib/domain/nutrition/macros.dart` | `Macros` value type. `+ - *`, `forGrams`, derived `kcal`, tolerant `fromJson` (Firestore returns int/double/String interchangeably) |
| `lib/domain/nutrition/energy.dart` | `Sex`, `ActivityLevel`, `Goal`, `TargetMode`; Mifflin-St Jeor BMR, TDEE, `dailyTarget`, `macroSplit`, `NutritionTargets` |
| `lib/domain/nutrition/portion_solver.dart` | `solveProportional` (default, with locks) and `solveForMacros` (projected gradient descent). Replaces TFLite |
| `lib/domain/food/food_item.dart` | Immutable catalog entity. No grams, no eaten flag |
| `lib/domain/meal/meal_entry.dart` | **sealed** `MealEntry` = `FoodEntry` \| `MealRefEntry`. Constants `kMaxNestDepth=3`, `kMaxLeafCount=60`, `kGramRounding=5` |
| `lib/domain/meal/meal_definition.dart` | `MealDefinition`, `MealOrigin`, `MealSource` |
| `lib/domain/meal/meal_math.dart` | `macrosOfMeal`, `depthOfMeal`, `descendantMealIdsOf`, `canNest`, `flattenMeal`, `ungroupEntry`, `renumber`, `withRecomputedCaches`; `MealResolver`; `MealDepthExceeded` / `MealCycleException` / `MealNotFound` |
| `lib/domain/day/day_log.dart` | `DayLog`, `DayEntry`, `FrozenItem`, `MealSlot`, `DayEntryOrigin` |
| `lib/domain/schedule/schedule_item.dart` | `ScheduleItem` with a frozen snapshot and `daysOfWeek` |
| `lib/domain/market/market_meal.dart` | `MarketMeal`, `MarketMealGroup`, and the `flatten` helper that builds group spans |

Tests: `test/domain/energy_test.dart` (27), `test/domain/meal_math_test.dart` (30),
`test/domain/macros_test.dart` (7), `test/domain/portion_solver_test.dart` (8).

### Typed food catalog slice: COMPLETE, `flutter analyze lib/data test/data` clean

| File | Contents |
|---|---|
| `lib/data/async_value.dart` | Exhaustive `Loading`, `Data`, and `Error` state for controllers and UI. |
| `lib/data/mappers/food_mapper.dart` | The sole `FoodItem` Firestore boundary; derives kcal from macros instead of trusting the denormalized field. |
| `lib/data/firestore_refs.dart` | Typed `foods` collection using `withConverter<FoodItem>`. |
| `lib/data/repositories/food_repository.dart` | Read-only id/watch and 30-item cursor pagination with category and migration-compatible Arabic token search. |

Tests: `test/data/food_mapper_test.dart` (2), `test/data/food_repository_test.dart` (2).

The new solver tests found a real defect in `solveForMacros`: its fixed gram learning rate made
the projected-gradient solver effectively immobile. It now uses a damped, curvature-normalized
step, which converges for reachable macro targets while retaining the non-negative and per-item
bounds constraints.

**The tests found two real bugs in `macroSplit` before any UI existed** -- exactly what they are
for. The 40% per-macro share cap was overriding the 1.6 g/kg protein floor, which meant a heavy
user on a low target got their protein cut below the safe minimum. Resolution: **the floors win
over the share caps**, because preserving lean mass beats an arbitrary percentage limit. The
share-cap test now asserts the cap only where the floor leaves room for it. `wasAdjusted` also
now reports share-cap compromises, not just waterfall ones.

### Step 1 -- implementation and automated verification complete

- Typed mappers/repositories cover profiles, meals, days, schedules, foods, and the marketplace
  stub. No raw Firestore maps escape mapper boundaries.
- Auth, prefs/session/settings, and the 90-frame performance probe are wired at startup.
- The dark metabolic-aurora design system, bounded glass, motion, reusable components, named
  routes/bindings, splash, real auth/onboarding, four-tab shell, gallery, legacy route, and the
  read-only guest path are live.
- `flutter test`: **82 passed**. Focused analyzer: **0 issues**. Debug and profile APKs build.
- Emulator install, force-stop, and relaunch return to `/home`; logcat has no permission-denied,
  Firebase, Flutter, or fatal exceptions. Firestore contains a completed schema-v2 profile with
  computed targets.
- **Only remaining gate:** DevTools raster p95 on a real mid-range Android. The emulator cannot
  substitute for the real-device requirement in the approved plan.

### Design polish pass (post Step-1 handoff)

The first Step 1 pass shipped structurally correct but visually inert: one shared aurora
controller instead of four independent ones, `GlassCard`/`GlassSurface` missing the specular
highlight the design spec calls for, the calorie ring's sweep gradient rotated 90° off its own
arc start, grain painted as 750 `drawCircle` calls per frame instead of the tiled `ImageShader`
the deviations table above already specifies, and a stock `CircularProgressIndicator` on the
splash screen. Rewritten, `flutter analyze` clean, all 83 tests green (`test/page/home_shell_test.dart`
updated for the FAB no longer being a `FloatingActionButton`):

- `lib/ui/background/aurora_background.dart` — four blobs, independent periods (19/23/29/31s),
  each on its own phase/amplitude so the field drifts in a figure-eight rather than pulsing in
  lockstep; added breathing radius, alpha shift, and a corner vignette. Content moved out of the
  painter's `AnimatedBuilder` and into a sibling in the `Stack` so it stops repainting every frame.
- `lib/ui/background/grain_texture.dart` — now bakes a seeded `ui.Image` once and tiles it via
  `ImageShader` + `BlendMode.softLight`, matching the deviation already recorded above; the old
  version repainted 750 circles per frame, above the text.
- `lib/ui/glass/glass_decoration.dart` — new shared file: body tint gradient, the specular sheen
  (was speced, never implemented), and a `GlassEdgePainter` for a lit edge instead of a flat
  `Border.all`. Used by both `GlassCard` and `GlassSurface`.
- `lib/ui/components/calorie_ring.dart` — sweep gradient now rotated to start at 12 o'clock to
  match the arc; kcal count-up and arc progress read from the same tween so they can't disagree;
  added a bright head dot on the arc tip, a bloom built from wide low-alpha passes instead of a
  per-frame `MaskFilter.blur`, and an over-target ring in the danger hue.
- `lib/ui/motion/pressable.dart` — one `AnimationController` with asymmetric press/release curves
  (fast bite, `easeOutBack` release) replacing three-widget-deep implicit animations.
- `lib/ui/motion/staggered_entry.dart` — one controller drives fade/slide/scale together; gated by
  an `enabled` flag so `ListView.builder` recycling can't replay the entrance on scroll-back (the
  old version had no such gate).
- `lib/page/splash/splash_screen.dart` — replaced the static icon + stock spinner with an
  entrance-animated mark and a swept-gradient arc built from the same painter vocabulary as
  `CalorieRing`, so the first frame already looks like this app.
- `lib/page/home/home_shell.dart` — FAB is now a custom glowing circle (`Pressable`, not
  `FloatingActionButton` — tests locate it via the new `HomeShellKeys.quickAddFab`), tab switches
  cross-fade/slide via `AnimatedSwitcher`, and the nav bar grew a selected-pill indicator with an
  icon swap (outline → filled) and an appearing label.

Not yet touched: `lib/page/onboarding/**`, `lib/page/guest/**`, `lib/page/dev/gallery_screen.dart`
still use the pre-polish primitives only insofar as they render correctly against the new
`GlassCard`/`Pressable` signatures (verified — `flutter analyze` and `flutter test` both clean) but
have not themselves been redesigned. Worth a pass before Step 2 screens build on top of them.

---

## Deviations from the approved plan so far

| Plan said | What was done | Why |
|---|---|---|
| `tool/migrate_foods.dart` | `tool/migrate_foods.js` (Node + `firebase-admin`) | The Admin SDK bypasses security rules, so `foods` stays client-read-only and no weakened ruleset ever gets deployed. A Dart script would have needed a Flutter runtime *and* a temporary permissive rule. |
| Generate `asset/image/noise.png` | Deferred to Step 1 as `lib/ui/background/grain_texture.dart` | Procedural generation — a seeded `Random` painted once into a `ui.Image` and tiled via `ImageShader`. No binary asset in git, tunable at runtime, one-time cost. |
| TFLite caller "stubbed out" | Replaced with a working proportional-scale solver | ~15 lines, and strictly better than the broken model. Keeps the legacy screen functional until Step 2 deletes it. |
| `intl: ^0.19.0` | `intl: ^0.20.2` | `flutter_localizations` from the SDK pins `intl` to 0.20.2; 0.19.0 failed version solving. |

---

## Decisions already locked — do not relitigate

Full detail in `general.md` §2. Summary:

- **Clean break on local data.** Wipe SharedPreferences on first launch (`schemaVersion < 2`).
  No migration code ships in the app.
- **Real Firebase Auth**, uid as the identity, profile in `users/{uid}`.
  Signup takes **email + password + display name**.
- **Full daily log + history.** `days/{yyyy-MM-dd}`, flattened and frozen at insert time.
- **Marketplace uses copy-on-add**, never a live reference.
- **`male` → `meal`** rename throughout ("male" is a misspelling of "meal" in the old code).
- **TFLite deleted**, replaced by a deterministic portion solver.
- **`diet_details_screen.dart` (the cost page) is dropped.**
- Dark theme only until Step 4. Western digits by default. Hand-rolled motion primitives.
- **`google_sign_in` stays out.**

## Still undecided

- **The AI assistant.** See `step5.md`. Not specified at all yet. Nothing in Steps 0–4 depends
  on it. Do not write code for it.
- Moderation for the marketplace (a client-side mute list is the Step 3 stopgap).
- Whether to rename the package from `com.example.diet_app2` — it would break the existing
  Firebase Android app registration and need a fresh `google-services.json`. Ask first.

---

## Environment

- Flutter 3.41.2 / Dart 3.11, Windows 11
- Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0, Java 17, minSdk 26, multidex
- Firebase project **`diet-app-a908a`**, Android package `com.example.diet_app2`
- Emulator: `emulator-5554` (Android 17 / API 37)
- `adb` is not on PATH — it lives at
  `~/AppData/Local/Android/sdk/platform-tools/adb.exe`
- Node v24.13.0 available; Firebase CLI is **not** installed globally (use `npx firebase-tools`)

## Useful commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554
```
