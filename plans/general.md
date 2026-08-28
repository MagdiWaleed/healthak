# Healthak — Overhaul Master Plan

This directory is the working plan for rebuilding Healthak into a real calorie tracker with
day history, composable meals, a marketplace, and a glassmorphic UI.

These are **living documents**. Update the checklists in each `stepN.md` as work lands.

## Index

**Picking this up fresh? Read `PROGRESS.md` first.** It records exactly where work stopped, what
is blocked on user credentials, and what to do next.

| File | Phase | Status |
|---|---|---|
| `PROGRESS.md` | **Handoff — where work stopped, what's next** | living |
| `general.md` | Architecture, decisions, schema, design system | — |
| `step0.md` | Housekeeping: pubspec, fonts, rules, lints, data migration | code done; deploy + migration blocked on credentials |
| `step1.md` | Foundation: domain, data, design system, auth, shell | **next** |
| `step2.md` | Daily tracking + meal composition | not started |
| `step3.md` | Marketplace | not started |
| `step4.md` | Polish: motion, settings, RTL sweep, performance, a11y | not started |
| `step5.md` | AI assistant — **TBD, not yet specified** | blocked on spec |

---

## 1. Why this rebuild

The app works, but five foundational gaps block everything that was asked for:

1. **No time concept exists.** Zero `DateTime`/`Timestamp` anywhere in `lib/`. `isEaten` flags
   are persisted and never reset — check a meal off and it stays checked forever. The
   "الانجاز اليومي" tab is a label with no daily logic behind it.
2. **Identity is fake.** `sign_in_controller.dart:43` hardcodes `id: "new account"` for every
   user. `UserAuthRepository` wraps Firebase Auth, but the one method that calls it discards
   the returned `User` and is not wired into the save path. Consequently
   `create_meals_repository.dart:25`'s `where("createdByid", ...)` matches every user's meals.
3. **The marketplace is disconnected.** Browsing a published meal has `onTap: () {}`
   (`main_screen.dart:170`). There is no code path from a public meal into anyone's diet.
4. **No nesting.** A meal cannot be used as a component of another meal.
5. **The theme is one line.** `scaffoldBackgroundColor: Colors.white`. 272 raw color literals
   across 31 files. RTL is declared (`locale: Locale('ar')`) but non-functional —
   `flutter_localizations` isn't even a dependency, so the app renders LTR.

## 2. Locked decisions

| Area | Decision | Consequence |
|---|---|---|
| Local data | **Clean break** — wipe SharedPreferences on first launch of the new version | No migration code ships in the app. Schema designed correctly from scratch. |
| Identity | **Real Firebase Auth**, uid as `UserModel.id`, profile in `users/{uid}` | Email + display name at signup. Password reset works. |
| Days | **Full daily log + history**, `days/{yyyy-MM-dd}` | Eaten state resets daily by construction. Calendar + trends. |
| Delivery | **Phased, foundation first** | App runs and is reviewable after every step. |
| Food catalog | **Migrate `single_male` → `foods`** | Throwaway script in `tool/`, never shipped in `lib/`. |
| Auto-weight | **Delete TFLite**, replace with a deterministic solver | `tflite_flutter` dependency and the `.tflite` asset both dropped. |
| Cost feature | **Drop `diet_details_screen.dart`** | Optional cost shown in meal detail when a food has a price. |
| Naming | **`male` → `meal` everywhere** | Free, because of the clean break. |

Assumptions taken (changeable on request):

- Dark theme only in Step 1; light theme in Step 4. Glass reads far better dark.
- Western digits (123) by default, with an Arabic-Indic (١٢٣) toggle in Settings.
- Hand-rolled motion primitives (~200 lines) rather than `flutter_animate`.
- Legacy screens stay reachable behind `/legacy` until Step 2 replaces them.
- Days materialize only when opened. No backfilling of history the user never confirmed.

## 3. Naming conventions

The codebase misspells *meal* as *male* throughout. The clean break makes fixing this free.

| Old | New |
|---|---|
| `SingleMaleModel` | `FoodItem` (catalog) + `FoodEntry` (a portion) |
| `CompleteMaleModel` | `MealDefinition` |
| `CreateMealsModel` | `MarketMeal` |
| `single_male` (collection) | `foods` |
| `complete_meals` (collection) | `marketMeals` |
| `myDietMales` | `DayLog.entries` / `ScheduleItem` |
| `MalesRepository` | `FoodRepository` |
| `carps` / `carp` | `carbs` |
| `fats` / `fat` | `fat` |
| `protien` / `protein` | `protein` |
| `calories` | `kcal` |
| `weight` (of a portion) | `grams` |

**One macro vocabulary everywhere:** `protein`, `carbs`, `fat`, `kcal`, `grams`.
The codebase currently has three mutually incompatible key sets for the same data
(`fat`/`carp` in Firestore, `fats`/`carps` in local JSON, `fat`/`carp` again in published
meals). All of them die.

**Booleans are booleans.** They are currently persisted as the strings `"true"` / `"false"`.

## 4. Target directory structure

