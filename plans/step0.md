# Step 0 — Housekeeping

**Goal:** get the project configuration correct before any feature work. No visible change to
the running app.

**Status:** COMPLETE. Verified 2026-08-28.

**Depends on:** nothing. This is the entry point.
**Blocks:** everything.

---

## Why this comes first

Three things here gate later steps and are painful to retrofit:

- Font weights must be registered before `app_typography.dart` can reference w500/w600.
- `flutter_localizations` must be present before RTL can be turned on safely.
- The `foods` collection must be populated, or Step 2 has nothing to build meals from.

---

## Tasks

### 0.1 `pubspec.yaml` — dependencies

- [x] Move `build_runner` from `dependencies` to `dev_dependencies` (it is a build tool, not a
      runtime dependency)
- [x] Delete `build_web_compilers` — web-only and almost certainly unused. **Verify first:**
      confirm there is no `build.yaml` and no web build target in use.
- [x] Remove `tflite_flutter` (see §0.5)
- [x] Add `flutter_localizations: {sdk: flutter}`
- [x] Add `intl` (needed for `DateFormat('yyyy-MM-dd')` day keys)
- [x] Add `uuid` (stable `localId` on meal entries — replaces index addressing)
- [x] Add `collection` (list equality, `firstWhereOrNull`)
- [x] Keep: `firebase_core`, `firebase_auth`, `cloud_firestore`, `get`, `shared_preferences`
- [x] Review for removal in a later step: `quickalert`, `expandable`, `loading_indicator`,
      `faker` — all become dead once their screens are rebuilt. Do **not** remove yet; legacy
      screens still use them.
- [x] **Do not add `google_sign_in`.** It was added and removed at the user's request.

### 0.2 `pubspec.yaml` — fonts

- [x] Register all 8 Cairo weights. Currently only Regular (400) and Bold (700) are declared,
      so every `FontWeight.w500` / `w600` in the new type scale would be synthesized.

```yaml
  fonts:
    - family: Cairo
      fonts:
        - {asset: asset/font/Cairo-ExtraLight.ttf, weight: 200}
        - {asset: asset/font/Cairo-Light.ttf,      weight: 300}
        - {asset: asset/font/Cairo-Regular.ttf,    weight: 400}
        - {asset: asset/font/Cairo-Medium.ttf,     weight: 500}
        - {asset: asset/font/Cairo-SemiBold.ttf,   weight: 600}
        - {asset: asset/font/Cairo-Bold.ttf,       weight: 700}
        - {asset: asset/font/Cairo-ExtraBold.ttf,  weight: 800}
        - {asset: asset/font/Cairo-Black.ttf,      weight: 900}
```

- [x] Verify all 8 files exist on disk at those exact names before building

### 0.3 `pubspec.yaml` — assets

The current block is broken:

```yaml
  assets:
    - asset/                                          # matches ZERO files
    - asset/image/javier-santos-guzman-...jpg
    - asset/model/converted_model (1).tflite
```

Flutter's directory-asset syntax is **non-recursive**, and `asset/` contains only
subdirectories — so the bare `- asset/` entry bundles nothing. `asset/image/main_screen_image.jpg`
and `asset/image/neom-yg6v0KoiIcU-unsplash.jpg` are therefore not bundled at all today.

- [x] Replace with explicit directory entries:

```yaml
  assets:
    - asset/image/
```

- [x] Drop the `.tflite` entry (see §0.5)
- [x] Delete `asset/model/` once the TFLite removal is confirmed
- [x] ~~Generate `asset/image/noise.png`~~ — **decision changed.** The grain layer is generated
      procedurally in Dart instead: a seeded `Random` painted once into a `ui.Image` at startup
      and tiled via `ImageShader`. No binary asset in git, tunable at runtime, one-time cost.
      Moved to Step 1 as `lib/ui/background/grain_texture.dart`.

### 0.4 Firebase configuration files

- [x] Create `firebase.json` pointing at the rules and indexes files
- [x] Create `firestore.rules` — full content in `general.md` §7
- [x] Create `firestore.indexes.json` — index list in `general.md` §7
- [x] Deployed by the user via `npx firebase-tools`. Verified live: an unauthenticated
      REST read of `appConfig` returns **200** (the ruleset makes it public) while `foods`
      returns **403** — which is only true of the new ruleset.

**Note:** the rules deliberately allow any signed-in user to increment `marketMeals.copyCount`
by exactly 1 and change nothing else. This is what avoids needing Cloud Functions, and therefore
avoids needing a Blaze (paid) plan.

