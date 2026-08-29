# Side Plan 2 — Diet Cost (الميزانية) + Today macro numbers + energy transparency

**Owner:** the user (the boss). **Executor:** GPT-terra.
**Status:** spec'd, not started.
**Depends on:** Step 2 (done), Living Glass phases 1–3 (done) — the UI work here consumes
`GlassCard`, `TickerNumber`, `MacroBar`, `HapticPhrase`, `MoodPalette`, `GlassSheet`.
**Touches:** `lib/ui/**`, `lib/page/**`, `lib/l10n/app_strings.dart`,
`lib/domain/nutrition/cost.dart` (new, pure Dart), SharedPreferences for the price cache.
One small **domain breaking change** (Workstream D): removing `Sex.preferNotToSay`.

| WS | Request | Size |
|---|---|---|
| A | Show consumed/target **grams** for protein, carbs, fat in the اليوم tab | S |
| B | Explain the BMR→target math so 2269→2967 never looks like a bug | S |
| C | **الميزانية** — per-component prices (cached locally) and day/week/month cost | M |
| D | Editable weekly-loss rate in Profile; remove `preferNotToSay` gender option | S |

---

## Workstream A — Macro numbers in the اليوم tab

**Problem:** the ring shows macro sub-*rings* (visual ratios only) and the legend names
the colors, but nowhere can the user read "128 / 180 ج بروتين". Numbers are the point of a
tracker.

**Spec:**

1. New widget `lib/ui/components/macro_numbers_panel.dart`:
   - Three rows (بروتين / كارب / دهون), each: macro-colored dot (matching the ring's
     sub-ring colors exactly — emerald / amber / violet), label, `MacroBar` with animated
     fill, and `consumed.round() / target.round() ج` using `TickerNumber`.
   - Data: `TodayController.day.value` — `consumedTotals` and the day's frozen
     `targets.macros`. No domain changes.
   - Over-target macro: the number turns `AppPalette.amber`, matching the ring's
     over-state language. Informative, never red.
2. Placement: directly **under** the calorie ring inside the Today header, so it collapses
   with the sliver header from Living Glass phase 4. In the collapsed (96px) state the
   panel hides — the sub-rings already carry that information in miniature.