```
lib/
  main.dart
  app/
    app_routes.dart          route name constants
    app_pages.dart           GetPage list + bindings
    bindings/                one Binding per feature
  domain/                    PURE DART — zero Flutter imports, fully unit-testable
    nutrition/
      macros.dart            Macros value type (+ operator, * operator)
      energy.dart            BMR / TDEE / target / macro split
      portion_solver.dart    replaces the TFLite model
    food/food_item.dart
    meal/
      meal_entry.dart        sealed: FoodEntry | MealRefEntry
      meal_definition.dart
      meal_math.dart         recursive macro resolution + cycle guard
    day/day_log.dart         DayLog, DayEntry, FrozenItem
    schedule/schedule_item.dart
    market/market_meal.dart
  data/
    firestore_refs.dart      withConverter<T> typed collection refs
    mappers/                 toJson / fromJson per entity, one place each
    repositories/            food, meal, day, schedule, market, profile
  service/
    auth_service.dart
    prefs_service.dart       owns the schemaVersion clean break
    session_controller.dart  replaces lib/appData.dart
    settings_controller.dart
  ui/
    theme/                   app_theme, app_colors, app_typography, app_spacing, glass_tokens
    glass/                   glass_surface, glass_card, glass_panel, glass_scaffold
    background/aurora_background.dart
    motion/                  staggered_entry, pressable, hero_tags, transitions
    components/              calorie_ring, macro_bar, glass_button, glass_field,
                             glass_chip, gram_stepper, empty_state, error_state, async_view
  page/
    splash/ onboarding/ home/ today/ meal_editor/ foods/
    my_meals/ marketplace/ history/ profile/ settings/
    dev/gallery_screen.dart  debug-only design system gallery
  l10n/app_strings.dart      static const Arabic strings
test/
  domain/                    the first tests in this repository
tool/
  migrate_foods.dart         throwaway single_male -> foods script
```

## 5. Domain model

### 5.1 Macros

```dart
class Macros {                       // grams
  final double protein, carbs, fat;
  double get kcal => protein * 4 + carbs * 4 + fat * 9;
  Macros operator +(Macros o);
  Macros operator *(double k);
  static const zero = Macros(protein: 0, carbs: 0, fat: 0);
}
```

**Never store a computed total as truth.** `kcal` is always derived. Denormalized totals exist
only for list sorting and Firestore querying, and are commented as such at every declaration.

### 5.2 Splitting the overloaded component type

`SingleMaleModel` is currently a catalog row (per-100g macros), a portion (a `weight`), *and*
a checklist item (`isEaten`) all at once. That single conflation is the root cause of:

- the stale `calories` field (set in the constructor at the constructed weight, so it is only
  per-100g when `weight == 100`),
- `single_male_controller.dart:32` treating that field as per-100g when it isn't,
- the `current_diet_controller` desync (eaten flags read from one object graph, macros from
  another, indexed positionally).

Splitting it into an immutable `FoodItem` + a `FoodEntry` portion + a `DayEntry.eaten` flag
dissolves all three at once.

```dart
class FoodItem {                     // immutable catalog entity
  final String id, name;
  final String? category, imageUrl, note;
  final Macros per100;               // the ONLY macro storage
  final Map<String, num>? micros;
  final double? pricePer100;
}
```

No `weight`. No `isEaten`. No cached `calories`.

### 5.3 Nesting — the sealed `MealEntry`

```dart
sealed class MealEntry {
  String get localId;                // stable uuid — survives reorder, kills index addressing
  int get order;
}

final class FoodEntry extends MealEntry {
  final String foodId;
  final String name;                 // denormalized so offline render needs no join
  final Macros per100;               // snapshot of the catalog row at add time
  final double grams;
}

final class MealRefEntry extends MealEntry {
  final String mealId;               // a reference to another MealDefinition
  final String name;
  final double scale;                // multiplies every leaf gram of the referenced meal
  final Macros cachedTotals;
  final DateTime cachedAt;
}
```

A Dart 3 sealed hierarchy means an exhaustive `switch` — adding a third entry kind later
(barcode scan, quick-kcal entry) becomes a compile error at every call site rather than a
silent fallthrough.

```dart
class MealDefinition {
  String id, ownerUid, name;
  List<MealEntry> entries;           // an ORDERED List, not an index-keyed map
  String? notes, imageUrl;
  Macros totalsCache;                // denormalized, for sorting only
  int depth, leafCount;
  Set<String> descendantMealIds;     // transitive closure, maintained on write
  MealOrigin origin;                 // authored | copiedFromMarket
  MealSource? source;                // {marketMealId, authorUid, authorName, version}
  String? publishedMarketMealId;
  DateTime createdAt, updatedAt;
}
```

### 5.4 Macro recursion

```dart
Macros macrosOfMeal(MealDefinition m, MealResolver r, {int depth = 0}) {
  if (depth > kMaxNestDepth) throw MealDepthExceeded(m.id);
  return m.entries.fold(Macros.zero, (acc, e) => acc + switch (e) {
    FoodEntry f     => f.per100 * (f.grams / 100),
    MealRefEntry mr => macrosOfMeal(r.require(mr.mealId), r, depth: depth + 1) * mr.scale,
  });
}
```

`MealResolver` memoizes per `mealId` within a traversal, so a diamond (meal C referenced from
two places) costs one resolution, not two.

### 5.5 Cycle prevention — three layers

1. **Precomputed closure.** Every `MealDefinition` stores `descendantMealIds` (transitive).
   Adding meal B into meal A is rejected if `B.id == A.id` or `A.id ∈ B.descendantMealIds`.
   O(1), zero extra reads.
