import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/theme/app_spacing.dart';

/// نوع الرسالة — يحدد اللون والأيقونة.
enum AppMessageType { info, success, warning, error }

/// تنبيه موحّد للتطبيق (SnackBar) بدل كتابة `ScaffoldMessenger` في كل شاشة.
///
/// القواعد:
/// - لا يجوز أن يحمل التنبيه بيانات حساسة (نص رسالة خاصة، رقم هاتف…).
/// - الرسائل قصيرة ومباشرة بالعربية.
abstract final class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    AppMessageType type = AppMessageType.info,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 4),
  }) {
    final ThemeData theme = Theme.of(context);
    final Color accent = _colorFor(theme, type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(AppSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          backgroundColor: theme.colorScheme.inverseSurface,
          action: action,
          content: Row(
            children: <Widget>[
              Icon(_iconFor(type), size: 20, color: accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onInverseSurface,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static Color _colorFor(ThemeData theme, AppMessageType type) {
    switch (type) {
      case AppMessageType.info:
        return theme.colorScheme.primary;
      case AppMessageType.success:
        return const Color(0xFF4ADE80);
      case AppMessageType.warning:
        return const Color(0xFFFBBF24);
      case AppMessageType.error:
        return const Color(0xFFF87171);
    }
  }

  static IconData _iconFor(AppMessageType type) {
    switch (type) {
      case AppMessageType.info:
        return Icons.info_outline;
      case AppMessageType.success:
        return Icons.check_circle_outline;
      case AppMessageType.warning:
        return Icons.warning_amber_outlined;
      case AppMessageType.error:
        return Icons.error_outline;
    }
  }
}
