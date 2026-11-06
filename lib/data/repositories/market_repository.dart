import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/market/market_meal.dart';
import '../../domain/meal/meal_definition.dart';
import '../../domain/meal/meal_entry.dart';
import '../../domain/meal/meal_math.dart';
import '../../domain/nutrition/macros.dart';
import '../../domain/day/day_log.dart';
import '../../domain/schedule/schedule_item.dart';
import '../firestore_refs.dart';
import 'meal_repository.dart';
import 'schedule_repository.dart';

enum MarketSort { newest, mostCopied }

class MarketPage {
  final List<MarketMeal> meals;
  final DocumentSnapshot<MarketMeal>? lastDocument;
  const MarketPage(this.meals, this.lastDocument);
}

/// Builds an independent private meal before any Firestore write.
MealDefinition buildMarketCopy(
  MarketMeal market,
  String uid, {
  List<double>? grams,
  Uuid uuid = const Uuid(),
  DateTime? copiedAt,
}) {
  if (!market.isPublished || market.items.isEmpty) {
    throw StateError('market_meal_unavailable');
  }
  if (grams != null &&
      (grams.length != market.items.length ||
          grams.any(
              (amount) => !amount.isFinite || amount < 1 || amount > 2000))) {
    throw const FormatException('invalid_market_weights');
  }
  final now = copiedAt ?? DateTime.now();
  return MealDefinition(
    id: uuid.v4(),
    ownerUid: uid,
    name: market.name,
    notes: market.notes,
    imageUrl: market.imageUrl,
    entries: [
      for (var i = 0; i < market.items.length; i++)
        FoodEntry(
          localId: uuid.v4(),
          order: i,
          foodId: market.items[i].foodId,
          name: market.items[i].name,
          per100: market.items[i].per100,
          grams: grams?[i] ?? market.items[i].grams,
        ),
    ],
    origin: MealOrigin.copiedFromMarket,
    source: MealSource(
      marketMealId: market.id,
      authorUid: market.authorUid,
      authorName: market.authorName,
      version: market.version,
      copiedAt: now,
    ),
    createdAt: now,
    updatedAt: now,
  );
}

ScheduleItem buildMarketSchedule(
  MarketMeal market,
  MealDefinition copy, {
  required List<double> grams,
  required MealSlot slot,
  required Set<int> daysOfWeek,
  required int order,
  Uuid uuid = const Uuid(),
  DateTime? createdAt,
}) {
  if (grams.length != market.items.length ||
      grams.any((amount) => !amount.isFinite || amount < 1 || amount > 2000) ||
      daysOfWeek.isEmpty ||
      daysOfWeek.any((day) => day < 1 || day > 7)) {
    throw const FormatException('invalid_market_schedule');
  }
  final now = createdAt ?? DateTime.now();
  return ScheduleItem(
    id: uuid.v4(),
    mealId: copy.id,
    name: copy.name,
    snapshot: [
      for (var i = 0; i < market.items.length; i++)
        market.items[i].withGrams(grams[i]),
    ],
    slot: slot,
    order: order,
    daysOfWeek: daysOfWeek,
    createdAt: now,
    updatedAt: now,
  );
}

class MarketRepository {
  final FirestoreRefs _refs;

  MarketRepository({FirestoreRefs? refs}) : _refs = refs ?? FirestoreRefs();

  Future<MarketMeal?> getPublished(String id) async {
    final meal = (await _refs.marketMeals.doc(id).get()).data();
    return meal?.isPublished == true ? meal : null;
  }

