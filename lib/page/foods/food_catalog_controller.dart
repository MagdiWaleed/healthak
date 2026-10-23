import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../../data/repositories/food_repository.dart';
import '../../domain/food/food_item.dart';

/// Backs both the standalone catalog screen and [FoodPickerSheet].
///
/// Paginated over [FoodRepository.list] -- the legacy `males_repository.dart`
/// did one unbounded `.get()` over the whole collection, which was survivable
/// at 8 rows and would not survive a real catalog.
class FoodCatalogController extends GetxController {
  final FoodRepository _repository;

  FoodCatalogController({FoodRepository? repository, String? uid})
      : _repository = repository ?? FoodRepository(uid: uid);

  final items = <FoodItem>[].obs;

  /// The user's own components, loaded whole on every reset.
  ///
  /// Held separately from [items] so they can be re-filtered locally on each
  /// query without another read, and so [isPersonal] can answer which rows
  /// the user is allowed to delete.
  final _personal = <FoodItem>[].obs;

  bool get canCreate => _repository.uid != null;

  bool isPersonal(FoodItem food) => _personal.any((f) => f.id == food.id);

  /// True only for the very first page of a given filter. Distinguished from
  /// [loadingMore] so the list doesn't flash back to a full-screen spinner
  /// every time the user scrolls near the bottom.
  final loading = true.obs;
  final loadingMore = false.obs;
  final error = Rxn<String>();
  final hasMore = true.obs;

  final searchText = ''.obs;
  final selectedCategory = Rxn<String>();

  DocumentSnapshot<FoodItem>? _cursor;
  Timer? _debounce;

  @override
  void onInit() {
    super.onInit();
    unawaited(_load(reset: true));
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  /// Categories seen in the pages loaded so far. There is no separate
  /// distinct-category query -- with an eight-row catalog the first page
  /// already is the catalog, and a dedicated facet query would mean another
  /// unbounded read on a collection this step is explicitly fixing that on.
  /// Revisit once the catalog is seeded past a page or two.
  List<String> get categories => {
        for (final item in items)
          if ((item.category ?? '').isNotEmpty) item.category!,
      }.toList()
        ..sort();

  void search(String text) {
    searchText.value = text;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_load(reset: true)),
    );
  }

  void selectCategory(String? category) {
    if (selectedCategory.value == category) return;
    selectedCategory.value = category;
    unawaited(_load(reset: true));
  }

  Future<void> reload() => _load(reset: true);

  Future<void> loadMore() async {
    if (loading.value || loadingMore.value || !hasMore.value) return;
    loadingMore.value = true;
    await _load(reset: false);
  }

  /// Creates a personal component and shows it immediately.
  ///
  /// The new row is inserted locally rather than triggering a full reload, so
  /// the user sees what they just typed at the top of the list without the
  /// catalog flashing through a spinner.
  Future<FoodItem> create(FoodItem draft) async {
    final saved = await _repository.createPersonal(draft);
    _personal.insert(0, saved);
    if (_matchesFilters(saved)) items.insert(0, saved);
    return saved;
  }

  Future<void> deletePersonal(FoodItem food) async {
    await _repository.deletePersonal(food.id);
    _personal.removeWhere((f) => f.id == food.id);
    items.removeWhere((f) => f.id == food.id);
  }

  /// Applies the active search/category filter to a personal component.
  ///
  /// The shared catalog does this server-side via `searchTokens`, which a
  /// personal component has no equivalent of; a `contains` over the folded
  /// name is both cheaper and more forgiving at this collection size.
  bool _matchesFilters(FoodItem food) {
    final category = selectedCategory.value;
    if (category != null &&
        category.isNotEmpty &&
        food.category != category) {
      return false;
    }
    final token = normalizeFoodSearchToken(searchText.value);
    if (token == null) return true;
    return food.nameNormalized.contains(token) ||
        foldArabic(food.name).contains(token);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _cursor = null;
      hasMore.value = true;
      loading.value = true;
      error.value = null;
    }
    try {
      // Personal components are refetched only on a reset -- they are not
      // paginated, so re-reading them per page would be pure waste.
      if (reset) _personal.value = await _repository.listPersonal();

      final page = await _repository.list(
        category: selectedCategory.value,
        searchToken: searchText.value,
        startAfter: reset ? null : _cursor,
      );
      _cursor = page.nextCursor;
      hasMore.value = page.hasMore;

      if (reset) {
        // The user's own components lead: they are the few rows they had to
        // type by hand, so burying them under a 30-row shared page would
        // defeat the point of having created them.
        items.value = [
          ..._personal.where(_matchesFilters),
          ...page.items,
        ];
      } else {
        items.value = [...items, ...page.items];
      }
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  }
}
