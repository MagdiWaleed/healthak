import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../data/repositories/day_repository.dart';
import '../../data/repositories/meal_repository.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/food/food_item.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_entry.dart';
import '../../domain/meal/meal_math.dart';
import '../../domain/meal/meal_solver_bridge.dart';
import '../../domain/nutrition/energy.dart';
import '../../domain/nutrition/macros.dart';
import '../../domain/nutrition/portion_solver.dart';
import '../../domain/schedule/schedule_item.dart';
import '../../service/session_controller.dart';

/// A single-slot undo: the entry list exactly as it was before the last
/// structural change (add, remove, ungroup, or an applied auto-balance).
/// Deliberately not a stack -- one level is what a snackbar's "تراجع" button
/// can offer honestly.
class _Undo {
  final List<MealEntry> entries;
  const _Undo(this.entries);
}

/// Owns one meal being built or edited.
///
/// Deliberately thin: every structural rule (cycle/depth/leaf guards,
/// flattening, renumbering, cache recomputation) already exists in
/// `domain/meal/meal_math.dart` from Step 1 and is unit-tested there. This
/// controller's job is to hold UI state and call into it -- see Step 2's risk
/// #1.
class MealEditorController extends GetxController {
  final String uid;
  final MealRepository _meals;
  final DayRepository _days;
  final ScheduleRepository _schedule;
  final SessionController _session;
  final Uuid _uuid;

  /// Every other meal in the library, used to resolve `MealRefEntry` macros
  /// and to run [canNest]. Excludes the meal being edited (a meal can never
  /// reference itself, and keeping a half-edited draft out of the resolver
  /// avoids feeding it its own in-progress state).
  final _otherMeals = <String, MealDefinition>{}.obs;

  final name = ''.obs;
  final entries = <MealEntry>[].obs;
  final lockedIds = <String>{}.obs;
  final loading = true.obs;
  final saving = false.obs;
  final error = RxnString();
  final _todayDay = Rxn<DayLog>();
  StreamSubscription<DayLog?>? _todaySubscription;

  /// Set once a meal is loaded for editing; null while composing a new one.
  final String? _editingId;
  late final String _draftId = _editingId ?? _uuid.v4();
  MealOrigin _origin = MealOrigin.authored;
  MealSource? _source;
  DateTime _createdAt = DateTime.now();

  _Undo? _undo;

  MealEditorController({
    required this.uid,
    String? editingId,
    MealRepository? meals,
    DayRepository? days,
    ScheduleRepository? schedule,
    SessionController? session,
    Uuid uuid = const Uuid(),
  })  : _editingId = editingId,
        _meals = meals ?? MealRepository(uid: uid),
        _days = days ?? DayRepository(uid: uid),
        _schedule = schedule ?? ScheduleRepository(uid: uid),
        _session = session ?? Get.find<SessionController>(),
        _uuid = uuid;

  /// Every other meal in the library, for the "إضافة وجبة" picker.
  List<MealDefinition> get otherMeals => _otherMeals.values.toList();

  bool get isNew => _editingId == null;
  bool get isEmpty => entries.isEmpty;
  bool get canUndo => _undo != null;

  /// The current daily target is a comparison aid while composing a meal; the
  /// draft itself remains a reusable recipe and never stores this value.
  NutritionTargets? get dailyTargets => _session.profile.value?.targets;

  /// The whole planned day after applying this draft.
  ///
  /// While editing a meal that is already present today, its frozen entry is
  /// removed from the comparison before the draft is added. Otherwise the
  /// same meal is counted twice and every editor page reports a different,
  /// inflated remainder. Multiple occurrences are replaced one-for-one.
  Macros get totalsAfterApplyingDraft {
    final day = _todayDay.value;
    if (day == null) return totals;
    return day.plannedTotalsAfterDraft(
      replacingMealId: _editingId,
      draftTotals: totals,
    );
  }

  MealResolver get _resolver => MealResolver(_otherMeals.values);

  /// Live totals, recursing through any nested `MealRefEntry`. This is what
  /// the animated header re-tweens against on every change.
  Macros get totals {
    final draft = _draftMeal();
    try {
      return macrosOfMeal(draft, _resolver);
    } on Exception {
      // A dangling reference (the referenced meal was deleted elsewhere)
      // shouldn't crash the header -- show what's still resolvable as zero
      // rather than the whole totals blowing up.
      return Macros.zero;
    }
  }

  int get depth {
    try {
      return depthOfMeal(_draftMeal(), _resolver);
    } on Exception {
      return 0;
    }
  }

  int get leafCount {
    try {
      return leafCountOfMeal(_draftMeal(), _resolver);
    } on Exception {
      return entries.length;
    }
  }

