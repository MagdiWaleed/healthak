import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  const SectionHeader(
      {required this.title, this.actionText, this.onAction, super.key});

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppPalette.text))),
        if (actionText != null)
          TextButton(onPressed: onAction, child: Text(actionText!)),
      ]);
}
