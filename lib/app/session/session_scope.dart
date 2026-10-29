import 'package:flutter/widgets.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';

/// إتاحة [SessionController] للشجرة، مع إعادة بناء المستمعين عند تغيّر الجلسة.
class SessionScope extends InheritedNotifier<SessionController> {
  const SessionScope({
    super.key,
    required SessionController controller,
    required super.child,
  }) : super(notifier: controller);

  /// قراءة مع تسجيل اعتماد (تُستخدم داخل `build`).
  static SessionController of(BuildContext context) {
    final SessionScope? scope = context
        .dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope غير موجود في شجرة الواجهة.');
    return scope!.notifier!;
  }

  /// قراءة **آمنة** لا تفترض وجود النطاق، وتُعيد `null` بلا `assert`.
  ///
  /// لماذا نحتاجها؟ ويدجت مثل `DemoBanner` صارت تتحقق من الجلسة ذاتيًا، لكنها
  /// تُبنى أيضًا في اختبارات تصميم واختبارات ويدجت **بلا** `SessionScope`
  /// (اختبار مكوّن منفرد). استخدام `of` هناك يُسقط الاختبار بـ`assert`، وهو
  /// ما نسميه «انهيار اختبار» ولا نريده. هذه الدالة تفسّر «لا نطاق» بأنها
  /// «لا جلسة معروفة» فيتصرف المستدعي بأمان.
  ///
  /// مثل `of` تسجّل اعتمادًا، فتُعاد الويدجت تلقائيًا عند تغيّر الجلسة.
  static SessionController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier;
  }

  /// قراءة بدون تسجيل اعتماد (تُستخدم في الأحداث و`initState`).
  static SessionController read(BuildContext context) {
    final SessionScope? scope = context
        .getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope غير موجود في شجرة الواجهة.');
    return scope!.notifier!;
  }
}
