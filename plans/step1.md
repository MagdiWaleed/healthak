# Step 1 — Foundation

**Goal:** the whole skeleton — domain model, data layer, glass design system, real auth, app
shell — with legacy screens still reachable as a fallback.

**Status:** implementation complete; final real-device performance gate pending

**Depends on:** Step 0 (fonts registered, `foods` populated, rules deployed)
**Blocks:** Steps 2, 3, 4

This is the largest step. Everything after it is filling in screens.

---

## 1.1 Domain layer — pure Dart, zero Flutter imports

Everything here must be unit-testable without a widget test. **If a file in `lib/domain/` needs
`package:flutter`, something is in the wrong layer.**

- [x] `lib/domain/nutrition/macros.dart` — `Macros` value type, `+`, `*`, `kcal` getter,
      `zero` const, `==`/`hashCode`
- [x] `lib/domain/nutrition/energy.dart` — `Sex`, `ActivityLevel`, `Goal` enums;
      `bmrMifflinStJeor`, `tdee`, `dailyTarget`, `macroSplit` with the clamping waterfall
      (spec in `general.md` §6)
- [x] `lib/domain/nutrition/portion_solver.dart` — Mode A proportional scale with locks; Mode B
      macro-targeted projected gradient descent (spec in `general.md` §12)
- [x] `lib/domain/food/food_item.dart` — immutable catalog entity
- [x] `lib/domain/meal/meal_entry.dart` — the `sealed class MealEntry`, `FoodEntry`,
      `MealRefEntry`
- [x] `lib/domain/meal/meal_definition.dart` — `MealDefinition`, `MealOrigin`, `MealSource`
- [x] `lib/domain/meal/meal_math.dart` — `macrosOfMeal` recursion, `MealResolver` with
      memoization and a `visited` set, `MealDepthExceeded` / `MealCycleException`,
      `canNest(parent, child)` closure check, `flatten()` for freezing into a day,
      `ungroup(entry)`
- [x] `lib/domain/day/day_log.dart` — `DayLog`, `DayEntry`, `FrozenItem`, `MealSlot`,
      `DayEntryOrigin`, `NutritionTargets`
- [x] `lib/domain/schedule/schedule_item.dart`
- [x] `lib/domain/market/market_meal.dart`

**Constants:** `kMaxNestDepth = 3`, `kMaxLeafCount = 60`, `kGramRounding = 5`.

## 1.2 Tests — the first in this repository

- [x] `test/domain/energy_test.dart` — known-value BMR for male/female/unspecified; the BMR
      floor clamp; the negative-carbs waterfall (all three stages); manual-mode passthrough;
      each `ActivityLevel` multiplier
- [x] `test/domain/macros_test.dart` — arithmetic, `kcal` derivation, zero identity
- [x] `test/domain/meal_math_test.dart` — flat meal totals; one level of nesting with a scale
      factor; 3 levels; depth-4 throws `MealDepthExceeded`; a diamond resolves once (memoized);
      `canNest` rejects self and rejects an ancestor; a corrupted cycle throws
      `MealCycleException` rather than overflowing the stack; `flatten` preserves `groupLabel`;
      `ungroup` conserves total macros
- [x] `test/domain/portion_solver_test.dart` — proportional scale hits the target within
      rounding; locked entries are untouched; all-locked is a no-op; Mode B converges; grams
      never go negative

Target: ~30 tests. `flutter test` green is a hard gate on this step.

## 1.3 Data layer

- [x] `lib/data/firestore_refs.dart` — every collection reference via `withConverter<T>`, so
      the codebase never touches a raw `Map<String, dynamic>` outside a mapper
- [x] `lib/data/mappers/` — one mapper per entity, each the single place `toJson`/`fromJson`
      lives. This is what kills the current double-encoded index-keyed-map serialization and
      the byte-identical `toMap()` / `convertToJson()` duplication.
- [x] `lib/data/repositories/food_repository.dart` — paginated list (`limit(30)` +
      `startAfterDocument`), search by `searchTokens`, filter by category, get by id
- [x] `lib/data/repositories/profile_repository.dart` — read/write `users/{uid}`, mirror to
      prefs. **Single writer:** Firestore first, prefs second, never the reverse.
- [x] `lib/data/repositories/meal_repository.dart` — CRUD on `users/{uid}/meals`, maintains
      `descendantMealIds` / `depth` / `leafCount` on every write
- [x] `lib/data/repositories/day_repository.dart` — `ensureDay`, watch, update entry, toggle eaten
- [x] `lib/data/repositories/schedule_repository.dart`
- [x] `lib/data/repositories/market_repository.dart` — stub in this step, filled in Step 3
- [x] `lib/data/async_value.dart` — `sealed class AsyncValue<T> { Loading | Data | Error }`

