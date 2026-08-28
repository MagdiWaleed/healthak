import '../nutrition/macros.dart';
import 'meal_entry.dart';

/// Where a meal in a user's library came from.
enum MealOrigin {
  /// Built by this user in the meal editor.
  authored,

  /// Copied out of the marketplace. Always a copy, never a live reference.
  copiedFromMarket,
}

/// Provenance for a meal copied from the marketplace.
class MealSource {
  final String marketMealId;
  final String authorUid;
  final String authorName;

  /// The publisher's version at the moment it was copied. Lets the app offer
  /// "the author updated this -- take the update?" later without committing to
  /// that behaviour now.
  final int version;

  final DateTime copiedAt;

  const MealSource({
    required this.marketMealId,
    required this.authorUid,
    required this.authorName,
    required this.version,
    required this.copiedAt,
  });

  Map<String, dynamic> toJson() => {
        'marketMealId': marketMealId,
        'authorUid': authorUid,
        'authorName': authorName,
        'version': version,
        'copiedAt': copiedAt.toIso8601String(),
      };

  factory MealSource.fromJson(Map<String, dynamic> json) => MealSource(
        marketMealId: json['marketMealId'] as String? ?? '',
        authorUid: json['authorUid'] as String? ?? '',
        authorName: json['authorName'] as String? ?? '',
        version: (json['version'] as num?)?.toInt() ?? 1,
        copiedAt: DateTime.tryParse(json['copiedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// A meal in a user's private library.
///
/// Lives at `users/{uid}/meals/{mealId}`.
class MealDefinition {
  final String id;
  final String ownerUid;
  final String name;

  /// Ordered. Not an index-keyed map of double-encoded JSON, which is what the
  /// old `CompleteMaleModel` used and why component order was only incidentally
  /// preserved -- it decoded by unordered `.keys` iteration.
  final List<MealEntry> entries;

  final String? notes;
  final String? imageUrl;

  /// Denormalized totals, for sorting and list rendering only. Never truth:
  /// recompute through `macrosOfMeal` whenever correctness matters.
  final Macros totalsCache;

  /// Nesting depth of the deepest branch. 0 for a meal of only foods.
  final int depth;

  /// Total leaf food entries, counting through every nested reference.
  final int leafCount;

  /// Transitive closure of every meal reachable from this one.
  ///
  /// Maintained on write so a cycle check is O(1) with no extra reads: adding
  /// meal B to meal A is illegal iff `B.id == A.id` or `A.id` is in
  /// `B.descendantMealIds`.
  final Set<String> descendantMealIds;

  final MealOrigin origin;
  final MealSource? source;

  /// Set once this meal has been published, so republishing updates the same
  /// marketplace document instead of creating a duplicate.
  final String? publishedMarketMealId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MealDefinition({
    required this.id,
    required this.ownerUid,
    required this.name,
    required this.entries,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.imageUrl,
    this.totalsCache = Macros.zero,
    this.depth = 0,
    this.leafCount = 0,
    this.descendantMealIds = const {},
    this.origin = MealOrigin.authored,
    this.source,
    this.publishedMarketMealId,
  });

  bool get isEmpty => entries.isEmpty;

  bool get isPublished => publishedMarketMealId != null;

  bool get isCopy => origin == MealOrigin.copiedFromMarket;

  /// True if this meal references any other meal.
  bool get hasNesting => entries.any((e) => e is MealRefEntry);

  /// Entries in display order. [entries] is expected to be sorted already;
  /// this guards against a bad write.
  List<MealEntry> get orderedEntries {
    final sorted = [...entries]..sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }

  MealDefinition copyWith({
    String? name,
    List<MealEntry>? entries,
    String? notes,
    String? imageUrl,
    Macros? totalsCache,
    int? depth,
    int? leafCount,
    Set<String>? descendantMealIds,
    MealOrigin? origin,
    MealSource? source,
    String? publishedMarketMealId,
    DateTime? updatedAt,
  }) =>
      MealDefinition(
        id: id,
        ownerUid: ownerUid,
        name: name ?? this.name,
        entries: entries ?? this.entries,
        notes: notes ?? this.notes,
        imageUrl: imageUrl ?? this.imageUrl,
        totalsCache: totalsCache ?? this.totalsCache,
        depth: depth ?? this.depth,
        leafCount: leafCount ?? this.leafCount,
        descendantMealIds: descendantMealIds ?? this.descendantMealIds,
        origin: origin ?? this.origin,
        source: source ?? this.source,
        publishedMarketMealId:
            publishedMarketMealId ?? this.publishedMarketMealId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) => other is MealDefinition && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MealDefinition($id, $name, ${entries.length} entries, depth $depth)';
}
