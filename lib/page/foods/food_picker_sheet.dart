import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/food/food_item.dart';
import '../../service/auth_service.dart';
import '../../ui/glass/glass_sheet.dart';
import 'food_catalog_body.dart';
import 'food_catalog_controller.dart';

/// Bottom sheet for picking one [FoodItem] -- the meal editor's
/// "إضافة مكوّن" and the Today FAB's quick-add both resolve through this.
///
/// Owns a scoped, tagged [FoodCatalogController] rather than the shared one
/// the catalog route uses, so opening the picker while the catalog screen is
/// itself open (Today -> meal editor -> picker, with the tab bar still
/// mounted underneath) can't have the two share pagination state.
class FoodPickerSheet extends StatefulWidget {
  const FoodPickerSheet({super.key});

  /// Shows the sheet and resolves to the chosen food, or `null` if dismissed.
  static Future<FoodItem?> show(BuildContext context) =>
      GlassSheet.show<FoodItem>(context, builder: (_) => const FoodPickerSheet());

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  late final String _tag = UniqueKey().toString();
  late final FoodCatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      FoodCatalogController(uid: Get.find<AuthService>().currentUser?.uid),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    Get.delete<FoodCatalogController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return GlassSheet(
      title: 'اختر مكوّناً',
      topInset: 48,
      expand: true,
      child: FoodCatalogBody(
        controller: _controller,
        bottomPadding: media.padding.bottom + 24,
        onSelect: (food) => Navigator.of(context).pop(food),
      ),
    );
  }
}
