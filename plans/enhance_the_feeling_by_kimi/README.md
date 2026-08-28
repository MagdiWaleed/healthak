# Enhance The Feeling — by Kimi

**A sensory-design overhaul plan for Healthak.** Not new features. Not a reskin. This is the
plan that makes the app *feel* alive — the difference between a tool people use and an app
people open just to touch.

**Owner of this vision:** the user (the boss). **Executor:** GPT-terra (or any agent).
**Read order:** this file → `01_design_language.md` → `02_motion_system.md` →
`03_screen_by_screen.md` → `04_implementation_phases.md` → `05_do_not_break.md`.

---

## The one-sentence brief

> **Living Glass.** The app's light reacts to the user's body, progress, and touch — and
> every single action, no matter how small, gets a physical, satisfying answer.

## Why the current build feels flat (diagnosis)

The foundation is genuinely good — aurora background, glass system, pressable, staggered
entries, a well-built calorie ring. But:

1. **Nothing celebrates.** Ticking a meal — the action the user does 5–10 times a day, the
   entire point of the app — produces a checkbox state change. No burst, no haptic phrase,
   no ring reaction. The core loop has no reward. Apps are addictive when the *smallest*
   action feels like a win.
2. **The light is indifferent.** The aurora drifts on its own schedule whether the user is
   at 0% or 100% of goal. The ring turns amber when over target but nothing else notices.
   The app has one emotional register: neutral.
3. **Motion is cosmetic, not physical.** Fixed 900ms tweens, one fade+scale route
   transition, no springs, no drag physics, no scroll-linked movement. It looks animated
   but doesn't *feel* simulated.
4. **Glass is cold.** Flat tints, static borders, no specular life. Real glass catches
   light as it moves. Ours doesn't move.
5. **Screens don't connect.** No hero flights, no shared elements. Navigation is
   teleportation.

## The design philosophy — three laws

### Law 1: Every touch gets a physical answer

Nothing changes state silently. Every tap, toggle, drag, and swipe answers with a
coordinated **motion + haptic + (subtle) light** phrase within 100ms of the touch. The
vocabulary is in `02_motion_system.md` §Haptics. An interaction with no defined phrase is a
bug against this plan.

### Law 2: The app has a mood, and the mood is your progress

The aurora is not wallpaper. It is the user's day, rendered as weather:

- **0–30% of goal:** cool, dim, slow drift. Emerald desaturated toward teal. Calm.
- **30–90%:** warming. Saturation rises, drift speeds slightly, mint tones arrive.
- **Goal reached (±5%):** a slow golden-green "bloom" breathes through the field for the
  rest of the day.
- **Over target:** not punishment — the field cools to violet/amber dusk. Informative,
  never angry.

Implementation: `ReactiveAurora` (phase 2) — `AuroraBackground` gains a `mood` parameter
(0..1 progress + over-target flag) driving color lerps. Same painter, same budget, zero new
blur.

### Law 3: Depth is earned, not painted

Glass reads as glass only when it sits *in front of* something that moves. Every screen
gets a parallax relationship: background slow, content at scroll speed, foreground accents
(ring, hero cards) floating slightly against scroll. Specular border highlights shift a few
degrees as the user scrolls. Nobody consciously notices. Everybody feels it.


## The emotional journey (per session)

| Moment | Feeling | Mechanism |
|---|---|---|
| Cold open | "Oh, this is beautiful" | Splash: logo materializes out of the aurora |
| First scroll | "It's alive" | Parallax + specular shift + staggered entries |
| First eat-toggle | "That was *satisfying*" | Check morph → burst → ring ripple → haptic phrase |
| Ring fills | "I'm getting somewhere" | Counter ticks up, ring head glows, aurora warms |
| Goal reached | "I won today" | Ring pulse → glow bloom → confetti-lite → persistent bloom |
| Marketplace copy | "I found treasure" | Card lifts, flies to My Meals tab, landing pulse |
| Tomorrow | "Fresh start, streak intact" | Clean ring + streak flame + yesterday's summary card |

## Non-negotiables (override every creative idea in this folder)

1. **Blur budget is law.** ≤2 simultaneous `BackdropFilter`s, zero inside scrolling
   viewports. The debug assert stays. Every glassy effect here is gradients, borders, and
   pre-computed assets — **never** new blur.
2. **60fps on mid-range or it doesn't ship.** Profile-mode raster check after every phase.
3. **RTL first-class.** Every directional animation spec'd start/end, never left/right.
4. **`MediaQuery.disableAnimations` kills all non-essential motion** via one
   `MotionSettings` gate (phase 1). Reduced-motion users get instant state changes with
   identical information content.
5. **`lib/domain/` stays pure Dart.** Mood/streak *logic* may live in domain/services; all
   rendering in `lib/ui/`.
6. **No new animation packages in phases 1–4.** No Rive, no Lottie, no confetti packages.
   Everything custom-painted. (Optional phase 5 may propose Rive for empty states — needs
   user approval.)

## Where this slots into the master plan

```
Step 2 (done) →  ★ THIS PLAN (phases 1–4)  →  Step 3 (marketplace)  →  Step 4 (polish)
```

Touches only `lib/ui/**`, screen-level wiring in `lib/page/**`, and small controller
additions (streak/mood). No data-model, Firestore-schema, or locked-decision changes.
`step4.md` remains the hygiene pass; its §4.1 motion items are **superseded and expanded**
by `02_motion_system.md` — do them from here instead.

## Files in this folder

| File | Contents |
|---|---|
| `01_design_language.md` | Tokens: reactive color, glass elevation, specular, typography, haptic vocabulary |
| `02_motion_system.md` | Full choreography spec with exact values: springs, transitions, eat-toggle moment, celebration, scroll physics |
| `03_screen_by_screen.md` | Per-screen directives: splash, onboarding, today, editor, marketplace, history, profile |
| `04_implementation_phases.md` | Ordered file-by-file task list, exit criteria, performance verification protocol |
| `05_do_not_break.md` | Constraint checklist to paste at the top of the executor's context |
