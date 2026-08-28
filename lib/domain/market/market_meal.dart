import '../day/day_log.dart';
import '../meal/meal_math.dart';
import '../nutrition/macros.dart';

/// Publication state. Removed rather than deleted, because other users hold
/// copies whose provenance points here.
enum MarketMealStatus { published, removed }

/// A group label spanning a contiguous run of [MarketMeal.items].
///
/// Published meals are flattened -- a published meal must be self-contained,
/// since referencing another user's private meal would dangle and referencing
/// other market meals would reintroduce cross-author cycles. This preserves the
/// author's nesting visually without preserving it structurally.
class MarketMealGroup {
  final String label;
  final int start;
  final int end;

  const MarketMealGroup({
    required this.label,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {'label': label, 'start': start, 'end': end};

  factory MarketMealGroup.fromJson(Map<String, dynamic> json) =>
      MarketMealGroup(
        label: json['label'] as String? ?? '',
        start: (json['start'] as num?)?.toInt() ?? 0,
        end: (json['end'] as num?)?.toInt() ?? 0,
      );
}

/// A meal published to the marketplace. Lives at `marketMeals/{id}`.
class MarketMeal {
  final String id;
  final String authorUid;
  final String authorName;

  final String name;
  final String? notes;
  final String? imageUrl;

  /// Flat leaves. Max 60, enforced client-side and in the security rules.
  final List<FrozenItem> items;

  final List<MarketMealGroup> groups;

  /// Denormalized so browse can sort without reading every item.
  final Macros totals;

  final List<String> tags;
  final String language;

  /// Maintained directly by clients. The security rules permit any signed-in
  /// user to increment this by exactly one and change nothing else, which is
  /// what avoids needing a Cloud Function and therefore a paid plan.
  final int copyCount;
  final int likeCount;

  final MarketMealStatus status;

  /// Bumped on every republish, so a copy can tell it is behind.
  final int version;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MarketMeal({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.imageUrl,
    this.groups = const [],
    this.totals = Macros.zero,
    this.tags = const [],
    this.language = 'ar',
    this.copyCount = 0,
    this.likeCount = 0,
    this.status = MarketMealStatus.published,
    this.version = 1,
  });

  static const int maxItems = 60;
  static const int maxNameLength = 80;

  bool get isPublished => status == MarketMealStatus.published;

  double get kcal => totals.kcal;

  /// Always derivable from [items]; [totals] is only a query convenience.
  Macros get computedTotals =>
      items.fold(Macros.zero, (Macros a, i) => a + i.macros);

  /// The group label covering [index], or null for an ungrouped item.
  String? groupLabelAt(int index) {
    for (final g in groups) {
      if (index >= g.start && index <= g.end) return g.label;
    }
    return null;
  }

  /// Builds the flat item list and group spans from a resolved meal.
  ///
  /// Contiguous leaves sharing a `groupLabel` become one span.
  static ({List<FrozenItem> items, List<MarketMealGroup> groups}) flatten(
    List<FlatItem> flat,
  ) {
    final items = [for (final f in flat) FrozenItem.fromFlat(f)];
    final groups = <MarketMealGroup>[];

    String? currentLabel;
    var runStart = 0;

    for (var i = 0; i < flat.length; i++) {
      final label = flat[i].groupLabel;
      if (label != currentLabel) {
        if (currentLabel != null) {
          groups.add(MarketMealGroup(
            label: currentLabel,
            start: runStart,
            end: i - 1,
          ));
        }
        currentLabel = label;
        runStart = i;
      }
    }

    if (currentLabel != null && flat.isNotEmpty) {
      groups.add(MarketMealGroup(
        label: currentLabel,
        start: runStart,
        end: flat.length - 1,
      ));
    }

    return (items: items, groups: groups);
  }

  MarketMeal copyWith({
    String? name,
    String? notes,
    String? imageUrl,
    List<FrozenItem>? items,
    List<MarketMealGroup>? groups,
    Macros? totals,
    List<String>? tags,
    int? copyCount,
    int? likeCount,
    MarketMealStatus? status,
    int? version,
    DateTime? updatedAt,
  }) =>
      MarketMeal(
        id: id,
        authorUid: authorUid,
        authorName: authorName,
        name: name ?? this.name,
        notes: notes ?? this.notes,
        imageUrl: imageUrl ?? this.imageUrl,
        items: items ?? this.items,
        groups: groups ?? this.groups,
        totals: totals ?? this.totals,
        tags: tags ?? this.tags,
        language: language,
        copyCount: copyCount ?? this.copyCount,
        likeCount: likeCount ?? this.likeCount,
        status: status ?? this.status,
        version: version ?? this.version,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  @override
  bool operator ==(Object other) => other is MarketMeal && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
