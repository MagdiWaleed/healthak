# Step 3 — Marketplace

**Goal:** publish meals, discover other people's, and add them to your day or your schedule with
independently customizable weights.

**Status:** not started

**Depends on:** Step 2 (`MealDefinition`, `DayLog`, `ScheduleItem` must be final)
**Blocks:** nothing

This is the feature that does not exist at all today. `main_screen.dart:170` currently has
`onTap: () {}` on every marketplace card — there is no code path from a published meal into
anyone's diet.

---

## 3.1 Repository — `lib/data/repositories/market_repository.dart`

- [ ] `publish(MealDefinition)` → flatten to `items` + `groups`, write `marketMeals/{id}`,
      store the returned id back on the source meal as `publishedMarketMealId`
      *(the old code wrote a literal `id: "newMeal"` and never reconciled it with
      `document.id` — `create_single_meal_details_controller.dart:117`)*
- [ ] `unpublish(id)` → set `status: 'removed'`. Never hard-delete: other users hold copies
      whose `source` points here.
- [ ] `updatePublished(id, meal)` → bump `version`
- [ ] `browse({sort, tags, cursor})` → paginated `limit(20)` + `startAfterDocument`.
      Sorts: newest (`createdAt DESC`), most copied (`copyCount DESC`)
- [ ] `search(query)` → over `tags` and name tokens
- [ ] `myPublished()` → `where('authorUid', ==, uid)`
- [ ] `copyToLibrary(marketMeal)` → write `users/{uid}/meals/{newId}` with fresh ids,
      `origin: copiedFromMarket`, and full `source` provenance
- [ ] `incrementCopyCount(id)` → a single-field update. The security rule permits any signed-in
      user to increment it by **exactly 1** and change nothing else, which is what avoids
      needing Cloud Functions and therefore a Blaze plan.
- [ ] `like` / `unlike` → write/delete `marketMeals/{id}/likes/{uid}`. One doc per like avoids
      counter contention.

## 3.2 Browse — `lib/page/marketplace/`

- [ ] `MarketplaceScreen` — a staggered `GlassCard` grid. **No `BackdropFilter` in the grid.**
- [ ] Sort chips: الأحدث / الأكثر استخداماً
- [ ] Tag filter chips
- [ ] Search with a 250ms debounce
- [ ] Infinite scroll with a skeleton loading state
- [ ] Each card: name, author, kcal, macro mini-bars, copy count, `Hero(tag: 'meal-$id')`
- [ ] Real empty and error states via `AsyncView`

Every card needs a distinct look. Today, **one** unsplash JPG is the background for every meal
card and every diet row, so every meal looks identical. Use a generated gradient seeded from the
meal id when no image is set.

## 3.3 Detail — `MarketMealDetailScreen`

- [ ] Hero flight from the card — container, image, and title.
      *(Hero across a `BackdropFilter` produces artifacts. The no-blur-in-lists rule already
      guarantees the source is a plain `GlassCard`; the detail header must match.)*
- [ ] Author attribution, publish date, copy count, like button
- [ ] Totals ring
- [ ] Item list with grams, grouped by `groupLabel` so the author's nesting stays visible
- [ ] A bottom glass action bar — **exactly one `BackdropFilter`**:
      - **"أضف لليوم"** → one-shot into today's `DayLog`
      - **"أضف لجدولي"** → copy to library + create a `ScheduleItem`
      - **"حفظ في مكتبتي"** → copy only, add nothing
- [ ] Report / hide (a simple client-side mute list is enough for now)

## 3.4 `CustomizeWeightsSheet` — the shared path

**Both CTAs route through this same sheet.** That is what makes "customize its weights in either
case" literally one code path rather than two divergent ones.

- [ ] A `GramStepper` per item
- [ ] Live totals + the delta from the author's original
- [ ] A "موازنة تلقائية" button reusing the portion solver from Step 2
- [ ] "استعادة الأصل" to reset to the author's weights
- [ ] Slot picker (breakfast / lunch / dinner / snack)
- [ ] For **أضف لجدولي**: day-of-week chips
- [ ] Confirm → copy-on-add, always. Never a live reference.

## 3.5 Publishing — `PublishSheet`

- [ ] Reached from the meal editor's "نشر في السوق"
- [ ] Name, description, tags, optional image
- [ ] Preview of exactly what others will see
- [ ] Validation matching the security rules — name 1–80 chars, ≤60 items — checked
      client-side **and** enforced server-side
- [ ] **A meal containing a `MealRefEntry` is flattened before publishing.** A published meal
      must be self-contained: it cannot reference another user's private meal, and referencing
      other market meals would reintroduce cross-author cycles and dangling links on delete.
      The `groups` metadata preserves the nesting visually.
- [ ] Republish updates the existing doc and bumps `version`

## 3.6 My published meals

- [ ] A tab in `MyMealsScreen` — view, edit, unpublish
- [ ] Per-meal stats: copy count, like count

---

## Files touched

**Created:** `lib/page/marketplace/**`, `lib/ui/components/customize_weights_sheet.dart`,
`lib/ui/components/publish_sheet.dart`

**Modified:** `lib/data/repositories/market_repository.dart` (filled in from its Step 1 stub),
`lib/page/meal_editor/` (publish action wired up), `lib/page/my_meals/` (published tab),
`lib/page/home/` (the السوق tab becomes real)

---

## Reviewable at the end

Two accounts, end to end:

1. Account A: build a meal, publish it with tags
2. Account B: open السوق, find it via browse and via search
3. Open the detail — hero flight from the card
4. **أضف لليوم** → customize grams in the sheet → confirm → it is in today's log,
   independently weighted
5. **أضف لجدولي** → customize differently → confirm → next day it materializes at *those*
   weights
6. Account A edits and republishes → Account B's copies are **unaffected** (this is the point of
   copy-on-add)
7. Copy count increments on A's meal, written directly from B's client under the narrow rule

## Exit criteria

- [ ] The full two-account flow verified on a device plus the emulator
- [ ] Security rules verified: B cannot edit A's `marketMeal`; B *can* increment `copyCount` by
      1; B cannot increment it by 2, and cannot change any other field in the same write
- [ ] Copies are genuinely independent — editing a copy does not touch the original
- [ ] `flutter analyze` clean, `flutter test` green
- [ ] The debug blur-count assert stays silent throughout

## Risks

1. **The `copyCount` rule is the subtle part.** `diff().affectedKeys().hasOnly(['copyCount'])`
   plus an exact `+1` check. Test the negative cases explicitly — this is the one place a
   client is trusted to write to another user's document.
2. **Firestore composite indexes** must be deployed before browse sorting works, or queries fail
   at runtime with a console link. Deploy them in Step 0 and verify here.
3. **Hero + glass artifacts.** If the flight flickers, the culprit is almost always a
   `BackdropFilter` in either the source or the destination.
4. **Moderation is out of scope.** Anyone can publish anything. A client-side mute list is the
   stopgap; real moderation needs a decision from the user if this ever goes public.
