# 01 — Design Language

Token-level upgrades to `lib/ui/theme/` and `lib/ui/glass/`. Everything here is a value or
a recipe — no component specs (those are in 02 and 03).

---

## 1. Reactive color — `MoodPalette`

New file: `lib/ui/theme/mood_palette.dart`.

The existing `AppPalette` stays as the **static base**. On top of it, a `MoodPalette` is
computed from day progress and interpolated over 600ms whenever progress crosses a band
boundary (so eat-toggles don't strobo the background):

```dart
enum DayMood { fresh, building, bloom, over }
```

| Mood | Progress | Emerald lerp target | Aurora alpha mult | Aurora speed mult | Ring accent |
|---|---|---|---|---|---|
| `fresh` | 0–30% | desaturate(emerald→teal 40%) | 0.85 | 1.0 | emerald |
| `building` | 30–90% | emerald (unchanged) | 1.0 | 1.15 | emerald→mint gradient |
| `bloom` | goal ±5% | lerp(emerald→amber 25%) | 1.2 | 1.0, + breathing amp ×1.5 | mint with gold specular |
| `over` | >105% | violet/amber dusk | 0.9 | 0.9 | amber (existing behavior) |

- Band boundaries are **hysteretic** (±3%) so hovering at 30% doesn't flip-flop.
- `MoodPalette` is consumed by `ReactiveAurora` (02 §7) and by `CalorieRing`'s accent
  shader. Nothing else reads it — do not sprinkle mood colors through random components.
- All lerps via `Color.lerp` on the *blob colors* before painting; painter cost unchanged.

## 2. Glass elevation scale — replace flat tints

Extend `GlassTokens` (keep existing names, add):

```dart
// New
static const specularSweepDeg = 30.0;   // border highlight arc width
static const innerGlowAlpha   = 0.06;   // top inner highlight on panels
static const refractionShift  = 2.0;    // px the border gradient rotates per 100px scroll
static const pressedTintDelta = 0.05;   // tint lightens when pressed (glass "gives")
```

Elevation levels (use consistently; today `GlassCard`/`GlassPanel` differ ad hoc):

| Level | Use | Tint | Border alpha | Shadow |
|---|---|---|---|---|
| L0 flush | rows inside a card | cardTint × 0.6 | 0.12 | none |
| L1 card | list cards, day items | cardTint | borderAlpha | 8dp, alpha .25 |
| L2 panel | sheets, dialogs | panelTint | 0.26 | 18dp, alpha .3 |
| L3 hero | calorie ring surround, celebration | panelTint + .04 | 0.34 w/ gradient border | 32dp + colored glow |

**Colored glow rule:** shadows at L3 use the mood accent at alpha .18, blur 24. This is
the "glass emits light" effect — cheap (`BoxShadow`, not blur filter).

## 3. Specular life — `SpecularBorder`

New painter in `lib/ui/glass/specular_border.dart`:

- A glass border whose brightest arc (width `specularSweepDeg`) sits at the corner nearest
  the *imaginary light source*.
- Light source = `Alignment(-0.7, -0.9)` by default; shifted by scroll offset via
  `refractionShift` and by drag position while a card is pressed/held.
- Implementation: `BoxDecoration` gradient border (sweep gradient with a bright stop),
  repainted only when a `ScrollNotification` or drag delta changes the angle by > 2°.
  Throttle with a `ValueNotifier<double>` per screen, **not** per card — one notifier
  drives all cards via the inherited widget so 30 cards don't each subscribe to scroll.

## 4. Typography moments

`AppTypography` gains three display roles (Arabic-first; numerals always tabular):

| Role | Use | Spec |
|---|---|---|
| `heroNumber` | ring center, streak count | w900, size = container × .19, letterSpacing -1, tabular |
| `celebration` | goal-reached headline | w800, 28sp, mint→emerald gradient shader on text |
| `whisper` | secondary stats | w500, 13sp, muted at alpha .8 |

- Number changes animate: old digit slides up + fades out, new digit slides in from below,
  250ms, `Curves.easeOutCubic`. Wrap in a `TickerNumber` widget
  (`lib/ui/components/ticker_number.dart`) so every counter in the app shares the behavior.
- Arabic-Indic vs Western digits stays a step-4 setting; `TickerNumber` must respect it.

## 5. Haptic vocabulary — `lib/ui/feedback/haptics.dart`

One file, one enum, one function: `HapticPhrase.play(AppHaptics.tick)` etc. Centralizing
means we can tune the whole app's feel in one place and respect a "haptics off" setting.

| Phrase | Where | Pattern |
|---|---|---|
| `tick` | eat-toggle ON | `selectionClick` → 40ms → `lightImpact` |
| `untick` | eat-toggle OFF | `selectionClick` only (quieter — removing is less rewarding) |
| `step` | gram stepper, day strip swipe | `selectionClick` (rate-limited to 1/80ms) |
| `lift` | long-press drag start, card grab | `mediumImpact` |
| `land` | drag drop, sheet settle | `lightImpact` |
| `goal` | goal reached | `mediumImpact` → 80ms → `heavyImpact` → 120ms → `mediumImpact` |
| `error` | invalid input, failed save | `heavyImpact` ×1 + red edge flash on the field |
| `celebrate` | confetti moment | `goal` phrase + trailing `selectionClick` ×3 at 60ms intervals |

Rate limiting is mandatory: the stepper can fire 10/s on a fling; queue coalescing in
`haptics.dart`, never at call sites.

## 6. Grain, vignette, and the "expensive" look

- `GrainTexture` opacity rises slightly on `bloom` mood (0.04 → 0.055) — filmic warmth.
- Vignette strength is mood-reactive (see 02 §7) — deeper vignette at `fresh`, opening up
  at `bloom`. Literal "the world brightens as you succeed."
- No new raster assets. If a glow sprite is needed (celebration), generate procedurally
  like `grain_texture.dart` does.

## 7. What is explicitly NOT in the language

- No neon/cyberpunk. Accent stays emerald/mint/amber/violet.
- No white cards, no Material elevation shadows on glass (shadows must be colored glows).
- No emoji in UI chrome. Emoji allowed only inside celebration copy strings.
- No sound effects in phases 1–4. Haptics carry the feel; audio is a phase-5 question.
