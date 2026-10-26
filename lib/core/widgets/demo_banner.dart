import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_colors.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// شريط تحذيري يوضّح أن ما يُعرض بيانات تجريبية محلية.
///
/// يظهر في كل شاشة تعرض بيانات وهمية، حتى لا يُفهم أنها بيانات حقيقية من
/// Firebase أو من مدرسين فعليين.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.demoBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.demoBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.demoForeground,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message ?? AppStrings.demoBanner,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.demoForeground,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
