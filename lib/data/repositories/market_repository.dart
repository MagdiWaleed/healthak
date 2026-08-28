import '../../domain/market/market_meal.dart';
import '../firestore_refs.dart';

/// Step 1 boundary only. Publishing, copying, likes, and browse filters land in Step 3.
class MarketRepository {
  final FirestoreRefs _refs;

  MarketRepository({FirestoreRefs? refs}) : _refs = refs ?? FirestoreRefs();

  Future<MarketMeal?> getPublished(String id) async {
    final meal = (await _refs.marketMeals.doc(id).get()).data();
    return meal?.isPublished == true ? meal : null;
  }
}
