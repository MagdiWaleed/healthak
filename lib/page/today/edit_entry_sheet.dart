import 'package:flutter/material.dart';

import '../../domain/day/day_log.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/gram_stepper.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';

/// Long-press on a logged entry: adjust the grams actually eaten, per item.
///
/// Replaces a method that was 60 lines of fully commented-out code and did
/// nothing (`current_diet_controller.dart:96-157`). Editing history directly
/// like this is deliberate -- a day is frozen from *recipe* edits, so
/// changing a component's weight elsewhere never touches what was logged, but
/// the user must still be able to correct what they actually logged here.
class EditEntrySheet extends StatefulWidget {
  final DayEntry entry;
  final void Function(List<FrozenItem> items) onSave;

  const EditEntrySheet({required this.entry, required this.onSave, super.key});

  static Future<void> show(
    BuildContext context, {
    required DayEntry entry,
    required void Function(List<FrozenItem> items) onSave,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => EditEntrySheet(entry: entry, onSave: onSave),
      );

  @override
  State<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends State<EditEntrySheet> {
  late final List<FrozenItem> _items = List.of(widget.entry.items);

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final totalKcal =
        _items.fold(0.0, (a, i) => a + i.kcal);

    return Padding(
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom,
        top: media.padding.top + 140,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLg)),
        child: DecoratedBox(
          decoration:
              BoxDecoration(color: AppPalette.surface.withValues(alpha: .97)),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md,
                AppSpacing.md, media.padding.bottom + AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(widget.entry.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: AppPalette.text)),
                Text('${totalKcal.round()} سعرة',
                    style: const TextStyle(color: AppPalette.muted)),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < _items.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(_items[i].name)),
                        GramStepper(
                          grams: _items[i].grams,
                          onChanged: (g) => setState(
                              () => _items[i] = _items[i].withGrams(g)),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                GlassButton(
                  label: 'حفظ',
                  onPressed: () {
                    widget.onSave(_items);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
