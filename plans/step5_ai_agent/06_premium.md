# 06 — Premium Tier (المساعد برو)

## Flag

`isPremium: bool` on `UserProfile`, default `false`. Manually flipped for the boss's
account during development. **Real billing (in-app purchase / RevenueCat) is a separate
later plan — do not build it here.**

## Gates (enforced in the proxy, mirrored in UI)

| Capability | Free | Premium (برو) |
|---|---|---|
| Chat + read tools + propose/confirm on today's diet | ✅ | ✅ |
| Turns / day | 30 | 300 |
| `web_search` | 5 / day (Flash) | 60 / day + Pro model |
| Coaching tools (`get_adherence_stats`, bodyweight trend, workout plan/log) | ❌ upsell | ✅ |
| History window (`get_history_range`) | 7 days | 90 days |
| Voice mode | ❌ | ✅ |

- Enforcement server-side (proxy checks the flag per call) — the client flag is cosmetic
  only; never trust it for gating.
- `agentUsage/{uid}` counters are server-only documents (rules deployed with the
  function; client rules untouched).

## UI treatment

- «برو» badge next to the assistant tab label when premium.
- Locked capability requested → shimmering **upsell card** inside the chat:
  «دي ميزة في المساعد برو ✨» + «اعرف أكتر» ghost button → a glass sheet listing the
  premium set. Never an error, never a dead end.
- Free tier approaching quota (>80%): a gentle chip in the composer area,
  «فاضل {n} رسايل النهاردة» — no surprise cutoffs.

## Graceful transitions

- Premium lapses mid-conversation: in-flight premium tool calls complete; new ones gate
  with the upsell card.
- Flag flips are read from `ProfileRepository.watch` — the UI reacts live, no restart.

## Coaching & search specifics (premium surfaces)

- **Coach persona** (system prompt): «أنت كوتش تغذية ولياقة» — grounded in read tools,
  so advice cites the user's actual numbers («البروتين عندك 0.9 جم/كجم الأسبوع ده،
  الهدف 1.8…»), never generic tips.
- **Workout proposals** render as structured cards (days × exercises × sets/reps) and
  save to a `workouts` list on the profile (small new sub-structure — flagged as
  mini-scope; local-only until a real gym feature plan exists).
- **Search** results always carry sources (see `03_chat_ux.md` sources card); health
  claims without sources are a system-prompt violation.
