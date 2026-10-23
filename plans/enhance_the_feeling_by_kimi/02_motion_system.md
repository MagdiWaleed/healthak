# 02 — Motion System

Every animation in the app, spec'd with exact values. The executor implements these
verbatim first, then tunes by feel — but every deviation gets recorded in
`plans/PROGRESS.md` Deviations, per repo convention.

**Global gate:** all of this reads `MotionSettings.enabled`
(`MediaQuery.disableAnimations` OR user setting). When disabled: duration = 0, springs
snap, particles/celebrations show their final frame for 400ms then clear. Information is
never lost, only motion.

---

## 1. Springs — `lib/ui/motion/spring.dart`

Replace fixed tweens on **interactive** elements (not ambient ones). Wrapper widget:

```dart
class SpringScale extends StatefulWidget { ... }   // like Pressable but spring-driven
```

Spring constants (`SpringDescription`):

| Name | Mass | Stiffness | Damping | Use |
|---|---|---|---|---|
| `snappy` | 1 | 500 | 28 | button press, chip select |
| `bouncy` | 1 | 300 | 14 | check toggle, badge pop, stepper |
| `gentle` | 1 | 180 | 22 | card settle, sheet, hero-adjacent |
| `wobbly` | 1 | 220 | 10 | celebration elements only — never on navigation |

`Pressable` is upgraded, not replaced: keep its API, swap its internal controller for
`SpringSimulation` with `snappy`, keep the asymmetric press/release feel (press bites in
<110ms; release is the spring). Haptic calls stay where they are.

## 2. Route transitions — replace `HealthakTransition`

| Transition | Where | Spec |
|---|---|---|
| **Fade-through-scale** | tab switches in shell | outgoing: fade→0 + scale 1→1.04, 150ms easeIn; incoming: fade from 0 + scale .96→1, 210ms easeOutCubic; 60ms overlap |
| **Hero flight** | meal card → meal editor, market card → detail | tags exist (`hero_tags.dart`); add `flightShuttleBuilder` so the card's glass tint cross-fades into the detail header; 380ms `easeInOutCubic` |
| **Drift-up sheet** | dialogs, pickers, stepper sheets | slide from bottom 12% + fade, spring `gentle`; scrim opacity 0→.45, ≤300ms, discrete controller (never continuous blur) |
| **Directional push** | forward nav in flows (onboarding, add-food) | RTL-aware via `Directionality`: in RTL, new pages slide in from the **left**; 300ms `easeOutCubic`; outgoing page parallaxes at 30% speed |

GetX: per-route via `customTransition`. Keep one file: `lib/ui/motion/transitions.dart`.

## 3. THE MOMENT — eat-toggle choreography (the addictive core)

The most important spec in this folder. The user does this 5–10×/day. It must feel like
popping bubble wrap made of light.

**Trigger:** tap the check circle on a `FrozenItem` row (Today tab).
**Timeline (~700ms total):**

| t (ms) | Element | Action |
|---|---|---|
| 0 | haptic | `HapticPhrase.tick` starts |
| 0–180 | check circle | scale 1→0.6 (`snappy`), ring stroke fills to solid emerald disc |
| 120–320 | check glyph | checkmark stroke draws on (200ms easeOut), disc springs 1.15→1.0 (`bouncy`) |
| 180–500 | **particle burst** | 10–14 particles from the check center: 2–3px circles + 4px sparkles; emerald/mint/white; velocity 60–180 px/s radial, gravity 300 px/s², drag .92/frame; fade over final 150ms; staggered 320–500ms lifetimes |
| 0–400 | row | bg tint lerps to emerald α.10; kcal text does `TickerNumber` swap; row nudges 4px toward start edge and back (`snappy`) |
| 200–600 | calorie ring | consumed arc extends (existing tween) **plus** ripple ring from the arc head: stroke circle expanding +20px, alpha .5→0, 400ms; head dot glows (shadowBlur 8→20→8) |
| 300–700 | macro bars | the three `MacroBar`s fill with 60ms stagger |

**Untoggle** is intentionally flatter: disc springs back to outline, tint fades, ring
retracts. No particles, `untick` haptic only. *Doing* feels better than undoing —
deliberate behavioral design.