2. **Limits.** `kMaxNestDepth = 3`, `kMaxLeafCount = 60`, enforced on save with a
   human-readable Arabic refusal — never a silent failure.
3. **Runtime guard.** `MealResolver` carries a `visited` set and throws `MealCycleException`
   rather than blowing the stack, in case data is ever corrupted out-of-band.

Cross-user cycles are structurally impossible because marketplace adds are always copies with
fresh ids.

**Ungroup.** `MealEditorController.ungroup(MealRefEntry)` expands a referenced meal into its
scaled leaf `FoodEntry`s in place, one tap. This is what makes "customize the weights of each
component" work even for nested and marketplace-sourced meals — the user is never trapped
behind a reference they cannot edit.

### 5.6 Days — flattened and frozen

```dart
class DayLog {
  String dateKey;                    // 'yyyy-MM-dd', local time, used as the doc id
  DateTime date;
  int tzOffsetMinutes;
  NutritionTargets targets;          // FROZEN copy of the user's targets that day
  List<DayEntry> entries;
  int materializedFromScheduleVersion;
}

class DayEntry {
  String entryId;
  DayEntryOrigin origin;             // scheduled | oneShot | quickAdd
  String? scheduleItemId, sourceMealId;
  String name;
  MealSlot slot;                     // breakfast | lunch | dinner | snack
  int order;
  bool eaten;
  DateTime? eatenAt;
  List<FrozenItem> items;            // FLAT leaves — nesting is collapsed
  Macros totals;
}

class FrozenItem {
  String foodId, name;
  String? groupLabel;                // "من: وجبة الإفطار" — preserves visual nesting
  Macros per100;
  double grams;
}
```

**This is the most important architectural decision in the plan.** Day logs contain no
references at all. Rationale:

- **History must be immutable.** Editing a recipe today must not retroactively change what you
  ate last Tuesday. A live reference guarantees exactly the opposite.
- **The hot path stays flat.** The tracker recomputes totals on every gram change and every
  eat-toggle. Recursion in that loop is both slow and a bug farm — it is precisely what the
  current `current_diet_controller` gets wrong.
- **One read.** A day is one document. Opening the app costs one read and works offline.
- `groupLabel` retains the visual grouping, so the user still *sees* the nesting they built.

**Materialization.** `DayService.ensureDay(dateKey)`: if the doc doesn't exist, read
`users/{uid}/schedule` where `active == true` and `daysOfWeek` contains the weekday,
materialize each into a `DayEntry` with `eaten: false`, and write in a transaction keyed on
`materializedFromScheduleVersion` so it is idempotent under races.

**Eaten state resets daily for free** — a new day is a new document, so `eaten` is false by
construction. There is no reset code to write and therefore nothing to get wrong.

### 5.7 Permanent vs one-shot

```dart
class ScheduleItem {
  String id, mealId, name;
  List<FrozenItem> snapshot;         // ensureDay needs ONE query, no meal resolution
  MealSlot slot;
  int order;
  Set<int> daysOfWeek;               // 1..7; {1..7} means daily
  bool active;
  DateTime createdAt, updatedAt;
}
```

- **Permanent** = a `ScheduleItem`. Auto-populates every matching day.
- **One-shot** = written straight into today's `DayLog.entries` with `origin: oneShot`.
  Never touches the schedule. Gone when the day ends.

The schedule item carries a frozen snapshot so materialization is one query with no resolution
and works offline. When the user edits the underlying `MealDefinition`, the app asks
explicitly — "تحديث الجدول أيضاً؟" — never silently.

### 5.8 Marketplace — copy-on-add, never live reference

Four reasons:

1. Weights must be independently customizable per user. A live reference would need a parallel
   per-user override document keyed by entry — strictly more machinery for strictly less clarity.
2. Publisher edits or deletions must not corrupt someone else's plan or history.
3. Offline: the copy lives under `users/{uid}`, covered by Firestore persistence.
4. Security rules collapse to "everything under `users/{uid}` belongs to uid".

Provenance is preserved on the copy: `source: {marketMealId, authorUid, authorName, version,
copiedAt}`. That leaves the door open for an opt-in "المؤلف حدّث هذه الوجبة — تحديث؟" later
without committing to it now.

**Published meals are flattened.** A `MarketMeal` stores flat `items` plus a `groups` array of
`{label, start, end}`. A published meal must be self-contained: it cannot reference another
user's private meal, and referencing other market meals would reintroduce cross-author cycles
and dangling links on delete. The `groups` metadata keeps the nesting visible to browsers.

## 6. Calorie math

`lib/domain/nutrition/energy.dart` — pure functions, fully unit-tested.

**BMR, Mifflin–St Jeor:**

```
male:        10*kg + 6.25*cm - 5*age + 5
female:      10*kg + 6.25*cm - 5*age - 161
unspecified: average of the two (i.e. -78)
```

This finally uses `heightCm`, `weightKg`, and `age` — all three are collected today and all
three are currently ignored. `calculateCalories()` is presently `caloriesNeeds = dailyActive`,
an identity function.

**New field: `sex`** (`male | female | preferNotToSay`), required by the formula. Added to
onboarding and to profile editing.

**TDEE** = `BMR × activityMultiplier`, where `ActivityLevel` is an enum with fixed multipliers,
not a free-text field:

