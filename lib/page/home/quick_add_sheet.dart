import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/app_strings.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';
import '../progress/weight_entry_sheet.dart';
import '../today/add_food_flow.dart';
import '../today/today_controller.dart';
import 'home_controller.dart';

class HomeQuickAddSheet {
  static Future<void> show(BuildContext context) => GlassSheet.show<void>(
        context,
        builder: (sheetContext) => GlassSheet(
          title: AppStrings.quickAdd,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _ActionTile(Icons.restaurant_rounded, AppStrings.logFood, () {
                Navigator.pop(sheetContext);
                openAddFoodFlow(context, Get.find<TodayController>());
              }),
              _ActionTile(Icons.monitor_weight_outlined, AppStrings.logWeight,
                  () {
                Navigator.pop(sheetContext);
                WeightEntrySheet.show(context);
              }),
              _ActionTile(Icons.fitness_center_rounded, AppStrings.startWorkout,
                  () {
                Navigator.pop(sheetContext);
                Get.find<HomeController>().goTo(HomeTab.training);
              }),
            ]),
          ),
        ),
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            contentPadding:
                const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            leading: Icon(icon, color: AppPalette.emerald, size: 30),
            title: Text(label, style: Theme.of(context).textTheme.titleMedium),
            onTap: onTap,
          ),
        ),
      );
}
