import 'package:flutter/material.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/error_state.dart';
import 'package:teacher_student_app/core/widgets/loading_state.dart';

/// حالة عنصر غير متزامن (تحميل / خطأ / فراغ / بيانات).
///
/// كل الشاشات تستخدم هذا الغلاف بدل كتابة `FutureBuilder` يدويًا، حتى تكون
/// الحالات الأربع بنفس الشكل والسلوك في كل الأقسام.
///
/// يستقبل **دالة جلب** لا نتيجة جاهزة، والسبب عملي: زر «إعادة المحاولة» يجب أن
/// يعيد قراءة البيانات فعلًا. لو استقبلنا `Future` جاهزًا لكان الضغط على الزر
/// يعيد عرض نفس الخطأ المحفوظ، أي زر بلا أثر.
///
/// مثال:
/// ```dart
/// AsyncView<List<TeacherProfile>>(
///   load: () => AppServicesScope.of(context).teachers.listApproved(),
///   builder: (BuildContext context, List<TeacherProfile> data) => ...,
///   isEmpty: (List<TeacherProfile> data) => data.isEmpty,
/// )
/// ```
///
/// ملاحظات:
/// - لا نُعيد الجلب عند كل إعادة بناء للأب (الدالة تُنشأ من جديد في كل بناء)،
///   لذلك إن تغيّر معامل الجلب (مثل `teacherId`) يجب تمرير `key` مختلف.
/// - عند ربط Firestore يمكن استبدال المصدر بـ`Stream` لاحقًا دون تغيير الشاشات.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.loadingLabel = AppStrings.loading,
    this.isEmpty,
    this.emptyBuilder,
  });

  /// يقرأ البيانات من المصدر. يُستدعى عند أول بناء وعند كل «إعادة المحاولة».
  final Future<T> Function() load;

  /// يبني المحتوى عند وجود بيانات.
  final Widget Function(BuildContext context, T data) builder;

  final String loadingLabel;

  /// هل النتيجة فارغة؟ (يُستخدم لإظهار [emptyBuilder] بدل قائمة فارغة).
  final bool Function(T data)? isEmpty;

  /// الحالة البديلة عند الفراغ. إن لم تُحدَّد، تُعرض حالة فراغ افتراضية.
  final WidgetBuilder? emptyBuilder;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  /// يعيد تشغيل الطلب من المصدر — لا يعيد استخدام المستقبل القديم.
  ///
  /// نستخدم جسمًا صريحًا (`{ }`) لا سهمًا: مع السهم يعيد `setState` قيمة
  /// الإسناد، وهي `Future`، فيرفضها Flutter برسالة
  /// «setState() callback argument returned a Future».
  void _retry() {
    setState(() {
      _future = widget.load();
    });
  }

  Widget _empty(BuildContext context) {
    return widget.emptyBuilder?.call(context) ??
        const EmptyState(
          icon: Icons.inbox_outlined,
          title: 'لا توجد بيانات لعرضها',
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<T> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return LoadingState(label: widget.loadingLabel);
        }

        if (snapshot.hasError) {
          return ErrorState(error: snapshot.error!, onRetry: _retry);
        }

        final T? data = snapshot.data;

        if (data == null) {
          return _empty(context);
        }

        if (widget.isEmpty?.call(data) ?? false) {
          return _empty(context);
        }

        return widget.builder(context, data);
      },
    );
  }
}
