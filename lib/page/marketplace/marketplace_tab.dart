import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/market_repository.dart';
import '../../domain/day/day_log.dart';
import '../../domain/market/market_meal.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../ui/components/empty_state.dart';
import '../../ui/components/error_state.dart';
import '../../ui/components/neon_button.dart';
import '../../ui/components/shimmer_box.dart';
import '../../ui/format/number_input.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/motion/navigation.dart';
import '../../ui/motion/staggered_entry.dart';
import '../../ui/theme/app_colors.dart';
import '../today/today_controller.dart';

class MarketplaceTab extends StatefulWidget {
  const MarketplaceTab({super.key});

  @override
  State<MarketplaceTab> createState() => _MarketplaceTabState();
}

class _MarketplaceTabState extends State<MarketplaceTab> {
  final Set<Object> _enteredMeals = {};
  final repository = MarketRepository();
  MarketSort sort = MarketSort.newest;
  final meals = <MarketMeal>[];
  DocumentSnapshot<MarketMeal>? cursor;
  bool loading = false;
  bool hasMore = true;
  String? error;
  int generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool restart = false}) async {
    if (loading && !restart) return;
    if (!hasMore && !restart) return;
    final request = ++generation;
    if (restart) {
      cursor = null;
      meals.clear();
      hasMore = true;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await repository.browse(sort: sort, after: cursor);
      if (!mounted || request != generation) return;
      setState(() {
        meals.addAll(page.meals);
        cursor = page.lastDocument;
        hasMore = page.meals.length == 20;
        loading = false;
      });
    } catch (_) {
      if (!mounted || request != generation) return;
      setState(() {
        loading = false;
        error = AppStrings.marketLoadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: () => _load(restart: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Text(AppStrings.market,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(AppStrings.marketIntro,
                style: TextStyle(color: AppPalette.muted)),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text(AppStrings.marketNewest),
                selected: sort == MarketSort.newest,
                selectedColor: AppPalette.emerald.withValues(alpha: .14),
                backgroundColor: AppPalette.surface,
                side: const BorderSide(color: AppPalette.outline),
                labelStyle: const TextStyle(color: AppPalette.text),
                onSelected: (_) {
                  sort = MarketSort.newest;
                  _load(restart: true);
                },
              ),
              ChoiceChip(
                label: const Text(AppStrings.marketMostCopied),
                selected: sort == MarketSort.mostCopied,
                selectedColor: AppPalette.emerald.withValues(alpha: .14),
                backgroundColor: AppPalette.surface,
                side: const BorderSide(color: AppPalette.outline),
                labelStyle: const TextStyle(color: AppPalette.text),
                onSelected: (_) {
                  sort = MarketSort.mostCopied;
                  _load(restart: true);
                },
              ),
            ]),
            const SizedBox(height: 12),
            if (meals.isEmpty && loading)
              const Column(children: [
                ShimmerBox(height: 92),
                SizedBox(height: 12),
                ShimmerBox(height: 92),
                SizedBox(height: 12),
                ShimmerBox(height: 92),
              ])
            else if (meals.isEmpty && error != null)
              ErrorState(message: error!, onRetry: () => _load(restart: true))
            else if (meals.isEmpty)
              const EmptyState(
                icon: Icons.storefront_outlined,
                title: AppStrings.marketEmptyTitle,
                message: AppStrings.marketEmptyBody,
              ),
            for (final (index, meal) in meals.indexed) ...[
              StaggeredEntry(
                index: index,
                replayKey: meal.id,
                replayGuard: _enteredMeals,
                child: _MarketCard(meal: meal),
              ),
              const SizedBox(height: 10),
            ],
            if (error != null && meals.isNotEmpty)
              TextButton(onPressed: _load, child: const Text(AppStrings.retry)),
            if (hasMore && meals.isNotEmpty)
              TextButton(
                onPressed: loading ? null : _load,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(AppStrings.marketMore),
              ),
          ],
        ),
      );
}

class _MarketCard extends StatelessWidget {
  final MarketMeal meal;
  const _MarketCard({required this.meal});

  @override
  Widget build(BuildContext context) => GlassCard(
        onTap: () => pushHealthak(() => _MarketDetail(meal: meal)),
        child: Row(children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppPalette.emerald.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: AppPalette.emerald),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(meal.name, style: Theme.of(context).textTheme.titleMedium),
              Text(meal.authorName,
                  style: const TextStyle(color: AppPalette.muted)),
              Text(
                  '${meal.kcal.round()} ${AppStrings.calories} · ${meal.copyCount} ${AppStrings.marketCopies}',
                  style: const TextStyle(color: AppPalette.emerald)),
            ],
          )),
          const Icon(Icons.chevron_left_rounded, color: AppPalette.muted),
        ]),
      );
}

class _MarketDetail extends StatefulWidget {
  final MarketMeal meal;
  const _MarketDetail({required this.meal});

  @override
  State<_MarketDetail> createState() => _MarketDetailState();
}

class _MarketDetailState extends State<_MarketDetail> {
  bool saving = false;
  bool saved = false;
  bool scheduled = false;
  String? error;
  MealSlot slot = MealSlot.lunch;
  final daysOfWeek = <int>{1, 2, 3, 4, 5, 6, 7};
  late final List<TextEditingController> weights = [
    for (final item in widget.meal.items)
      TextEditingController(text: item.grams.toString()),
  ];

  List<double>? get parsedWeights {
    final values = [
      for (final controller in weights) parseNutritionAmount(controller.text)
    ];
    if (values.any((value) => value == null || value < 1 || value > 2000)) {
      return null;
    }
    return values.cast<double>();
  }

