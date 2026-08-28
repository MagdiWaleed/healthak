import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/food/food_item.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import 'food_catalog_controller.dart';

/// The search field, category chips, and paginated list.
///
/// Shared by [FoodCatalogScreen] (browse -> detail) and [FoodPickerSheet]
/// (browse -> select). [onSelect] switches between the two: passed, a tap
/// resolves the sheet; absent, a tap opens [FoodDetailScreen].
class FoodCatalogBody extends StatefulWidget {
  final FoodCatalogController controller;
  final void Function(FoodItem food)? onSelect;
  final void Function(FoodItem food)? onOpenDetail;

  /// Extra vertical space reserved below the last row -- a picker sheet needs
  /// less than a full screen under a bottom nav bar.
  final double bottomPadding;

  const FoodCatalogBody({
    required this.controller,
    super.key,
    this.onSelect,
    this.onOpenDetail,
    this.bottomPadding = 120,
  });

  @override
  State<FoodCatalogBody> createState() => _FoodCatalogBodyState();
}

class _FoodCatalogBodyState extends State<FoodCatalogBody> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger the next page a little before the physical end, so the network
    // round trip has time to land before the user hits blank space.
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
          child: TextField(
            controller: _search,
            onChanged: c.search,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'ابحث عن مكوّن...',
              isDense: true,
            ),
          ),
        ),
        Obx(() {
          final categories = c.categories;
          if (categories.isEmpty) return const SizedBox.shrink();
          return SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                GlassChip(
                  label: 'الكل',
                  selected: c.selectedCategory.value == null,
                  onTap: () => c.selectCategory(null),
                ),
                const SizedBox(width: AppSpacing.xs),
                for (var i = 0; i < categories.length; i++) ...[
                  GlassChip(
                    label: categories[i],
                    selected: c.selectedCategory.value == categories[i],
                    onTap: () => c.selectCategory(categories[i]),
                  ),
                  if (i != categories.length - 1)
                    const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xs),
        Expanded(
          child: Obx(() {
            if (c.loading.value) {
              return const Center(child: CircularProgressIndicator());
            }
            final error = c.error.value;
            if (error != null && c.items.isEmpty) {
              return ErrorState(message: error, onRetry: c.reload);
            }
            if (c.items.isEmpty) {
              return const EmptyState(
                icon: Icons.search_off_rounded,
                title: 'لا توجد نتائج',
                message: 'جرّب كلمة بحث أخرى أو غيّر التصنيف',
              );
            }
            return RefreshIndicator(
              onRefresh: c.reload,
              color: AppPalette.emerald,
              child: ListView.separated(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs,
                    AppSpacing.md, widget.bottomPadding),
                itemCount: c.items.length + (c.hasMore.value ? 1 : 0),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  if (index >= c.items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    );
                  }
                  final food = c.items[index];
                  return StaggeredEntry(
                    index: index,
                    maxStaggered: 6,
                    child: _FoodRow(
                      food: food,
                      onTap: () =>
                          (widget.onSelect ?? widget.onOpenDetail)?.call(food),
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodItem food;
  final VoidCallback? onTap;

  const _FoodRow({required this.food, this.onTap});

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: onTap,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${food.per100.kcal.round()} سعرة  •  '
                    'بروتين ${food.per100.protein.round()}غ  •  '
                    'كارب ${food.per100.carbs.round()}غ  •  '
                    'دهون ${food.per100.fat.round()}غ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              '/100غ',
              style: TextStyle(
                fontFamily: AppTypography.family,
                fontSize: 11,
                color: AppPalette.muted,
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: AppPalette.muted),
          ],
        ),
      );
}