  @override
  void onInit() {
    super.onInit();
    _todaySubscription = _days.watch(DateTime.now()).listen((day) {
      _todayDay.value = day;
    });
    _load();
  }

  @override
  void onClose() {
    _todaySubscription?.cancel();
    super.onClose();
  }

  Future<void> _load() async {
    loading.value = true;
    try {
      final all = await _meals.getAll();
      MealDefinition? editing;
      for (final meal in all) {
        if (meal.id == _editingId) {
          editing = meal;
        } else {
          _otherMeals[meal.id] = meal;
        }
      }

      if (editing != null) {
        name.value = editing.name;
        entries.value = editing.orderedEntries;
        _origin = editing.origin;
        _source = editing.source;
        _createdAt = editing.createdAt;
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  MealDefinition _draftMeal() => MealDefinition(
        id: _draftId,
        ownerUid: uid,
        name: name.value,
        entries: entries,
        createdAt: _createdAt,
        updatedAt: DateTime.now(),
        origin: _origin,
        source: _source,
      );

  void setName(String value) => name.value = value;

  void _pushUndo() => _undo = _Undo(List.of(entries));

  void undo() {
    final saved = _undo;
    if (saved == null) return;
    entries.value = saved.entries;
    _undo = null;
  }

  /// Appends a catalog food at 100g. The default weight matches how the
  /// catalog itself states macros, so a freshly added row already reads
  /// correctly before the user touches the stepper.
  void addFood(FoodItem food) {
    _pushUndo();
    entries.add(FoodEntry(
      localId: _uuid.v4(),
      order: entries.length,
      foodId: food.id,
      name: food.name,
      per100: food.per100,
      grams: 100,
    ));
  }

  /// Whether [child] may be nested into the meal currently being edited.
  /// Exposed so the meal picker can grey out illegal choices instead of
  /// letting the user pick one and then explaining why it bounced.
  NestCheck checkNest(MealDefinition child) =>
      canNest(parent: _draftMeal(), child: child, resolver: _resolver);

  /// Result of attempting to add [child] as a `MealRefEntry`. `null` on
  /// success; otherwise the Arabic refusal message to show.
  String? addMealRef(MealDefinition child) {
    final check = checkNest(child);
    if (!check.allowed) return check.messageAr;

    _pushUndo();
    Macros childTotals;
    try {
      childTotals = macrosOfMeal(child, _resolver);
    } on Exception {
      childTotals = child.totalsCache;
    }

    entries.add(MealRefEntry(
      localId: _uuid.v4(),
      order: entries.length,
      mealId: child.id,
      name: child.name,
      scale: 1.0,
      cachedTotals: childTotals,
      cachedAt: DateTime.now(),
    ));
    return null;
  }

  void updateFoodGrams(String localId, double grams) {
    final index = entries.indexWhere((e) => e.localId == localId);
    if (index == -1) return;
    final entry = entries[index];
    if (entry is! FoodEntry) return;
    entries[index] = entry.copyWith(grams: grams);
  }

  void updateRefScale(String localId, double scale) {
    final index = entries.indexWhere((e) => e.localId == localId);
    if (index == -1) return;
    final entry = entries[index];
    if (entry is! MealRefEntry) return;
    entries[index] = entry.copyWith(scale: scale);
  }

  void removeEntry(String localId) {
    _pushUndo();
    entries.value = renumber(
      entries.where((e) => e.localId != localId).toList(),
    );
    lockedIds.remove(localId);
  }

  void reorder(int oldIndex, int newIndex) {
    _pushUndo();
    final list = List<MealEntry>.of(entries);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    entries.value = renumber(list);
  }

  /// Expands a `MealRefEntry` into its scaled leaf foods, in place.
  /// See `ungroupEntry`'s doc: this is what stops a reference from being a
  /// trap the user can't edit into.
  String? ungroup(String localId) {
    final index = entries.indexWhere((e) => e.localId == localId);
    if (index == -1 || entries[index] is! MealRefEntry) return null;

    _pushUndo();
    try {
      entries.value = ungroupEntry(
        entries: entries,
        localId: localId,
        resolver: _resolver,
        newLocalId: _uuid.v4,
      );
      lockedIds.remove(localId);
      return null;
    } on Exception {
      // Nothing was mutated by the failed attempt, but the undo point above
      // was pushed pre-emptively -- drop it so a later undo can't restore to
      // a state that was never actually left.
      _undo = null;
      return 'تعذر فك تجميع هذه الوجبة';
    }
  }

  void toggleLock(String localId) {
    if (!lockedIds.add(localId)) lockedIds.remove(localId);
  }

  /// Runs the portion solver against every entry, mixed food and meal-ref
  /// alike.
  ///
  /// A `MealRefEntry` has no grams -- it has a scale factor. The solver only
  /// understands (per100, grams) pairs, so a ref is presented to it as
  /// 100 units == scale 1.0 and converted back afterwards. This is exactly
  /// what `SolverItem.per100`'s doc comment anticipates: "for a nested meal
  /// reference this is the resolved totals treated as a single composite
  /// ingredient."
  SolverResult autoBalance({required double targetKcal, Macros? targetMacros}) {
    final items = [
      for (final e in entries)
        toSolverItem(e, locked: lockedIds.contains(e.localId)),
    ];
    return targetMacros == null
        ? solveProportional(items: items, targetKcal: targetKcal)
        : solveForMacros(
            items: items, targetKcal: targetKcal, targetMacros: targetMacros);
  }

  void applyBalance(SolverResult result) {
    _pushUndo();
    final byId = {for (final item in result.items) item.localId: item};
    entries.value = [
      for (final entry in entries) applySolved(entry, byId[entry.localId]),
    ];
  }

  /// Persists the draft. Returns the saved meal, with caches recomputed by
  /// the repository against every other meal in the library.
  Future<MealDefinition?> save() async {
    if (name.value.trim().isEmpty || entries.isEmpty) return null;
    saving.value = true;
    error.value = null;
    try {
      final saved = await _meals.save(_draftMeal().copyWith(
        name: name.value.trim(),
        entries: entries,
      ));
      return saved;
    } catch (e) {
      error.value = e.toString();
      return null;
    } finally {
      saving.value = false;
    }
  }

  /// Flattens the current draft and logs it against today only. Saves the
  /// meal first if it hasn't been saved yet, so a one-shot always has a
  /// `sourceMealId` to point back at.
  Future<bool> addToToday() async {
    final saved = await save();
    if (saved == null) return false;

    final profile = _session.profile.value;
    if (profile == null) return false;

    final now = DateTime.now();
    final day = await _days.ensureDay(date: now, targets: profile.targets);
    final flat =
        flattenMeal(saved, MealResolver([..._otherMeals.values, saved]));

    await _days.upsertEntry(
      day.dateKey,
      DayEntry(
        entryId: _uuid.v4(),
        origin: DayEntryOrigin.oneShot,
        sourceMealId: saved.id,
        name: saved.name,
        slot: MealSlot.snack,
        order: day.entries.length,
        items: [for (final f in flat) FrozenItem.fromFlat(f)],
      ),
    );
    return true;
  }

  /// Schedule items already pointing at this meal, if it's being edited.
  ///
  /// Their `snapshot` is frozen at the moment they were created (see
  /// [ScheduleItem]'s doc) -- editing the meal here does not touch them.
  /// The screen calls this after a save to decide whether to ask "update the
  /// schedule too?" rather than silently leaving them stale.
  Future<List<ScheduleItem>> linkedScheduleItems() async {
    if (_editingId == null) return const [];
    final all = await _schedule.getAll();
    return all.where((item) => item.mealId == _editingId).toList();
  }

  /// Re-flattens the just-saved meal into each of [items]' snapshots,
  /// preserving their slot, order, and days. Called only when the user
  /// explicitly opts in via the "تحديث الجدول أيضاً؟" prompt.
  Future<void> refreshLinkedSchedule(List<ScheduleItem> items) async {
    final saved =
        _draftMeal().copyWith(name: name.value.trim(), entries: entries);
    final flat =
        flattenMeal(saved, MealResolver([..._otherMeals.values, saved]));
    final snapshot = [for (final f in flat) FrozenItem.fromFlat(f)];
    for (final item in items) {
      await _schedule.save(item.copyWith(
        name: saved.name,
        snapshot: snapshot,
        updatedAt: DateTime.now(),
      ));
    }
  }

  /// Saves the draft and creates a recurring [ScheduleItem] from it.
  Future<bool> addToSchedule({
    required MealSlot slot,
    required Set<int> daysOfWeek,
  }) async {
    final saved = await save();
    if (saved == null) return false;

    final flat =
        flattenMeal(saved, MealResolver([..._otherMeals.values, saved]));
    final now = DateTime.now();
    await _schedule.save(ScheduleItem(
      id: _uuid.v4(),
      mealId: saved.id,
      name: saved.name,
      snapshot: [for (final f in flat) FrozenItem.fromFlat(f)],
      slot: slot,
      order: 0,
      daysOfWeek: daysOfWeek,
      createdAt: now,
      updatedAt: now,
    ));
    return true;
  }
}
