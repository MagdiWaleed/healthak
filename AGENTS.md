# AGENTS.md

Guidance for any coding agent working in this repository.

> ## READ THIS FIRST
>
> **This repo is mid-rewrite.** A full overhaul is underway and the plan is committed:
>
> 1. **`plans/PROGRESS.md`** — where work stopped, what is done, what to do next. **Start here.**
> 2. **`plans/general.md`** — architecture, domain model, Firestore schema, design system.
> 3. **`plans/stepN.md`** — the phase you are working on.
>
> The architecture is **already decided**. Do not re-derive it, and do not redesign the data
> model. If something in the plan looks wrong, say so — do not silently deviate.
>
> Two codebases currently coexist in `lib/`. See "The two codebases" below before editing
> anything.

## What this is

`diet_app2` (repo name `healthak`) — a Flutter calorie tracker with an Arabic (RTL) UI.

**Target:** the user enters body stats and a goal, browses a shared catalog of food components,
composes meals (including nesting a meal inside another meal as a component), schedules them as
permanent or adds them one-shot to a single day, ticks items off as they eat, and publishes
meals to a marketplace others can copy and re-weight.

Locale is `ar`. All user-facing strings are Arabic. New strings go in `lib/l10n/app_strings.dart`
(from Step 1 onward); legacy screens still have them inline.

## Commands

```bash
flutter pub get
flutter analyze
flutter test                      # domain tests only so far
flutter build apk --debug
flutter run -d emulator-5554
```

`adb` is not on PATH: `~/AppData/Local/Android/sdk/platform-tools/adb.exe`

Tooling scripts (Node, not part of the Flutter build):

```bash
node tool/migrate_foods.js        # dry run
node tool/migrate_foods.js --commit
npx firebase-tools deploy --only firestore:rules,firestore:indexes
```

## The two codebases

`lib/` currently holds **new code** and **legacy code** side by side. They do not share types.

### New — build here

| Path | State |
|---|---|
| `lib/domain/**` | **Done.** Pure Dart, zero Flutter imports, 57 tests green |
| `lib/data/**` | Not started |
| `lib/service/**` | Not started (except the legacy `user_service.dart`) |
| `lib/ui/**` | Not started |
| `lib/app/**` | Not started |
| `test/domain/**` | Partial — solver and macros still uncovered |

**`lib/domain/` must never import `package:flutter`.** That is what keeps it unit-testable and
reusable by anything else later. If you need a `Color` or a `DateFormat` there, the logic belongs
in a layer above.

### Legacy — do not invest in

Everything else under `lib/page/`, `lib/model/`, `lib/widget/`, `lib/theme/`, `lib/appData.dart`,
`lib/service/*_repository.dart`, `lib/service/user_service.dart`.

These are **scheduled for deletion in Step 2**. Do not refactor them, do not fix their lints, do
not migrate them to the new types. Keep them compiling so the app still runs, nothing more.

`plans/analyze-baseline.txt` lists every warning in them — that is the deletion checklist, not a
to-do list.

## Naming

The legacy code misspells *meal* as *male* — `SingleMaleModel`, `CompleteMaleModel`,
`myDietMales`, `MalesRepository`. There is nothing gendered here; it is a typo that spread.

**New code uses correct English.** The mapping is in `plans/general.md` §3:

| Legacy | New |
|---|---|
| `SingleMaleModel` | `FoodItem` (catalog) + `FoodEntry` (a portion) |
| `CompleteMaleModel` | `MealDefinition` |
| `CreateMealsModel` | `MarketMeal` |
| `carps` / `carp` | `carbs` |
| `calories` | `kcal` |
| `weight` (of a portion) | `grams` |

Never propagate `male` into new code. Never rename it inside legacy code either — those files are
being deleted, so a rename is wasted work that risks breaking a screen still in use.

**One macro vocabulary everywhere:** `protein`, `carbs`, `fat`, `kcal`, `grams`. The legacy code
had three mutually incompatible key sets for the same data, which is how values drifted between
layers.

## Architecture (new code)

Full detail in `plans/general.md`. The load-bearing decisions:

- **`Macros` is a value type; `kcal` is always derived**, never stored as truth. Denormalized
  totals exist only so Firestore can sort on them, and are commented as such.
- **`MealEntry` is a Dart 3 `sealed` class** — `FoodEntry` or `MealRefEntry`. Switches over it
  are exhaustive, so adding a third kind later is a compile error at every call site rather than
  a silent fallthrough.
- **Nesting is guarded three ways:** a precomputed `descendantMealIds` closure (O(1) check on
  add), `kMaxNestDepth = 3` / `kMaxLeafCount = 60`, and a runtime `visited` set that throws
  `MealCycleException` instead of blowing the stack.
