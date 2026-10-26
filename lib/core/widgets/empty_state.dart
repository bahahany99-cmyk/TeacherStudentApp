import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// حالة فراغ/خطأ موحّدة.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onActionTap,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          if (message != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (actionLabel != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onActionTap, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
