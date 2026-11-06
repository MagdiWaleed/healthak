import 'package:flutter/material.dart';

import 'quick_add_sheet.dart';
import 'today_controller.dart';

void openAddFoodFlow(BuildContext context, TodayController controller) {
  controller.ensureCurrentDay();
  if (controller.canEditSelectedDay) QuickAddSheet.show(context, controller);
}