- **Day logs are flat and frozen at insert time.** No references at all. Editing a recipe today
  must not rewrite what was eaten last Tuesday, the eat-toggle hot path must not recurse, and a
  day must cost one Firestore read. `groupLabel` preserves the *visual* nesting.
- **Eaten state resets daily by construction** — a new day is a new document, so `eaten` is false
  with no reset code to get wrong. (The legacy app persisted eaten flags forever.)
- **Marketplace is copy-on-add, never a live reference.**
- **Entries are addressed by `localId` (a uuid), never by list index.** The legacy code used
  position as identity, so a reorder silently repointed every edit.

### State (from Step 1 on)

GetX with `Rx` + `Obx` and named routes + `Binding` classes. The legacy code has zero `.obs` and
zero `Obx` — it is all `GetBuilder` + manual `update()`, with several screens constructing the
same controller twice and calling `FutureBuilder(future: controller.getData())` inside `build`.
Do not copy those patterns.

## Firestore

New collections: `foods`, `users/{uid}` (+ `/meals`, `/schedule`, `/days`, `/bodyWeights`),
`marketMeals` (+ `/likes`), `appConfig`.

Legacy and unreferenced: `single_male`, `complete_meals`, `data`, `*_component_stat`. Left in
place as a rollback. Do not read or write them.

`firestore.rules` is deployed and live. Note the deliberate rule letting any signed-in user
increment `marketMeals.copyCount` by **exactly 1** and change nothing else — that is what avoids
needing Cloud Functions, and therefore a paid Blaze plan. Do not widen it.

Every collection is accessed through `withConverter<T>` in `lib/data/firestore_refs.dart`.

## Secrets

- `.env` is gitignored and holds **paths only**, never a credential.
- The Firebase service account key lives **outside the repo**, at `Documents/GitHub/`.
- `.gitignore` also blocks `node_modules/`, `*serviceAccount*.json`, `*-firebase-adminsdk-*.json`.
- Never commit a key, and never move one into the repo.

## Android build — do not downgrade

The toolchain was upgraded to work with Flutter 3.41 / Dart 3.11. Below these versions the
Flutter Gradle plugin itself fails to compile (`Unresolved reference: filePermissions` needs
Gradle 8.3+).

- Gradle wrapper **8.12**, AGP **8.7.3**, Kotlin **2.1.0**, Java / `jvmTarget` **17**
- `minSdk` 26, multidex enabled
- `com.google.gms.google-services` **4.4.2** in `android/app/build.gradle`

Firebase initializes twice over: natively from `android/app/google-services.json` and from Dart
via `DefaultFirebaseOptions.currentPlatform`. Both must stay in sync (project `diet-app-a908a`,
package `com.example.diet_app2`).

The google-services plugin is what makes native init succeed. Without it the app logs
`Default FirebaseApp failed to initialize because no default options were found` and only the
Dart-side init works.

**`google_sign_in` was added and then removed at the user's explicit request. Do not reintroduce
it without asking.**

## Gotchas that will bite you

- **RTL.** `flutter_localizations` is now a dependency. Once the delegates are added in Step 1,
  `Directionality` flips app-wide and every legacy screen — all hand-tuned for LTR — will mirror
  and break. That is why `LegacyLtrShim` must land in the *same* commit as the delegates.
  `Positioned(left:/right:)` does **not** flip; only `PositionedDirectional` does.
- **Glass performance.** At most **2** simultaneous `BackdropFilter`s, and **zero inside any
  scrolling viewport** — list cards use `GlassCard`, which is deliberately filter-free. A
  debug-only instance counter asserts on violation; do not remove it.
- **`lib/appData.dart` cannot be deleted until Step 2.** Legacy screens still read it.
- Flutter's directory-asset syntax is **non-recursive**. A bare `- asset/` entry matches zero
  files when `asset/` contains only subdirectories.
- `flutter analyze` is noisy with legacy warnings. Judge new code by whether it *adds* problems.
  New code under `lib/domain`, `lib/data`, `lib/ui`, `lib/app` must be clean.
- There are two unrelated `sign_in_controller.dart` files: `lib/page/sign_in/` (the real one) and
  `lib/page/my_informations/sing_in_details/` (note "sing"). Check the path.
- `print()` is used throughout the legacy code. New code should not add more.

## Working style

- Update `plans/PROGRESS.md` as you go. It is the handoff between agents and sessions, and a
  stale one is worse than none.
- Record any deviation from the approved plan in the "Deviations" table there, with the reason.
- Features the user has mentioned but not specified get a stub file listing the open questions —
  see `plans/step5.md` (the AI assistant). Do not write code for an unspecified feature.
