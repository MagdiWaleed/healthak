# PROGRESS — handoff

**Last updated:** 2026-08-28
**Current position:** Step 0 code complete. Step 1 not started.

Read this first, then `general.md`, then the `stepN.md` for whatever step is current.
If you are a fresh agent picking this up: **everything you need is in this directory.** Do not
re-derive the architecture — it is already decided and written down in `general.md`.

---

## TL;DR for whoever picks this up next

Step 0 (housekeeping) is done in code and verified: builds, installs, runs, Firebase initializes.
Two Step 0 items are **blocked on user credentials** and cannot be done by an agent (see
"Blocked" below).

**The next thing to build is Step 1**, and specifically it should start with
`lib/domain/**` + `test/domain/**`, because that layer is pure Dart with no Flutter dependency
and everything else is built on it.

Step 1 does **not** need the blocked items to begin. Only Step 2 does.

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

## Blocked — needs the user, not an agent

Both require interactive credentials. **Neither blocks Step 1.** Both block Step 2.

### 1. Deploy rules and indexes

The Firebase CLI is not installed globally on this machine, but Node v24 is, so use `npx`.
`login` opens a browser and must be run by the user:

```
npx firebase-tools login
npx firebase-tools use diet-app-a908a
npx firebase-tools deploy --only firestore:rules,firestore:indexes
```

Indexes take a few minutes to build. Step 3's marketplace browse queries will fail with a
console link until they finish.

### 2. Run the food catalog migration

Needs a service account key: Firebase console → Project settings → Service accounts →
Generate new private key. Save it **outside the repo**, then:

```
npm install firebase-admin
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccountKey.json
node tool/migrate_foods.js            # dry run first, always
node tool/migrate_foods.js --commit
```

`single_male` is never modified — it is the rollback. Full instructions in `tool/README.md`.

**Step 2 has nothing to build meals from until this runs.** It is the single highest-priority
unblock.

---

## Next: Step 1

Read `step1.md`. Suggested order — it is roughly a strict dependency chain:

1. **`lib/domain/**` first.** Pure Dart, zero Flutter imports. If a file there needs
   `package:flutter`, something is in the wrong layer.
2. **`test/domain/**` alongside it**, not after. ~30 tests, the first in this repo.
   `flutter test` green is a hard gate on the step.
3. `lib/data/**` — typed repositories via `withConverter<T>`
4. `lib/service/**` — `PrefsService` (owns the clean break), `AuthService`, `SessionController`
5. `lib/ui/**` — theme, then glass, then background, then motion, then components
6. `lib/app/**` — routes and bindings
7. Screens: splash → onboarding → home shell → `/dev/gallery`

### Non-obvious things that will bite you

- **`lib/appData.dart` must NOT be deleted in Step 1.** Legacy screens still read it. It dies in
  Step 2. Same for `lib/theme/`, `lib/widget/`, and every legacy screen.
- **`LegacyLtrShim` must land in the same commit as the localization delegates.** Adding
  `GlobalWidgetsLocalizations` flips `Directionality` to RTL app-wide, and every legacy screen
  was hand-tuned for LTR. Without the shim, the whole old app mirrors and breaks at once.
  `Positioned(left:/right:)` in particular does **not** flip — only `PositionedDirectional` does.
- **Measure `BackdropFilter` performance in Step 1, not Step 4.** Profile mode, real mid-range
  Android, DevTools raster timeline. If the aurora plus two blurs already janks, the visual
  direction needs re-scoping — vastly cheaper to learn now than in week six.
- **Verify `BackdropFilter.grouped` / `BackdropGroup` actually exist on Flutter 3.41** before
  relying on them. Fall back to two independent blurs if not.
- The single hard rule of the design system: **zero `BackdropFilter` inside any scrolling
  viewport.** List cards use `GlassCard`, which is deliberately fake glass (tint + border +
  specular highlight, no filter). `GlassSurface` carries a debug-only live-instance counter that
  asserts above 2 — do not remove it.

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