| level | Arabic | multiplier |
|---|---|---|
| sedentary | خامل | 1.2 |
| light | نشاط خفيف | 1.375 |
| moderate | نشاط متوسط | 1.55 |
| high | نشاط عالٍ | 1.725 |
| athlete | رياضي | 1.9 |

This matches the "1.2 to 1.9" hint the UI already shows, confirming a multiplier was always the
intent — and it removes the `double.parse` crash surface on an arbitrary text field.

**Target:**

```
delta  = weeklyRateKg * 7700 / 7          // 0.25kg -> 275, 0.5 -> 550, 0.75 -> 825 kcal/day
cut:   tdee - delta      bulk: tdee + delta      maintain: tdee
floor  = max(bmr, sex == female ? 1200 : 1500)
target = clamp(target, floor, tdee * 1.5)
```

The magic `± 500` becomes a user-chosen rate, and the target can never drop below BMR.

**Macros, with a deterministic clamping waterfall** (fixes the current unclamped negative-carbs
bug — `getCarp()` is a bare remainder today and can go negative):

```
protein = clamp(proteinPerKg, 1.6, 2.2) * weightKg      // default 1.8
fat     = max(0.8 * weightKg, target * 0.25 / 9)
carbs   = (target - protein*4 - fat*9) / 4

if (carbs < 0) {
  1. reduce fat toward 20% of target
  2. reduce protein toward 1.6 g/kg
  3. floor carbs at 0
}
cap: proteinKcal <= 40% of target, fatKcal <= 40% of target
```

Plus a **manual mode**: the user types a target kcal and macro percentages;
`targets.mode = 'manual'` skips the computation entirely. Targets are frozen into each `DayLog`
so changing your goal never rewrites history.

## 7. Firestore schema

```
foods/{foodId}                            # public catalog (replaces single_male)
  name, nameAr, category, active,
  per100: {protein, carbs, fat}, kcalPer100 (denorm, sort only),
  micros: {}, imageUrl, pricePer100, note,
  searchTokens: [], createdAt, updatedAt

users/{uid}                               # profile (replaces the SharedPrefs "user" blob)
  displayName, email, photoUrl,
  sex, birthYear, heightCm, weightKg,
  activityLevel, goal, weeklyRateKg,
  targets: {mode, kcal, protein, carbs, fat},
  settings: {themeMode, accent, graphicsQuality, digits, units},
  onboardingComplete, schemaVersion: 2, createdAt, updatedAt

users/{uid}/meals/{mealId}                # private library: authored AND copied
  name, notes, imageUrl,
  entries: [ {type:'food', localId, order, foodId, name, per100:{}, grams}
           | {type:'meal', localId, order, mealId, name, scale, cachedTotals, cachedAt} ],
  totalsCache: {}, depth, leafCount, descendantMealIds: [],
  origin, source, publishedMarketMealId, createdAt, updatedAt

users/{uid}/schedule/{itemId}
users/{uid}/days/{yyyy-MM-dd}
users/{uid}/bodyWeights/{yyyy-MM-dd}

marketMeals/{marketMealId}                # replaces complete_meals
  authorUid, authorName, name, notes, imageUrl,
  items: [ {foodId, name, groupLabel, per100:{}, grams} ],   # FLAT
  groups: [ {label, start, end} ],
  totals: {protein, carbs, fat, kcal},
  tags: [], language: 'ar',
  copyCount, likeCount, status: 'published'|'removed',
  createdAt, updatedAt, schemaVersion: 2
marketMeals/{id}/likes/{uid}              # one doc per like, avoids counter contention

appConfig/home                            # replaces the `data` collection and its .single crash
```

Server timestamps on write (`FieldValue.serverTimestamp()`), `Timestamp` on read, `DateTime` in
the model layer. Day docs carry both the sortable string `dateKey` and a real `Timestamp date`
for range queries.

**Typed access.** `lib/data/firestore_refs.dart` uses `withConverter<T>` so every collection ref
is statically typed and `fromFirestore`/`toFirestore` lives in exactly one place. This is what
kills the current double-encoded index-keyed-map serialization and the byte-identical
`toMap()`/`convertToJson()` duplication.

### Indexes (`firestore.indexes.json`)

- `marketMeals`: `(status ASC, createdAt DESC)`, `(status ASC, copyCount DESC)`,
  `(authorUid ASC, createdAt DESC)`, `(tags ARRAY, createdAt DESC)`
- `foods`: `(active ASC, category ASC, name ASC)`, `(searchTokens ARRAY, name ASC)`
- `users/{uid}/days`: the single-field index on `date` suffices.

