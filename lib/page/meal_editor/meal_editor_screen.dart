import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/meal/meal_entry.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/gram_stepper.dart';
import '../../ui/components/scale_stepper.dart';
import '../../ui/feedback/haptics.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/app_typography.dart';
import '../foods/food_picker_sheet.dart';
import 'balance_sheet.dart';
import 'meal_editor_controller.dart';
import 'meal_picker_sheet.dart';
import 'schedule_sheet.dart';

/// The core screen: build a meal from catalog components, nest other meals
/// inside it, auto-balance to a calorie target, and either save it to the
/// library, log it against today, or schedule it as recurring.
///
/// Deliberately reads only from [MealEditorController] and never touches
/// `MealEntry`'s domain rules directly -- see the controller's doc comment.
class MealEditorScreen extends StatefulWidget {
  /// `null` starts a new meal; otherwise the id of one being edited.
  final String? mealId;

  const MealEditorScreen({super.key, this.mealId});

  @override
  State<MealEditorScreen> createState() => _MealEditorScreenState();
}

class _MealEditorScreenState extends State<MealEditorScreen> {
  late final MealEditorController controller = MealEditorController(
    uid: Get.find<AuthService>().currentUser!.uid,
    editingId: widget.mealId,
  );
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    // GetxController.onInit() is only invoked automatically by GetX's own DI
    // (Get.put/lazyPut/a Binding). This controller is a plain, screen-scoped
    // object instead, so nothing calls onInit() unless this does -- without
    // it, `_load()` never runs: the screen spins forever regardless of
    // whether this is a new or an existing meal, and the library never
    // populates for "إضافة وجبة" either.
    controller.onInit();
    _name = TextEditingController(text: controller.name.value)
      ..addListener(() => controller.setName(_name.text));
    // The name field only fills in once the meal finishes loading (editing an
    // existing meal); keep the text field's controller in sync.
    ever(controller.name, (String value) {
      if (_name.text != value) _name.text = value;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    controller.onClose();
    super.dispose();
  }

  void _snack(String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      action:
          undo == null ? null : SnackBarAction(label: 'تراجع', onPressed: undo),
    ));
  }

  Future<void> _addFood() async {
    final food = await FoodPickerSheet.show(context);
    if (food == null || !mounted) return;
    controller.addFood(food);
    _snack('أُضيف ${food.name}', undo: controller.undo);
  }

  Future<void> _addMealRef() => MealPickerSheet.show(context, controller);

  Future<void> _balance() => BalanceSheet.show(context, controller);

  Future<void> _save({bool pop = true}) async {
    if (controller.name.value.trim().isEmpty) {
      _snack('أدخل اسماً للوجبة أولاً');
      return;
    }
    if (controller.isEmpty) {
      _snack('أضف مكوّناً واحداً على الأقل');
      return;
    }
    final wasEditing = !controller.isNew;
    final saved = await controller.save();
    if (!mounted) return;
    if (saved == null) {
      _snack(controller.error.value ?? 'تعذر الحفظ');
      return;
    }

    // Never silent: a meal on the schedule keeps a frozen snapshot, so an
    // edit here does nothing to it until the user explicitly says so.
    if (wasEditing) {
      final linked = await controller.linkedScheduleItems();
      if (linked.isNotEmpty && mounted) {
        final update = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تحديث الجدول أيضاً؟'),
            content: Text('هذه الوجبة مضافة لجدولك في ${linked.length} موضع. '
                'هل تريد تحديثها لتطابق التعديلات الجديدة؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('لاحقاً'),
              ),
              GlassButton(
                label: 'تحديث',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
        if (update == true) await controller.refreshLinkedSchedule(linked);
      }
    }

    if (pop && mounted) {
      _snack('تم حفظ الوجبة');
      Get.back(result: saved);
    }
  }

  Future<void> _addToToday() async {
    if (controller.name.value.trim().isEmpty || controller.isEmpty) {
      _snack('أكمل الوجبة أولاً');
      return;
    }
    final ok = await controller.addToToday();
    if (!mounted) return;
    _snack(ok
        ? 'أُضيفت الوجبة لليوم'
        : (controller.error.value ?? 'تعذرت الإضافة'));
    if (ok) Get.back();
  }

  Future<void> _addToSchedule() async {
    if (controller.name.value.trim().isEmpty || controller.isEmpty) {
      _snack('أكمل الوجبة أولاً');
      return;
    }
    final picked = await ScheduleSheet.show(context);
    if (picked == null || !mounted) return;
    final ok = await controller.addToSchedule(
      slot: picked.slot,
      daysOfWeek: picked.daysOfWeek,
    );
    if (!mounted) return;
    _snack(ok
        ? 'أُضيفت الوجبة لجدولك'
        : (controller.error.value ?? 'تعذرت الإضافة'));
    if (ok) Get.back();
  }

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(
          // `Obx` needs at least one `.obs` read inside its builder to know
          // what to listen to. `controller.isNew` is a plain bool getter, not
          // reactive -- a `isNew ? staticText : controller.name.value`
          // ternary reads zero Rx values whenever isNew is true (i.e. on
          // every new meal), which GetX flags as "improper use of Obx" and
          // fails to render at all. Reading `name.value` unconditionally
          // fixes both the crash and gives the title a placeholder that
          // updates live as the user types.
          title: Obx(() => Text(
                controller.name.value.isEmpty
                    ? 'وجبة جديدة'
                    : controller.name.value,
              )),
          actions: [
            Obx(() => controller.saving.value
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4)),
                  )
                : IconButton(
                    onPressed: () => _save(pop: false),
                    icon: const Icon(Icons.check_rounded),
                    tooltip: 'حفظ',
                  )),
          ],
        ),
        body: Obx(() {
          if (controller.loading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              const SizedBox(height: 56),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: TextField(
                  controller: _name,
                  style: Theme.of(context).textTheme.titleLarge,
                  decoration: const InputDecoration(
                    hintText: 'اسم الوجبة',
                    border: InputBorder.none,
                  ),
                ),
              ),
              _TotalsHeader(controller: controller),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: controller.isEmpty
                    ? _EmptyEditor(onAddFood: _addFood)
                    : _EntryList(controller: controller, onSnack: _snack),
              ),
              _ActionBar(
                onAddFood: _addFood,
                onAddMealRef: _addMealRef,
                onBalance: controller.isEmpty ? null : _balance,
                onAddToToday: _addToToday,
                onAddToSchedule: _addToSchedule,
              ),
            ],
          );
        }),
      );
}

