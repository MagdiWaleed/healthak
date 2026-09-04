# 03 — Chat UX («المساعد» tab)

Glassy, Arabic-first, Living Glass throughout. Shell: 6th tab,
`Icons.auto_awesome_rounded`, label «المساعد». `GlassScaffold` + `ReactiveAurora` — the
assistant lives in the same weather as Today.

## Layout

```
GlassScaffold
 ├─ app bar: «المساعد» + «برو» badge (premium) + clock icon → سجل المساعد
 ├─ message list (reversed ListView.builder, filter-free GlassCard bubbles)
 ├─ suggestion chips row (context-aware)
 └─ composer: glass field + send (Pressable) + mic (voice deferred, see
    plans/voice_agent_deferred.md — not built in this step)
```

## Message rendering

- **User bubble:** start-side (right edge in RTL), emerald-tinted border, `GlassCard` L1.
- **Assistant bubble:** opposite side, neutral glass, L1. Markdown-lite: bold + lists
  only (no headings, no images).
- Tail: tiny `BorderRadius` asymmetry on the sender's corner — not images.
- **Streaming:** tokens append per chunk; a 2px emerald cursor bar pulses at the text
  end (`MotionSettings`-gated). Completed streams settle with a 150ms fade.
- **Typing indicator:** three glass dots, phase-offset scale pulses (reuses
  `typing_dots.dart`).
- **Entry motion:** `StaggeredEntry` per message (directional per Living Glass 02 §6).

## Tool-call cards (the signature element)

Three states, all `GlassCard` L2 with the tool icon in an emerald ring chip:

1. **Working** («ببحث في الكتالوج…», «بحسب المتبقي من هدفك…») — animated progress
   hairline, no shimmer.
2. **Proposal** — `ProposalCard`:
   - The visual diff: swap shows old→new side by side with macro deltas; grams shows
     `old g → new g`; create-meal shows the full draft with per-row macros.
   - Buttons: «تأكيد» (emerald `GlassButton`, `HapticPhrase.land`), «إلغاء» ghost,
     «عدّل» — opens the app's real editor sheet pre-filled (e.g. gram stepper), result
     returns as a **new** proposal.
   - Confirming an action that touches **today** plays the eat-toggle micro-burst and
     the ring ripple — the chat and Today visibly share one world.
3. **Receipt** — collapses to one line + «تراجع» chip (10-minute inline undo window;
    beyond that, undo lives in سجل المساعد).

Other cards: **sources card** (search results: domain, snippet, link chips opening
externally), **upsell card** (premium-gated tool: shimmering «دي ميزة في المساعد برو
✨»), **disclosure/disclaimer cards** (one-time, §7 in 01_architecture.md).

## Suggestion chips

Above the composer, recomputed from read tools when the day changes:
«ماذا بقي اليوم؟»، «بدّل الغداء»، «أضف سناك بروتين»، «خطط لي أسبوع». Horizontal scroll,
`GlassChip`, `HapticPhrase.step` on tap.

## States

- **Empty conversation:** ambient ring-outline motif + «اسألني عن يومك، أو خلّيني
  أعدّل عليه».
- **Offline:** calm «المساعد محتاج نت» with retry; composer disabled, history readable.
- **Quota exhausted:** upsell-style card «وصلت لحد اليوم — ترجع تكمل بكرة».
- **Error:** inline «حصلت مشكلة — جرّب تاني» with retry chip; never a dead red screen.

## Persistence

Conversation is **local-only**: SharedPreferences blob per day, 7-day retention, same
pattern as `price_book.dart`. No chat in Firestore in v1 (cost + privacy — stated in the
UI).

## Budget rules (from 05_do_not_break.md — apply verbatim)

- Zero `BackdropFilter` in the message list; bubbles are filter-free `GlassCard`s.
- `MotionSettings` gate on every animation; reduced-motion = instant append, no cursor
  pulse.
- Full RTL: bubble sides, chip scroll direction, card layouts — all `Directionality`
  resolved.
- Keyboard avoidance via the existing sheet pattern; list keeps scroll position on
  keyboard open.
