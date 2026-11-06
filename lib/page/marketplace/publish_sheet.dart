import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/repositories/market_repository.dart';
import '../../domain/meal/meal_definition.dart';
import '../../l10n/app_strings.dart';
import '../../service/auth_service.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/glass/glass_sheet.dart';
import '../../ui/theme/app_colors.dart';

class PublishSheet extends StatefulWidget {
  final MealDefinition meal;
  const PublishSheet({required this.meal, super.key});

  static Future<void> show(BuildContext context, MealDefinition meal) =>
      GlassSheet.show<void>(
        context,
        builder: (_) => PublishSheet(meal: meal),
      );

  @override
  State<PublishSheet> createState() => _PublishSheetState();
}

class _PublishSheetState extends State<PublishSheet> {
  final repository = MarketRepository();
  late final name = TextEditingController(text: widget.meal.name);
  late final notes = TextEditingController(text: widget.meal.notes ?? '');
  final tags = TextEditingController();
  bool loading = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (widget.meal.publishedMarketMealId != null) _loadPublished();
  }

  Future<void> _loadPublished() async {
    setState(() => loading = true);
    try {
      final existing =
          await repository.getPublished(widget.meal.publishedMarketMealId!);
      if (!mounted) return;
      if (existing != null) {
        name.text = existing.name;
        notes.text = existing.notes ?? '';
        tags.text = existing.tags.join('، ');
      }
      setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = AppStrings.marketPublishFailed;
        });
      }
    }
  }

  @override
  void dispose() {
    name.dispose();
    notes.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    if (saving ||
        loading ||
        name.text.trim().isEmpty ||
        name.text.trim().length > 80) {
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final user = Get.find<AuthService>().currentUser!;
      await repository.publish(
        widget.meal,
        authorName: user.displayName ?? AppStrings.marketAuthorFallback,
        name: name.text,
        notes: notes.text,
        tags: tags.text.split(RegExp(r'[,،]')),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = AppStrings.marketPublishFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => GlassSheet(
        title: widget.meal.isPublished
            ? AppStrings.marketRepublish
            : AppStrings.marketPublish,
        topInset: 70,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(AppStrings.marketPublishReview),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  enabled: !loading && !saving,
                  maxLength: 80,
                  decoration:
                      const InputDecoration(labelText: AppStrings.marketName),
                  onChanged: (_) => setState(() {}),
                ),
                TextField(
                  controller: notes,
                  enabled: !loading && !saving,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: AppStrings.marketDescription),
                ),
                TextField(
                  controller: tags,
                  enabled: !loading && !saving,
                  decoration:
                      const InputDecoration(labelText: AppStrings.marketTags),
                ),
                const SizedBox(height: 8),
                Text(
                    '${widget.meal.leafCount} ${AppStrings.marketIngredients} · '
                    '${widget.meal.totalsCache.kcal.round()} ${AppStrings.calories}',
                    style: const TextStyle(color: AppPalette.muted)),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(color: AppPalette.danger)),
                ],
                const SizedBox(height: 18),
                GlassButton(
                  label: saving
                      ? AppStrings.saving
                      : widget.meal.isPublished
                          ? AppStrings.marketRepublish
                          : AppStrings.marketPublish,
                  busy: saving || loading,
                  onPressed: name.text.trim().isNotEmpty &&
                          name.text.trim().length <= 80 &&
                          !loading
                      ? _publish
                      : null,
                ),
              ],
            ),
          ),
        ),
      );
}