## 1.4 Services

- [x] `lib/service/prefs_service.dart` — `GetxService`. Owns the **clean break**:

```dart
final v = prefs.getInt('schemaVersion') ?? 0;
if (v < 2) { await prefs.clear(); await prefs.setInt('schemaVersion', 2); }
```

  Stores only `{uid, profileJson, cachedAt, settings}`. Firestore's own persistence is the real
  cache for everything else.

- [x] `lib/service/auth_service.dart` — `GetxService` wrapping `FirebaseAuth`:
      `Stream<User?> authState`, `signUp`, `signIn`, `signOut`, `sendPasswordReset`,
      `reauthenticate`, `deleteAccount`. Maps `FirebaseAuthException` codes to Arabic messages.
- [x] `lib/service/session_controller.dart` — replaces `lib/appData.dart`. Holds the current
      `UserProfile` as an `Rx`. **`appData.dart` is not deleted until Step 2**, because legacy
      screens still read it.
- [x] `lib/service/settings_controller.dart` — theme mode, accent, graphics quality, digit
      style, units. Persisted via prefs.
- [x] `lib/service/performance_probe.dart` — samples `SchedulerBinding.addTimingsCallback` over
      the first ~90 frames; if p95 raster > 12ms, drops a `GraphicsQuality` tier

## 1.5 Design system — `lib/ui/`

### Theme
- [x] `theme/app_colors.dart` — const palette, accent gradients. **No mutable statics** (the
      current `AppColors` has three, reassigned at runtime by the settings screen).
- [x] `theme/app_typography.dart` — the full `TextTheme` from the table in `general.md` §9.5
- [x] `theme/app_spacing.dart` — 4/8pt scale, radii, durations, curves
- [x] `theme/glass_tokens.dart` — sigmas, tint/border alphas, the 4 elevation levels
- [x] `theme/app_theme.dart` — `ThemeData` dark (and a light stub for Step 4).
      `useMaterial3: true`, app-level `fontFamily: 'Cairo'`, plus `appBarTheme`,
      `elevatedButtonTheme`, `inputDecorationTheme`, `bottomNavigationBarTheme`,
      `cardTheme`, `dividerTheme` — so the ~28 inline one-off `ButtonStyle`s stop being needed.

### Glass
- [x] `glass/glass_surface.dart` — the **one** `BackdropFilter` primitive. `ClipRRect` +
      `RepaintBoundary` + `TileMode.mirror`. Includes the **debug-only live-instance counter
      that `assert`s when more than 2 are mounted.**
- [x] `glass/glass_card.dart` — deliberately *fake* glass: tint gradient + hairline border +
      specular highlight + shadow, **no filter**. This is what every list card uses.
- [x] `glass/glass_panel.dart` — real blur. App bar, nav bar, sheets, dialogs only.
- [x] `glass/glass_scaffold.dart` — aurora + safe area + panel composition

### Background
- [x] `background/aurora_background.dart` — 3–4 radial-gradient blobs on 18–30s ping-pong
      controllers, one `CustomPaint`, one `RepaintBoundary`, plus the tiled noise overlay at ~4%

### Motion
- [x] `motion/staggered_entry.dart` — 40ms per item, **capped at 8**
- [x] `motion/pressable.dart` — `AnimatedScale` 0.97, 120ms, optional haptic
- [x] `motion/transitions.dart` — a custom fade + 0.98→1.0 scale `CustomTransition`
      (direction-agnostic, so it has no RTL pitfalls)
- [x] `motion/hero_tags.dart` — centralized tag builders so tags can't drift apart

### Components
- [x] `components/calorie_ring.dart` — sweep-gradient `CustomPainter`, 3 macro sub-rings,
      `MaskFilter.blur` glow, `tabularFigures()` center number
- [x] `components/macro_bar.dart`, `glass_button.dart`, `glass_field.dart`, `glass_chip.dart`,
      `gram_stepper.dart`, `empty_state.dart`, `error_state.dart`, `async_view.dart`

## 1.6 App infrastructure

- [x] `lib/app/app_routes.dart` — route name constants
- [x] `lib/app/app_pages.dart` — `GetPage` list with bindings, `defaultTransition`
- [x] `lib/app/bindings/` — one `Binding` per feature. This is what fixes controllers being
      constructed twice via nested `GetBuilder(init:)` and `FutureBuilder(future: ...)` inside
      `build`.
