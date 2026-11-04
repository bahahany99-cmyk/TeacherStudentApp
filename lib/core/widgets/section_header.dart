import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// عنوان قسم داخل صفحة، مع إجراء اختياري على الطرف الآخر (RTL).
///
/// نسخة 2: شريط لوني صغير قبل العنوان (لهجة بصرية بلا صورة)، والعنوان أعرض
/// وأثقل قليلًا، والإجراء بشكل «حبة دواء» بدل نص عائم.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  /// أيقونة اختيارية بجانب العنوان (تعزّز التعرّف السريع للقسم).
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
              ),
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: AppSpacing.xs),
          ] else ...<Widget>[
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withAlpha(90),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.xs),
              child: TextButton(
                onPressed: onActionTap,
                style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary.withAlpha(20),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}
