import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../ui/components/empty_state.dart';

class ProgressTab extends StatelessWidget {
  const ProgressTab({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(AppStrings.progress,
                style: Theme.of(context).textTheme.headlineMedium),
          ),
        ),
        const Expanded(
          child: EmptyState(
            icon: Icons.insights_outlined,
            title: AppStrings.progressEmptyTitle,
            message: AppStrings.progressEmptyMessage,
          ),
        ),
      ]);
}
