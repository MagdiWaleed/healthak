import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/food/food_item.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../../ui/theme/glass_tokens.dart';
import 'component_editor_sheet.dart';
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

  Future<void> _createComponent() async {
    final draft = await ComponentEditorSheet.show(context);
    if (draft == null) return;
    try {
      final saved = await widget.controller.create(draft);
      if (!mounted) return;
      // In the picker, a component is created in order to be used right away;
      // resolving the picker with it saves the user finding the row they just
      // typed. In the browse screen there is nothing to resolve, so it simply
      // appears at the top of the list.
      widget.onSelect?.call(saved);
    } catch (e) {
      if (!mounted) return;
      GlassSnackBar.show(
        context,
        'تعذر حفظ المكوّن: $e',
        tone: GlassSnackTone.error,
      );
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
          child: Row(
            children: [
              Expanded(
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
              if (c.canCreate) ...[
                const SizedBox(width: AppSpacing.sm),
                _AddComponentButton(onTap: _createComponent),
              ],
            ],
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
                      specularIndex: index,
                      mine: c.isPersonal(food),
                      onTap: () =>
                          (widget.onSelect ?? widget.onOpenDetail)?.call(food),
                      onDelete: c.isPersonal(food)
                          ? () => c.deletePersonal(food)
                          : null,
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

/// The catalog's create-component affordance, sized to sit flush beside the
/// dense search field rather than floating over the list like a second FAB --
/// the screen already has one of those for the tab it lives in.
class _AddComponentButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddComponentButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'مكوّن جديد',
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.all(10),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          tint: AppPalette.emerald,
          child: const Icon(Icons.add_rounded,
              color: AppPalette.emerald, size: 22),
        ),
      );
}

class _FoodRow extends StatelessWidget {
  final FoodItem food;
  final VoidCallback? onTap;

  /// A component this user created, as opposed to one from the shared
  /// catalog. Only these can be deleted, and only these get the badge.
  final bool mine;
  final VoidCallback? onDelete;
  final int specularIndex;

  const _FoodRow({
    required this.food,
    required this.specularIndex,
    this.onTap,
    this.mine = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => GlassCard(
        specularAngleOffset:
            specularIndex * GlassTokens.listSpecularStepDeg,
        onTap: onTap,
        onLongPress: onDelete == null ? null : () => _confirmDelete(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(food.name,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      if (mine) ...[
                        const SizedBox(width: 6),
                        const _MineBadge(),
                      ],
                    ],
                  ),
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppPalette.surface,
        title: const Text('حذف المكوّن؟'),
        content: Text(
          'سيُحذف "${food.name}" من مكوّناتك. الوجبات التي تستخدمه '
          'تحتفظ بقيمها كما هي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child:
                const Text('حذف', style: TextStyle(color: AppPalette.danger)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) onDelete?.call();
  }
}

/// Marks a row as the user's own component rather than a shared-catalog one.
class _MineBadge extends StatelessWidget {
  const _MineBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppPalette.emerald.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'خاص بك',
          style: TextStyle(fontSize: 10, color: AppPalette.emerald),
        ),
      );
}
