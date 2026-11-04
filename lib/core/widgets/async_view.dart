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
///   load: () => AppServicesScope.of(context).teachers.listVerified(),
///   builder: (BuildContext context, List<TeacherProfile> data) => ...,
///   isEmpty: (List<TeacherProfile> data) => data.isEmpty,
/// )
/// ```
///
/// ملاحظات:
/// - لا نُعيد الجلب عند كل إعادة بناء للأب (الدالة تُنشأ من جديد في كل بناء)،
///   لذلك إن تغيّر معامل الجلب (مثل `teacherId`) يجب تمرير `key` مختلف، أو
///   أفضل: تمرير [reloadKey] (انظر أدناه).
/// - **`reloadKey` بدل `key` (P18):** تمرير `key` مختلف يُدمّر حالة الودجت
///   ويُعيد بناءه من الصفر، فتظهر حالة تحميل كاملة عند كل تغيير فلتر وتقفز
///   القائمة. [reloadKey] يُعيد الجلب **دون** فقدان الحالة، ومع
///   [keepPreviousData] تبقى النتائج السابقة معروضة حتى تصل الجديدة.
/// - عند ربط Firestore يمكن استبدال المصدر بـ`Stream` لاحقًا دون تغيير الشاشات.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.loadingLabel = AppStrings.loading,
    this.isEmpty,
    this.emptyBuilder,
    this.reloadKey,
    this.keepPreviousData = false,
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

  /// قيمة تُقارن بالمساواة: تغيّرها يُعيد الجلب **مع الحفاظ على حالة الودجت**.
  ///
  /// تُستخدم بدل `key` عندما يتغيّر معامل الجلب (فلتر، معرّف) ولا نريد مسح
  /// الشاشة وإظهار حالة تحميل كاملة في كل تغيير.
  final Object? reloadKey;

  /// إبقاء آخر بيانات ناجحة معروضة أثناء إعادة الجلب بدل شاشة تحميل.
  ///
  /// يمنع «وميض» القائمة عند تغيير فلتر، ويُظهر شريط تقدّم رقيقًا فوق البيانات
  /// القديمة حتى تصل الجديدة.
  final bool keepPreviousData;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future;

  /// آخر بيانات ناجحة — تبقى معروضة أثناء إعادة الجلب عند
  /// [AsyncView.keepPreviousData].
  T? _lastData;
  bool _hasLastData = false;

  @override
  void initState() {
    super.initState();
    _future = _start();
  }

  @override
  void didUpdateWidget(AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // إعادة جلب عند تغيّر المعامل فقط، لا عند كل بناء للأب.
    if (widget.reloadKey != oldWidget.reloadKey) {
      _future = _start();
    }
  }

  /// يبدأ طلبًا جديدًا ويحفظ آخر نتيجة ناجحة (بلا `setState`: `FutureBuilder`
  /// يعيد البناء عند اكتمال المستقبل أصلًا).
  Future<T> _start() {
    final Future<T> future = widget.load();
    future.then(
      (T value) {
        _lastData = value;
        _hasLastData = true;
      },
      // الخطأ يُعرض عبر حالت الخطأ في `FutureBuilder`؛ لا نبتلعه هنا.
      onError: (Object _) {},
    );
    return future;
  }

  /// يعيد تشغيل الطلب من المصدر — لا يعيد استخدام المستقبل القديم.
  ///
  /// نستخدم جسمًا صريحًا (`{ }`) لا سهمًا: مع السهم يعيد `setState` قيمة
  /// الإسناد، وهي `Future`، فيرفضها Flutter برسالة
  /// «setState() callback argument returned a Future».
  void _retry() {
    setState(() {
      _future = _start();
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
          // إعادة جلب فوق بيانات موجودة: نُبقي القديم مع مؤشر رقيق بدل شاشة
          // تحميل كاملة، فلا «تومض» القائمة عند تغيير فلتر.
          if (widget.keepPreviousData && _hasLastData) {
            final T previous = _lastData as T;
            final bool previousEmpty =
                widget.isEmpty?.call(previous) ?? false;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const LinearProgressIndicator(minHeight: 2),
                if (previousEmpty)
                  _empty(context)
                else
                  widget.builder(context, previous),
              ],
            );
          }
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
