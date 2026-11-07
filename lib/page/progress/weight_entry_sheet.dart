import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/body_weight_repository.dart';
import '../../domain/body/body_weight.dart';
import '../../domain/profile/body_stats.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../service/weigh_in_service.dart';
import '../../ui/feedback/glass_snack_bar.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/components/number_field.dart';
import '../../ui/format/number_input.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/motion/celebration.dart';

class WeightEntrySheet extends StatefulWidget {
  const WeightEntrySheet({super.key, this.entry, this.saveWeight});
  final BodyWeightEntry? entry;
  final Future<void> Function(DateTime date, double kg)? saveWeight;

  static Future<void> show(BuildContext context, {BodyWeightEntry? entry}) =>
      GlassSheet.show<void>(context,
          builder: (_) => WeightEntrySheet(entry: entry));

  @override
  State<WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends State<WeightEntrySheet> {
  late final TextEditingController _kg =
      TextEditingController(text: widget.entry?.kg.toStringAsFixed(1) ?? '');
  late DateTime _date = widget.entry?.date ?? DateTime.now();
  bool _saving = false;
  String? _error;

  // Shared parser accepts Arabic-Indic and Persian digits from Arabic
  // keyboards; blank stays invalid here (the parser maps blank to 0).
  double? get _parsed =>
      _kg.text.trim().isEmpty ? null : parseNutritionAmount(_kg.text);
  bool get _valid =>
      _parsed != null &&
      _parsed!.isFinite &&
      _parsed! >= kMinWeightKg &&
      _parsed! <= kMaxWeightKg;

  @override
  void dispose() {
    _kg.dispose();
    super.dispose();
  }

  void _step(int direction) {
    final value = _parsed ?? 70;
    _kg.text = (((value * 10).round() + direction)
                .clamp(kMinWeightKg * 10, kMaxWeightKg * 10) /
            10.0)
        .toStringAsFixed(1);
    setState(() => _error = null);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day - 30);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _date.isBefore(first) ? first : (_date.isAfter(last) ? last : _date),
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_valid) {
      setState(() => _error = AppStrings.invalidWeight);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      var newLow = false;
      if (widget.saveWeight != null) {
        await widget.saveWeight!(_date, _parsed!);
      } else {
        final uid = Get.find<AuthService>().currentUser!.uid;
        final weights = BodyWeightRepository(uid: uid);
        final before = await weights.watchLatest(100).first;
        final now = DateTime.now();
        final newEntry = BodyWeightEntry(
          dateKey: WeightTrend.keyFor(_date),
          date: _date,
          kg: _parsed!,
          createdAt: now,
          updatedAt: now,
        );
        newLow = WeightTrend(before).isNewLow(newEntry);
        await Get.find<WeighInService>().logWeight(date: _date, kg: _parsed!);
      }
      if (!mounted) return;
      if (newLow) Celebration.show(context);
      GlassSnackBar.show(context, AppStrings.weightSaved,
          tone: GlassSnackTone.success);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => GlassSheet(
        title: AppStrings.logWeight,
        child: SingleChildScrollView(
            child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Editing keeps the entry's date: entries are keyed by date, so
            // re-dating would leave the original entry behind.
            TextButton.icon(
                onPressed: widget.entry == null ? _pickDate : null,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(
                    '${AppStrings.weightDate}: ${_date.day}/${_date.month}/${_date.year}')),
            Row(children: [
              IconButton(
                  onPressed: () => _step(1), icon: const Icon(Icons.add)),
              Expanded(
                  child: NumberField(
                controller: _kg,
                min: kMinWeightKg,
                max: kMaxWeightKg,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                    labelText: AppStrings.weight, errorText: _error),
                onChanged: (_) => setState(() => _error = null),
              )),
              IconButton(
                  onPressed: () => _step(-1), icon: const Icon(Icons.remove)),
            ]),
            const SizedBox(height: 16),
            NeonButton(
                onPressed: _saving || !_valid ? null : _save,
                loading: _saving,
                label: _saving ? AppStrings.saving : AppStrings.save),
          ]),
        )),
      );
}