  /// Publishes a self-contained snapshot and records its id on the source meal
  /// in the same batch. Republish keeps the public id and its counters.
  Future<MarketMeal> publish(
    MealDefinition source, {
    required String authorName,
    required String name,
    required String notes,
    required List<String> tags,
  }) async {
    if (name.trim().isEmpty || name.trim().length > MarketMeal.maxNameLength) {
      throw const FormatException('invalid_market_name');
    }
    final meals =
        await MealRepository(uid: source.ownerUid, refs: _refs).getAll();
    final current = meals.firstWhere((meal) => meal.id == source.id);
    final resolver = MealResolver(meals);
    final flat = flattenMeal(current, resolver);
    if (flat.isEmpty || flat.length > MarketMeal.maxItems) {
      throw const FormatException('invalid_market_items');
    }
    final flattened = MarketMeal.flatten(flat);
    final existingId = current.publishedMarketMealId;
    final existing = existingId == null ? null : await getPublished(existingId);
    if (existingId != null && existing == null) {
      throw StateError('published_meal_missing');
    }
    final publicRef = existingId == null
        ? _refs.marketMeals.doc()
        : _refs.marketMeals.doc(existingId);
    final now = DateTime.now();
    final market = MarketMeal(
      id: publicRef.id,
      authorUid: current.ownerUid,
      authorName: authorName.trim(),
      name: name.trim(),
      notes: notes.trim().isEmpty ? null : notes.trim(),
      imageUrl: current.imageUrl,
      items: flattened.items,
      groups: flattened.groups,
      totals: flattened.items
          .fold(Macros.zero, (Macros sum, item) => sum + item.macros),
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      copyCount: existing?.copyCount ?? 0,
      likeCount: existing?.likeCount ?? 0,
      version: (existing?.version ?? 0) + 1,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final batch = _refs.firestore.batch();
    batch.set(publicRef, market);
    batch.update(_refs.meals(current.ownerUid).doc(current.id),
        {'publishedMarketMealId': publicRef.id});
    await batch.commit();
    return market;
  }

  /// Soft-removes the public meal. The source id is cleared in the same batch
  /// so a later publish starts a fresh public document instead of targeting an
  /// unreadable removed document.
  Future<void> unpublish(
    MealDefinition source, {
    bool deleteSource = false,
  }) async {
    final publicId = source.publishedMarketMealId;
    if (publicId == null) return;
    final batch = _refs.firestore.batch();
    batch.update(_refs.marketMeals.doc(publicId), {
      'status': MarketMealStatus.removed.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
    final privateRef = _refs.meals(source.ownerUid).doc(source.id);
    if (deleteSource) {
      batch.delete(privateRef);
    } else {
      batch.update(privateRef, {'publishedMarketMealId': null});
    }
    await batch.commit();
  }

  Future<MarketPage> browse({
    MarketSort sort = MarketSort.newest,
    DocumentSnapshot<MarketMeal>? after,
  }) async {
    Query<MarketMeal> query = _refs.marketMeals
        .where('status', isEqualTo: MarketMealStatus.published.name)
        .orderBy(sort == MarketSort.newest ? 'createdAt' : 'copyCount',
            descending: true)
        .limit(20);
    if (after != null) query = query.startAfterDocument(after);
    final page = await query.get();
    return MarketPage(
      page.docs.map((doc) => doc.data()).toList(growable: false),
      page.docs.isEmpty ? null : page.docs.last,
    );
  }

  /// Makes a private snapshot with fresh ids. A counter failure cannot undo a
  /// successfully saved private copy or cause a retry to duplicate it.
  Future<MealDefinition> copyToLibrary(
    MarketMeal market,
    String uid, {
    List<double>? grams,
  }) async {
    final meal = buildMarketCopy(market, uid, grams: grams);
    final saved = await MealRepository(uid: uid, refs: _refs).save(meal);
    await incrementCopyCountBestEffort(market.id);
    return saved;
  }

  /// Saves an independently weighted private meal and its recurring snapshot
  /// together, so a failed schedule write cannot strand an extra library copy.
  Future<ScheduleItem> copyToSchedule(
    MarketMeal market,
    String uid, {
    required List<double> grams,
    required MealSlot slot,
    required Set<int> daysOfWeek,
  }) async {
    final draft = buildMarketCopy(market, uid, grams: grams);
    final meal = withRecomputedCaches(draft, MealResolver([draft]));
    final existing = await ScheduleRepository(uid: uid, refs: _refs).getAll();
    final schedule = buildMarketSchedule(market, meal,
        grams: grams,
        slot: slot,
        daysOfWeek: daysOfWeek,
        order: existing.length);
    final batch = _refs.firestore.batch();
    batch.set(_refs.meals(uid).doc(meal.id), meal);
    batch.set(_refs.schedule(uid).doc(schedule.id), schedule);
    await batch.commit();
    await incrementCopyCountBestEffort(market.id);
    return schedule;
  }

  Future<void> incrementCopyCountBestEffort(String marketId) async {
    try {
      await _refs.marketMeals
          .doc(marketId)
          .update({'copyCount': FieldValue.increment(1)});
    } on FirebaseException {
      // The private copy is complete; a counter failure must not imply that
      // retrying the action is safe. The UI reports the saved copy.
    }
  }
}