### Security rules (`firestore.rules`)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {

    function signedIn() { return request.auth != null; }

    match /users/{uid} {
      allow read, write: if signedIn() && request.auth.uid == uid;
      match /{document=**} {
        allow read, write: if signedIn() && request.auth.uid == uid;
      }
    }

    match /foods/{id} {
      allow read:  if signedIn();
      allow write: if false;                    // seeded/admin only
    }

    match /marketMeals/{id} {
      allow read: if signedIn() && resource.data.status == 'published';

      allow create: if signedIn()
        && request.resource.data.authorUid == request.auth.uid
        && request.resource.data.name is string
        && request.resource.data.name.size() > 0
        && request.resource.data.name.size() <= 80
        && request.resource.data.items.size() <= 60
        && request.resource.data.copyCount == 0
        && request.resource.data.likeCount == 0;

      allow update, delete: if signedIn()
        && resource.data.authorUid == request.auth.uid
        && request.resource.data.authorUid == resource.data.authorUid;

      // any signed-in user may increment copyCount by exactly 1, and change nothing else
      allow update: if signedIn()
        && request.resource.data.diff(resource.data)
             .affectedKeys().hasOnly(['copyCount'])
        && request.resource.data.copyCount == resource.data.copyCount + 1;

      match /likes/{likeUid} {
        allow read:  if signedIn();
        allow write: if signedIn() && request.auth.uid == likeUid;
      }
    }

    match /appConfig/{id} { allow read: if true; allow write: if false; }
  }
}
```

The narrow `copyCount` rule means **no Cloud Functions and no Blaze plan are needed**. Same
pattern for `likeCount` via the likes subcollection.

Old collections (`single_male`, `complete_meals`, `data`, `*_component_stat`) are left in place,
unreferenced. `statistics_repository.dart` — which creates an unbounded number of collections
named after the component count (`3_component_stat`, `5_component_stat`, …) — is deleted.

## 8. Auth

`lib/service/auth_service.dart` (`GetxService`) wraps `FirebaseAuth`: `Stream<User?> authState`,
`signUp`, `signIn`, `signOut`, `sendPasswordReset`, `reauthenticate`, `deleteAccount`.
`user_auth_repository.dart` folds into it and is deleted.

**Bootstrap** (`main.dart`):

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true, cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED);
await Get.putAsync(() => PrefsService().init());   // the clean break happens here
Get.put(AuthService());
runApp(const HealthakApp());
```

**The clean break**, in `PrefsService.init()`:

```dart
final v = prefs.getInt('schemaVersion') ?? 0;
if (v < 2) { await prefs.clear(); await prefs.setInt('schemaVersion', 2); }
```

One line drops both the old `"user"` blob and the old `"myDiet"` list — and structurally fixes
the `deleteTheAccount()` orphan bug, since there is no longer a second key to forget.

**Routing** (`SplashScreen`, replacing `loading_Screen.dart`, which currently does
`jsonDecode(SP.getString("user").toString())` on a possibly-null string):

- `authState == null` → `/onboarding`
- signed in but `users/{uid}` missing or `onboardingComplete != true` → `/onboarding/profile`
- otherwise → `/home`, with the cached profile painting instantly while Firestore reconciles

**Offline cache.** SharedPreferences holds *only* `{uid, profileJson, cachedAt, settings}` —
enough for a zero-flicker first frame. Firestore's own offline persistence is the real cache for
meals, schedule, days, and market browsing. Single writer: `ProfileRepository.save()` writes
Firestore then mirrors to prefs, never the reverse. This eliminates the entire class of
read-modify-write bugs in the current `user_service.dart`.

**Delete account.** Reauthenticate → batched delete of `users/{uid}` subcollections → mark
authored `marketMeals` as `status: 'removed'` → `user.delete()` → `prefs.clear()`. Behind a
typed-confirmation dialog. There is currently no confirmation at all.

## 9. Glass design system

New `lib/ui/` tree replacing `lib/theme/` and `lib/widget/`.

### 9.1 Three background layers

1. **Base** — near-black `#0A0D14`. A deep desaturated ground so translucent white tints read
   as *light on glass* rather than as grey.
2. **`AuroraBackground`** — 3–4 large soft `RadialGradient` blobs (teal / violet / amber at
   20–35% alpha) on long ping-pong `AnimationController`s (18–30s, `Curves.easeInOut`), each
   slowly translating and scaling. One `CustomPaint`, one `RepaintBoundary`.
   **Key insight: the softness comes from the gradients, not from `ImageFilter.blur`.** Radial
   gradients are already blur-shaped. This delivers the full glassmorphic look for essentially
   zero GPU cost, and it is what makes the blur budget below achievable rather than aspirational.
3. **Grain** — a tiled 128×128 noise PNG at ~4% opacity over everything. Grain is what makes
   glass read as a physical material instead of flat translucency, and it hides gradient banding
   on cheap panels. **`asset/image/noise.png` does not exist yet and must be generated.**

### 9.2 Primitives

```dart
GlassSurface({
  required Widget child,
  double blurSigma = GlassTokens.sigmaPanel,   // 18
  GlassElevation elevation = GlassElevation.level1,
  BorderRadius radius = const BorderRadius.all(Radius.circular(24)),
  EdgeInsetsGeometry padding,
  bool enableBlur = true,      // ANDed with the resolved GraphicsQuality tier
  GlassBorder border = GlassBorder.hairline,
  Color? scrim,                // for surfaces over unpredictable imagery
})
```

**Elevation model.** Glass has no Material shadow-as-elevation. Four levels, each a tuple of
(tint alpha, border alpha, blur sigma, ambient shadow):

| level | tint | border | sigma | shadow | used for |
|---|---|---|---|---|---|
| 0 base | — | — | — | — | the aurora itself |
| 1 card | .08 | .14 | *none* | 24px @ .35 | list cards, tiles |
| 2 panel | .12 | .20 | 18 | 32px @ .40 | app bar, nav bar |
| 3 modal | .16 | .28 | 28 | 48px @ .50 | sheets, dialogs |
| 4 popover | .20 | .32 | 28 | 56px @ .55 | menus, tooltips |

