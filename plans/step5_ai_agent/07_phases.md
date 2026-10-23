# 07 — Phases & Verification

Each phase ends shippable: `flutter analyze` zero new issues, `flutter test` green,
deviations recorded in `plans/PROGRESS.md`.

## Phase 5A — Plumbing + read-only chat

**Boss sign-off on the API-key decision happens first** (README, open decision #1).

- Cloud Function `agentTurn`: auth, rate limit, Flash model, tool defs.
- `ai_client.dart` streaming client + dev-key fallback with `kReleaseMode` assert.
- `ChatOrchestrator` + the 6 read tools in `AgentToolRegistry`.
- Assistant tab: bubbles, streaming text, typing dots, composer, suggestion chips,
  working cards, offline/empty/error states. **No writes yet.**
- **Exit:** «ماذا أكلت اليوم؟» and «إيه المتبقي من هدفي؟» answer correctly and
  grounded, streamed into the glass chat. `agent_tools_test.dart` green for all read
  tools. Quota-exhausted path renders the graceful card.

## Phase 5B — Write tools + confirmation cards

- The 7 propose tools, `ProposalCard` with تأكيد/إلغاء/عدّل, execution through the
  registry, `AgentActionLog` with inline 10-minute undo chip.
- Swap-meal and update-grams visual diffs; «تقديري» estimated-macros path; stale
  proposal invalidation.
- **Exit:** «بدّل الغداء بأرخص وجبة بروتين عندي» → proposal → confirm → Today updates
  live (ring + aurora mood react). Undo restores. Rapid propose/confirm stress: no stuck
  cards, one in-flight enforced.

## Phase 5C — Action history

- «سجل المساعد» screen: rows, day sections, filters, per-row registry-driven undo,
  struck-through undone rows, 30-day retention.
- **Exit:** every 5B action appears with correct Arabic summary and undoes; undo of a
  stale action refuses politely.

## Phase 5D — Premium + coaching + search

- `isPremium` on profile + proxy gating + upsell cards + «برو» badge.
- `web_search` with sources cards; coaching tools (`get_adherence_stats`,
  `get_bodyweight_trend`, `propose_workout_plan`, `log_workout`); the «مش دكتور»
  disclaimer gate.
- **Exit:** free account hits graceful upsells; premium account searches (sources render
  RTL), gets coaching grounded in its real numbers; flag flips mid-session degrade
  gracefully.

## Voice — split out (not a phase here anymore)

Voice was Phase 5V. Deferred to its own plan, `plans/voice_agent_deferred.md`, so this
step's phases (5A–5D) ship as a complete, self-contained unit without waiting on the
voice dependency-approval gate. Pick that file up separately when the boss wants it.

## Verification (whole step)

1. `flutter analyze` zero new issues; `flutter test` green incl.
   `test/service/agent_tools_test.dart` — per tool: validation, execution, undo,
   hallucinated-ID rejection, clamping.
2. Security rules: `agentUsage` server-only; client rules unchanged.
3. Manual loop on device (RTL, reduced-motion on and off): reads → proposals → confirms
   → undos → history audit.
4. Proxy: quota exhaustion, offline, and both premium-flag states.
5. Record model/search costs per phase in PROGRESS.md.

## Explicitly out of scope

- Real payments/billing (separate plan).
- Firestore sync of chat or action history (flagged upgrades only).
- Wake word / continuous voice; photo-of-food vision parsing (revisit after 5A–5D and
  the deferred voice plan).
- A real workout-tracking feature beyond the coach's log card.
