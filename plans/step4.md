# Step 4 — Polish

**Goal:** make it feel finished. Motion, real settings, performance, the final RTL sweep,
accessibility.

**Status:** not started

**Depends on:** Steps 1–3
**Blocks:** nothing

---

## 4.1 Motion pass

- [ ] Audit every list for `StaggeredEntry` (capped at 8 items)
- [ ] Tune hero flights — timing, curve, and the shape morph between card and detail
- [ ] Calorie ring: the goal-reached pulse + glow, and the hue shift when over target
- [ ] Page transition timing across the whole app
- [ ] Haptics — `selectionClick` on eat-toggle and gram stepper, `mediumImpact` on goal reached
- [ ] Sheet open/close blur ramp (discrete, ≤300ms — **never** on a continuous controller)
- [ ] Empty states get a small looping ambient animation
- [ ] Verify every animation is disabled under `MediaQuery.disableAnimations`

## 4.2 Settings — `lib/page/settings/`

Replaces `setting/setting_screen.dart`: six identical `ElevatedButton`s that mutate a global
static, **every one labelled with the literal English word `"title"`**, not persisted, lost on
restart, in a `Column` with no scroll view.

- [ ] **المظهر** — accent gradient swatch row, dark / light / system
- [ ] **التأثيرات البصرية** — graphics tier (عالية / متوسطة / موفرة), reduce motion
- [ ] **الوحدات والأرقام** — kg/lb, Arabic-Indic (١٢٣) vs Western (123) digits
- [ ] **الأهداف** — manual target override (kcal + macro percentages), protein g/kg
- [ ] **الحساب** — change password, sign out, delete account
- [ ] **عن التطبيق** — version, licenses
- [ ] All persisted via `SettingsController` → prefs, applied reactively

## 4.3 Light theme

- [ ] Fill in the light `ThemeData` stubbed in Step 1
- [ ] Glass on light needs a **much** higher tint alpha (≈.55 vs .08) and a darker border, or it
      disappears entirely
- [ ] Aurora blobs need lower alpha and lighter hues
- [ ] Re-check contrast on every surface, against the lightest aurora state
- [ ] System theme following

## 4.4 Performance

- [ ] Profile-mode run on a real mid-range Android with the DevTools raster timeline
- [ ] Verify ≤2 `BackdropFilter`s at every point in the app (the debug assert should already
      guarantee this — confirm it never fires)
- [ ] `RepaintBoundary` audit around the aurora, the ring, and list items
- [ ] `const` constructor audit
- [ ] Confirm every long list is virtualized (`ListView.builder` / slivers, not a `for` loop in
      a `Column` — the pattern used in 10 places in the old code)
- [ ] Confirm no `Future` is created inside `build` (4 old screens did this, refetching on every
      rebuild)
- [ ] Measure and record cold start; target < 2s to first frame
- [ ] Verify the `PerformanceProbe` tier drop actually triggers on a low-end device

## 4.5 RTL sweep

- [ ] Delete `lib/ui/legacy_ltr_shim.dart` — by now nothing should use it
- [ ] Grep `lib/` and fix any survivors:
      - `Positioned(` → `PositionedDirectional`
      - `EdgeInsets.only(left|right` → `EdgeInsetsDirectional.only(start|end`
      - `Alignment.centerLeft|centerRight` → `AlignmentDirectional.centerStart|centerEnd`
      - `BorderRadius.only(topLeft` → `BorderRadiusDirectional`
      - `TextAlign.left|right` → `TextAlign.start|end`
- [ ] Verify every screen with the debug LTR toggle, side by side
- [ ] Check custom back arrows flip (the Material leading button does automatically; custom ones
      do not)
- [ ] Check reorderable drag handles land on the correct side

## 4.6 States and resilience

- [ ] Empty, loading, error, and **offline** states on every screen via `AsyncView`
- [ ] An offline banner when Firestore is disconnected
- [ ] Retry affordances everywhere — never a dead end
- [ ] Confirm no untranslated English is left anywhere in the UI
- [ ] Arabic copy review pass: fix "معلواتي", the meaningless snackbar title "دن", and any
      screen whose AppBar title was copy-pasted from another screen

## 4.7 Branding

- [ ] App icon (`flutter_launcher_icons`)
- [ ] Native splash matching the aurora (`flutter_native_splash`)
- [ ] Fix the Android task title — `main.dart` currently says
      `title: 'Localizations Sample App'`, a leftover from the Flutter sample
- [ ] Consider renaming the package from `com.example.diet_app2`. **This breaks the existing
      Firebase Android app registration and requires a new `google-services.json`** — ask the
      user before doing it.

## 4.8 Accessibility

- [ ] Contrast audit against the darkest and lightest aurora states
- [ ] All tap targets ≥ 48dp
- [ ] `Semantics` labels on icon-only buttons and on the calorie ring
- [ ] Test with TalkBack
- [ ] Verify the app is usable at 200% text scale — glass cards must grow, not clip
- [ ] Honour `MediaQuery.accessibleNavigation`

## 4.9 Deferred from earlier steps

- [ ] History trends, if they were moved out of Step 2
- [ ] Bodyweight logging + chart
- [ ] Optional cost display in meal detail, where a food has `pricePer100`
      *(all that survives of the dropped `diet_details_screen.dart`)*

---

## Reviewable at the end

A finished app: fast, smooth, correctly mirrored, themed both ways, accessible, with real
settings and no placeholder text anywhere.

## Exit criteria

- [ ] Profile-mode p95 raster under budget on a real mid-range device
- [ ] No `BackdropFilter` count assert ever fires
- [ ] Every screen verified in RTL, in both themes, at 200% text scale
- [ ] Zero untranslated English in the UI
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] `flutter build apk --release` succeeds and installs

## Risks

1. **The light theme is not a recolor.** Glass has to be re-tuned from scratch — the alpha
   values that make it read on dark make it invisible on light. Budget real time for it.
2. **Package rename breaks Firebase.** Only do it if the user explicitly asks, and re-download
   `google-services.json` immediately after.
3. **Polish expands without a boundary.** Timebox each subsection.
