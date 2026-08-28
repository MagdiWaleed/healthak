# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

`diet_app2` (repo name `healthak`) — a Flutter diet/nutrition tracker with an
Arabic (RTL) UI. The user enters their body stats and goal, browses a shared
catalog of food components and meals stored in Firestore, assembles a daily
diet, and ticks items off as they eat them. A bundled TFLite model solves
component weights so a 3-component meal lands on a calorie target.

Locale is hard-coded to `ar` in `lib/main.dart`. All user-facing strings are
Arabic literals written inline in the widgets — there is no localization file.
New UI strings follow the same pattern.

## Commands

```bash
flutter pub get
flutter run                       # attached device/emulator
flutter build apk --debug
flutter analyze
```

There are no tests in the repo. `test/` does not exist; don't claim test
coverage that isn't there.

## Naming: "male" means "meal"

The codebase consistently misspells *meal* as *male*. This is not a domain
concept — there is nothing gendered here. It shows up in class names, file
names, Firestore collection names, and SharedPreferences keys:

- `SingleMaleModel` — a single food **component** (chicken, rice, oil)
- `CompleteMaleModel` — a **meal** built from several components
- `single_male` — Firestore collection of components
- `myDietMales`, `MalesRepository`, `my_males_current_diet/`

Keep the existing spelling when touching existing identifiers or Firestore
keys — renaming breaks stored JSON and live documents. Do not propagate it into
genuinely new, self-contained code.

Other recurring misspellings that are load-bearing (persisted or in Firestore):
`carps` (carbs), `protien`/`protein` used inconsistently, `compeletMeals`.

## Architecture

### State management: GetX, per-page controller

Every page is `lib/page/<name>/<name>_screen.dart` plus
`<name>_controller.dart`. Screens are usually `StatelessWidget` wrapping a
`GetBuilder<XController>` and calling `controller.update()` to repaint.
Controllers extend `GetxController`; repositories *also* extend `GetxController`
purely so they can be pulled in with `Get.put(...)`.

Navigation is `Get.to` / `Get.off` / `Get.offAll` with widget instances, not
named routes.

### Global mutable state: `lib/appData.dart`

`appData` is a class of static fields — the current `UserModel`, the bottom-nav
page index, and the main-screen GIF URL. It is the de-facto app singleton;
controllers read and write it directly via `appData.getUserModel()` /
`appData.setUserModel(m)`. `UserModel` is mutable, so `getUserModel()` returns a
live reference — mutating it mutates the global.

### Two independent persistence layers

**SharedPreferences is the source of truth for the signed-in user.**

| Key | Contents |
|---|---|
| `user` | JSON of `UserModel` (`UserModel.ConvertToJson`) |
| `myDiet` | `List<String>`, each a JSON `CompleteMaleModel` |

`lib/service/user_service.dart` owns all `myDiet` reads/writes.
`LoadingController` (`lib/page/loading/loading_controller.dart`) is the boot
gate: if `user` exists it rebuilds `UserModel` and goes to `MainScreen`,
otherwise it goes to `SignInScreen`.

**Firestore holds shared, read-mostly catalog data** (`lib/service/*_repository.dart`):

| Collection | Model | Used by |
|---|---|---|
| `single_male` | `SingleMaleModel` | `MalesRepository` |
| `complete_meals` | `CreateMealsModel` | `CreateMealsRepository` |
| `data` (doc with `id == "mainScreenGif"`) | `Gif` | `MainRepository` |
| `<n>_component_stat` | `Statistics` | `StatisticsRepository` (collection name is built from component count) |

### Auth is decoupled from the app's own user

This is the biggest thing to understand before touching sign-in.