  double get previewKcal {
    final values = parsedWeights;
    if (values == null) return 0;
    var total = 0.0;
    for (var i = 0; i < values.length; i++) {
      total += widget.meal.items[i].per100.forGrams(values[i]).kcal;
    }
    return total;
  }

  @override
  void dispose() {
    for (final controller in weights) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _copy() async {
    if (saving || saved) return;
    final amounts = parsedWeights;
    if (amounts == null) {
      setState(() => error = AppStrings.marketInvalidWeights);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.marketCopyTitle),
        content: const Text(AppStrings.marketCopyBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.assistantCancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.marketCopy)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final uid = Get.find<AuthService>().currentUser!.uid;
      await MarketRepository().copyToLibrary(widget.meal, uid, grams: amounts);
      if (mounted) {
        setState(() {
          saving = false;
          saved = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = AppStrings.marketCopyFailed;
        });
      }
    }
  }

  Future<void> _addToday() async {
    if (saving) return;
    final amounts = parsedWeights;
    if (amounts == null) {
      setState(() => error = AppStrings.marketInvalidWeights);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.marketAddToday),
        content:
            Text(AppStrings.marketAddTodayBody(widget.meal.name, slot.labelAr)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.assistantCancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.assistantConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await Get.find<TodayController>().addMarketMeal(
        widget.meal,
        grams: amounts,
        slot: slot,
      );
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.marketAddedToday)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = AppStrings.marketAddFailed;
        });
      }
    }
  }

  Future<void> _addSchedule() async {
    if (saving || scheduled) return;
    final amounts = parsedWeights;
    if (amounts == null || daysOfWeek.isEmpty) {
      setState(() => error = AppStrings.marketInvalidSchedule);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.marketAddSchedule),
        content: const Text(AppStrings.marketScheduleBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(AppStrings.assistantCancel)),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(AppStrings.assistantConfirm)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final uid = Get.find<AuthService>().currentUser!.uid;
      await MarketRepository().copyToSchedule(
        widget.meal,
        uid,
        grams: amounts,
        slot: slot,
        daysOfWeek: Set.of(daysOfWeek),
      );
      if (mounted) {
        setState(() {
          saving = false;
          scheduled = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.marketScheduled)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = AppStrings.marketScheduleFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return Scaffold(
      appBar: AppBar(title: Text(meal.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(meal.authorName,
              style: const TextStyle(color: AppPalette.muted)),
          const SizedBox(height: 12),
          Text('${previewKcal.round()} ${AppStrings.calories}',
              style: Theme.of(context).textTheme.headlineMedium),
          if (meal.notes != null) ...[
            const SizedBox(height: 10),
            Text(meal.notes!),
          ],
          const SizedBox(height: 18),
          Text(AppStrings.marketIngredients,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (var i = 0; i < meal.items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Expanded(child: Text(meal.items[i].name)),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: weights[i],
                    enabled: !saving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    decoration:
                        const InputDecoration(suffixText: AppStrings.grams),
                    onChanged: (_) => setState(() => error = null),
                  ),
                ),
              ]),
            ),
          TextButton.icon(
            onPressed: saving
                ? null
                : () {
                    for (var i = 0; i < weights.length; i++) {
                      weights[i].text = meal.items[i].grams.toString();
                    }
                    setState(() => error = null);
                  },
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text(AppStrings.marketResetWeights),
          ),
          if (parsedWeights == null)
            const Text(AppStrings.marketInvalidWeights,
                style: TextStyle(color: AppPalette.danger)),
          const SizedBox(height: 8),
          DropdownButtonFormField<MealSlot>(
            initialValue: slot,
            isExpanded: true,
            decoration:
                const InputDecoration(labelText: AppStrings.chooseMealSlot),
            items: [
              for (final value in MealSlot.values)
                DropdownMenuItem(value: value, child: Text(value.labelAr)),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) setState(() => slot = value);
                  },
          ),
          const SizedBox(height: 12),
          const Text(AppStrings.marketScheduleDays),
          Wrap(spacing: 5, children: [
            for (var day = 1; day <= 7; day++)
              FilterChip(
                label: Text(AppStrings.weekdayShort[day - 1]),
                selected: daysOfWeek.contains(day),
                selectedColor: AppPalette.emerald.withValues(alpha: .14),
                onSelected: saving || scheduled
                    ? null
                    : (selected) {
                        setState(() {
                          if (selected) {
                            daysOfWeek.add(day);
                          } else {
                            daysOfWeek.remove(day);
                          }
                        });
                      },
              ),
          ]),
          if (daysOfWeek.isEmpty)
            const Text(AppStrings.marketInvalidSchedule,
                style: TextStyle(color: AppPalette.danger)),
          if (error != null)
            Text(error!, style: const TextStyle(color: AppPalette.danger)),
          const SizedBox(height: 14),
          NeonButton(
            onPressed: saving || parsedWeights == null ? null : _addToday,
            label: saving ? AppStrings.saving : AppStrings.marketAddToday,
            loading: saving,
          ),
          const SizedBox(height: 8),
          NeonButton(
            onPressed: saving || saved ? null : _copy,
            label: saved
                ? AppStrings.marketCopied
                : saving
                    ? AppStrings.saving
                    : AppStrings.marketCopy,
            loading: saving,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: saving ||
                    scheduled ||
                    parsedWeights == null ||
                    daysOfWeek.isEmpty
                ? null
                : _addSchedule,
            child: Text(scheduled
                ? AppStrings.marketScheduled
                : AppStrings.marketAddSchedule),
          ),
        ],
      ),
    );
  }
}