/// Live kcal + P/C/F, re-tweening on every entry change. Reads
/// [MealEditorController.totals] through an [Obx] listening to `entries` --
/// the controller's totals getter recomputes from the entry list, so an
/// [Obx] over `entries` is what makes it reactive without a redundant cached
/// Rx<Macros> the entries could drift out of sync with.
class _TotalsHeader extends StatelessWidget {
  final MealEditorController controller;

  const _TotalsHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Reading `entries.length` (any field on the Rx list) is what
      // subscribes this Obx to structural changes; `controller.totals` itself
      // is a plain getter, not a Rx.
      // ignore: unused_local_variable
      final _ = controller.entries.length;
      final totals = controller.totals;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: GlassCard(
          child: Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: totals.kcal),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  '${value.round()}',
                  style: const TextStyle(
                    fontFamily: AppTypography.family,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppPalette.text,
                    fontFeatures: AppTypography.tabular,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('سعرة', style: TextStyle(color: AppPalette.muted)),
              ),
              const Spacer(),
              _MacroPill(
                  label: 'ب', value: totals.protein, color: AppPalette.emerald),
              const SizedBox(width: 8),
              _MacroPill(
                  label: 'ك', value: totals.carbs, color: AppPalette.amber),
              const SizedBox(width: 8),
              _MacroPill(
                  label: 'د', value: totals.fat, color: AppPalette.violet),
            ],
          ),
        ),
      );
    });
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(
            '$label ${v.round()}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              fontFeatures: AppTypography.tabular,
            ),
          ),
        ),
      );
}

class _EmptyEditor extends StatelessWidget {
  final VoidCallback onAddFood;
  const _EmptyEditor({required this.onAddFood});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle_outline,
                size: 48, color: AppPalette.muted),
            const SizedBox(height: AppSpacing.sm),
            const Text('ابدأ بإضافة مكوّن'),
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onAddFood, child: const Text('إضافة مكوّن')),
          ],
        ),
      );
}

class _EntryList extends StatelessWidget {
  final MealEditorController controller;
  final void Function(String message, {VoidCallback? undo}) onSnack;

  const _EntryList({required this.controller, required this.onSnack});