**Border and highlight.** A 1px border painted as a `LinearGradient` from `white .35` at
top-left to `white .06` at bottom-right — light catching an edge. Plus a specular highlight: a
top-40%-height `LinearGradient(white .10 → transparent)` inside the clip. These two details are
most of the difference between "translucent rectangle" and "glass".

**Readability floor.** Every glass surface enforces a minimum tint alpha (`.10` dark,
`.55` light). Body text `white .92`, secondary `white .64`. Contrast is checked against the
*darkest* aurora state, not the average.

### 9.3 Performance budget — hard rules

`BackdropFilter` forces a `saveLayer` and a full read of everything painted beneath it, per
widget, per frame. On mid-range Android this is the single largest jank source in a design
like this.

1. **At most 2 simultaneous `BackdropFilter`s on screen**, and they must be structurally fixed —
   never inside a scroll viewport. In practice: the header panel and the bottom nav bar. An
   open modal counts as one — dismiss or replace, never stack.
2. **Zero `BackdropFilter` inside any `ListView`, `GridView`, or `PageView`.** List cards use
   `GlassCard`, which is *deliberately fake glass*: tint gradient + hairline border + specular
   highlight + soft shadow, **no filter**. Against a soft aurora it is visually ~90% identical
   and costs approximately nothing. **This is the most important rule in the design system.**
   Enforced by a debug-only live-instance counter in `GlassSurface` that `assert`s when more
   than 2 are mounted, so a violation surfaces the moment it is written rather than during a
   profiling session weeks later.
3. Every `BackdropFilter` wrapped in `ClipRRect` (mandatory — an unclipped `BackdropFilter`
   blurs the entire screen) and a `RepaintBoundary`.
4. `ImageFilter.blur(sigmaX: s, sigmaY: s, tileMode: TileMode.mirror)`. `mirror` avoids the
   transparent-edge artifact at clip bounds that makes glass look cheap.
5. When two blurs must coexist (header + nav bar), wrap the scaffold in a `BackdropGroup` and
   use `BackdropFilter.grouped` so they share one backdrop read instead of two.
   *Verify API availability on Flutter 3.41 at implementation time.*
6. **Never animate `sigma` on a continuously running controller.** Discrete transitions only
   (sheet open/close), ≤300ms.

**Quality tiers.** `GraphicsQuality { high, balanced, low }`, resolved once at startup by a
`PerformanceProbe` sampling `SchedulerBinding.instance.addTimingsCallback` over the first ~90
frames; if p95 raster > 12ms, drop a tier. Always overridable in Settings
("التأثيرات البصرية: عالية / متوسطة / موفرة").

| | high | balanced | low |
|---|---|---|---|
| blur | header + nav + sheets | sheets only | none |
| aurora | animated | half speed | static gradient |
| grain | on | on | off |
| stagger | full | shortened | off |

Honour `MediaQuery.disableAnimations` and `accessibleNavigation` → force `low` regardless of tier.

### 9.4 Motion

- **Durations** `fast 150 / base 250 / slow 400 / ambient 20s`.
  **Curves** `easeOutCubic` entry, `easeInCubic` exit, `easeOutBack` for emphasis (ring settle,
  check toggle), `easeInOut` ambient.
- **Staggered entry** — `StaggeredEntry(index: i, child: ...)`, one shared controller per list,
  40ms per item, **capped at 8** so a 40-row list doesn't crawl in. Fade + 12px translate +
  0.98 scale.
- **Hero transitions** — marketplace card → detail, `Hero(tag: 'meal-$id')` on the container,
  image, and title. Caveat: Hero flight across a `BackdropFilter` produces visible artifacts.
  Rule 2 above already guarantees the source card is a plain `GlassCard`; the detail header
  must match.
- **Calorie ring** — `CustomPainter` sweep-gradient arc, `TweenAnimationBuilder<double>` at
  600ms `easeOutCubic`. Three thin concentric sub-rings for P/C/F. A `MaskFilter.blur` outer
  glow that intensifies approaching 100% and shifts hue when over. Center number animates via
  `TweenAnimationBuilder<int>` with `FontFeature.tabularFigures()` so digits don't jitter.
- **Page transitions** — a custom fade + 0.98→1.0 scale rather than `Transition.cupertino`.
  Slide-based transitions have RTL direction pitfalls; a direction-agnostic transition sidesteps
  them entirely.
- **Micro-interactions** — `Pressable`: `AnimatedScale` to 0.97 on tap-down, 120ms.
  `HapticFeedback.selectionClick()` on eat-toggle and gram stepper, `.mediumImpact()` on goal
  reached. A one-shot pulse + glow on the ring when the target is hit.

### 9.5 Typography

Register **all 8** Cairo weights. Only 2 of the 8 files on disk are currently declared, so
w500/w600 are synthesized:

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

`ThemeData(fontFamily: 'Cairo')` at the app level **plus** a complete `textTheme`. This is what
stops GetX snackbars, QuickAlert buttons, and Material defaults falling back to Roboto —
currently `fontFamily: "Cairo"` is a string literal repeated in 6 places and anything not routed
through `CustomText` renders in the wrong face.