### 0.5 Remove TFLite

- [x] Delete `lib/logic/auto_calculate.dart`
- [x] Delete `asset/model/converted_model (1).tflite`
- [x] Remove `tflite_flutter` from `pubspec.yaml`
- [x] Remove the `.tflite` asset declaration
- [x] Stub out the one caller — `complete_male_controller.autoChangeWeight()` — so the legacy
      screen still compiles. It is deleted entirely in Step 2.

Rationale is in `general.md` §12. Short version: it is hardcoded to exactly 3 components, has
several genuine index bugs, mutates its caller's data through a shallow copy, and the problem it
solves has a closed form that needs no ML.

### 0.6 Migrate `single_male` → `foods`

- [x] Write `tool/migrate_foods.js` — a standalone script, **never imported from `lib/`**.
      **Deviation from plan:** written in Node with `firebase-admin` rather than Dart. The
      Admin SDK bypasses security rules, so `foods` can stay client-read-only and no weakened
      ruleset ever has to be deployed. A Dart script would have needed a Flutter runtime and a
      temporary permissive rule.
- [x] Read every doc from `single_male`
- [x] Map the keys onto the new vocabulary:

| old key | new location |
|---|---|
| `name` | `name` |
| `category` | `category` |
| `protein` | `per100.protein` |
| `fat` | `per100.fat` |
| `carp` | `per100.carbs` |
| `note` | `note` |
| `document.id` | `foods/{same id}` — preserve ids so nothing has to be re-linked |

- [x] Compute `kcalPer100 = protein*4 + carbs*4 + fat*9` (denormalized, for sorting only)
- [x] Generate `searchTokens`: lowercased name split on whitespace, plus prefix n-grams,
      plus an Arabic-normalized form (strip diacritics, unify أ/إ/آ → ا, ة → ه, ى → ي)
- [x] Set `active: true`, `createdAt`/`updatedAt` to server timestamps
- [x] Write to `foods/{id}` in batches of 400 (Firestore's limit is 500)
- [x] **Dry-run mode first** — print what would be written, write nothing. Review the output
      before the real run.
- [x] Leave `single_male` untouched. It is the rollback.

### 0.7 Lints

- [x] Tighten `analysis_options.yaml`:

```yaml
linter:
  rules:
    avoid_print: true
    use_super_parameters: true
    prefer_const_constructors: true
    prefer_final_fields: true
    unawaited_futures: true
    always_declare_return_types: true
```

- [x] Run `flutter analyze` and **capture the full output to `plans/analyze-baseline.txt`**.
      This becomes the migration checklist — every warning it lists is a legacy file that Steps
      1–4 will either rewrite or delete.
- [x] Do **not** fix legacy warnings now. They are the map, not the work.

---

## Files touched

| File | Action |
|---|---|
| `pubspec.yaml` | modify — deps, fonts, assets |
| `analysis_options.yaml` | modify — lint rules |
| `firebase.json` | create |
| `firestore.rules` | create |
| `firestore.indexes.json` | create |
| `tool/migrate_foods.js` | create (Node + firebase-admin, not Dart) |
| `tool/README.md` | create |
| `asset/model/` | delete (whole dir) |
| `lib/logic/auto_calculate.dart` | delete |
| `asset/model/converted_model (1).tflite` | delete |
| `plans/analyze-baseline.txt` | create (generated) |

---

## Reviewable at the end

- App builds and runs **identically** to before — this step is invisible by design
- `flutter analyze` produces the baseline checklist
- The `foods` collection exists in Firestore, populated, with clean key names
- Security rules are deployed and reject unauthenticated reads

## Exit criteria

- [x] `flutter build apk --debug` succeeds
- [x] App launches on `emulator-5554` and behaves as before (`FirebaseInitProvider: FirebaseApp initialization successful`, no crash)
- [x] `foods` verified: **8 docs**, keys `per100:{protein,carbs,fat}`, `kcalPer100`,
      `searchTokens`, `active`, server timestamps. `single_male` intact at 8 docs.
- [x] Rules deployed; a signed-out read of `foods` is rejected (HTTP 403)
- [x] `plans/analyze-baseline.txt` written — 584 issues: **0 errors**, 66 warnings, 518 info, all in legacy files

## Risks

- **`build_web_compilers` removal** — verify nothing depends on it before deleting.
- **Migration script correctness** — always dry-run first. `single_male` is left intact as the
  rollback, so a bad run costs only a re-run.
- **Firebase CLI may not be installed.** If so, the rules can be pasted into the console
  manually — but flag it, because indexes are much more tedious that way.
