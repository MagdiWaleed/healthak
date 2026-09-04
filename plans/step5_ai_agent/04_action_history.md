# 04 — Action History («سجل المساعد»)

The agent's audit trail — not the nutrition history tab (that stays untouched). Entry
point: clock icon in the assistant tab's app bar (not a 7th tab).

## `AgentActionLog` (`lib/service/agent/`)

- Append-only record per executed write:
  `{id, timestamp, toolName, params, humanSummary, inverseToolCall}`.
- `inverseToolCall` is captured **at execution time** from the pre-write state (e.g.
  swap stores the old entry's frozen snapshot; update-grams stores the old grams;
  remove stores the full removed entry). Undo never recomputes — it replays stored
  state.
- Storage: SharedPreferences JSON, 30-day retention, v1. Firestore
  `users/{uid}/agentActions` is the flagged sync upgrade — **not built now**.
- Undone entries are marked `{undoneAt}` and kept — an audit trail is never silently
  rewritten.

## Screen (`lib/page/history_ai/`)

- Reverse-chronological `GlassCard` rows: tool icon in its ring chip, Arabic summary
  («استبدلت الغداء بـ وجبة التونة»), relative timestamp («من ساعتين»), and a per-row
  «تراجع» action.
- «تراجع» executes the inverse through the **registry** (so validation and logging apply
  to undos too — an undo is itself a logged action), with `HapticPhrase.land` and a
  struck-through «تم التراجع» state on the row.
- Section headers by day («اليوم»، «أمبارح»، date).
- Empty state: «لسه مفيش أكشنات — المساعد بيسجل كل تعديل هنا».
- Filter chip row: الكل / إضافة / تعديل / حذف / استبدال.

## Safety invariants

- Undo of a stale action (underlying day changed since) revalidates like any write —
  version check, else a polite refusal card.
- The log is the proof behind the privacy promise: «المساعد مابيعملش حاجة من غيرك،
  وكل حاجة متسجلة هنا.»
