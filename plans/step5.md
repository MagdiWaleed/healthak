# Step 5 — AI Assistant

**Status: NOT SPECIFIED. This is a stub.**

The user has said an AI assistant is planned for this app, but **its behaviour and scope have
not been drafted yet.**

**Do not write any code for this step until this file is filled in.**

Nothing in Steps 0–4 depends on it. It is deliberately last so that whatever it turns out to be
can be built on a finished, stable foundation rather than shaping that foundation around
guesses.

---

## Open questions — all still to be decided

### What does it actually do?

Candidate directions, not yet chosen. They differ enormously in cost, complexity, and risk:

- **Suggest meals to close the gap** — "you have 620 kcal and 40g protein left today, here are
  three meals from your library that fit"
- **Parse natural language into components** — the user types "دجاج مشوي مع رز وسلطة" and gets
  a draft meal with components and estimated grams
- **Parse a photo of a meal** — a vision model estimates components and portions
- **Coach on progress** — weekly summaries, adherence patterns, plateau detection
- **Answer nutrition questions** — general Q&A, with all the accuracy and liability that implies
- **Generate a full weekly schedule** from targets and preferences

### Where does it live in the UI?

- A tab? A FAB? A sheet invoked from Today? Inline suggestions in the meal editor?
- Conversational, or one-shot task-oriented actions?

### Technical

- Which model, and which provider?
- On-device inference or a hosted API?
- **Where does the API key live?** It cannot ship in the client — that is the single biggest
  constraint on this feature. Realistically this means a proxy, which means a server, which
  means a Firebase Blaze plan or a separate backend. **This is the decision that most shapes the
  rest.**
- Streaming or single response?
- How are calls authenticated and attributed to a user?

### Data and privacy

- What may it read? The user's profile, day history, meal library, the food catalog?
- May it **write** anything — create meals, modify the schedule — or only propose, with the user
  confirming every change? (Strong prior: propose-only. An assistant that silently edits a
  user's diet log is a bad idea.)
- Is any data sent to a third-party provider? The user must be told, explicitly, before it is.

### Cost and limits

- Who pays for inference?
- Rate limiting per user
- Graceful degradation when quota is exhausted
- Offline behaviour — the rest of the app works offline; this will not

### Correctness

- Nutrition advice has real-world consequences. What disclaimers are needed?
- How are hallucinated macro values prevented from entering the user's log? (Likely answer:
  the assistant may only ever select from the real `foods` catalog, never invent a food with
  invented macros.)

---

## What the existing architecture already gives this feature

Two decisions made in Step 1 were taken partly with this in mind, so the design should not need
unpicking later:

1. **`lib/domain/` is pure Dart with zero Flutter imports.** An assistant — in-app, in an
   isolate, or server-side — can call exactly the same `macrosOfMeal`, `dailyTarget`,
   `macroSplit`, and `portionSolver` the UI uses. There is no second implementation of the math
   to drift out of sync.

2. **`DayLog` entries are flat, frozen `FrozenItem`s with timestamps.** Any assistant gets a
   clean tabular read of what was actually eaten and when — no graph traversal, no reference
   resolution, no ambiguity about whether a recipe was edited after the fact.

3. **The `foods` catalog has `searchTokens`**, so grounding a model's output in real catalog
   entries (rather than letting it invent macros) is a lookup, not a fuzzy match.

---

## Next action

When the user is ready, answer the questions above — particularly **what it does** and
**where the API key lives** — and this stub becomes a real phase plan with tasks, files, and
exit criteria, in the same shape as `step0.md` through `step4.md`.
