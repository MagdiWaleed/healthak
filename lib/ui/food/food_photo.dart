import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Illustrative photos are used only when the saved meal matches the dish.
/// Unknown meals retain the neutral icon instead of showing a wrong food.
class FoodPhoto extends StatelessWidget {
  final String? asset;
  final IconData fallbackIcon;
  final double size;

  const FoodPhoto({
    required this.asset,
    required this.fallbackIcon,
    this.size = 82,
    super.key,
  });

  static String? forMeal(String title, Iterable<String> ingredients) {
    final foods = ingredients.toList();
    final joined = '$title ${foods.join(' ')}'.toLowerCase();
    final hasTea = title.contains('شاي') || title.toLowerCase().contains('tea');
    final hasMilk = joined.contains('حليب') || joined.contains('milk');
    if (hasTea && hasMilk) {
      return 'asset/image/food/milk_tea.jpg';
    }
    final hasEgg =
        RegExp(r'(^|\s)بيض(\s|$)').hasMatch(joined) || joined.contains('egg');
    final hasRice = joined.contains('أرز') ||
        joined.contains('ارز') ||
        joined.contains('rice');
    if (hasEgg && hasRice) {
      return 'asset/image/food/rice_boiled_eggs.jpg';
    }
    if (joined.contains('كبسة') || joined.contains('kabsa')) {
      return 'asset/image/food/chicken_kabsa.jpg';
    }
    final hasYogurt = joined.contains('زبادي') || joined.contains('yogurt');
    final hasOats = joined.contains('شوفان') || joined.contains('oat');
    if (hasYogurt && hasOats) {
      return 'asset/image/food/yogurt_oats_berries.jpg';
    }
    final hasChicken = joined.contains('دجاج') || joined.contains('chicken');
    if (hasChicken && hasRice) {
      return 'asset/image/food/grilled_chicken_rice.jpg';
    }
    if (foods.length == 1) return forFoodName(foods.single);
    return null;
  }

  static String? forFoodName(String name) {
    final value = name.toLowerCase();
    if (value.contains('كبسة') || value.contains('kabsa')) {
      return 'asset/image/food/chicken_kabsa.jpg';
    }
    if (value.contains('تفاح أحمر') || value.contains('red apple')) {
      return 'asset/image/food/red_apple.jpg';
    }
    if ((value.contains('حليب') || value.contains('milk')) &&
        (value.contains('بروتين') || value.contains('protein'))) {
      return 'asset/image/food/protein_milk.jpg';
    }
    if (value.contains('دولما') || value.contains('dolma')) {
      return 'asset/image/food/dolma.jpg';
    }
    if ((value.contains('شاورما') || value.contains('shawarma')) &&
        (value.contains('بروستد') || value.contains('broasted'))) {
      return 'asset/image/food/shawarma_broasted.jpg';
    }
    if (value == 'شوفان' || value == 'oats' || value == 'rolled oats') {
      return 'asset/image/food/rolled_oats.jpg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: size,
          height: size,
          child: asset == null
              ? ColoredBox(
                  color: AppPalette.soft,
                  child: Icon(fallbackIcon, color: AppPalette.emerald),
                )
              : Image.asset(
                  asset!,
                  fit: BoxFit.cover,
                  cacheWidth:
                      (size * MediaQuery.devicePixelRatioOf(context)).round(),
                ),
        ),
      );
}
