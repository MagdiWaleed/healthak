import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/food/food_item.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/navigation.dart';
import 'food_catalog_body.dart';
import 'food_catalog_controller.dart';
import 'food_detail_screen.dart';

/// Full-screen browse: search, category chips, infinite scroll, tap through
/// to [FoodDetailScreen].
class FoodCatalogScreen extends GetView<FoodCatalogController> {
  const FoodCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(title: const Text('المكوّنات')),
        body: Padding(
          padding: const EdgeInsets.only(top: 56),
          child: FoodCatalogBody(
            controller: controller,
            onOpenDetail: (food) => _openDetail(context, food),
          ),
        ),
      );

  void _openDetail(BuildContext context, FoodItem food) =>
      pushHealthak(() => FoodDetailScreen(food: food));
}
