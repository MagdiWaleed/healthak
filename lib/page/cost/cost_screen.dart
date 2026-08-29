import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/nutrition/cost.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/components/glass_chip.dart';
import '../../ui/components/ticker_number.dart';
import '../../ui/feedback/haptics.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/motion/pressable.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../../ui/theme/app_spacing.dart';
import '../../ui/theme/motion_settings.dart';
import 'cost_controller.dart';

/// الميزانية -- what the current diet costs, per day / week / month.
///
/// Prices are per 100g and live only on this device (see `PriceBook`); the
/// catalog's `pricePer100` is a fallback beneath them, never an override.
class CostScreen extends GetView<CostController> {
  const CostScreen({super.key});

  @override
  Widget build(BuildContext context) => GlassScaffold(
        appBar: AppBar(
          title: const Text('الميزانية'),
          actions: [
            IconButton(
              onPressed: () => _editCurrency(context),
              icon: const Icon(Icons.currency_exchange_rounded),
              tooltip: 'العملة',
            ),
          ],
        ),
        body: Obx(() {
          final error = controller.error.value;
          if (error != null && controller.components.isEmpty) {
            return ErrorState(message: error, onRetry: controller.reload);
          }
          if (controller.loading.value && controller.components.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final unpriced = controller.unpriced;
          // Recomputing a period costs a schedule read and a day-range read.
          // Everything below the chips still shows the period the user just
          // left, so fade it and say so rather than letting last period's
          // totals sit under the new period's heading.
          final stale = controller.isStale;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 88, AppSpacing.md, AppSpacing.xxl),
            children: [
              _PeriodChips(controller: controller),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: 2,
                child: stale
                    ? const LinearProgressIndicator(
                        minHeight: 2, color: AppPalette.emerald)
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              // One opacity for the whole body rather than one per row: the
              // grams on every line belong to the outgoing period too, not
              // just the headline.
              AnimatedOpacity(
                duration: MotionSettings.duration(
                    context, const Duration(milliseconds: 180)),
                opacity: stale ? .35 : 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TotalCard(controller: controller),
                    const SizedBox(height: AppSpacing.md),
                    if (controller.components.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'لا توجد مكوّنات بعد',
                        message: 'أضف وجبات ليومك أو جدولك ثم عد لتسعيرها',
                      )
                    else ...[
                      for (final (index, item) in controller.priced.indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: StaggeredEntry(
                            index: index,
                            child: _CostRow(
                              item: item,
                              currency: controller.currency.value,
                              unit: controller.unitFor(item.foodId),
                              onUnit: (unit) =>
                                  controller.setPriceUnit(item.foodId, unit),
                              onPrice: (value) =>
                                  controller.setPrice(item.foodId, value),
                              onSkip: () => controller.skip(item.foodId),
                              onUnskip: () => controller.unskip(item.foodId),
                            ),
                          ),
                        ),
                      if (unpriced.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            const Text('بلا سعر',
                                style: TextStyle(color: AppPalette.muted)),
                            const SizedBox(width: 6),
                            _CountBadge(count: unpriced.length),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        for (final item in unpriced)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: _CostRow(
                              item: item,
                              currency: controller.currency.value,
                              unit: controller.unitFor(item.foodId),
                              onUnit: (unit) =>
                                  controller.setPriceUnit(item.foodId, unit),
                              onPrice: (value) =>
                                  controller.setPrice(item.foodId, value),
                              onSkip: () => controller.skip(item.foodId),
                              onUnskip: () => controller.unskip(item.foodId),
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      );

  Future<void> _editCurrency(BuildContext context) async {
    final value = await GlassSheet.show<String>(
      context,
      builder: (_) => _CurrencySheet(initial: controller.currency.value),
    );
    if (value != null && value.isNotEmpty) await controller.setCurrency(value);
  }
}

/// The currency field, owning its own [TextEditingController].
///
/// This was originally a closure with the controller created and disposed
/// around the `await`. `showModalBottomSheet`'s future completes when the pop
/// *starts*, not when the sheet is gone, so disposing there tore the
/// controller out from under a `TextField` that was still mounted for the
/// exit animation -- which surfaced as
/// `'_dependents.isEmpty': is not true` from `InheritedElement`, on every
/// cancel. A `State` that disposes in its own `dispose` cannot get that
/// ordering wrong.
class _CurrencySheet extends StatefulWidget {
  final String initial;
  const _CurrencySheet({required this.initial});

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  late final TextEditingController _field =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_field.text.trim());

  @override
  Widget build(BuildContext context) => GlassSheet(
        title: 'العملة',
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'رمز فقط، بلا تحويل عملات — الأسعار تُدخل بعملتك كما هي',
                style: TextStyle(color: AppPalette.muted),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _field,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'رمز العملة'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassButton(label: 'حفظ', onPressed: _submit),
            ],
          ),
        ),
      );
}

class _PeriodChips extends StatelessWidget {
  final CostController controller;
  const _PeriodChips({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() => Wrap(
        spacing: 8,
        children: [
          for (final value in CostPeriod.values)
            GlassChip(
              label: value.labelAr,
              selected: controller.period.value == value,
              onTap: () => controller.setPeriod(value),
            ),
        ],
      ));
}

/// The headline. Only priced components are summed -- an unpriced one counts
/// as unknown, never as free, which is what the coverage line underneath is
/// there to say.
class _TotalCard extends StatelessWidget {
  final CostController controller;
  const _TotalCard({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() {
        final total = controller.total;
        final period = controller.period.value;
        return GlassCard(
          highlighted: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تكلفة ${period.labelAr} واحد',
                  style: const TextStyle(color: AppPalette.muted)),
              const SizedBox(height: 2),
              TickerNumber(
                value: total.knownTotal.round(),
                format: (value) => '$value ${controller.currency.value}',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                '${total.pricedCount} من ${total.components.length} مكوّنات مسعّرة',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (controller.fromSchedule.value) ...[
                const SizedBox(height: 2),
                Text(
                  period == CostPeriod.month
                      ? 'تقدير على أساس أسبوعك الحالي (٣٠٫٤ يوم)'
                      : 'من جدولك الأسبوعي',
                  style: const TextStyle(color: AppPalette.muted, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      });
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppPalette.amber.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('$count',
            style: const TextStyle(
                color: AppPalette.amber, fontWeight: FontWeight.w700)),
      );
}

/// One aggregated component: its total grams for the selected period, an
/// editable price per 100g, and the line cost that falls out of the two.
class _CostRow extends StatefulWidget {
  final ComponentCost item;
  final String currency;
  final PriceUnit unit;
  final ValueChanged<PriceUnit> onUnit;

  /// Always receives a per-100g price -- [_CostRowState] converts out of
  /// whatever unit the field is showing before calling this.
  final ValueChanged<double> onPrice;
  final VoidCallback onSkip;
  final VoidCallback onUnskip;

  const _CostRow({
    required this.item,
    required this.currency,
    required this.unit,
    required this.onUnit,
    required this.onPrice,
    required this.onSkip,
    required this.onUnskip,
  });

  @override
  State<_CostRow> createState() => _CostRowState();
}

class _CostRowState extends State<_CostRow> {
  late final TextEditingController _price = TextEditingController(text: _shown);

  /// The stored per-100g price, rendered in the unit the field is showing.
  String get _shown {
    final value = widget.item.pricePer100;
    if (value == null) return '';
    final inUnit = priceIn(value, widget.unit);
    // Whole-number prices are the common case, so do not render "15.0".
    return inUnit == inUnit.roundToDouble()
        ? inUnit.round().toString()
        : inUnit.toString();
  }

  @override
  void didUpdateWidget(covariant _CostRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Adopt an external change (a skip cleared the price, the book reloaded)
    // or a unit switch, which re-denominates the same price. Rewriting the
    // field unconditionally would fight typing.
    if (oldWidget.item.pricePer100 != widget.item.pricePer100 ||
        oldWidget.unit != widget.unit) {
      final incoming = _shown;
      if (_price.text != incoming) _price.text = incoming;
    }
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final entered = double.tryParse(text.trim());
    if (entered == null || entered < 0) return;
    // The field speaks the chosen unit; everything below stores per 100g.
    final perHundred = pricePer100From(entered, widget.unit);
    if (perHundred == widget.item.pricePer100) return;
    HapticPhrase.play(AppHaptics.step);
    widget.onPrice(perHundred);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    // Two lines rather than one: the price now carries its own unit control,
    // and name + grams + field + unit + cost + action does not fit across a
    // phone without the name being clipped to nothing.
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (item.cost == null)
                Text(
                  item.skipped ? 'متخطّى' : '—',
                  style: const TextStyle(color: AppPalette.muted),
                )
              else
                TickerNumber(
                  value: item.cost!.round(),
                  format: (value) => '$value ${widget.currency}',
                  style: const TextStyle(
                      color: AppPalette.emerald, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('${item.grams.round()} غ',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'السعر',
                    isDense: true,
                  ),
                  onSubmitted: _commit,
                  onTapOutside: (_) => _commit(_price.text),
                ),
              ),
              const SizedBox(width: 6),
              _UnitChip(unit: widget.unit, onChanged: widget.onUnit),
              // A skip is reversible without having to type a price to escape
              // it, so the same slot flips to an undo once the row is skipped.
              if (item.skipped)
                IconButton(
                  onPressed: widget.onUnskip,
                  icon: const Icon(Icons.undo_rounded, color: AppPalette.amber),
                  tooltip: 'إعادة التسعير',
                )
              else if (item.needsPrice)
                IconButton(
                  onPressed: widget.onSkip,
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppPalette.muted),
                  tooltip: 'تخطَّ',
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }
}

/// The unit this one component's price is quoted in.
///
/// Per component, not per screen: rice comes by the kilo and a spice does
/// not, and having to convert one of them in your head to enter the other is
/// exactly the arithmetic this page exists to do for you. Tapping cycles the
/// unit; the stored per-100g price never moves, so the cost beside it does
/// not change -- only the number in the field.
class _UnitChip extends StatelessWidget {
  final PriceUnit unit;
  final ValueChanged<PriceUnit> onChanged;

  const _UnitChip({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final next = PriceUnit.values[(unit.index + 1) % PriceUnit.values.length];
    return Pressable(
      onTap: () => onChanged(next),
      pressedScale: .92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: AppPalette.emerald.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '/${unit.labelAr}',
          style: const TextStyle(
            color: AppPalette.emerald,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