3. **Planned split:** when `plannedTotals` differs from `consumedTotals`, each bar shows
   the planned extension as a faded segment (alpha .38, matching the ring's planned band),
   and a caption toggle «المخطط / المأكول» switches the numbers. Default: المأكول.
4. Motion: bars fill with the 60ms stagger (Living Glass 02 §3); number swaps use
   `TickerNumber` direction-aware slides; `MotionSettings` gate respected.

**Exit:** eat-toggle visibly moves both the ring and the numbers in the same beat; RTL
walk; analyze clean.

## Workstream B — Energy transparency card («من أين جاء رقمك؟»)

**Problem (user-reported):** "it tells me my BMR is 2269 and then I'm cutting on 2967, so
something is off." The math is **correct** — verified against `energy.dart`:

```
BMR (Mifflin-St Jeor)           = 2269
TDEE = 2269 × 1.55 (نشاط متوسط)  = 3517   ← what you actually burn
Cut 0.5 kg/week → −550/day       → 2967    ← the target
```

You cut below **TDEE** (total burn), never below **BMR** (survival burn). The app already
refuses targets below BMR (`energyFloor`). The failure is that the app never shows its
work. Fix is presentational — **do not change the equations.**

**Spec:**

1. New widget `lib/ui/components/energy_breakdown_card.dart`. Input: `UserProfile`.
   Recomputes BMR/TDEE live from profile stats (the existing `_TargetSummary` already
   recomputes live; follow that pattern).
2. Layout — a 4-step chain, each step a row with label + `TickerNumber` value, connected
   by a hairline:
   - **معدل الحرق الأساسي (BMR):** 2269 سعرة — «جسمك يحرقها وأنت نائم»
   - **× مستوى النشاط (نشاط متوسط 1.55):** 3517 سعرة — «احتراقك الكلي اليومي»
   - **− هدفك (تنشيف 0.5 كجم/أسبوع):** −550 سعرة
   - **= هدفك اليومي:** 2967 سعرة — emphasized, `heroNumber` typography, mood accent.
3. Explainer line under the chain:
   «تنقص سعراتك عن احتراقك **الكلي**، لا عن معدل الحرق الأساسي — الأكل تحت 2269 أبعد ما
   يكون عن الصحي.»
4. Placement: (a) Profile screen, above the targets diff; (b) onboarding, replacing the
   bare «هدفك اليومي المحسوب» preview box — it becomes this breakdown, updating live via
   `recalculatePreview()`.
5. If `targets.mode == TargetMode.manual`, show the manual numbers with
   «أدخلت هذا الهدف يدويًا» instead of the chain.

**Exit:** the boss's own numbers (2269 / 3517 / −550 / 2967) render with his profile;
strings in `app_strings.dart`.


## Workstream C — الميزانية (diet cost page)

**What the boss asked:** a page that shows the current diet's components, asks for
price-per-100g per component, and estimates what the diet costs **per day, per week, per
month**. Prices cached in SharedPreferences to refine future estimates.

**Pipeline context:** `pricePer100` already exists in the food schema (`foods/{id}`,
`general.md` §10) and the migration populates it when legacy data had a price. Step 4
§4.9 owns *displaying* a price in meal detail — unchanged. This page is new scope.

### C.1 Domain — `lib/domain/nutrition/cost.dart` (pure Dart, unit-tested)

```dart
/// One component's contribution to a period's cost.
class ComponentCost {
  final String foodId;
  final String name;
  final double grams;          // total grams in the period
  final double? pricePer100;   // null = no price known
  double? get cost => pricePer100 == null ? null : grams * pricePer100! / 100;
}

class PeriodCost {
  final List<ComponentCost> components;
  double get knownTotal;       // sum of priced components only
  int get pricedCount;
  int get unpricedCount;       // drives the «بلا سعر» section
  double get coverage => pricedCount / max(1, components.length);
}
```

Aggregation rules:
- **Day:** today's `DayLog.items` — each `FrozenItem` carries `foodId`, `per100`,
  `grams`. Sum per `foodId`. No joins needed.
- **Week:** the 7-day composition from the schedule (permanent items × their weekdays +
  this week's one-shots), read via the same repository the Today tab uses — read-only,
  no new writes.
- **Month:** 30.4 × the average daily cost of the scheduled week. Document the assumption
  in the UI: «تقدير على أساس أسبوعك الحالي».
- Prices are per-100g in the user's currency. **Currency is a plain string setting**
  (default «ج.م», editable in the page's settings overflow) — no forex, no conversion.

### C.2 Price cache — SharedPreferences

- New `lib/service/price_book.dart`: `Map<foodId, double>` persisted as one JSON blob
  under key `priceBook.v1`, plus `currency` under `priceBook.currency`.
- Resolution order per component: **user override (price book) → catalog `pricePer100` →
  null (unpriced)**. Overrides win — the user's local market beats a migrated default.
- Editing a price writes the book immediately (debounced 400ms), fires
  `HapticPhrase.step`, and totals re-roll via `TickerNumber`.
- Local-only **by design** (boss's call: SharedPreferences). Header comment: if
  multi-device sync is ever wanted this graduates to `users/{uid}/priceBook` — do not
  build that now.

### C.3 Screen — `lib/page/cost/` (`cost_screen.dart`, `cost_controller.dart`)

Route: 5th shell tab («الميزانية», `Icons.payments_outlined`) — **confirm tab count with
the boss before committing**; fallback placement is a Profile shortcut card.

Layout (top→bottom):
1. **Period totals hero** — three `GlassCard`s (يوم / أسبوع / شهر), each a `TickerNumber`
   total + currency + coverage chip («7 من 9 مكوّنات مسعّرة»). Day card carries the mood
   accent; the rest neutral glass. Staggered entry.
2. **Component list** — one `GlassCard` row per `foodId` (aggregated): name, total grams
   in the selected period (chip row above: يومي/أسبوعي/شهري), price-per-100g `GlassField`
   (numeric, prefilled from the resolution order), computed line cost in `TickerNumber`.
   Editing slides the row's cost number (direction-aware).
3. **«بلا سعر» section** — unpriced components grouped at the bottom under a muted header
   with count badge; each row has an inline price field and a «تخطَّ» ghost action that
   records an explicit skip marker in the price book (stops counting as "missing" without
   inventing 0.0). Empty state: «كل مكوناتك مسعّرة ✨» with the phase-3 micro-burst.
4. No `DayLog` yet (fresh day): show the scheduled-week composition with caption
   «من جدولك الأسبوعي».

Motion/feel: `StaggeredEntry` rows, `Pressable`, `step` haptic on field commits,
`GlassSheet` for the currency overflow, `MotionSettings` gate, full RTL. No new blur —
rows are filter-free `GlassCard`s per the budget law.

### C.4 Tests

- `test/domain/cost_test.dart`: per-component math, aggregation, null-price handling,
  coverage ratio, skip-marker semantics.
- Price book: round-trip JSON, override-beats-catalog resolution.

## Workstream D — Weekly rate editing + Sex enum cleanup

### D.1 Editable weekly-loss rate (boss note #1)

Onboarding already has «المعدل الأسبوعي» (0.25/0.5/0.75/1.0 kg). The gap is **Profile**:
once signed up you're locked in.

- Profile screen: add «المعدل الأسبوعي» control beside goal/activity (same dropdown
  values). On change: recompute `NutritionTargets.compute(...)` with the new rate,
  animate the targets diff with `TickerNumber` (the existing before/after pattern in
  Profile), persist via `ProfileRepository.save` with `updatedAt: now`.
- Guardrail: if the clamped target hits `energyFloor`, show the amber note
  «وصلنا لأقل هدف آمن — لا ننصح بالأكل تحت معدل حرقك الأساسي» instead of silently
  clamping.
- Render the Workstream B breakdown card right under it, so changing the rate visibly
  walks the chain (BMR → TDEE → delta → target).

### D.2 Remove `Sex.preferNotToSay` (boss note #2 — "bruh")

Files to touch:
- `lib/domain/nutrition/energy.dart`: delete the enum value, its `SexLabel` case, the
  `switch` arm in `bmrMifflinStJeor` (the −78 constant), and simplify `energyFloor`.
- `onboarding_controller.dart` (currently defaults `sex = Sex.preferNotToSay`): default
  becomes `Sex.male`. Keep the picker — female users must still select «أنثى»; it just
  can't be skipped.
- Tolerant deserialization: wherever `Sex` is decoded from Firestore/prefs
  (`profile_repository` / `UserProfile.fromJson`), map the legacy string
  `'preferNotToSay'` → `Sex.male` with a code comment, so existing stored profiles don't
  crash. One line, marked for deletion in a future cleanup.
- `test/domain/energy_test.dart`: drop the unspecified-sex cases; add a regression test
  that `'preferNotToSay'` in JSON decodes to `Sex.male`.
- Record in `plans/PROGRESS.md` Deviations: `general.md` §6 specified three sex values;
  the boss cut it to two after living with it.

## Verification (whole plan)

1. `flutter analyze` — zero new issues.
2. `flutter test` — all green incl. new cost tests and updated energy tests.
3. `flutter build apk --debug` succeeds.
4. On emulator: Today macro numbers move with each eat-toggle; Profile rate change
   re-rolls the breakdown chain; cost page totals respond to price edits after restart
   (SharedPreferences persistence).
5. Boss's-numbers check: with his profile, the breakdown card must read
   2269 → 3517 → −550 → 2967.
6. RTL walk on every new widget; reduced-motion walk per the Living Glass gate.
7. Update `plans/PROGRESS.md` (position + deviations).

## Explicitly out of scope

- Multi-currency conversion, price history charts, store comparison.
- Syncing the price book to Firestore (noted in C.2 for the future).
- Changing the Mifflin-St Jeor equations or the clamping waterfall — the math stays.