  @override
  Widget build(BuildContext context) => Obx(() {
        final entries = controller.entries;
        return ReorderableListView.builder(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          itemCount: entries.length,
          onReorderStart: (_) => unawaited(HapticPhrase.play(AppHaptics.lift)),
          onReorderEnd: (_) => unawaited(HapticPhrase.play(AppHaptics.land)),
          onReorder: controller.reorder,
          proxyDecorator: (child, _, animation) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (_, proxy) => Transform.scale(
              scale: 1 + animation.value * .02,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.emerald
                          .withValues(alpha: .16 * animation.value),
                      blurRadius: 22 * animation.value,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: proxy,
              ),
            ),
          ),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return StaggeredEntry(
              key: ValueKey(entry.localId),
              index: index,
              maxStaggered: 6,
              child: _EntryRow(
                controller: controller,
                entry: entry,
                index: index,
                onSnack: onSnack,
              ),
            );
          },
        );
      });
}

class _EntryRow extends StatelessWidget {
  final MealEditorController controller;
  final MealEntry entry;

  /// This row's current position in the list. [ReorderableDragStartListener]
  /// needs its real index to report the right drag source -- a stale or
  /// placeholder value here would make every drag reorder from the wrong row.
  final int index;

  final void Function(String message, {VoidCallback? undo}) onSnack;

  const _EntryRow({
    required this.controller,
    required this.entry,
    required this.index,
    required this.onSnack,
  });

  @override
  Widget build(BuildContext context) {
    final isRef = entry is MealRefEntry;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle_rounded, color: AppPalette.muted),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isRef)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.restaurant_menu,
                              size: 14, color: AppPalette.violet),
                        ),
                      Flexible(
                        child: Text(entry.name,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_kcalOf(entry).round()} سعرة',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Obx(() {
              final locked = controller.lockedIds.contains(entry.localId);
              return IconButton(
                onPressed: () => controller.toggleLock(entry.localId),
                icon: Icon(
                  locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  size: 18,
                  color: locked ? AppPalette.amber : AppPalette.muted,
                ),
                tooltip: locked ? 'إلغاء التثبيت' : 'تثبيت الوزن',
              );
            }),
            switch (entry) {
              FoodEntry f => GramStepper(
                  grams: f.grams,
                  onChanged: (g) => controller.updateFoodGrams(f.localId, g),
                ),
              MealRefEntry r => ScaleStepper(
                  scale: r.scale,
                  onChanged: (s) => controller.updateRefScale(r.localId, s),
                ),
            },
            PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert_rounded, color: AppPalette.muted),
              onSelected: (action) => _onMenu(context, action),
              itemBuilder: (context) => [
                if (isRef)
                  const PopupMenuItem(
                      value: 'ungroup', child: Text('فك التجميع')),
                const PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _kcalOf(MealEntry entry) => switch (entry) {
        FoodEntry f => f.kcal,
        MealRefEntry r => r.approximateMacros.kcal,
      };

  void _onMenu(BuildContext context, String action) {
    switch (action) {
      case 'ungroup':
        final refusal = controller.ungroup(entry.localId);
        if (refusal != null) {
          onSnack(refusal);
        } else {
          onSnack('تم فك تجميع ${entry.name}', undo: controller.undo);
        }
      case 'delete':
        final name = entry.name;
        controller.removeEntry(entry.localId);
        onSnack('تم حذف $name', undo: controller.undo);
    }
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onAddFood;
  final VoidCallback onAddMealRef;
  final VoidCallback? onBalance;
  final VoidCallback onAddToToday;
  final VoidCallback onAddToSchedule;

  const _ActionBar({
    required this.onAddFood,
    required this.onAddMealRef,
    required this.onBalance,
    required this.onAddToToday,
    required this.onAddToSchedule,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ChipButton(
                    icon: Icons.add_rounded,
                    label: 'مكوّن',
                    onTap: onAddFood,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _ChipButton(
                    icon: Icons.restaurant_menu,
                    label: 'وجبة',
                    onTap: onAddMealRef,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _ChipButton(
                    icon: Icons.auto_awesome,
                    label: 'موازنة',
                    onTap: onBalance,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onAddToToday,
                    icon: const Icon(Icons.today_outlined),
                    label: const Text('أضف لليوم'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onAddToSchedule,
                    icon: const Icon(Icons.event_repeat_outlined),
                    label: const Text('أضف لجدولي'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.comingNext))),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('نشر'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

class _ChipButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ChipButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        pressedScale: .95,
        child: Opacity(
          opacity: onTap == null ? .4 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: .14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppPalette.text),
                const SizedBox(height: 2),
                Text(label,
                    style:
                        const TextStyle(fontSize: 11, color: AppPalette.text)),
              ],
            ),
          ),
        ),
      );
}