Arabic needs more leading than Latin; Cairo's default is tight:

| token | size | weight | height |
|---|---|---|---|
| displayLarge | 34 | 800 | 1.25 |
| headlineMedium | 24 | 700 | 1.30 |
| titleLarge | 20 | 600 | 1.35 |
| titleMedium | 16 | 600 | 1.40 |
| bodyLarge | 15 | 400 | 1.60 |
| bodyMedium | 13 | 400 | 1.60 |
| labelLarge | 14 | 600 | 1.20 |
| labelSmall | 11 | 500 | 1.30 |

**`CustomText` is deleted.** Its ~235 call sites across 28 files migrate to
`Theme.of(context).textTheme.x` screen by screen as each screen is rebuilt — never as one
big-bang pass. This also fixes its missing `maxLines`/`overflow`/`textAlign`, which is why long
Arabic strings overflow today.

## 10. RTL — the biggest hidden risk

Adding `flutter_localizations` and the delegates flips `Directionality` to RTL app-wide, and
**every screen hand-tuned for LTR will mirror and break**:

- `Row` + `Spacer` faking right-alignment now pushes content the wrong way.
- **`Positioned(left:/right:)` does not flip.** Only `PositionedDirectional` does.
- `EdgeInsets.only(left:/right:)` → `EdgeInsetsDirectional.only(start:/end:)`.
- `Alignment.centerLeft` → `AlignmentDirectional.centerStart`.
- `BorderRadius.only(topLeft:)` → `BorderRadiusDirectional`.
- `TextAlign.left/right` → `TextAlign.start/end`.
- Custom back arrows don't auto-flip (the Material leading button does).
- `ReorderableListView` drag handles move sides.
- The signup `PageController`: `nextPage` now advances visually right-to-left.

**Mitigation — do not flip globally while legacy screens still exist:**

- **Step 1** adds the delegates but wraps every not-yet-rebuilt legacy screen in a
  `LegacyLtrShim` — `Directionality(textDirection: TextDirection.ltr, child: ...)`. Old screens
  keep working byte-identically; new screens are born RTL-correct.
- **Steps 2–3**: each screen drops its shim at the moment it is rebuilt.
- **Step 4**: delete `LegacyLtrShim` and grep `lib/` for `Positioned(`,
  `EdgeInsets.only(left`, `Alignment.centerLeft`, `TextAlign.left` as a final checklist.
- A debug-only toggle forces `TextDirection.ltr` so mirroring can be spot-checked side by side.

This turns "an afternoon of confusing breakage" into a controlled, reviewable migration.

## 11. Screens

**Navigation infrastructure first** (`lib/app/app_routes.dart`, `app_pages.dart`,
`lib/app/bindings/*`): named routes + `Binding` classes. This alone fixes three current classes
of bug — controllers constructed twice via nested `GetBuilder(init:)`,
`FutureBuilder(future: controller.getData())` inside `build` refetching on every rebuild
(4 screens), and 12 inline-constructed `Get.to` targets with no lifecycle.

**State:** adopt `Rx` + `Obx`. There are currently zero `.obs` and zero `Obx` in the codebase —
everything is `GetBuilder` + manual `update()`. Plus a small `AsyncValue<T>` sealed type
(`loading | data | error`) and an `AsyncView<T>` widget so every screen renders loading, empty,
and error states consistently.

| # | New screen | Path | Replaces |
|---|---|---|---|
| 1 | `SplashScreen` | `lib/page/splash/` | `loading/loading_Screen.dart` |
| 2 | `OnboardingFlow` | `lib/page/onboarding/` | `sign_in/sign_in_screen.dart` |
| 3 | `HomeShell` | `lib/page/home/` | `main_screen/main_screen.dart` |
| 4 | `TodayScreen` | `lib/page/today/` | `MainBody` (the GIF) + `current_diet/` |
| 5 | `MealEditorScreen` | `lib/page/meal_editor/` | `create_single_meal_details/` + `add_complete_meal/` |
| 6 | `FoodCatalog` + `FoodPickerSheet` | `lib/page/foods/` | `single_male_screen/` |
| 7 | `MyMealsScreen` | `lib/page/my_meals/` | `create_meals/` + `my_males_current_diet/` |
| 8 | `MarketplaceScreen` + `MarketMealDetail` | `lib/page/marketplace/` | `ShowMeals` in `main_screen.dart` |
| 9 | `HistoryScreen` | `lib/page/history/` | *new* |
| 10 | `ProfileScreen` | `lib/page/profile/` | `my_informations/my_informations_screen.dart` |
| 11 | `SettingsScreen` | `lib/page/settings/` | `setting/setting_screen.dart` |

**Files deleted:** `lib/appData.dart` (global mutable statics → `SessionController`),
`lib/widget/custom_multi_choose.dart` (dead — zero call sites, empty `onTap`),
`lib/widget/custom_background.dart` (a `StatefulWidget` with no state rendering a plain white
rect), `lib/page/setting/setting_screen.dart`, `lib/page/diet_details/`,
`lib/model/statistics.dart`, `lib/service/statistics_repository.dart`,
`lib/service/user_service.dart`, `lib/logic/auto_calculate.dart`.

## 12. Portion solver — replacing TFLite

`lib/logic/auto_calculate.dart` is beyond economical repair:

