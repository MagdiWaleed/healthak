# 03 — Screen by Screen

What each screen must *feel* like when this plan is done. Component mechanics reference
01/02. Screens that don't exist yet (marketplace is Step 3) are spec'd now so they're born
with the feeling instead of retrofitted.

---

## Splash — the promise

First 2 seconds decide whether the app feels premium.

1. Screen opens already mid-aurora (native splash background matches `AppPalette.ink`,
   per step 4.7 — coordinate with that task).
2. Blobs converge 15% toward center over 900ms (one-off `speedScale` trick — reuse the
   existing parameter, no new painter).
3. Logo/wordmark fades + scales .92→1 with `gentle` spring; a thin emerald ring draws
   around it once (stroke draw, 600ms) — foreshadowing the calorie ring, the app's symbol.
4. No spinner ever. If auth check exceeds 1.2s, the ring around the logo begins a slow
   breathing pulse — loading disguised as design.

## Onboarding — the story

- Paged flow with the progress indicator as a **filling arc**, not dots — the user
  completes their first "ring" before they ever see the real one. Chekhov's gun.
- Each page: one oversized numeral or glyph (height/weight/goal), glass card at L2,
  content staggered in. Page transitions use directional push (02 §2).
- The goal-selection page previews the calorie ring filling to the computed target as the
  user picks — *their* number appears inside it. First hit of personalization.
- Final page: "تجهيز يومك الأول" — ring fills to 100%, `bouncy` completion pop, `goal`
  haptic-lite (medium + light), auto-advance. The user has already won once before
  tracking a single calorie.

## Today — the hero screen

This screen carries the app. Priority order of everything on it:

1. **The ring is the sun.** Collapsing header (02 §5): big and central at rest, shrinking
   into the app bar on scroll, never disappearing — progress is always visible.
2. **Streak flame** beside the date (data: consecutive days with ≥1 eaten item — logic in
   the day controller, pure Dart). Flame glyph scales with streak length (1.0 → 1.3 cap),
   gentle idle breathing (scale ±3%, 2.4s period), `bouncy` pop + `step` haptic when it
   increments. At 7/30 days it gains a small badge. Milestones are cheap; ship 7/30/100.
3. **Week strip**: sliding selected pill, swipe-snapping (02 §5). Days with logged data
   get a micro-ring under the date (4px stroke) — the whole week read at a glance.
4. **Item rows**: the eat-toggle moment (02 §3). Meal groups collapse/expand with
   `gentle` spring on the `groupLabel` header; collapsing plays a soft `step` haptic.
5. **Empty day** (no items planned): not a dead `EmptyState` — an invitation. Ambient
   slow-pulsing ring outline + copy «يومك فارغ… أضف أول وجبة» + the CTA button breathing
   (scale ±2%). Pulsing stops on first add, forever replaced by the real ring's life.
6. **Midnight/day change**: if the app is open across midnight, the ring drains with a
   600ms reverse sweep, streak pops, and a «يوم جديد، بداية جديدة» chip slides in. A tiny
   theatrical reset moment instead of a silent data swap.

## Meal Editor — the workshop

- Hero flight from the My Meals card into the editor header (02 §2).
- Component rows: spring-apart drag reorder (02 §5), swipe actions (02 §6).
- **Auto-balance solver** (the "intelligent" feature): on tap, each affected row's grams
  value does a `TickerNumber` roll to its new value with 40ms stagger down the list, rows
  whose value changed flash emerald tint for 600ms, undo chip slides up with `land`
  haptic. The stagger is what makes it feel like the app *thought*.
- Nested meal rows get a subtle L1 inset + connecting hairline to their parent —
  hierarchy you can see, no blur needed.

## Marketplace (Step 3 — spec'd now)

- Grid cards at L1 with parallax + fling tilt (02 §5).
- Tap card → hero flight to detail. The kcal number and macro bars are shared hero
  elements — they fly too, not just the card shell.
- **Copy to library — the treasure moment:** on confirm, the detail card scales down and
  *flies* along an arc toward the My Meals tab icon (custom `Overlay` flight, 500ms,
  easeInCubic then easeOutCubic on the vertical), tab icon does the 1→1.15→1 pop with
  `land` haptic, then a toast «أُضيفت إلى وجباتك». This single animation is what makes
  copying feel like collecting.
- Like button: heart bursts with 6 micro-particles (reuse `burst_particles.dart` with a
  smaller config — do not write a second particle system).

## History — the memory

- Month calendar: each day cell carries a micro-ring (completion %) instead of a dot —
  consistent visual language. Month swipe cross-fades + slides directionally.
- Tapping a day: cell expands (`gentle`) into the day summary card in place (not a route
  push for a glance; route push only for full detail).
- Streaks of goal-met days render as connected emerald segments between cells — the
  calendar itself shows chains. (Chains are the addiction mechanic; render them proudly.)

## Profile — the mirror

- Before/after target diff cards animate between old and new values with `TickerNumber`
  when the user edits stats — they *watch* their plan recompute.
- Bodyweight chart (when Step 4 lands it): line draws on with 800ms stroke animation on
  first open, points pop in with 30ms stagger.

## Guest preview

- Everything above visible but read-only; interactions that need an account trigger the
  sign-up sheet with the drift-up transition and copy tuned to what they just tried to do
  («سجّل لتبدأ التتبع» after trying to tick an item). The forbidden fruit is the funnel.
