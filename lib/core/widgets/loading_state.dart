import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// حالة تحميل موحّدة.
///
/// نستخدم مؤشرًا صغيرًا مع نص بدل شاشة تحميل كاملة، حتى لا "ترتجف" الواجهة
/// عند إعادة التحميل، ولتبقى بنفس الشكل في كل الأقسام.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = AppStrings.loading});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
