# 01 — Architecture

## Data flow

```
Chat UI (tab) ──► ChatOrchestrator ──► AI proxy (Cloud Functions) ──► Gemini
      ▲                   │                                             │
      │                   ▼ tool-call intents                           │ tool defs
      │           AgentToolRegistry  ◄── model asks to call a tool ─────┘
      │                   │
      │        read tools ─► repositories (day/meal/schedule/food/profile/prefs)
      │        write tools ─► Proposal objects ─► confirmation cards in chat
      │                                                   │ «تأكيد»
      │                                                   ▼
      │                                    registry executes via repositories
      │                                                   │
      └──────── action log + undo ◄── AgentActionLog ◄────┘
```

## Components

### `ChatOrchestrator` (`lib/service/agent/`)

- Owns conversation state: `RxList<ChatMessage>` where `ChatMessage = user text |
  assistant text (streaming) | toolCall (working) | proposal (pending) | receipt |
  sources | system`.
- `send(String text)` → builds context (recent turns + tool results, **not** the whole
  DB) → streams `ai_client.agentTurn()` → on `tool_call` chunk, invokes the registry →
  feeds the tool result back as the next turn. Loop until the model answers in text.
- Max 6 tool calls per user message (runaway guard); on the 7th, injects a system nudge
  «جاوب باللي عندك» and forces a text answer.
- Read tools execute immediately and silently (working card shown). Write tools return a
  `Proposal` that parks in the conversation until the user acts on its card.

### `AgentToolRegistry`

- Registers every tool as `{schema, validate(args), run(args)}` where `run` returns
  either a read result or a `Proposal`.
- `execute(Proposal)` performs the confirmed write via the real repositories, appends
  `{action, inverse}` to `AgentActionLog`, returns a `Receipt`.
- Pure Dart. Constructed with repository interfaces → unit tests use fakes; no Flutter,
  no model, no network.

### `ai_client.dart`

- `Stream<AgentChunk> agentTurn(...)`: text deltas, tool-call intents, quota/offline
  errors as typed chunks.
- 25s timeout, exponential backoff ×2 max. Offline → typed `assistant_offline`.
- Proxy mode: Firebase callable/HTTPS with ID token. Dev mode: `--dart-define=AI_DEV_KEY`
  direct Gemini call; `kReleaseMode` assert forbids it.

### The proxy (Cloud Functions) — `functions/`

One streaming endpoint `agentTurn`:

1. **Auth:** verify Firebase ID token; resolve `users/{uid}.isPremium`.
2. **Rate limit:** per-uid daily counters (`agentUsage/{uid}`, server-only rules) —
   free: 30 turns/day, 5 searches/day; premium: 300/60. Exhausted → typed
   `quota_exceeded` → graceful upsell card, never an error.
3. **Prompt + tools:** the proxy owns the system prompt and tool schemas, kept in sync
   with `agent_tools.dart` (one shared source or duplicated with comment pairs — pick
   one, record in PROGRESS.md).
4. **Model:** free = Gemini Flash; premium = Gemini Pro. Grounding (search) enabled for
   premium only.
5. **No user data persisted** in the proxy beyond usage counters.

## Privacy & safety rules (load-bearing)

- One-time disclosure card before the first turn: exactly what data leaves the device
  (profile stats, day summaries — enumerated) and where it goes (Gemini via our proxy).
  Ack persisted in prefs. «مش بيتبعت غير اللي المساعد محتاجه عشان يرد عليك.»
- Coaching disclaimer («المساعد مش دكتور») before the first advice-style answer;
  persisted.
- System-prompt hard rules: never medical diagnosis; eating-disorder-safe language (no
  shaming, ever); macro numbers only from tools; search-backed health claims always carry
  sources.
- Conversation history is **local-only** (SharedPreferences, 7-day retention) — no chat
  in Firestore in v1. Stated in the UI as a privacy feature.
- Offline: the tab shows a calm «المساعد محتاج نت» state; the rest of the app untouched.

## Hallucination rails (repeated here because they're architectural)

- All IDs validated against real data before proposing.
- Grams clamped 1–2000; history window clamped to tier.
- Macros computed registry-side (`per100 × grams`, `Macros` math) — model supplies grams
  only.
- One in-flight proposal at a time; a new proposal supersedes the pending card.
