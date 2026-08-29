# PROGRESS — handoff

**Last updated:** 2026-08-28
**Current position:** Step 0 COMPLETE. Step 1 implementation COMPLETE (one real-device gate still
open). **Step 2 implementation COMPLETE** — the full personal loop (catalog, meal editor with
nesting, my meals, today, history, profile) is built, wired, and the legacy codebase it replaces
is deleted. Not yet committed to git; not yet walked by hand on a device/emulator.

**Side Plan 1:** the first-launch guest preview is complete. It is local and read-only; see
`sideplan1_guest_mode.md`.

**Side Plan 2 (started, Workstream A):** Today now has a filter-free
`MacroNumbersPanel` directly below the calorie ring. It presents protein, carbs, and fat as
exact consumed/target grams with the same emerald/amber/violet mapping as the ring, a
direction-aware `TickerNumber`, and a planned-versus-consumed toggle. `MacroBar` now supports
the specified faded planned extension and 60ms staggered fills without adding blur or packages.
The panel fades out with the pinned ring header's existing collapse. Automated validation is
still pending: the local Flutter/Dart analyzer processes were already occupied and produced no
completion result during this handoff, so this slice is not yet marked verified.

**Side Plan 2 (Workstream B, implementation complete pending validation):** Added
`EnergyBreakdownCard`, a presentational BMR → activity-adjusted total burn → goal adjustment
→ daily-target chain. It uses the existing `bmrMifflinStJeor`, `tdee`, and frozen
`NutritionTargets` values rather than changing or duplicating nutrition logic; manual targets
say so plainly. The same card now appears above the profile target diff and replaces the bare
onboarding target preview, with live ticker values as the inputs change. Full analyzer/test/APK
validation is still pending alongside Workstream A for the same local analyzer-process reason.

**Living Glass:** Kimi's Phase 1 foundations are implemented: shared springs, haptics, mood
tokens, reduced-motion gate, ticker number, and the requested glass/typography/copy tokens.
They remain deliberately opt-in apart from routing existing haptics and `Pressable` through the
central systems. `flutter analyze` is clean, `flutter test` has 98 passing tests, and the debug
APK builds. The emulator eye check and logcat smoke test passed; real-device profile raster data
remains a separate cross-phase performance gate.

**Living Glass Phase 2:** implemented and emulator-smoke-tested: `ReactiveAurora` lerps the
existing painter's colors/alpha/vignette/grain only (no new blur); Today publishes hysteretic
progress mood to the shell; the calorie-ring accent follows it; and `SpecularBorder` uses one
throttled scroll-angle notifier per `GlassScaffold`. `GlassCard` / `GlassSurface` now consume
L0-L3 elevation tokens without adding a `BackdropFilter`. Analyzer, all 98 tests, and the debug
APK pass. The remaining Phase 2 exit gate is baseline-versus-new profile raster p95 on a **real
mid-range device**; the desktop-mode emulator is not valid evidence for that measurement.

**Living Glass Phase 3:** implemented and verified by analyzer, all 98 tests, and a debug APK
build. A positive Today check now has the contained check morph, deterministic overlay burst,
ring ripple, and central tick phrase; undo remains deliberately flat. `TodayController` owns an
in-memory, per-date edge trigger at 95% of target, so the 24-particle goal celebration and ring
double-pulse play once per day/session rather than on Firestore echoes or rotation. All new
painters have `RepaintBoundary` and value-equality repaint checks; no new package or blur was
added. The Phase 3 real-device rapid-toggle raster stress measurement remains open.

**Today regression fix (2026-08-28):** the Phase 3 rollout exposed two interaction-path issues.
`selectDate` awaited the schedule-materialization transaction before subscribing to `days/{date}`;
that made the Today tab look stalled on a slow or unavailable network. It now starts the
cache-backed day stream first and materializes in the background, guarded against stale date
selections. The eat-toggle transaction also could not complete offline, so the optimistic tick
eventually rolled back. The hot path now writes the already-updated `DayLog` with Firestore's
offline-capable `set`, which queues sync while retaining the visible eaten state. Verified on the
emulator with Firestore DNS unavailable: the meal remained ticked and the calorie ring stayed at
152 kcal after five seconds; no Flutter exception was emitted.

**Living Glass Phase 4 (in progress):** the route transition now has fade-through-scale behavior,
staggered entries resolve their start edge in RTL and add the planned subtle rotation, steppers use
the shared direction-aware `TickerNumber`, and pull-to-refresh uses the emerald ring language.
The existing splash already materializes the logo/ring; onboarding now shows the first-filling arc
across its authentication/profile stages. Today now uses a pinned `SliverPersistentHeader` that
shrinks the ring from 200px to 96px without a scroll listener or per-frame controller work; the
meal editor's drag proxy lifts with an L3-style emerald bloom and has central lift/land haptics.
The populated Today top state was visually checked on the emulator; a long-list collapse walk,
and a reusable `pushHealthak` helper now routes imperative Food Detail and Meal Editor pushes
through the same `HealthakTransition` used by named pages.

