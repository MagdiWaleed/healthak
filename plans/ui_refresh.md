# UI refresh — 2026-10-23

Authorized by the user after reviewing `output/review/healthak-ui-concept.png`.
Continue on `cline-UI`; the prior app state is merged into local `main` at
`ab158cd`. Remote publication awaits explicit permission after automatic review
rejected pushing to shared main.

## Direction and scope

Calm, food-focused light UI: porcelain `#F5F8F6`, white surfaces, forest text
`#193D33`, emerald `#147D64`, muted `#62766E`, outline `#DFE8E2`. Use the bundled
Cairo family; no new font/network dependency. Larger text and RTL must work.

- Shared theme and surface primitives adopt flat opaque treatments. Legacy glass
  primitives remain bounded and their dark-path tests remain explicit; no blur
  budget assertion is removed. The production app currently uses light mode.
- Today: compact calories/remaining + macros, expandable planned totals, a stable
  labelled assistant entry, and meals grouped by slot. No collapsing 690px header,
  ambient sweeps, stacking rows, or repeated from-zero progress animation.
- Preserve date browsing, explicit past-day unlock, correct frozen-day totals,
  eat toggles, edit/delete, quick add, stable entry keys, and per-day scroll state.
- Four navigation destinations always show labels. Today owns its add action;
  the library keeps a labelled create-meal action. No placeholder FAB elsewhere.
- Assistant: quieter surfaces, readable pending cards, 48px confirmation targets,
  explicit confirmation note, and a compact options menu retaining all controls.

## Boundaries

No domain/schema/provider changes. Voice recording and TTS are not implemented in
this UI pass; the assistant entry truthfully opens text chat. No fabricated food
photos or added image fields: slot icons represent meals until real media exists.
Inline proposal editing remains deferred. The transaction/rules/proxy issues from
the source review remain separate work.

## Verification

Focused tests exercise consumed/planned values, over/zero targets, read-only
history, explicit edit actions, 320px/large-text layouts, and the real Today and
Assistant widgets using test-only data. Optional `CAPTURE_REVIEW=true` writes
rendered screenshots under `output/review/` without introducing a production demo
mode or connecting to Firebase. Android runtime QA remains required when an
emulator or device is connected.

Final local checks: analyzer clean, 197 tests pass, debug APK builds. Inspected
`today-implemented.png`, `assistant-implemented.png`, and
`assistant-proposal-implemented.png`. Corrected the mirrored assistant back arrow
and removed the empty-state directional gradient that threw during rendering.
