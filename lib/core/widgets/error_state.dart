import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';

/// حالة خطأ موحّدة مع زر «إعادة المحاولة».
///
/// تحوّل أي استثناء إلى رسالة عربية مفهومة عبر [AppException]، فلا تظهر
/// تفاصيل تقنية للمستخدم، وتُعرض في نفس المكان في كل الشاشات.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
  });

  final Object error;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final AppException failure = toAppException(error);

    return EmptyState(
      icon: _iconFor(failure.kind),
      title: failure.title,
      message: failure.message,
      actionLabel: onRetry == null ? null : retryLabel,
      onActionTap: onRetry,
    );
  }

  static IconData _iconFor(AppErrorKind kind) {
    return switch (kind) {
      AppErrorKind.network => Icons.wifi_off_outlined,
      AppErrorKind.permission => Icons.lock_outline,
      AppErrorKind.notFound => Icons.search_off,
      AppErrorKind.unknown => Icons.error_outline,
    };
  }
}

/// شريط صغير يوضّح أن المستخدم غير متصل — يُعرض أعلى المحتوى القابل للتحديث.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.wifi_off_outlined,
            size: 18,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'أنت غير متصل — تُعرض آخر بيانات متاحة.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('تحديث'),
          ),
        ],
      ),
    );
  }
}