- [x] `lib/l10n/app_strings.dart` — `static const` Arabic strings. Kills the English leakage
      (`"there are no data "` ×4, `"there are no meals"`, `"error"`, `"title"` ×6).
- [x] `lib/ui/legacy_ltr_shim.dart` — `Directionality(textDirection: ltr)` wrapper for every
      not-yet-rebuilt legacy screen

## 1.7 `main.dart`

- [x] Bootstrap per `general.md` §8 — Firestore persistence, `PrefsService`, `AuthService`
- [x] Add `localizationsDelegates` (`GlobalMaterialLocalizations`, `GlobalWidgets`,
      `GlobalCupertino`) and `supportedLocales: [Locale('ar'), Locale('en')]`. The existing
      `locale: Locale('ar')` is currently **inert** without these.
- [x] Wire theme, routes, `defaultTransition`
- [x] Fix `title: 'Localizations Sample App'` — a leftover from the Flutter sample, currently
      shown as the Android task title

## 1.8 Screens

- [x] `page/splash/` — replaces `loading_Screen.dart`, which currently does
      `jsonDecode(SP.getString("user").toString())` on a possibly-null string. Branded, with a
      real error/retry state (a Firestore failure currently leaves the spinner running forever).
- [x] `page/onboarding/` — real Firebase signup (email + password + display name), login,
      password reset, then a profile flow collecting **sex** (new field), birth year, height,
      weight, activity level, goal, weekly rate. Ends by animating the computed targets in.
- [x] `page/home/` — `HomeShell`: `IndexedStack` + a glass bottom bar with **real icons and
      labels**. Currently `CustomText` is used *as* the icon with `label: ""`, and selection is
      faked by swapping font size 14→18. Tab index moves to an `Rx` in `HomeController`, out of
      the global static `appData.pageIndex`. Four tabs: اليوم / وجباتي / السوق / حسابي, plus a
      center FAB. Tabs are placeholders in this step. **Exactly one `BackdropFilter` here.**
- [x] `page/dev/gallery_screen.dart` — debug-only `/dev/gallery` rendering every token, glass
      level, button, ring, and motion primitive on one scrollable page
- [x] `/legacy` route keeping the old `MainScreen` reachable, wrapped in `LegacyLtrShim`

---

## Files touched

**Created:** all of `lib/domain/**`, `lib/data/**`, `lib/ui/**`, `lib/app/**`,
`lib/service/{auth,prefs,session,settings,performance_probe}`, `lib/l10n/app_strings.dart`,
`lib/page/{splash,onboarding,home,dev}/**`, `test/domain/**`

**Modified:** `lib/main.dart`, `pubspec.yaml`

**Deleted:** `lib/service/user_auth_repository.dart` (folded into `AuthService`)

**Untouched:** every legacy screen, `lib/appData.dart`, `lib/theme/`, `lib/widget/` — all still
live behind `/legacy` until Step 2.

---

## Reviewable at the end

- The new dark aurora app with the glass shell and animated background
- **Real signup and login** against Firebase
- Onboarding that computes and animates your actual targets from real BMR math
- The `/dev/gallery` page — the full visual direction, judgeable in one scroll
- `/legacy` still opens the old app as a fallback
- `flutter test` green

Data is empty at this point but the schema is live and the look is fully assessable.

## Exit criteria

- [x] `flutter test` green (82 tests)
- [x] `flutter analyze` clean for everything under `lib/domain`, `lib/data`, `lib/ui`, `lib/app`
- [x] `flutter build apk --debug` succeeds
- [x] Sign up with a real email → `users/{uid}` doc appears in Firestore with computed targets
- [x] Kill and relaunch → lands on `/home`, signed in, profile painted from cache with no flicker
- [ ] **Profile-mode raster check on a real mid-range Android** (see risks)

## Risks

1. **`BackdropFilter` jank — measure now, not in Step 4.** Run in profile mode on a real
   mid-range device and check the DevTools raster timeline. Confirm ≤2 blurs and p95 raster
   under budget. If the aurora plus two blurs already janks, the visual direction needs
   re-scoping — and that is vastly cheaper to learn in week one than in week six.
2. **`BackdropFilter.grouped` / `BackdropGroup`** — verify these exist on Flutter 3.41 before
   relying on them. Fall back to two independent blurs if not.
3. **RTL** — the delegates go in here, so `LegacyLtrShim` must wrap every legacy screen in the
   same commit. Without it, every old screen mirrors and breaks at once.
4. **Scope.** This step is large. If it needs splitting, the natural seam is
   1a = domain + data + tests, 1b = design system + shell + auth.
