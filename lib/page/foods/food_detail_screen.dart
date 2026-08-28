import 'package:flutter/material.dart';

import '../../domain/food/food_item.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';

/// Read-only detail for one catalog row: macros per 100g, micros if the
/// migration carried any, and price when the source data had one.
class FoodDetailScreen extends StatelessWidget {
  final FoodItem food;

  const FoodDetailScreen({required this.food, super.key});

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(title: Text(food.name)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 88, AppSpacing.md, AppSpacing.xl),
          children: [
            GlassCard(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${food.per100.kcal.round()}',
                          style: Theme.of(context).textTheme.displayMedium),
                      const SizedBox(width: 6),
                      const Text('سعرة / 100غ', style: TextStyle(color: AppPalette.muted)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _MacroRow(label: 'بروتين', grams: food.per100.protein, color: AppPalette.emerald),
                  const SizedBox(height: AppSpacing.sm),
                  _MacroRow(label: 'كربوهيدرات', grams: food.per100.carbs, color: AppPalette.amber),
                  const SizedBox(height: AppSpacing.sm),
                  _MacroRow(label: 'دهون', grams: food.per100.fat, color: AppPalette.violet),
                ],
              ),
            ),
            if (food.category != null && food.category!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.category_outlined, color: AppPalette.muted),
                    const SizedBox(width: AppSpacing.sm),
                    Text('التصنيف: ${food.category}'),
                  ],
                ),
              ),
            ],
            if (food.pricePer100 != null) ...[
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: AppPalette.muted),
                    const SizedBox(width: AppSpacing.sm),
                    Text('السعر التقريبي: ${food.pricePer100!.toStringAsFixed(1)} / 100غ'),
                  ],
                ),
              ),
            ],
            if (food.micros != null && food.micros!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('عناصر أخرى', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    for (final entry in food.micros!.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(entry.key),
                            Text('${entry.value}'),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (food.note != null && food.note!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(food.note!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
}

class _MacroRow extends StatelessWidget {
  final String label;
  final double grams;
  final Color color;

  const _MacroRow({required this.label, required this.grams, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: Text(label)),
          Text('${grams.toStringAsFixed(1)} غ',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
}
