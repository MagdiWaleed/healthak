import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../marketplace/marketplace_tab.dart';
import '../my_meals/my_meals_tab.dart';

class NutritionTab extends StatefulWidget {
  const NutritionTab({super.key, this.tabs});
  final List<Widget>? tabs;

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  int selected = 0;

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.nutrition,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text(AppStrings.myMeals)),
                ButtonSegment(value: 1, label: Text(AppStrings.market)),
              ],
              selected: {selected},
              onSelectionChanged: (value) =>
                  setState(() => selected = value.single),
            ),
          ]),
        ),
        Expanded(
          child: IndexedStack(
              index: selected,
              children: widget.tabs ??
                  const [
                    MyMealsTab(),
                    MarketplaceTab(),
                  ]),
        ),
      ]);
}