`lib/service/user_auth_repository.dart` wraps Firebase Auth (email/password
only). But the sign-up flow in `lib/page/sign_in/sign_in_controller.dart`
builds a `UserModel` and writes it to SharedPreferences **without requiring a
Firebase session** — `createNewUserRepository()` exists but is not wired into
the main "save" path (`onCreateAccountSave`), and the commented-out call is
still in `sign_in_screen.dart`. `UserModel.id` is literally the string
`"new account"` for locally-created users, and `UserModel.password` is stored in
plaintext in SharedPreferences.

Consequence: `CreateMealsRepository.getMyMeals()` filters on
`appData.getUserModel().id`, which is `"new account"` for anyone who signed up
locally. Firestore ownership and local identity are not actually linked yet.

There is no Google / social sign-in. It was added and then removed on request,
so `google_sign_in` is not a dependency — don't reintroduce it without asking.

## Nutrition math

`SingleMaleModel` stores macros **per 100 g**. `getProtein()`, `getCarps()`,
`getFats()` scale by `weight / 100`; `getCalories()` is `4/4/9`. Changing
`weight` re-derives everything, so `CompleteMaleModel.setNewWeight` recomputes
its totals from scratch rather than patching them.

`UserModel.calculateCalories()` sets `caloriesNeeds = dailyActive` directly and
`caloriesGoal = caloriesNeeds ± 500` (bulk/cut). Note the mismatch: the sign-up
UI tells the user `dailyActive` is an activity **factor** between 1.2 and 1.9,
but the model treats it as an absolute calorie count. Pre-existing; don't
"fix" it silently, as stored `user` JSON depends on the current meaning.

## TFLite auto-calculation

`lib/logic/auto_calculate.dart` loads
`asset/model/converted_model (1).tflite` (note: `asset/`, singular, and the
space and parentheses in the filename are real and referenced in
`pubspec.yaml`).

`weight_for__3Component` only handles exactly **3** components. It sorts meals
by name, flattens `[protein, carbs, fat] × 3 + targetCalories` into a 13-feature
vector, generates permutations via `swap_indexes`, runs a `[6,3]` output tensor,
and picks the row whose total calories is closest to the goal.

## Android build

The toolchain was upgraded to work with Flutter 3.41 / Dart 3.11. Do not
downgrade these — the Flutter Gradle plugin itself fails to compile below them
(`Unresolved reference: filePermissions` needs Gradle 8.3+).

- Gradle wrapper **8.12**
- Android Gradle Plugin **8.7.3**
- Kotlin **2.1.0**
- Java / `jvmTarget` **17**
- `minSdk` 26, multidex enabled
- `com.google.gms.google-services` **4.4.2** applied in `android/app/build.gradle`

Firebase initializes twice over: natively from
`android/app/google-services.json` and from Dart via
`DefaultFirebaseOptions.currentPlatform` in `lib/firebase_options.dart`. Both
must stay in sync (project `diet-app-a908a`, package `com.example.diet_app2`).

The google-services plugin is what makes native Firebase init succeed. Without
it the app logs `Default FirebaseApp failed to initialize because no default
options were found` and only the Dart-side init works.

## Conventions and known rough edges

- Shared widgets live in `lib/widget/` and are prefixed `Custom*`
  (`CustomText`, `CustomTextField`, `CustomBackground`, ...). `CustomText`
  defaults to white, size 14, font family `Cairo`.
- Colors come from `lib/theme/app_colors.dart` (`AppColors.buttonColor`,
  `.loading`, `.doneColor`). Don't hard-code colors in new widgets.
- The project still uses `MaterialStatePropertyAll` everywhere. It is
  deprecated in favour of `WidgetStatePropertyAll`, but is used consistently —
  match the surrounding file rather than mixing both.
- `flutter analyze` is noisy with pre-existing deprecation and `prefer_const`
  warnings. Judge new code by whether it *adds* problems, not by a clean run.
- `print()` is used for logging throughout; there is no logging framework.
- There are two unrelated `sign_in_controller.dart` files:
  `lib/page/sign_in/` (the real one) and
  `lib/page/my_informations/sing_in_details/` (note "sing"). Check the path.
