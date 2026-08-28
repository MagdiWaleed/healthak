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

  FoodCatalogController({FoodRepository? repository})
      : _repository = repository ?? FoodRepository();

  final items = <FoodItem>[].obs;

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

  Future<void> _load({required bool reset}) async {
    if (reset) {
      _cursor = null;
      hasMore.value = true;
      loading.value = true;
      error.value = null;
    }
    try {
      final page = await _repository.list(
        category: selectedCategory.value,
        searchToken: searchText.value,
        startAfter: reset ? null : _cursor,
      );
      _cursor = page.nextCursor;
      hasMore.value = page.hasMore;
      items.value = reset ? page.items : [...items, ...page.items];
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
      loadingMore.value = false;
    }
  }
}