**Implementation:** `lib/ui/motion/eat_toggle/` — `eat_check.dart` (morphing check),
`burst_particles.dart` (one `CustomPainter`, one controller, particles precomputed with a
seeded `Random` so replay is identical), `ring_ripple.dart` (overlay on the ring).
Particles paint in an `Overlay` entry so they escape row bounds; disposed on completion.
`RepaintBoundary` around the particle painter only.

## 4. Goal-reached celebration

**Trigger:** `consumed >= target × .95` crossing from below — edge-triggered, once per day
per session (flag on the day controller so rotation doesn't replay).

**Sequence (~1.6s):**

1. Ring double-pulse: scale 1→1.03→1.0→1.02→1.0 over 600ms; accent lerps to bloom palette.
2. Glow bloom behind ring: radial gradient alpha 0→.35→.18, radius 1×→1.6× ring, 900ms
   easeOut; persists at .18 while mood = `bloom`.
3. **Confetti-lite:** 24 particles from the ring head, initial velocity along the arc
   tangent then gravity; circles + 4-point stars, 4 palette colors, stars rotate;
   700–1100ms staggered lifetimes. One painter, one controller. A whisper, not a parade.
4. `HapticPhrase.goal` at t=0.
5. Copy fades in under the ring (`AppTypography.celebration`), random from
   `app_strings.dart` pool: «وصلت لهدفك اليوم! 🎯» / «يوم مثالي، استمر!» /
   «الحلقة اكتملت ✨» (Arabic copy review in step 4; emoji inside copy only).
6. Aurora cross-fades to `bloom` mood over 600ms.

**Over-target:** no celebration, no scolding. Ring head turns amber, thin amber outer arc
shows overshoot magnitude, aurora cools to `over`. Neutral copy: «تجاوزت الهدف بـ 240 سعرة».


## 5. Scroll-linked motion

| Where | Effect |
|---|---|
| Today tab | Collapsing header: ring shrinks 200→96px into the app bar as you scroll (sliver layout); the painter renders at both sizes, so it's cheap |
| All screens | `SpecularBorder` light angle shifts with scroll (01 §3) |
| Week strip | Selected-day pill slides (animated alignment, 250ms easeOutCubic); day list cross-fades; strip swipes snap with `bouncy` spring on release |
| Marketplace grid | Card parallax: content translates at −4% of scroll delta; tilt ±2° toward fling direction, spring back on settle |
| Meal editor | Dragging a component row: lifted row scales 1.02, shadow blooms (L3 glow), siblings spring apart; drop = `land` haptic + `gentle` settle |

## 6. List & micro-motion upgrades

- `StaggeredEntry`: offset becomes directional (from `start` edge: `Offset(±.06, .04)`
  resolved via `Directionality`), plus slight rotate (−1.5°→0). Cap stays at 8.
- Swipe actions on rows: background reveals icon + label as the row translates
  (RTL-aware), commits at 40% width with `lift` haptic, springs back otherwise.
- Pull-to-refresh: custom indicator — a small emerald ring that draws with pull distance
  and spins on release (matches the calorie ring's visual language).
- Tab bar: active indicator is a glass pill sliding with `bouncy` spring; active tab icon
  pops 1→1.15→1 on selection.
- `GramStepper`: value uses `TickerNumber`; + slides digits up, − slides them down.

## 7. ReactiveAurora — `lib/ui/background/reactive_aurora.dart`

Wraps `AuroraBackground`. Input: `DayMood` + progress 0..1. Lerps blob colors, alpha/speed
multipliers, vignette depth per 01 §1. Transition 600ms `easeInOut` on mood change; silent
otherwise — it just passes new blob specs into the existing painter. The aurora must
**never** gain an `ImageFilter`.

## 8. Budget rules

- One active celebration animation at a time; a second trigger joins, not stacks.
- Particle painters: max 2 alive app-wide (one eat burst + one celebration).
- Every painter in this file is wrapped in `RepaintBoundary` with value-equality
  `shouldRepaint`.
- Profile-mode raster check after phase 3 lands all of this (protocol in 04 §Verification).
