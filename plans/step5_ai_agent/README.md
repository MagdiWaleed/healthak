# Step 5 — AI Agent (المساعد)

**The app's agentic assistant: chat, diet-editing tools, coaching, search.**

**Owner:** the user (the boss). **Executor:** GPT-terra (or any agent).
**Status:** SPECIFIED. Supersedes the old `step5.md` stub (its open questions are
answered below).
**Depends on:** Steps 1–2 (done), Living Glass phases 1–4. Independent of Steps 3–4.
Reuses `price_book.dart`'s local-persistence pattern and the whole `lib/ui` language.

**Voice was split out (2026-09-04)** into its own deferred plan,
`plans/voice_agent_deferred.md` — not part of this step's phases anymore. See that file
before starting it; it is not scheduled.

**Read order:** this file → `01_architecture.md` → `02_tools.md` → `03_chat_ux.md` →
`04_action_history.md` → `06_premium.md` → `07_phases.md`.
Constraints file to paste into the executor's context:
`plans/enhance_the_feeling_by_kimi/05_do_not_break.md` (applies here unchanged).

---

## The one-sentence brief

> An Arabic-first agent that **knows your numbers and acts on your diet** — every action
> proposed as a beautiful glass card, confirmed by you, logged, and undoable.

## Locked answers (from the boss)

| Question | Answer |
|---|---|
| What does it do? | Agentic tool-calling on the diet: reads everything (profile, weights, calories, history, meals, catalog), writes via propose/confirm — add/remove meals, change grams, **swap meals**, log a component by name with macros. Plus diet & gym **coaching** and **internet search** (premium). |
| Where does it live? | New shell tab «المساعد» — full conversational chat UI. |
| May it write? | **Propose-only.** Nothing writes until «تأكيد». Every write logged + undoable. |
| Voice? | Deferred — see `plans/voice_agent_deferred.md`. Not part of this step's phases; would share the **same** orchestrator and tools when picked up. |
| Premium? | Yes — `isPremium` gates search, coaching, voice, bigger model, longer history. |
| Language? | **Modern Standard Arabic (MSA) only.** Understand dialectal input, but generated responses and all assistant UI copy remain neutral MSA rather than adopting any regional dialect. |

**Open decision #1 (boss sign-off BEFORE Phase 5A):** where the API key lives.
Default spec: **Firebase Cloud Functions proxy** (Blaze plan) — no key ships in the
client. Dev fallback: `--dart-define=AI_DEV_KEY`, gitignored, blocked from release by an
assert.

**Open decision #2:** search provider. Default: **Gemini grounding with Google Search**
(one provider). A separate search API (Tavily/SerpAPI) can replace it later behind the
same `web_search` tool interface.

## Why the architecture is what it is

The model is the *only* untrusted component. So:

- It **never** touches Firestore, the network, or the file system. It emits structured
  tool calls; `AgentToolRegistry` (pure Dart, over repository interfaces, unit-testable
  with fakes) is the single bridge.
- It **never** supplies macro numbers — it supplies grams; the registry computes macros
  from catalog `per100` values. Hallucinated kcal cannot enter the log by construction.
- Unknown IDs (`foodId`/`mealId`/`entryId`) are looked up before proposing; failures
  return a structured tool error the model must recover from, never a guess.
- Every write is a **Proposal** → confirmation card → execute on tap → append to
  `AgentActionLog` **with its inverse** so undo is always one call.

The Step-1 architecture pays off here exactly as designed: domain is pure Dart (the
registry and the proxy share the same macro math the UI uses), `DayLog` entries are flat
frozen rows (clean tabular reads for the model), and `searchTokens` makes grounding a
lookup, not a fuzzy match.

## File map (what gets built)

| File | Role |
|---|---|
| `lib/service/agent/chat_orchestrator.dart` | Streams turns, dispatches tool calls, conversation `Rx` state |
| `lib/service/agent/agent_tool_registry.dart` | All tools; read vs. propose split; executes confirmed proposals |
| `lib/service/agent/agent_tools.dart` | Tool JSON schemas + argument validation |
| `lib/service/agent/agent_action_log.dart` | Append-only executed-writes log + inverses |
| `lib/service/agent/ai_client.dart` | Proxy streaming client, dev-key fallback, backoff |
| `lib/page/assistant/` | Chat tab (bubbles, streaming, tool cards, proposal cards, sources cards, chips, composer) |
| `lib/page/history_ai/` | «سجل المساعد» audit screen with per-row undo |
| Cloud Functions `functions/` | Auth, rate limit, premium gate, Gemini call w/ tools + grounding |
| `test/service/agent_tools_test.dart` | Registry vs. fake repos: validation, execution, undo per tool |

`lib/domain/` stays pure. `service/agent/` imports domain + data only — never Flutter.

## Sub-plans

| File | Contents |
|---|---|
| `01_architecture.md` | Orchestrator/registry/proxy detail, data flow, privacy & safety rules |
| `02_tools.md` | Full v1 tool catalog: schemas, validation, card templates, rails |
| `03_chat_ux.md` | The glassy chat tab, streaming, tool/proposal/sources cards, chips |
| `04_action_history.md` | «سجل المساعد» audit tab + undo semantics |
| `06_premium.md` | `isPremium`, gates, quotas, upsells |
| `07_phases.md` | Phases 5A→5D with exit criteria + verification protocol |

Voice (`speech_to_text`/`flutter_tts` capture, waveform, TTS, tap-only confirm) lives
outside this step now — see `plans/voice_agent_deferred.md`.
