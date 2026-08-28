import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/app_strings.dart';
import '../../app/app_routes.dart';
import '../../ui/components/glass_button.dart';
import '../../ui/glass/glass_card.dart';
import '../../ui/glass/glass_scaffold.dart';
import '../../ui/theme/app_colors.dart';

/// Read-only first-launch experience for people who have not signed in yet.
///
/// This deliberately uses no repository and no Firebase read: Firestore rules
/// require authentication for personal data and the food catalog. Guest mode
/// is therefore an honest visual preview, not a second identity model.
class GuestPreviewScreen extends StatelessWidget {
  const GuestPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) => GlassScaffold(
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 18),
              Text(AppStrings.appName,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 24),
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: Chip(
                  avatar: Icon(Icons.visibility_outlined, size: 18),
                  label: Text(AppStrings.guestMode),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                AppStrings.guestHeadline,
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.guestDescription,
                style: TextStyle(fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 24),
              const _TargetPreviewCard(),
              const SizedBox(height: 16),
              const Text(
                AppStrings.mealIdeas,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const _MealPreview(name: 'إفطار متوازن', kcal: '420 سعرة'),
              const _MealPreview(name: 'غداء صحي', kcal: '680 سعرة'),
              const SizedBox(height: 18),
              GlassButton(
                onPressed: () => Get.toNamed(AppRoutes.onboarding),
                label: AppStrings.signInOrCreateAccount,
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  AppStrings.accountNeeded,
                  style: TextStyle(color: AppPalette.muted),
                ),
              ),
            ],
          ),
        ),
      );
}

class _TargetPreviewCard extends StatelessWidget {
  const _TargetPreviewCard();

  @override
  Widget build(BuildContext context) => const GlassCard(
        child: Padding(
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: CircularProgressIndicator(
                  value: .42,
                  strokeWidth: 8,
                  backgroundColor: AppPalette.surface,
                  color: AppPalette.emerald,
                ),
              ),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.dailyTarget,
                        style: TextStyle(fontSize: 16)),
                    SizedBox(height: 4),
                    Text('2000 سعرة',
                        style: TextStyle(
                            fontSize: 23, fontWeight: FontWeight.w700)),
                    Text('${AppStrings.remaining}: 1160 سعرة'),
                  ],
                ),
              ),
              Icon(Icons.lock_outline, color: AppPalette.emerald),
            ],
          ),
        ),
      );
}

class _MealPreview extends StatelessWidget {
  final String name;
  final String kcal;

  const _MealPreview({required this.name, required this.kcal});

  @override
  Widget build(BuildContext context) => GlassCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(
            backgroundColor: AppPalette.surface,
            child: Icon(Icons.restaurant_outlined, color: AppPalette.emerald),
          ),
          title: Text(name),
          subtitle: Text(kcal),
          trailing: const Icon(Icons.lock_outline),
        ),
      );
}
