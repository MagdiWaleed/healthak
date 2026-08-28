import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/food/food_item.dart';
import '../../ui/glass/glass_surface.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
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
      showModalBottomSheet<FoodItem>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const FoodPickerSheet(),
      );

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet> {
  late final String _tag = UniqueKey().toString();
  late final FoodCatalogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(FoodCatalogController(), tag: _tag);
  }

  @override
  void dispose() {
    Get.delete<FoodCatalogController>(tag: _tag);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: media.padding.top + 48),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLg)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  children: [
                    Text('اختر مكوّناً',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppPalette.text,
                        )),
                  ],
                ),
              ),
              Expanded(
                child: FoodCatalogBody(
                  controller: _controller,
                  bottomPadding: media.padding.bottom + 24,
                  onSelect: (food) => Navigator.of(context).pop(food),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
