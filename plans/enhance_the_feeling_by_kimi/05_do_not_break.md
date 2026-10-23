# 05 — Do Not Break (paste this at the top of the executor's context)

Hard constraints inherited from `AGENTS.md` and `plans/general.md`, plus this plan's own
budget rules. If a creative idea conflicts with anything below, the constraint wins.
Surface the conflict in `plans/PROGRESS.md` Deviations instead of silently choosing.

## Architecture

- `lib/domain/` imports **zero** Flutter. Mood/streak logic may be pure Dart in domain or
  services; all rendering stays in `lib/ui/`.
- No changes to the Firestore schema, security rules, data model, or any "locked decision"
  in `general.md` §2. Celebration/streak state lives in GetX controllers and (if
  persistence is truly needed) SharedPreferences — never a new Firestore field.
- The `male`→`meal` naming law and macro vocabulary (`protein`, `carbs`, `fat`, `kcal`,
  `grams`) apply to every new file.
- New user-facing strings are Arabic and go in `lib/l10n/app_strings.dart`. No inline
  strings, no English leftovers.

## Performance

- **≤2 simultaneous `BackdropFilter`s, zero inside scrolling viewports.** The debug
  counter/assert stays — do not remove or loosen it. All "glass" effects in this plan are
  gradients, borders, and procedural paint.
- Aurora never gains an `ImageFilter`. Ever.
- Every new `CustomPainter` gets `RepaintBoundary` + value-equality `shouldRepaint`.
- Max 2 particle painters alive app-wide. One celebration at a time.
- One scroll-angle `ValueNotifier` per screen for specular borders — never one
  subscription per card.
- No `Future` created inside `build`. No `print()` in new code.

## Motion discipline

- Everything respects the `MotionSettings` gate (`MediaQuery.disableAnimations` OR user
  pref): duration 0, springs snap, celebrations show a static final frame 400ms. Same
  information, no motion.
- Springs and haptics use the central tables (`spring.dart`, `haptics.dart`) — no
  ad-hoc constants scattered in screens. Tuning happens in one place.
- Haptics are rate-limited centrally. Never call `HapticFeedback` directly from a screen.

## RTL

- Every directional value is resolved via `Directionality` / `*Directional` widgets:
  `PositionedDirectional`, `EdgeInsetsDirectional`, `AlignmentDirectional`,
  `TextAlign.start/end`. New code must mirror correctly with zero LTR assumptions.
- Swipe directions, page pushes, stagger origins, and the treasure-flight arc are all
  direction-aware.

## Dependencies & assets

- **No new packages** in phases 1–4 (no Rive, Lottie, confetti, etc.). Everything is
  custom-painted. Phase 5 extras require explicit user approval first.
- No binary image assets; procedural generation like `grain_texture.dart` if a sprite is
  needed.
- `google_sign_in` must not be reintroduced. Don't touch the Android toolchain versions.

## Process

- Work phase by phase (04). Each phase: `flutter analyze` (zero new issues),
  `flutter test` green, profile-mode raster check per the verification protocol.
- Update `plans/PROGRESS.md` as work lands — it's the handoff between agents.
- If a spec value in 01/02/03 feels wrong on-device (duration, spring constant, particle
  count), tune it, then record old → new + reason in Deviations. The values are strong
  defaults, not religion — the *system* (centralized constants, budgets, gates) is what's
  non-negotiable.
- Do not start Step 3 (marketplace) work except the treasure-flight animation, which is
  spec'd here and lands with Step 3.