**Full sheet vocabulary is now done.** Every `showModalBottomSheet` call site rendered its own
chrome by hand -- `food_picker_sheet.dart` used `GlassSurface` (a real `BackdropFilter`, spending
one of the app's two-blur budget the moment it opened over a screen that had already spent both),
the rest used a raw `DecoratedBox(color: AppPalette.surface.withValues(alpha:.97))` with no
Living Glass motion or haptic integration at all. Added `lib/ui/glass/glass_sheet.dart`: the one
`GlassSheet` widget every sheet now goes through -- deliberately flat (`GlassElevation.hero`,
never a blur, for the budget reason above), `SpecularBorder` edge, drag handle, optional title
row, an `expand: bool` that switches between a list-filling sheet (`Expanded`) and a
content-sized one (`mainAxisSize: min`), and a `GlassSheet.show<T>()` static that opens through
`showModalBottomSheet` and fires `HapticPhrase.play(AppHaptics.lift)` on open. Migrated all seven
call sites: `food_picker_sheet.dart`, `meal_editor/meal_picker_sheet.dart`,
`meal_editor/balance_sheet.dart`, `meal_editor/schedule_sheet.dart`, `today/edit_entry_sheet.dart`,
and `today/quick_add_sheet.dart`'s two sheets (`_QuickAddMenu`, `_LibraryMealSheet`). Each kept its
own keyboard-avoidance (`media.viewInsets.bottom`) and bottom-safe-area padding inside its
`child`, since those are per-sheet concerns `GlassSheet` doesn't own. `flutter analyze`: no
issues. `flutter test`: all 98 tests pass. A real-device RTL/reduced-motion walk remains before
this phase can be called done.

**Bug fix -- Today's add button silently dead after a day rollover:** `TodayController.selectedDate`
was `DateTime.now().obs`, evaluated once at controller construction and never revisited.
`isViewingToday` itself re-reads `DateTime.now()` on every call, so once real midnight passed
while the controller stayed alive (a debug session left running, or any phone that never left the
Today tab overnight), it correctly started reporting `false` -- but nothing ever moved
`selectedDate` forward, so the FAB and the empty-day "إضافة الآن" button both silently refused to
add (My Meals was unaffected: its add button has no date dependency at all). Fixed by having
`TodayController` mix in `WidgetsBindingObserver` and re-`selectDate(DateTime.now())` whenever the
app resumes from background, but only while the user was following today (never yanks someone
back from a day they browsed to on purpose); a companion `ensureCurrentDay()` also runs on every
FAB tap so a rollover that happens while the app stays foregrounded self-heals immediately rather
than waiting for a resume event.

**Feature -- manual one-off entry ("أضف عنصراً يدوياً"):** a fourth Quick Add option next to
library meal / quick food / new meal. `lib/page/today/manual_entry_sheet.dart`: a name field plus
protein/carbs/fat fields (kcal is a live read-only Atwater-derived preview, never entered directly
-- kept consistent with "kcal is always derived" elsewhere in the app). Submits through
`TodayController.logCustomEntry()`, which builds a `FrozenItem` with a synthetic `manual:<uuid>`
id straight into today's `DayLog` (`DayEntryOrigin.quickAdd`) -- no `FoodItem` is created, no
`foods` write happens, nothing is publishable. This is the explicit design point: log "sushi with
kabsa, whatever, here's roughly what was in it" for today only, without it becoming a reusable or
marketplace-visible component.

**Bug fix -- no way back to today once browsing a populated past day, and past days were
editable:** the only "العودة لليوم" affordance lived in the *empty*-day branch (no document at
all for that date); a past day that had a real, populated `DayLog` relied entirely on the user
noticing today's cell in the week strip, with no explicit control. Fixed at the source: `_Greeting`
(shared by all three Today branches -- empty, materialized-but-empty, and populated) now renders
its subtitle as a tappable "استعراض يوم سابق" chip that calls `selectDate(DateTime.now())`
whenever the viewed day isn't today, so every branch gets the same way back, not just the one that
already had it. Separately, a browsed-to past day's entries were fully interactive -- swipe to
delete, long-press to edit grams, tap to toggle eaten -- despite the day being a frozen historical
record by design. `_EntryTile` now checks `controller.isViewingToday`: past days disable the
`Dismissible`, drop the long-press handler, and swap the live `EatCheck` toggle for a plain static
check icon, matching the read-only rendering History's own day-detail sheet already used. Today
remains the only day anyone can act on.

**Polish -- the read-only indicator on past-day entries:** the check-circle/circle-outline icon
that replaced `EatCheck` on a read-only row still read as a checkbox, implying it was tappable
when it wasn't. Replaced it with a colored-glass treatment instead: `GlassDecoration.body()` and
`GlassCard` both gained an optional `color`/`tint` parameter (defaults to the existing white glass
everywhere else), and a read-only `_EntryTile` now passes `tint: AppPalette.emerald,
highlighted: true` -- a green-tinted, hero-elevation glass card (picking up the elevation's
built-in emerald shadow bloom too) with no leading icon at all. Eaten/not-eaten still reads
through the existing strike-through + opacity on the name, same as before.

**Investigated -- week-strip cell briefly refusing to return to today:** reported as "go from
Saturday to Friday, then can't tap back to Saturday." The strip's `isFuture` guard
(`date.isAfter(today)`) is correct as written -- today itself is never future, only the days after
it are. The device clock was checked directly (`adb shell date` -> `Sat Aug 29 00:15:42`) and this
session's own real-world midnight had passed only ~15 minutes before the report, so the almost
certain explanation is that Saturday was still genuinely tomorrow (rightly disabled) in the moments
just before rollover, not a logic bug. No code change made for this specifically; the
`_Greeting`-based "استعراض يوم سابق" tap-to-return chip added earlier this phase is an
independent backup path that does not depend on the week strip at all if it recurs.

**Feature -- consumed macro grams inside the ring:** the three thin macro rings around the main
arc had color but no numbers -- `_RingLegend` said which color was which macro, but not how much
of it had actually been eaten. `CalorieRing` now prints a third line under the kcal figure /
remaining label: a colored dot matching each macro ring plus its consumed grams (protein, carbs,
fat, same emerald/amber/violet mapping as everywhere else). Gated to `size > 145` so it only
appears on the big ring -- past that point it would land in the same crowded range where
`_TodayRingHeaderDelegate` already fades its other detail text out while the header collapses.

**Feature -- a ring in History's day-detail sheet:** the calendar's day-detail popup only ever
showed text totals and the entry list, no ring. Added a `CalorieRing` at the top, fed directly
from that day's frozen `DayLog` (`consumedKcal`/`targets.kcal`/`consumedTotals`/`targets.macros`)
-- the same numbers that day's Today screen showed while it was still today, not a live
recomputation of anything. No planned band here: History is a record of what was actually eaten,
not a projection. While in the file, migrated `_DayDetailSheet`'s chrome off the last remaining
raw `DecoratedBox` sheet onto `GlassSheet`, the one spot the earlier sheet-vocabulary pass missed.

### Data-loss bug — ticking a meal off did not survive a restart

Two compounding defects, both in the materialization path. Verified fixed on the emulator by
ticking a meal, `am force-stop`, relaunch: the tick and the 152-kcal ring both survived.

1. **`scheduleVersionOf` used `Object.hashAll`.** Dart explicitly documents `Object.hash`/
   `hashAll` as *not stable between runs of a program* — `String.hashCode` is randomized per
   isolate — so an unchanged schedule produced a different "version" on every launch. Replaced
   with a hand-rolled djb2 digest over a canonical `id|order|updatedAt` string, masked to 32 bits
   each step so the value is identical on a native int and on the JS number representation. This
   is the only reason a value like this can be persisted at all. `schedule_version_test.dart` now
   pins the digest against a literal — the pre-existing "is stable across re-fetching identical
   content" test could never have caught this, because within a single run even a randomized hash
   looks stable.
2. **`ensureDay` compared that fingerprint with `>=`.** A fingerprint has no ordering, so the
   comparison was meaningless in both directions: roughly half the time a stale stored value
   compared greater and materialization was wrongly skipped, the other half an unchanged schedule
   compared lower and the day was needlessly rebuilt — and rebuilding regenerates every
   `scheduled` entry from its schedule item with `eaten: false` and a fresh uuid. Now `==`.

Also hardened the rebuild itself, which was one-shot-away from the same bug for a legitimate
reason: `_fromSchedule` now takes the previous entry (matched on `scheduleItemId`) and carries its
`eaten`, `eatenAt`, and `entryId` across. Editing the schedule mid-day no longer un-ticks what has
already been eaten, and reusing the entryId keeps list keys, an in-flight eat toggle, and any
`Dismissible` pointing at the same row. This does not weaken the daily reset: a new day has no
document, so there is nothing to carry over and every entry still starts false.

### Bug — the week strip froze at whatever day it last rebuilt on

`_WeekStrip` computed `DateTime.now()` inline in `build`, and `_Greeting` had its own private
`_isToday`. A process alive across midnight never re-ran them, so the new day kept failing the
`isFuture` test and stayed permanently greyed out and untappable — the reported "I can't navigate
to the current day", with the strip visibly disabling today's own cell.

`TodayController` now publishes `today` as an `Rx<DateTime>`, updated by a single `Timer` armed
for the next local midnight (one wakeup, not a poll), re-armed and recomputed on resume since a
frozen background process runs no timers. `_isToday`, the strip, and the greeting all read it, so
the rollover reaches every dependent at once. `_Greeting` got its own `Obx` in the process: its
`build` runs outside the closure of whichever `Obx` created it, so reading an `Rx` there was never
registering as a dependency.

### Regression — `GlassSheet` was ~90% transparent

The sheet-vocabulary migration replaced each sheet's
`DecoratedBox(color: AppPalette.surface.withValues(alpha: .97))` with only `GlassDecoration.body`,
a white gradient over *nothing*. Correct for a card floating on the aurora, wrong for a modal:
form labels and text fields competed with whatever list was scrolled behind them. `GlassSheet` now
paints an opaque `surface` base *under* the glass tint rather than instead of it. Still no
`BackdropFilter` — a fill, not a blur, so the two-blur budget is untouched.

### Feature — creating your own component

New `+` beside the search field on the components screen (and in the picker sheet), opening
`ComponentEditorSheet`: name, optional category chip, and protein/carbs/fat per 100g, with kcal
shown live and never entered — derived through the same Atwater factors as everything else, so a
component cannot claim an energy value its own macros contradict.

**These do not go in the shared `foods` collection.** `firestore.rules` has `allow write: if false`
there, deliberately: it is a public catalog seeded out of band, and letting any signed-in client
write to it would make one user's typo everybody's data. Personal components live at
`users/{uid}/foods`, where the existing `users/{uid}/{document=**}` rule already grants the owner
full access and nobody else any — **no rules change was needed or made.** Same `FoodItem` shape and
same mapper, so the picker, meal editor, and solver treat them identically.

`FoodCatalogController` loads them whole on each reset (a hand-typed collection is inherently
small) and merges the ones matching the active filter ahead of the shared page; they carry a
`خاص بك` badge and are the only rows that can be deleted (long-press, with a confirm). The
`listPersonal` read is deliberately unfiltered and unordered — filtering server-side would buy
nothing at this size and would cost a composite index. `nameNormalized` is generated with the new
shared `foldArabic`, which `normalizeFoodSearchToken` now also uses, so a hand-created component
is findable by exactly the search that finds a migrated one; a test pins that.

### Correcting a past day

The read-only lock on past days left no way to *fix* a wrong record — which mattered immediately,
because the `scheduleVersionOf` bug above had already wiped `eaten` on days the user had really
eaten on, and those days were stuck reading 0 kcal with no recourse. Forgetting to tick something
off before midnight is also just normal.

Locked stays the default (the green glass, no checkbox — correcting history should be deliberate,
not a mis-tap). A `تعديل` pill next to "استعراض يوم سابق" unlocks the day in view: rows revert to
normal glass with live checkboxes and the pill becomes `تم`. `TodayController.editingPast` is
per-selection and never persisted — `selectDate` clears it, so unlocking one day cannot leave
others unlocked behind it.

`canEditSelectedDay` (`isViewingToday || editingPast`) now gates `quickAddFood`,
`addLibraryMeal`, and `logCustomEntry` as well as the row controls, so an unlocked day also
accepts a meal that was missing from it — being able to untick but not add would be a strange
half-correction. The FAB's refusal message now points at the pill rather than flatly saying today
only.

Two `Obx`-scope traps were hit and fixed while building this, both the same shape as the
`_Greeting` one: a widget's `build` runs *outside* the closure of whichever `Obx` created it, so
reading an `Rx` there registers no dependency. `readOnly` is therefore computed inside `TodayTab`'s
`Obx` and passed into `_EntryTile` as a parameter, and `_EditDayToggle` carries its own `Obx` —
without the latter the rows went editable while the button still read `تعديل`, because the pinned
`SliverPersistentHeader`'s `shouldRebuild` compares the day and selected date but knows nothing
about the unlock.

Verified on the emulator end to end: day 28 read 0, unlocked, ticked, ring went to 152 with
8/12/8 macros, `am force-stop`, relaunch — 152 still there, day green and locked again.

Read this first, then `general.md`, then the `stepN.md` for whatever step is current.
If you are a fresh agent picking this up: **everything you need is in this directory.** Do not
re-derive the architecture — it is already decided and written down in `general.md`.

---

## TL;DR for whoever picks this up next

**Step 0 is complete and verified.** Rules deployed, `foods` collection migrated and populated,
app builds and runs.

**Step 1 code is complete.** Domain, typed data repositories, services, the glass design system,
auth/onboarding, routes, shell, gallery, and guest mode are implemented.

**Step 2 code is complete.** Food catalog (paginated), meal editor (nesting + cycle guard +
ungroup + auto-balance solver + reorder), My Meals (library + schedule), Today (materialization +
eat-toggle + week strip + calorie ring), a lean History (month calendar + day detail; trend line
and bodyweight logging explicitly deferred to Step 4, which the plan itself allows), and Profile
(before/after target diff, typed-confirmation account deletion). **The entire legacy codebase this
replaces is deleted** — `lib/page/{current_diet,main_screen,my_informations,sign_in,loading,
setting,single_male_screen,add_complete_meal,diet_details}/`, `lib/appData.dart`, `lib/model/`,
`lib/widget/`, `lib/theme/`, and five legacy `lib/service/*.dart` files. The `/legacy` fallback
route is gone with them.

**Everything verified except by hand:** `flutter analyze` → **0 issues** across all of `lib/`.
`flutter test` → **96 passed**, 0 failed. `flutter build apk --debug` → succeeds.

**Do this next, in order:**
1. Continue the manual walk of the 9-step "Reviewable at the end" loop in `step2.md` on a device
   or emulator. A first pass (Today only) found and fixed two real bugs -- see below. My Meals,
   the meal editor, and history/profile have not been tapped through yet.
2. Real-device DevTools raster p95 — the one gate still open from **Step 1**, never done.
3. `git add -A && git commit` — nothing from this session is committed yet. Review the diff first;
   it is a large one (new `lib/page/{foods,meal_editor,my_meals,today,history,profile}/`, `lib/ui/`
   rewrites, and the entire legacy deletion in one pass, per Step 2's own risk #4).
4. Then start Step 3 (marketplace) — see `step3.md`. It depends on `MealDefinition` and `DayLog`
   being final, which they now are.

### Manual walk-through, attempt 1 — two real bugs found and fixed, one environment blocker

Installed the debug APK on `emulator-5554` and drove it via `adb shell input tap` +
`adb exec-out screencap`, screenshotting after each action (no Appium/integration-test harness in
this repo). Today tab only; the rest of the loop is not yet covered.

**Bug: browsing to a day with no logged data spun forever.** `TodayTab`'s build had exactly three
branches -- loading, error, and "has a `DayLog`" -- and no branch for the fourth real state:
loading finished, no error, and `day == null` because a past day genuinely has no Firestore
document (only `ensureDay`, called for *today* only, ever creates one; browsing history must never
invent one — see `general.md` §5.6). That state fell through to the loading branch's own
`CircularProgressIndicator`, which then never left the screen. Reproduced by tapping a past date
in the week strip. Fixed in `lib/page/today/today_tab.dart`: that state now renders a dedicated
"لا يوجد سجل لهذا اليوم" empty view instead of a spinner with no exit.

**Bug: the empty-day CTA button rendered underneath the FAB.** `ListView` top-aligns short
content; the FAB is docked at a fixed position near the bottom of the *viewport* regardless of
content length. On a day with zero entries, the accumulated height of greeting + week strip + ring
+ empty state happened to land almost exactly at the FAB's height on this device's screen size, so
**"إضافة الآن" rendered directly behind the "+" button** — reachable in theory, effectively
untappable in practice. Confirmed visually (screenshot showed the button's Arabic text truncated
behind the FAB circle), not something `flutter analyze`/widget tests would have caught, since
nothing errors — it's a pure visual collision. Fixed by moving the empty-day branch out of the
scrolling list into a `CustomScrollView` + `SliverFillRemaining(hasScrollBody: false)`, which
centers short content in the *true* remaining viewport instead of top-aligning it against a
fixed-position FAB. Verified fixed by screenshot after rebuilding and reinstalling — a clear gap
now separates "إضافة الآن" from the FAB.

### Manual walk-through, attempt 2 — the serious one: 4 controllers' onInit() never ran

The user reported مكتبتي/جدولي (My Meals' two tabs) never loaded -- stuck spinners. First fix
attempt added `onError` handling to `MyMealsController`'s two stream listeners (good defensive
coding regardless, kept), but that wasn't the actual cause: the streams weren't erroring, they
were never being *subscribed to at all*.

**Root cause:** `GetxController.onInit()` is only invoked automatically by GetX's own DI
machinery -- `Get.put`, `Get.lazyPut`, or a `Bindings` class. Four controllers across Step 2 are
constructed as plain objects instead (`late final XController controller = XController(...)`, no
`Get.put`), because nothing outside their own screen needs to `Get.find` them. Nobody ever called
`onInit()` on them, so nothing inside `onInit()` ever ran:

| Controller | What `onInit()` does | What broke without it |
|---|---|---|
| `MyMealsController` | Subscribes to the library and schedule streams | Both My Meals tabs spun forever |
| `MealEditorController` | Calls `_load()` -- fetches the library, populates `_otherMeals` | **The meal editor was completely unusable, for a new meal or an existing one** -- permanent spinner, the single most important screen in the app |
| `HistoryController` | Fetches the current month's range | History never loaded |
| `ProfileController` | Populates the form fields from the current profile | Height/weight/birth year/sex/activity/goal all sat blank instead of showing the real profile |

`TodayController` was the one exception and the reason Today alone worked in attempt 1: it's
`Get.put`-registered (so `HomeShell`'s FAB can `Get.find` it), which calls `onInit()` as a
side effect of registration. That was incidental, not a deliberate safeguard -- nothing about the
pattern flagged the other four as different in kind.

**Fix:** each of the four screens now calls `controller.onInit()` explicitly in `initState()`,
with a comment explaining why (so the next screen written this way doesn't repeat it). Considered
switching them to `Get.put`/`Get.delete` instead, matching `TodayController`; kept them as plain
objects because none of the other three need cross-widget lookup, and `Get.put` would mean
remembering a matching `Get.delete` in every `dispose()` (already true for `TodayController` and
easy to get wrong) for no benefit here.

Verified by temporarily defaulting `HomeController.tabIndex` to `1` (`emulator-5554`'s taskbar
made the nav bar and FAB untappable -- see below -- so this was the fastest way to actually reach
My Meals), rebuilding, and screenshotting both tabs: both now render their real empty state
("لا توجد وجبات بعد" / "لا يوجد جدول بعد") instead of an infinite spinner. Reverted the diagnostic
default before finishing.

**Meal editor independently verified on-device** in the follow-up session below (opened for a new
meal, loaded, added a real component). **Profile still not separately screenshotted** -- same
root cause, same fix, but worth a dedicated check before this ships.

### Manual walk-through, attempt 3 — two more real bugs in the meal editor

The user opened a new meal directly and hit two errors: a red, textless AppBar title, and a
Firestore error opening "إضافة مكوّن".

**Bug: `Obx` with no unconditional Rx read.** The AppBar title was
`Obx(() => Text(controller.isNew ? 'وجبة جديدة' : controller.name.value))`. `isNew` is a plain
bool getter, not reactive -- for a brand-new meal (`isNew == true`, the common case, arguably the
first thing every user of this screen ever sees) the ternary short-circuits and the builder never
reads a single `.obs` value. GetX's `Obx` requires at least one reactive read to know what to
subscribe to; without one it fails to render the child at all, which is what painted as a solid,
textless red block with no logcat exception (GetX's own failure path here doesn't go through
`FlutterError.onError` the way a normal build exception would, which is what made this one
slower to pin down than the other two). Audited every other `Obx` in the new code afterward
(23 call sites) for the same shape — one other risk pattern searched for specifically. None found;
this was the only instance. Fixed by reading `controller.name.value` unconditionally and deriving
the placeholder from emptiness instead of from `isNew`, which is also strictly better UX: the
title now updates live as the user types instead of staying static.

*(The right-pointing arrow visible in the same screenshot was not a bug -- it's Flutter's
automatic back button, correctly mirrored for RTL. Worth writing down since it looked exactly
like a defect at first glance.)*

**Bug: `[cloud_firestore/failed-precondition] The query requires an index.`** on opening
"إضافة مكوّن" (`FoodPickerSheet` → `FoodRepository.list()`). With no search text and no category
selected -- the very first thing anyone sees, since nothing is typed or picked yet -- the query is
`where('active', ==, true).orderBy('name')`. Firestore requires a composite index for any
equality-filter-plus-orderBy-on-a-different-field combination; `firestore.indexes.json` had the
`{active, category, name}` and `{active, searchTokens, name}` composites for the *filtered* cases
but never the plain `{active, name}` base case. Added it, deployed via
`npx firebase-tools deploy --only firestore:indexes` (already authenticated against
`diet-app-a908a` on this machine), confirmed live in the Firebase console. A fresh composite index
build is not instant even for an 8-document collection -- for this project's *first ever*
composite index it took roughly 8 minutes end to end (deploy → "currently building" →
usable), not the minute or two a warm project usually sees. Budget for that on a similarly cold
project.

**Both confirmed fixed on-device, end to end:** reopened the meal editor, the AppBar showed
"وجبة جديدة" correctly (no red block), opened "إضافة مكوّن", the catalog loaded, tapped a food
(حمص), it was added at 100g with live totals updating to 177 kcal / 5g protein / 20g carbs / 9g
fat -- the full row rendered correctly (stepper, lock toggle, overflow menu, drag handle).

### Manual walk-through, attempt 4 — food category data, and a snackbar red herring

**Real bug, in migrated data, not in this step's code:** the category filter chips on
"اختر مكوّناً" read "protein" / "protien" / "carp" instead of Arabic. `migrate_foods.js` carried
`foods.category` over from legacy `single_male.category` verbatim, and the legacy data used
English macro-type tags with the exact typos `CLAUDE.md` already documents for other fields
(`carp` for `carbs`, plus a `protien` misspelling `CLAUDE.md` hadn't caught). Wrote
`tool/normalize_food_categories.js` -- dry-run by default, `--commit` to write, same `.env`
credential loading as `migrate_foods.js` -- mapping the known raw values to `بروتين`/`كارب`/`دهون`
and leaving anything unrecognized untouched rather than guessing. Ran it: all 8 catalog rows
matched a known value, 0 left unrecognized. Committed. Re-running dry afterward confirms
idempotency (0 to update). Kept the script in `tool/` alongside `migrate_foods.js` as a record,
matching that file's precedent.

**Not a bug -- the same environment quirk, a second symptom of it:** after adding a component,
the confirmation `SnackBar` (with its "تراجع" undo action) stayed on screen well past its default
4-second duration -- confirmed stuck for 23+ seconds in one observation. The `_snack()` call
site is unremarkable: a single `ScaffoldMessenger.of(context).showSnackBar` per user action, no
custom duration, never called from `build()`. Given the desktop-taskbar blocker documented below
was independently confirmed to be intercepting input in this same session, the more likely
explanation is that Android's own focus handling around the taskbar pauses Flutter's `Ticker`s
when it engages -- which stalls the SnackBar's built-in dismiss *animation*, not just touch
delivery, since both ride the same paused ticker. Asked the user directly whether they were
testing on this same `emulator-5554`; confirmed yes. Recorded as an open item to re-check on a
real device or a standard (non-desktop-mode) AVD rather than treated as fixed or as a confirmed
app bug either way.

### Manual walk-through, attempt 5 — a real Dismissible crash, a feature request, and the aurora finding upgraded from theory to evidence

**Real bug: "A dismissed Dismissible widget is still part of the tree."** Reported as "error while
animating" on both mark-complete and swipe-to-delete on Today. `TodayController.deleteEntry` and
`MyMealsController.deleteMeal` both awaited their Firestore write with no local update first, so
the list only lost the item once the stream ticked -- a beat after `Dismissible.onDismissed` had
already played its own removal animation and reported itself gone. If anything else rebuilt the
list in that window (an eat-toggle on another row shares the same `Obx`; a stream tick), the
just-dismissed item's key reappeared in the tree after `Dismissible` had already dismissed it,
which is the exact scenario that error is thrown for. Fixed by making both deletes optimistic --
same pattern `TodayController.toggleEaten` already used, with the same rollback-on-failure. This
closes the gap between the widget's own animation completing and the data catching up.

**Feature: a ghost "planned" band on the calorie ring + BMR/target display.** User asked to see,
at a glance, whether today's *planned* meals (scheduled and logged, whether ticked off yet or
not) will reach the day's target -- not just what's already been eaten. `DayLog.plannedTotals`
already existed from Step 1/2 (everything planned, eaten or not) alongside `consumedTotals`
(eaten only); nothing new needed at the domain layer. Added optional `plannedKcal`/`plannedMacros`
to `CalorieRing` -- a faded, neutral (not the vivid sweep-gradient) band on the main ring *and*
each macro sub-ring, running from wherever the solid "eaten" arc ends out to wherever the full
plan would land. Solid = eaten, faded = already planned but not yet ticked off. Added a
`_TargetSummary` card (BMR, recomputed live from the current profile rather than cached, and
today's target kcal) and a small floating legend (`_RingLegend`, `Positioned(top:, right:)`
deliberately -- see its own comment on why that's not the RTL-flip trap it would be for inline
content) over the ring's top-right corner naming what each ring color means.

**The aurora/animation report escalated from "elsewhere" to "everywhere but splash."** The user's
own further testing narrowed it to: motion only during the splash/loading screen, nowhere else --
including Today, which they'd earlier said *did* move. That's the one moment before this AVD's
desktop-taskbar has had a chance to steal focus, which lines up exactly with the zero-pixel-diff
result recorded in attempt 3 (identical code path, identical widget, no motion detected over a
4-second/1539-point sample). Between that measurement and this new data point, treating this as an
environment defect in this specific AVD rather than continuing to guess at code fixes is now the
better-supported call. The one code change made (blob periods 19-31s → 7-13s) is kept regardless
-- faster ambient motion is a real improvement once focus is clean -- but is not claimed as a fix
for the reported freeze. **Whoever picks this up:** verify on a real device or a standard
(non-desktop-mode) AVD before spending more time on it here.

### Manual walk-through, attempt 6 — the actual root cause of the Dismissible crash, plus a stranded-on-a-past-day gap

Attempt 5's optimistic-delete fix was necessary but not sufficient -- the user reported the same
"error while animating" on Today persisting after it shipped, on both add and remove. The real
mechanism: `ListView.builder`'s `itemBuilder` reuses each `Element` purely by its *position* in
the list across rebuilds, unless given `findChildIndexCallback`. Today's `sections` list flattens
the header, every slot's label, every entry, and a spacer after each into one array with no keys
anywhere above the individual `Dismissible`s three layers down. Removing (or, via the shared
`Obx`, even just toggling a *different* row) shifts every later item's index by one -- without a
key lookup, Flutter can rebuild a `Dismissible` at a stale slot with a *different* entry's data
mid-animation, which is exactly what throws "A dismissed Dismissible widget is still part of the
tree." Fixed by giving every item in `sections` (and `header`, shared with the empty-day branch)
an explicit stable key -- role-based for the fixed pieces (`'greeting'`, `'ring'`, ...),
`entry.entryId`-based for anything that can move -- and adding `findChildIndexCallback` to the
`ListView.builder` so it looks items up by that key instead of by position. Required adding
`super.key` to four previously key-less private widgets (`_Greeting`, `_WeekStrip`,
`_TargetSummary`, `_EntryTile`) to even have something to pass.

**Not yet independently re-verified on-device** -- the user's own live session made force-stopping
the app to test this build unsafe to do from here this round; installed without relaunching so it
lands the next time the app is naturally restarted.

**Gap found and fixed along the way:** browsing to a past day with no record (the empty state from
attempt 3's spinner fix) had no way back to today at all -- no week strip in that branch, no
button, nothing short of killing and relaunching the app. Reproduced firsthand while chasing the
Dismissible bug. Added an "العودة لليوم" button to that branch, shown whenever
`!controller.isViewingToday`.

### Both confirmed fixed -- and why they looked unfixed for three rounds

The user kept reporting the Dismissible crash and the frozen aurora as still present after each
of the two prior fixes. Root cause of the *confusion*, not of either bug: the user runs the app
through an IDE debug session (F5/"continue" in their message is exactly that), and every
`adb install -r` in this session installed a new APK without ever restarting that debug process.
Android does not hot-swap a running Dart VM's compiled code on `pm install -r` -- the process has
to actually restart to load it. The same stale, pre-fix build was being retested every single
time. Once the user genuinely restarted the debug session: **the Dismissible error is gone, and
the aurora is visibly moving on every screen.**

This also retroactively settles attempt 5's aurora finding, which should be treated as
**superseded, not just unconfirmed**: the "zero pixel movement even on Today" measurement and the
desktop-taskbar/`TickerMode` theory built on it were measuring this same stale build, not the
sped-up one. The real fix was exactly what it looked like at the time -- periods that were too
slow (19-31s) to read as motion within a short glance, shortened to 7-13s -- and the environment
theory, while a reasonable inference from the evidence available in the moment, was a red herring
caused by the testing method, not a property of the AVD. Worth remembering for next time: **before
trusting a "still broken" report against a fix in this repo, confirm the actual running process
restarted, not just that a new APK was installed** -- `adb shell pidof com.example.diet_app2`
before and after is the check, and if the pid didn't change, nothing was actually retested.

### Blocker, not a bug: this AVD runs in desktop/taskbar mode. `dumpsys window` showed a
`Taskbar` window and a `DisplayBackGestureHandler` sitting in front of the app, both occupying a
band across the bottom third of the screen -- the same band the bottom nav bar and FAB live in.
Taps there never reached the app (confirmed via `dumpsys window`/`dumpsys input` showing the app
correctly focused, and via taps *above* that band -- the week strip -- working immediately and
consistently). This blocked automated tapping of the bottom nav bar, the FAB's quick-add menu, and
therefore My Meals / meal editor / history / profile from this pass. **Not an app defect** — a
form-factor property of this specific AVD image. Whoever continues the walk-through should either
use a standard phone-profile AVD (no taskbar) or a real device, or disable desktop windowing on
this AVD if the emulator config exposes that toggle.

---

Do **not** re-derive the architecture. It is decided and written down in `general.md`.

---

## Done

### Earlier in the session (before the overhaul plan existed)

These were fixes to get the app building at all. Do not undo them.

- Gradle wrapper 7.5 → **8.12** (the Flutter Gradle plugin fails to compile below 8.3 —
  `Unresolved reference: filePermissions`)
- Android Gradle Plugin 7.3.0 → **8.7.3**, Kotlin 1.7.10 → **2.1.0**, Java/`jvmTarget` 8 → **17**
- `compileSdkVersion`/`minSdkVersion`/`targetSdkVersion` → `compileSdk`/`minSdk`/`targetSdk`
- `tflite_flutter` 0.10.4 → 0.12.1 (0.10.4 used `UnmodifiableUint8ListView`, removed in Dart 3.4).
  *Since removed entirely in Step 0.*
- Applied `com.google.gms.google-services` 4.4.2. **This matters:** without it, native Firebase
  init fails with `Default FirebaseApp failed to initialize because no default options were
  found` and only the Dart-side init works.
- `google_sign_in` was added and then **removed at the user's explicit request.**
  **Do not reintroduce it.**

### Step 0 — housekeeping

| Item | File | Note |
|---|---|---|
| Deps restructured | `pubspec.yaml` | `build_runner` → dev_deps; `build_web_compilers` deleted (no `build.yaml` exists, and Flutter web doesn't use it); added `flutter_localizations`, `intl ^0.20.2`, `uuid`, `collection` |
| `tflite_flutter` removed | `pubspec.yaml` | see below |
| All 8 Cairo weights registered | `pubspec.yaml` | was only 2 of 8, so w500/w600 were being synthesized |
| Assets block fixed | `pubspec.yaml` | the bare `- asset/` entry matched **zero** files — Flutter's directory-asset syntax is non-recursive and `asset/` holds only subdirs. Now `- asset/image/` |
| `lib/logic/auto_calculate.dart` deleted | — | TFLite solver: hardcoded to exactly 3 components, index bugs in `swap_indexes`, shallow-copied its caller's list and mutated it, compared against the wrong target |
| `asset/model/` deleted | — | the `.tflite` file and its awkward space-and-parens filename |
| TFLite caller replaced | `complete_male_controller.dart:87` | interim proportional-scale solver, ~15 lines. Actually *more* correct than the model was. Real solver with locks lands in Step 2 |
| Security rules written | `firestore.rules` | full new schema; see "the copyCount rule" below |
| Indexes written | `firestore.indexes.json` | 4 on `marketMeals`, 2 on `foods` |
| `firebase.json` written | — | points at both |
| Migration script written | `tool/migrate_foods.js` | **Node, not Dart** — see deviation below |
| Tool docs | `tool/README.md` | how to get a service account key and run it |
| Lints tightened | `analysis_options.yaml` | `avoid_print`, `use_super_parameters`, `prefer_const_constructors`, `unawaited_futures`, etc. Legacy noise downgraded to `info` so it doesn't drown out real problems |
| Baseline captured | `plans/analyze-baseline.txt` | **584 issues: 0 errors, 66 warnings, 518 info** — all in legacy files. This is the migration checklist |

**Verified:** `flutter pub get` resolves, `flutter build apk --debug` succeeds, app installs and
launches on `emulator-5554`, logcat shows `FirebaseInitProvider: FirebaseApp initialization
successful` with no crash.

---

## Previously blocked -- both now DONE

### Rules and indexes: deployed

The user deployed via `npx firebase-tools`. Verified live by REST: an unauthenticated read of
`appConfig` returns **200** (this ruleset makes it public) while `foods` returns **403**. That
combination is only true of the new ruleset, so it is definitely the one that is live.

### Food catalog: migrated

`node tool/migrate_foods.js --commit` ran successfully. **8 foods** written, 0 skipped, no
all-zero-macro warnings. `single_male` left intact at 8 docs as the rollback.

Verified doc shape: `per100:{protein,carbs,fat}`, `kcalPer100`, `searchTokens`, `active`,
`nameNormalized`, server timestamps.

Credentials setup, for any future run:

- `.env` (gitignored) holds `GOOGLE_APPLICATION_CREDENTIALS` and `FIREBASE_PROJECT_ID`.
  It stores only the **path** to the key, never the key itself.
- `.env.example` is committed as the template.
- `.gitignore` also blocks `node_modules/`, `*serviceAccount*.json`, and
  `*-firebase-adminsdk-*.json` defensively.
- `tool/migrate_foods.js` reads `.env` itself -- nothing needs exporting by hand.
- `package.json` at the repo root is **tooling only**. It is not part of the Flutter build.
- The service account key lives at `Documents/GitHub/`, i.e. outside the repo. Confirmed by
  `git check-ignore`, which reports it as outside the repository entirely.

> **Flag for the user:** the catalog has only **8 components**. That is thin for building meals
> from. Step 2's catalog screen will work, but the app will feel empty. Worth seeding more foods,
> or pulling the "add a custom food" screen earlier than planned.


---

## Step 1 -- what is done

### Domain layer: COMPLETE, `flutter analyze` clean, **72 domain tests green**

Pure Dart, zero Flutter imports, as designed.

| File | Contents |
|---|---|
| `lib/domain/nutrition/macros.dart` | `Macros` value type. `+ - *`, `forGrams`, derived `kcal`, tolerant `fromJson` (Firestore returns int/double/String interchangeably) |
| `lib/domain/nutrition/energy.dart` | `Sex`, `ActivityLevel`, `Goal`, `TargetMode`; Mifflin-St Jeor BMR, TDEE, `dailyTarget`, `macroSplit`, `NutritionTargets` |
| `lib/domain/nutrition/portion_solver.dart` | `solveProportional` (default, with locks) and `solveForMacros` (projected gradient descent). Replaces TFLite |
| `lib/domain/food/food_item.dart` | Immutable catalog entity. No grams, no eaten flag |
| `lib/domain/meal/meal_entry.dart` | **sealed** `MealEntry` = `FoodEntry` \| `MealRefEntry`. Constants `kMaxNestDepth=3`, `kMaxLeafCount=60`, `kGramRounding=5` |
| `lib/domain/meal/meal_definition.dart` | `MealDefinition`, `MealOrigin`, `MealSource` |
| `lib/domain/meal/meal_math.dart` | `macrosOfMeal`, `depthOfMeal`, `descendantMealIdsOf`, `canNest`, `flattenMeal`, `ungroupEntry`, `renumber`, `withRecomputedCaches`; `MealResolver`; `MealDepthExceeded` / `MealCycleException` / `MealNotFound` |
| `lib/domain/day/day_log.dart` | `DayLog`, `DayEntry`, `FrozenItem`, `MealSlot`, `DayEntryOrigin` |
| `lib/domain/schedule/schedule_item.dart` | `ScheduleItem` with a frozen snapshot and `daysOfWeek` |
| `lib/domain/market/market_meal.dart` | `MarketMeal`, `MarketMealGroup`, and the `flatten` helper that builds group spans |

Tests: `test/domain/energy_test.dart` (27), `test/domain/meal_math_test.dart` (30),
`test/domain/macros_test.dart` (7), `test/domain/portion_solver_test.dart` (8).

### Typed food catalog slice: COMPLETE, `flutter analyze lib/data test/data` clean

| File | Contents |
|---|---|
| `lib/data/async_value.dart` | Exhaustive `Loading`, `Data`, and `Error` state for controllers and UI. |
| `lib/data/mappers/food_mapper.dart` | The sole `FoodItem` Firestore boundary; derives kcal from macros instead of trusting the denormalized field. |
| `lib/data/firestore_refs.dart` | Typed `foods` collection using `withConverter<FoodItem>`. |
| `lib/data/repositories/food_repository.dart` | Read-only id/watch and 30-item cursor pagination with category and migration-compatible Arabic token search. |

Tests: `test/data/food_mapper_test.dart` (2), `test/data/food_repository_test.dart` (2).

The new solver tests found a real defect in `solveForMacros`: its fixed gram learning rate made
the projected-gradient solver effectively immobile. It now uses a damped, curvature-normalized
step, which converges for reachable macro targets while retaining the non-negative and per-item
bounds constraints.

**The tests found two real bugs in `macroSplit` before any UI existed** -- exactly what they are
for. The 40% per-macro share cap was overriding the 1.6 g/kg protein floor, which meant a heavy
user on a low target got their protein cut below the safe minimum. Resolution: **the floors win
over the share caps**, because preserving lean mass beats an arbitrary percentage limit. The
share-cap test now asserts the cap only where the floor leaves room for it. `wasAdjusted` also
now reports share-cap compromises, not just waterfall ones.

### Step 1 -- implementation and automated verification complete

- Typed mappers/repositories cover profiles, meals, days, schedules, foods, and the marketplace
  stub. No raw Firestore maps escape mapper boundaries.
- Auth, prefs/session/settings, and the 90-frame performance probe are wired at startup.
- The dark metabolic-aurora design system, bounded glass, motion, reusable components, named
  routes/bindings, splash, real auth/onboarding, four-tab shell, gallery, legacy route, and the
  read-only guest path are live.
- `flutter test`: **82 passed**. Focused analyzer: **0 issues**. Debug and profile APKs build.
- Emulator install, force-stop, and relaunch return to `/home`; logcat has no permission-denied,
  Firebase, Flutter, or fatal exceptions. Firestore contains a completed schema-v2 profile with
  computed targets.
- **Only remaining gate:** DevTools raster p95 on a real mid-range Android. The emulator cannot
  substitute for the real-device requirement in the approved plan.

### Design polish pass (post Step-1 handoff)

The first Step 1 pass shipped structurally correct but visually inert: one shared aurora
controller instead of four independent ones, `GlassCard`/`GlassSurface` missing the specular
highlight the design spec calls for, the calorie ring's sweep gradient rotated 90° off its own
arc start, grain painted as 750 `drawCircle` calls per frame instead of the tiled `ImageShader`
the deviations table above already specifies, and a stock `CircularProgressIndicator` on the
splash screen. Rewritten, `flutter analyze` clean, all 83 tests green (`test/page/home_shell_test.dart`
updated for the FAB no longer being a `FloatingActionButton`):

- `lib/ui/background/aurora_background.dart` — four blobs, independent periods (19/23/29/31s),
  each on its own phase/amplitude so the field drifts in a figure-eight rather than pulsing in
  lockstep; added breathing radius, alpha shift, and a corner vignette. Content moved out of the
  painter's `AnimatedBuilder` and into a sibling in the `Stack` so it stops repainting every frame.
- `lib/ui/background/grain_texture.dart` — now bakes a seeded `ui.Image` once and tiles it via
  `ImageShader` + `BlendMode.softLight`, matching the deviation already recorded above; the old
  version repainted 750 circles per frame, above the text.
- `lib/ui/glass/glass_decoration.dart` — new shared file: body tint gradient, the specular sheen
  (was speced, never implemented), and a `GlassEdgePainter` for a lit edge instead of a flat
  `Border.all`. Used by both `GlassCard` and `GlassSurface`.
- `lib/ui/components/calorie_ring.dart` — sweep gradient now rotated to start at 12 o'clock to
  match the arc; kcal count-up and arc progress read from the same tween so they can't disagree;
  added a bright head dot on the arc tip, a bloom built from wide low-alpha passes instead of a
  per-frame `MaskFilter.blur`, and an over-target ring in the danger hue.
- `lib/ui/motion/pressable.dart` — one `AnimationController` with asymmetric press/release curves
  (fast bite, `easeOutBack` release) replacing three-widget-deep implicit animations.
- `lib/ui/motion/staggered_entry.dart` — one controller drives fade/slide/scale together; gated by
  an `enabled` flag so `ListView.builder` recycling can't replay the entrance on scroll-back (the
  old version had no such gate).
- `lib/page/splash/splash_screen.dart` — replaced the static icon + stock spinner with an
  entrance-animated mark and a swept-gradient arc built from the same painter vocabulary as
  `CalorieRing`, so the first frame already looks like this app.
- `lib/page/home/home_shell.dart` — FAB is now a custom glowing circle (`Pressable`, not
  `FloatingActionButton` — tests locate it via the new `HomeShellKeys.quickAddFab`), tab switches
  cross-fade/slide via `AnimatedSwitcher`, and the nav bar grew a selected-pill indicator with an
  icon swap (outline → filled) and an appearing label.

Not yet touched: `lib/page/onboarding/**`, `lib/page/guest/**`, `lib/page/dev/gallery_screen.dart`
still use the pre-polish primitives only insofar as they render correctly against the new
`GlassCard`/`Pressable` signatures (verified — `flutter analyze` and `flutter test` both clean) but
have not themselves been redesigned. Worth a pass before Step 2 screens build on top of them.

---

## Step 2 — what is done

Full checklist state is in `step2.md`; this is the summary and the things a fresh agent needs to
know that aren't obvious from the checkboxes.

### New screens, all `flutter analyze` clean

| Directory | Screens | Controller(s) |
|---|---|---|
| `lib/page/foods/` | `FoodCatalogScreen`, `FoodPickerSheet`, `FoodDetailScreen` | `FoodCatalogController` (paginated, debounced search, category chips built from the loaded page rather than a separate facet query — see below) |
| `lib/page/meal_editor/` | `MealEditorScreen`, `MealPickerSheet`, `BalanceSheet`, `ScheduleSheet` | `MealEditorController` — thin; every structural rule is a call into `domain/meal/meal_math.dart` |
| `lib/page/my_meals/` | `MyMealsTab` (library + schedule sub-tabs) | `MyMealsController` |
| `lib/page/today/` | `TodayTab`, `QuickAddSheet`, `EditEntrySheet` | `TodayController` |
| `lib/page/history/` | `HistoryScreen` | `HistoryController` |
| `lib/page/profile/` | `ProfileScreen` | `ProfileController` |

### Domain/data additions this step

- `lib/domain/meal/meal_solver_bridge.dart` — `toSolverItem`/`applySolved`, pure functions
  bridging `MealEntry` (grams for a food, a `scale` for a meal ref) to `SolverItem` (always
  grams). A `MealRefEntry` at `scale: 1.0` presents to the solver as "100 units" and is converted
  back afterward — this is what lets **موازنة تلقائية** run over food and nested-meal entries in
  one pass. Unit-tested in `test/domain/meal_solver_bridge_test.dart` (8 tests), including a
  round-trip through the real `solveProportional`.
- `lib/domain/schedule/schedule_item.dart` gained `scheduleVersionOf(List<ScheduleItem>)` — see
  the dedicated note below. Tested in `test/domain/schedule_version_test.dart` (6 tests).
- `lib/ui/components/numeric_stepper.dart` — `GramStepper` generalized into a shared
  tap-to-type/long-press-to-repeat primitive. `ScaleStepper`
  (`lib/ui/components/scale_stepper.dart`) reuses it for `MealRefEntry` portions, shown/typed as a
  percentage.
- `DayRepository` gained `removeEntry`, `getRange` (one range query on the document id for a
  month, not 28–31 individual reads — `dateKey` sorts lexically since it's `yyyy-MM-dd`).
  `ensureDay`'s signature changed: it no longer takes a caller-supplied `scheduleVersion` int; see
  below.
- `ScheduleRepository` gained `getAll()` (a one-time read, alongside the existing `watchAll()`
  stream and `getActiveFor(date)`).
- `ProfileRepository` gained `delete(uid)` — removes the Firestore doc; callers delete the
  Firebase Auth user separately (`AuthService.deleteAccount()`, already existed from Step 1) and
  are expected to do both together, which `ProfileController.deleteAccount()` does.

### `scheduleVersionOf` — how day materialization idempotency actually works

`general.md` and `step2.md` both mention `materializedFromScheduleVersion` without saying where
the version number itself comes from. Implemented as a **content fingerprint**, not a persisted
counter: `scheduleVersionOf` hashes each active `ScheduleItem`'s `(id, order, updatedAt)`, sorted
by id so the result doesn't depend on fetch order. `DayRepository.ensureDay` already has to fetch
today's active schedule items to materialize them, so hashing that same list is free — no extra
document, no extra write on every schedule edit, and the one-read-per-day-open budget in
`general.md` §5.6 stays exactly one read. A stored counter field (on the profile, or its own doc)
would have needed a transactional increment on every `ScheduleRepository.save`/`delete`, for a
guarantee the fingerprint gives for nothing. Tested for stability, order-independence, and
sensitivity to edits/adds/removes in `test/domain/schedule_version_test.dart`.

### Real bugs found and fixed mid-build (not from the legacy code — new to this pass)

- **`ReorderableDragStartListener(index: 0)`** — written once with a placeholder index and a
  comment claiming the widget "reads position from the tree, not this value." That claim is
  false; `ReorderableDragStartListener` uses the index to report which item is being dragged, so
  every drag would have reordered from row 0 regardless of which row was actually grabbed. Fixed
  by threading the real `itemBuilder` index through to the row.
- **`home_shell.dart`'s tab body regressed from `IndexedStack` to `AnimatedSwitcher` +
  `KeyedSubtree`** during the Step 1 design-polish pass (chasing a nicer cross-fade). That tears
  down and rebuilds the whole subtree on every tab switch — harmless when the tabs were
  placeholders, but Today and My Meals now hold live Firestore stream subscriptions and scroll
  state, so it would have resubscribed on every tap and lost scroll position every time. Reverted
  to `IndexedStack` before either controller existed to be affected by it.
- `test/page/home_shell_test.dart` was deleted, not fixed. `HomeShell` now requires a signed-in
  `AuthService.currentUser` and live `SessionController`/Firestore state to render at all (both
  Today and My Meals construct real repository-backed controllers in `initState`), which a plain
  `flutter test` widget test can't provide without `fake_cloud_firestore` and a mocked
  `FirebaseAuth` — out of scope for this pass. This matches the rest of the suite's existing
  boundary: pure-Dart/mapper logic is unit-tested, Firestore-backed reads are not.

- **Day switching flashed "لا يوجد سجل لهذا اليوم" before every day loaded.** `selectDate`
  nulled `day.value` and set `loading.value = false` in the same breath, so for the frames
  before the Firestore snapshot arrived the screen was in `loading == false && day == null` —
  the exact signature the view uses for "this day has no record". Fixed by keeping `loading`
  true until the first snapshot lands, plus a `_materializing` flag so a `null` arriving while
  today's document is still being written is treated as not-yet rather than as an answer.
  `_materializeToday` releases both in a `finally`. Today's screen is now an `AnimatedSwitcher`
  whose child is keyed on `DayLog.keyFor(selectedDate)`, so a date change cross-fades while an
  eat-toggle on the same day stays an in-place rebuild. The switcher needs a custom
  `layoutBuilder` — the default centres the outgoing child and sizes the stack to the incoming
  one, collapsing a full-height `CustomScrollView` mid-transition.

- **Week strip only shows days that exist.** A chip for an empty past day dead-ended on "no
  record for this day", and a future chip was rendered at 35% opacity with `onTap: null` — both
  are places with nothing to see. `DayRepository.watchRange` (a live version of `getRange`: one
  bounded `FieldPath.documentId` listener, no composite index) feeds `TodayController
  .loggedDayKeys`, and the strip renders only those days plus today and the current selection,
  so it can never become a strip with no way back. Re-subscribed on rollover only when the week
  itself changed.

- **`Sex.preferNotToSay` removed.** It existed so the app could still compute *something*,
  using the midpoint (-78) of the male/female Mifflin-St Jeor constants. Dropped at the user's
  request. `ProfileMapper` falls back to `Sex.male` for profiles written before the change, since
  the stored string no longer matches any enum value; the profile screen can correct it.
- **The rate of loss is now editable, in kcal.** `weeklyRateKg` had no UI on the profile screen
  at all — it was set once in onboarding from a `.25/.5/.75/1.0` dropdown and never revisited.
  The profile screen now has a 0–1100 kcal/day slider (step 50) writing
  `ProfileController.dailyDelta`, which is the same value as `weeklyRateKg` converted through
  `kKcalPerKg`, not a second stored field. `dailyDeltaForWeeklyRate` / `weeklyRateForDailyDelta`
  in `energy.dart` are the one pair of conversions, shared by `dailyTarget` and the UI.
  Projections (kg/week, /month, /year) are computed from `effectiveWeeklyRateKg` — what the
  finished target actually delivers — because `dailyTarget` clamps at the energy floor, so an
  aggressive cut becomes a gentler one and showing the requested rate would be a lie. The card
  says so explicitly when the clamp bites.

- **Committing an action now leaves the screen it was performed on.** Two places broke the rule
  every sheet in the app already followed. The meal editor's app-bar check called
  `_save(pop: false)` — the *only* caller of that flag — so it saved with no snack and no
  navigation, indistinguishable from the tap doing nothing; the flag is gone and `_save` always
  snacks and pops. The profile screen showed "تم حفظ التغييرات" and stayed on the form, which
  reads as the save not having taken. It now pops on success and stays put on failure so the
  input is not lost.

### Deviations specific to Step 2 (also folded into the table below)

- **`AsyncView<T>` not used in the food catalog.** It models loading/data/error as three
  mutually exclusive states; the catalog needs "has items already AND is loading more" at the
  same time, which doesn't fit. Used `EmptyState`/`ErrorState`/`CircularProgressIndicator` inline
  instead.
- **Category chips are built from the loaded page, not a separate distinct-category query.**
  With an 8-row catalog the first page (`limit(30)`) already *is* the whole catalog. A dedicated
  facet query would be exactly the kind of unbounded-collection read this step's catalog screen
  exists to fix elsewhere. Revisit once the catalog is seeded past a page or two — see the
  Step 0 flag about the catalog being thin, still unresolved.
- **Schedule reordering is up/down buttons, not drag-and-drop.** `ReorderableListView` doesn't
  support nesting one instance per slot inside a single scrolling view. Still satisfies "the
  schedule is reorderable" — just not via drag.
- **`lib/page/setting/` deleted with no Step 2 replacement**, even though nothing in `step2.md`
  builds one. Judged safe on inspection: the legacy screen had no real settings in it — five
  buttons that mutated a mutable `static Color AppColors.buttonColor` global nothing in the new
  code reads, with placeholder `"title"` button labels (the untranslated-string bug the plan
  already lists). Nothing functional was lost. **Flag for whoever builds Step 4's real Settings
  screen:** `SettingsController` (theme mode, accent, graphics quality, digits, units) already
  exists and is fully wired end to end from Step 1 — it just has no screen yet.
- **`lib/service/create_meals_repository.dart` and `lib/service/user_auth_repository.dart`
  deleted** though absent from `step2.md`'s explicit 2.7 list. Found orphaned by a dependency
  sweep before deleting anything: the first's only three importers were all inside directories
  already being deleted; the second had zero importers anywhere in the repo and was fully
  superseded by Step 1's `AuthService`, never migrated over in the first place.

---

## Deviations from the approved plan so far

| Plan said | What was done | Why |
|---|---|---|
| `tool/migrate_foods.dart` | `tool/migrate_foods.js` (Node + `firebase-admin`) | The Admin SDK bypasses security rules, so `foods` stays client-read-only and no weakened ruleset ever gets deployed. A Dart script would have needed a Flutter runtime *and* a temporary permissive rule. |
| Generate `asset/image/noise.png` | Deferred to Step 1 as `lib/ui/background/grain_texture.dart` | Procedural generation — a seeded `Random` painted once into a `ui.Image` and tiled via `ImageShader`. No binary asset in git, tunable at runtime, one-time cost. |
| TFLite caller "stubbed out" | Replaced with a working proportional-scale solver | ~15 lines, and strictly better than the broken model. Kept the legacy screen functional until Step 2 deleted it (now moot — the screen is deleted). |
| `intl: ^0.19.0` | `intl: ^0.20.2` | `flutter_localizations` from the SDK pins `intl` to 0.20.2; 0.19.0 failed version solving. |
| `AsyncView` in the food catalog | `EmptyState`/`ErrorState` used directly | Pagination needs simultaneous "has items" + "loading more" states `AsyncValue`'s 3-way switch doesn't model. |
| Schedule "reorderable" | Up/down buttons, not drag | `ReorderableListView` can't nest per-slot inside one scroll view. |
| `materializedFromScheduleVersion` source | Content fingerprint (`scheduleVersionOf`), not a stored counter | Free from the fetch `ensureDay` already does; a counter would need a transactional write on every schedule edit for no extra guarantee. |
| Step 2.7's deletion list | Also deleted `create_meals_repository.dart` + `user_auth_repository.dart` | Found orphaned by dependency analysis; not in the plan's list but unreachable after the listed deletions. |
| `lib/page/setting/` deletion | Deleted with no Step 2 replacement | The legacy screen was non-functional (mutated a dead static, placeholder labels); Step 4 still owes a real Settings screen over the already-working `SettingsController`. |
| Living Glass Phase 1 user-motion preference | OS reduced-motion/accessibility is honoured now; no persisted user toggle yet | `AppSettings` has no motion/haptics fields. Adding them would change the profile model, mapper, and persistence, conflicting with the Kimi plan's explicit Phase 1 no-data-model boundary. Wire the setting in Step 4. |
| Kimi phases must wait for the previous real-device raster p95 exit gate | Phase 3 and the safe Phase 4 motion primitives proceeded before that measurement | The user explicitly directed the implementation to continue one phase at a time without stopping. The p95 baseline/new measurement remains an explicit release gate, not replaced by emulator or automated evidence. |

---

## Decisions already locked — do not relitigate

Full detail in `general.md` §2. Summary:

- **Clean break on local data.** Wipe SharedPreferences on first launch (`schemaVersion < 2`).
  No migration code ships in the app.
- **Real Firebase Auth**, uid as the identity, profile in `users/{uid}`.
  Signup takes **email + password + display name**.
- **Full daily log + history.** `days/{yyyy-MM-dd}`, flattened and frozen at insert time.
- **Marketplace uses copy-on-add**, never a live reference.
- **`male` → `meal`** rename throughout ("male" is a misspelling of "meal" in the old code).
- **TFLite deleted**, replaced by a deterministic portion solver.
- **`diet_details_screen.dart` (the cost page) is dropped.**
- Dark theme only until Step 4. Western digits by default. Hand-rolled motion primitives.
- **`google_sign_in` stays out.**

## Still undecided

- **The AI assistant.** See `step5.md`. Not specified at all yet. Nothing in Steps 0–4 depends
  on it. Do not write code for it.
- Moderation for the marketplace (a client-side mute list is the Step 3 stopgap).
- Whether to rename the package from `com.example.diet_app2` — it would break the existing
  Firebase Android app registration and need a fresh `google-services.json`. Ask first.

---

## Environment

- Flutter 3.41.2 / Dart 3.11, Windows 11
- Gradle 8.12, AGP 8.7.3, Kotlin 2.1.0, Java 17, minSdk 26, multidex
- Firebase project **`diet-app-a908a`**, Android package `com.example.diet_app2`
- Emulator: `emulator-5554` (Android 17 / API 37)
- `adb` is not on PATH — it lives at
  `~/AppData/Local/Android/sdk/platform-tools/adb.exe`
- Node v24.13.0 available; Firebase CLI is **not** installed globally (use `npx firebase-tools`)

## Useful commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d emulator-5554
```
