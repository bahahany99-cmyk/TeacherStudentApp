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

  /// قراءة بدون تسجيل اعتماد (تُستخدم في الأحداث و`initState`).
  static SessionController read(BuildContext context) {
    final SessionScope? scope = context
        .getInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope غير موجود في شجرة الواجهة.');
    return scope!.notifier!;
  }
}
