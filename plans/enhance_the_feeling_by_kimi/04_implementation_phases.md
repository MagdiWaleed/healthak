# 04 — Implementation Phases

Ordered, file-by-file. Each phase ends reviewable and shippable. Do not start a phase
before the previous phase's exit criteria pass. Record deviations in `plans/PROGRESS.md`.

Executor note: this plan touches **only** `lib/ui/**`, `lib/l10n/app_strings.dart`, and
small reactive state additions to existing GetX controllers (`mood`, `streak`,
`goalCelebratedToday` flags). No domain, data, Firestore, or routing-structure changes.

---

## Phase 1 — The nervous system (foundations)

**New files:**
- `lib/ui/motion/spring.dart` — spring constants + `SpringScale` widget (02 §1)
- `lib/ui/feedback/haptics.dart` — phrase table + rate limiter (01 §5)
- `lib/ui/theme/mood_palette.dart` — `DayMood`, lerp tables, hysteresis (01 §1)
- `lib/ui/theme/motion_settings.dart` — single gate: `disableAnimations` OR user pref
- `lib/ui/components/ticker_number.dart` — sliding digit swap (01 §4)

**Modified files:**
- `lib/ui/motion/pressable.dart` — internals → `snappy` spring; API unchanged
- `lib/ui/theme/glass_tokens.dart` — add tokens from 01 §2
- `lib/ui/theme/app_typography.dart` — add `heroNumber`, `celebration`, `whisper`
- `lib/l10n/app_strings.dart` — celebration copy pool, new-day chip, empty-day copy

**Exit criteria:** existing screens look identical (foundations are opt-in);
`flutter analyze` adds zero issues; `flutter test` still 96/96; Pressable still passes the
eye test on press/release.

## Phase 2 — The living background

**New files:**
- `lib/ui/background/reactive_aurora.dart` — mood-reactive wrapper (02 §7)
- `lib/ui/glass/specular_border.dart` — scroll-reactive border highlight (01 §3)

**Modified files:**
- `lib/ui/glass/glass_surface.dart`, `glass_card.dart`, `glass_panel.dart` — elevation
  levels L0–L3, specular border, pressed-tint delta
- Shell/scaffold: one scroll-angle `ValueNotifier` per screen feeding all specular borders
- Today controller: expose `mood` + `progress` as `Rx`; wire to ReactiveAurora

**Exit criteria:** aurora visibly warms as items are ticked; vignette opens at bloom;
specular highlight drifts on scroll; **profile-mode raster p95 unchanged vs. baseline
(measure both)**; blur assert never fires.

## Phase 3 — The moments (core reward loop)

**New files:**
- `lib/ui/motion/eat_toggle/eat_check.dart`
- `lib/ui/motion/eat_toggle/burst_particles.dart`
- `lib/ui/motion/eat_toggle/ring_ripple.dart`
- `lib/ui/motion/celebration.dart` — goal sequence + confetti-lite (02 §4)

**Modified files:**
- Today item row → full eat-toggle choreography (02 §3)
- `calorie_ring.dart` — ripple overlay hook, glow bloom, double-pulse, over-target arc
- `macro_bar.dart` — staggered fill API
- Day controller: `goalCelebratedToday` edge-trigger flag
- Week strip: sliding pill, micro-rings under dates, swipe snap
- Tab bar: sliding glass pill + icon pop

**Exit criteria:** the 02 §3 timeline plays start-to-finish on tap; goal crossing fires
the full 02 §4 sequence exactly once; untoggle is the flat version; all haptics per
01 §5; reduced-motion mode swaps to instant states; **raster p95 still under budget while
tapping items rapidly** (stress: 20 fast toggles, watch for overlay leaks).

## Phase 4 — Connection & depth (navigation + scroll)

**Modified files:**
- `lib/ui/motion/transitions.dart` — fade-through-scale, drift-up sheet, directional
  push, hero `flightShuttleBuilder` (02 §2)
- Today: collapsing ring header sliver (02 §5)
- `staggered_entry.dart` — directional offset + rotate
- `gram_stepper.dart`, `numeric_stepper.dart` — `TickerNumber` + directional slides
- Rows app-wide: swipe actions (02 §6), spring-apart reorder in meal editor
- Splash: logo materialization (03 §Splash); onboarding: arc progress + ring preview
- Pull-to-refresh: emerald ring indicator

**Exit criteria:** every route change uses the new vocabulary; ring collapses on scroll
without jank; hero flights land cleanly in RTL; walk the full step-2 nine-step loop
end-to-end on emulator and it *feels* like a different app with zero functional change.

## Phase 5 (optional, needs user approval) — Delight extras

- Rive/Lottie mascot for empty states — **new dependency, ask first**
- Sound design layer (soft glass ticks) — ask first
- Marketplace treasure-flight (03 §Marketplace) — lands with Step 3 regardless of
  approval, since it reuses phase-3 particles

---

## Verification protocol (run after EVERY phase)

1. `flutter analyze` — zero **new** issues; all touched files clean.
2. `flutter test` — all green (add golden tests for `MoodPalette` lerp bands and the
   edge-trigger logic; painters get `shouldRepaint` unit tests where cheap).
3. `flutter build apk --debug` succeeds.
4. **Profile mode on a real mid-range device** (not emulator): DevTools raster timeline
   while (a) scrolling Today, (b) toggling 5 items, (c) triggering goal celebration.
   p95 raster ≤ 8ms; no frame > 16ms during celebration.
5. Blur audit: debug BackdropFilter counter never exceeds 2; grep confirms no
   `BackdropFilter` inside any `ListView`/`CustomScrollView`.
6. RTL walk: `android:forceRTL` + in-app locale — every directional animation mirrors.
7. Reduced motion: enable `disableAnimations` — every flow still completes, states still
   correct, zero stuck overlays.
8. Record p95 numbers per phase in `plans/PROGRESS.md`.

## Order-of-attack cheat sheet for GPT-terra

```
Phase 1: spring.dart, haptics.dart, mood_palette.dart, motion_settings.dart,
         ticker_number.dart  → wire nothing yet, unit test the pure parts
Phase 2: reactive_aurora.dart, specular_border.dart → glass widgets → Today wiring
Phase 3: eat_toggle/* , celebration.dart → Today row → ring → strip → tab bar
Phase 4: transitions.dart → collapsing header → steppers → swipe actions → splash
```