- hardcoded to exactly 3 components (`[6,3]` output shape, explicit `temp[0..2]` indexing)
- `swap_indexes` has index bugs (`(j+3)+1` should be `(j*3)+2`)
- `final temp = [...meals]` is a **shallow** copy, so `setWeight` mutates the caller's real
  components
- the scoring loop then reads `meals[i].getCalories()` — the mutated originals — not `temp`
- `closestIndex` compares against `caloriesGoal`, ignoring the `custom_calories` that was
  actually fed to the model
- the interpreter is loaded fresh on every call and never closed
- the caller does `double.parse` on a possibly-empty text field

Generalizing it past 3 components would mean retraining a model whose training source isn't in
the repo. The underlying problem — given N components with fixed macro ratios and a target
kcal, pick grams — has a closed form.

**`lib/domain/nutrition/portion_solver.dart`:**

- **Mode A, proportional scale (default).** `factor = targetKcal / currentKcal`, applied to
  every unlocked entry, rounded to 5g, with the rounding residual assigned to the largest
  entry. Locked entries keep their grams and are subtracted from the target first. Always
  solvable, instant, trivially explainable.
- **Mode B, macro-targeted.** Minimize weighted squared error against (kcal, P, C, F) subject
  to `grams >= 0` and per-entry min/max. Projected gradient descent over an N-vector — ~30
  lines, deterministic, converges in <100 iterations for N ≤ 20.
- **UX:** a "موازنة تلقائية" button showing a preview diff (old grams → new grams) with undo,
  plus per-entry lock toggles. The lock toggles are what make it feel intelligent — far more
  than the model ever did.

Removing `tflite_flutter` also drops a native `.so` per ABI (smaller APK, fewer build-config
risks) and lets us delete `asset/model/converted_model (1).tflite`, including its awkward
space-and-parenthesis filename in the asset manifest.

## 13. AI assistant — TBD

An AI assistant is planned, but **its behaviour and scope have not been drafted yet**. Nothing
in Steps 0–4 depends on it, and no code should be written for it until it is specified. See
`step5.md` for the open questions.

Two things are worth noting now so the design doesn't have to be unpicked later:

- The domain layer is **pure Dart with zero Flutter imports**, so an assistant can call exactly
  the same macro math and portion solver the UI uses.
- The frozen `FrozenItem` day model gives any assistant a clean, flat, timestamped read of what
  was actually eaten — no graph traversal, no resolution.

## 14. Bugs being fixed along the way

| Bug | Location |
|---|---|
| `updateMeal()` builds a new model `ddd` then passes the *original* — edits silently discarded | `create_single_meal_details_controller.dart:144` |
| Eaten flags and macros read from two different object graphs, indexed positionally | `current_diet_controller.dart` |
| `_reCalculatTheWholeCalories()` never called in `onInit` — totals show 0 on first open | `current_diet_controller.dart` |
| Long-press to edit a component calls 60 lines of fully commented-out code — silently does nothing | `current_diet_controller.dart:96-157` |
| `deleteTheAccount()` removes `"user"` but leaves `"myDiet"` orphaned | `my_informations_controller.dart:10` |
| `.single` throws if the config doc count isn't exactly 1 | `main_repository.dart:11` |
| `faker.image.image()` as a background — a different random photo every build | `single_male_screen.dart:32` |
| In-memory append and disk append as two ops that can diverge | `add_complete_meal_screen.dart:157-158` |
| `id: "newMeal"` never reconciled with `document.id` | `create_single_meal_details_controller.dart:117` |
| Untranslated English in the Arabic UI: `"there are no data "` ×4, `"there are no meals"`, `"error"`, `"title"` ×6 | multiple |
| Unbounded full-collection scan, no pagination | `males_repository.dart:11` |
| AppBar typo "معلواتي"; `MyCriteriaScreen` titled "معلومات تسجيل الدخول"; `SettingScreen` titled "تصميماتي" | multiple |
| Delete account has no confirmation dialog | `my_informations_controller.dart` |
| The bare `- asset/` pubspec entry matches **zero** files (dir-asset syntax is non-recursive) | `pubspec.yaml:76` |

## 15. Verification

Per step: `flutter analyze` clean for new code, `flutter test` for `test/domain/**`,
`flutter build apk --debug`, then run on `emulator-5554`.

Manual end-to-end after Step 3, on a real device in **profile** mode: sign up → onboard →
build a meal from components → nest a meal inside another → publish it → sign in as a second
account → discover it → customize grams → add as one-shot and as permanent → confirm the
one-shot appears only today and the permanent repopulates tomorrow → tick items and watch the
ring → check history.

Performance is verified in **Step 1, not Step 4** — DevTools raster timeline on a real
mid-range Android, confirming ≤2 blurs and p95 raster under budget. If the aurora plus two
blurs already janks, the visual direction needs re-scoping, and that is vastly cheaper to learn
in week one.

## 16. Build environment (already fixed — do not change)

Flutter 3.41.2 / Dart 3.11. Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0, Java 17, minSdk 26, multidex.
`com.google.gms.google-services` 4.4.2 applied. Firebase project `diet-app-a908a`, package
`com.example.diet_app2`. `tflite_flutter` 0.12.1 (being removed in Step 0).

`google_sign_in` was added and then removed at the user's request — **do not reintroduce it.**
