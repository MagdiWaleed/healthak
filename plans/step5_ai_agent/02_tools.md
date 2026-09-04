# 02 — Tool Catalog (v1)

Every tool: name, JSON schema, Dart-side validation, Arabic card template. Read tools
execute immediately; write tools return a `Proposal` rendered as a confirmation card.

## Read tools (free tier)

| Tool | Args | Returns |
|---|---|---|
| `get_today` | — | Today's `DayLog`: entries (name, grams, macros, eaten), consumed/planned totals, targets |
| `get_history_range` | `days` (≤7 free / ≤90 premium) | Per-day consumed-vs-target summaries |
| `get_profile` | — | Stats, goal, activity, weekly rate, computed BMR/TDEE/targets via `energy.dart` |
| `get_meals` | — | `MealDefinition` library: names, totals, component lists |
| `search_foods` | `query` | Catalog hits via `searchTokens` — the grounding source for all macros |
| `get_remaining_targets` | — | kcal + protein/carbs/fat left today (the coach's favorite) |

## Write tools (propose-only)

| Tool | Args | Proposal card shows |
|---|---|---|
| `propose_log_food` | `foodId, grams, slot` | component, grams, computed macros, slot; «تقديري» badge if estimated |
| `propose_log_meal` | `mealId, slot, scale?` | meal name, computed totals, slot |
| `propose_swap_meal` | `dateKey, entryId, newMealId` | **old → new** side by side, macro deltas (+120 سعرة، −8 ج بروتين…) |
| `propose_update_grams` | `dateKey, entryId, newGrams` | `old g → new g`; `TickerNumber` roll on confirm |
| `propose_remove_entry` | `dateKey, entryId` | what's removed + its kcal impact |
| `propose_create_meal` | `name, entries[]` | full draft meal card; saves to library on confirm |
| `propose_log_custom_component` | `name, estPer100, grams` | the boss's case — agent invents a component by name. Macros **must** come from `search_foods` first; no catalog match → creates a *personal* `FoodItem` marked estimated («تقديري»), never catalog truth |

## Premium tools (see `06_premium.md`)

| Tool | Args | Notes |
|---|---|---|
| `web_search` | `query` | Gemini grounding w/ Google Search (default); summary + sources |
| `get_bodyweight_trend` | `days?` | From Step 4's bodyweight log; degrades gracefully if absent |
| `get_adherence_stats` | — | days-on-target %, streak, avg deficit/surplus |
| `propose_workout_plan` | `split` | structured gym card: days × exercises × sets/reps |
| `log_workout` | `session` | records a session so coaching adapts |

## Execution mapping (registry → repositories)

| Tool verb | Repository call |
|---|---|
| log food / custom component | `DayRepository.upsertEntry` (new `DayEntry`, origin `quickAdd`) |
| log meal | `upsertEntry` after flattening the `MealDefinition` via `meal_math` |
| swap meal | `removeEntry(old)` + `upsertEntry(new)` as **one logged action** (inverse = swap back) |
| update grams | rebuild the entry with new grams → `upsertEntry` |
| remove entry | `removeEntry` (inverse = re-add the frozen snapshot) |
| create meal | `MealRepository.save(draft)` |

`dateKey` defaults to today when the model omits it. Writes to **past days are refused**
unless that day is unlocked (mirrors the Today tab's `editingPast` rule — the registry
checks the same invariant, not just the UI).

## Validation rules (every write tool)

1. IDs resolved against real data first; unknown → structured tool error
   («لم أجد هذا المكوّن في الكتالوج») the model must recover from.
2. `grams ∈ [1, 2000]`; `scale ∈ [0.1, 10]`; `slot ∈ MealSlot.values`.
3. Registry computes all macros; model-provided kcal fields are ignored if present.
4. Proposal expiry: if the underlying day/entry changed since the proposal was built
   (version check), the card invalidates with «المعطيات اتغيّرت، أعمل اقتراح جديد»
   instead of writing against stale state.

## Card copy templates (Arabic, into `app_strings.dart`)

- log food: «هسجّل {name} ({grams} جم) في {slot}»
- swap: «هستبدل {oldName} بـ {newName}»
- grams: «هغيّر {name} من {old} لـ {new} جم»
- remove: «هشيل {name} من يومك»
- custom: «هضيف {name} كمكوّن شخصي (تقديري)»
