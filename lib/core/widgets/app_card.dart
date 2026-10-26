import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// سطح/بطاقة موحّدة تُستخدم في كل الشاشات.
///
/// نستخدم `Container` مع تزيين صريح بدلًا من `Card` لتقليل الارتباط بتغيّرات
/// `CardTheme` بين إصدارات Flutter.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius radius = BorderRadius.circular(AppSpacing.radiusLg);

    final Widget content = Container(
      margin: margin,
      padding: padding ?? AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: theme.colorScheme.outline, width: 0.7),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: radius,
      onTap: onTap,
      child: content,
    );
  }
}
