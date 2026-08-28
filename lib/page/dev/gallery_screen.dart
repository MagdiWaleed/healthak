import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/nutrition/macros.dart';
import '../../ui/components/calorie_ring.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/components/gram_stepper.dart';
import '../../ui/components/macro_bar.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  double grams = 100;

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final sections = <Widget>[
      const CalorieRing(
        consumed: 1370,
        target: 2100,
        consumedMacros: Macros(protein: 82, carbs: 145, fat: 48),
        targetMacros: Macros(protein: 130, carbs: 230, fat: 70),
      ),
      const MacroBar(
          label: 'البروتين', value: 82, target: 130, color: AppPalette.emerald),
      const MacroBar(
          label: 'الكربوهيدرات',
          value: 145,
          target: 230,
          color: AppPalette.amber),
      GlassCard(
          child: GramStepper(
              grams: grams,
              onChanged: (value) => setState(() => grams = value))),
      const Wrap(spacing: 8, children: [
        GlassChip(label: 'إفطار', selected: true),
        GlassChip(label: 'غداء'),
        GlassChip(label: 'عشاء')
      ]),
      GlassButton(
          label: 'إجراء أساسي', icon: Icons.auto_awesome, onPressed: () {}),
    ];
    return GlassScaffold(
      appBar: AppBar(title: const Text('معرض التصميم')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(22, 88, 22, 32),
        itemCount: sections.length,
        separatorBuilder: (context, index) => const SizedBox(height: 22),
        itemBuilder: (_, index) =>
            StaggeredEntry(index: index, child: sections[index]),
      ),
    );
  }
}
