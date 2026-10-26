import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';

/// غلاف موحّد لتحميل البيانات غير المتزامنة.
///
/// في المرحلة 2 تُستخدم futures مُخزَّنة مؤقتًا من مستودعات تجريبية.
/// عند ربط Firestore يمكن استبدال هذا الغلاف بـ `StreamBuilder` أو إدارة حالة
/// مناسبة، دون تغيير الشاشات من حيث المفهوم.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.loadingLabel = AppStrings.loading,
    this.errorTitle = 'تعذّر تحميل البيانات',
    this.errorMessage = 'تحقق من الاتصال ثم أعد المحاولة.',
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final String loadingLabel;
  final String errorTitle;
  final String errorMessage;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
                Text(loadingLabel, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: errorTitle,
            message: errorMessage,
          );
        }

        final T? data = snapshot.data;
        if (data == null) {
          return const SizedBox.shrink();
        }

        return builder(context, data);
      },
    );
  }
}
