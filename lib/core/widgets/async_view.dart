import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/error_state.dart';
import 'package:teacher_student_app/core/widgets/loading_state.dart';

/// حالة عنصر غير متزامن (تحميل / خطأ / فراغ / بيانات).
///
/// كل الشاشات تستخدم هذا الغلاف بدل كتابة `FutureBuilder` يدويًا، حتى تكون
/// الحالات الأربع بنفس الشكل والسلوك في كل الأقسام، ويوجد **دائمًا** زر
/// «إعادة المحاولة» عند الخطأ.
///
/// عند ربط Firestore يمكن استبدال المصدر بـ`Stream` عبر [AsyncView.stream]
/// دون تغيير الشاشات.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.future,
    required this.builder,
    this.loadingLabel = AppStrings.loading,
    this.isEmpty,
    this.emptyBuilder,
    this.onRetry,
  });

  final Future<T> future;

  /// يبني المحتوى عند وجود بيانات.
  final Widget Function(BuildContext context, T data) builder;

  final String loadingLabel;

  /// هل النتيجة فارغة؟ (يُستخدم لإظهار [emptyBuilder] بدل قائمة فارغة).
  final bool Function(T data)? isEmpty;

  /// الحالة البديلة عند الفراغ. إن لم تُحدَّد، تُعرض قائمة فارغة افتراضية.
  final WidgetBuilder? emptyBuilder;

  /// إن حُدِّد، يُستدعى لإعادة جلب البيانات (ويُعاد تشغيل [future] من الأب).
  final VoidCallback? onRetry;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  /// مفتاح إعادة البناء: يسمح بإعادة تشغيل الـfuture دون إعادة بناء الشاشة.
  Key _futureKey = UniqueKey();

  void _retry() {
    setState(() => _futureKey = UniqueKey());
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      key: _futureKey,
      future: widget.future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingState(label: widget.loadingLabel);
        }

        if (snapshot.hasError) {
          return ErrorState(error: snapshot.error!, onRetry: _retry);
        }

        final T? data = snapshot.data;

        if (data == null) {
          return const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'لا توجد بيانات لعرضها',
          );
        }

        if (widget.isEmpty?.call(data) ?? false) {
          return widget.emptyBuilder?.call(context) ??
              const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'لا توجد بيانات لعرضها',
              );
        }

        return widget.builder(context, data);
      },
    );
  }
}
