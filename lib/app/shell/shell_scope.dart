import 'package:flutter/widgets.dart';

import 'package:teacher_student_app/app/shell/shell_controller.dart';

/// إتاحة [ShellController] لأي شاشة داخل الهيكل، مع إعادة بناء المستمعين.
class ShellScope extends InheritedNotifier<ShellController> {
  const ShellScope({
    super.key,
    required ShellController controller,
    required super.child,
  }) : super(notifier: controller);

  /// قراءة مع اعتماد (داخل `build`).
  static ShellController of(BuildContext context) {
    final ShellScope? scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope غير موجود في شجرة الواجهة.');
    return scope!.notifier!;
  }

  /// قراءة **آمنة** لا تفترض وجود النطاق: `null` إن لم يوجد (اختبار ويدجت
  /// منفرد). تُستخدم في شاشات قد تُستضاف خارج الهيكل في الاختبارات.
  static ShellController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>()?.notifier;
  }

  /// قراءة بلا اعتماد **وبلا افتراض وجود النطاق** (في الأحداث).
  ///
  /// تُستخدم في شاشات تُستضاف في اختبارات منفردة بلا هيكل تنقّل: التنقل يصبح
  /// بلا أثر بدل أن يسقط التطبيق بـ assert.
  static ShellController? readOrNull(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ShellScope>()?.notifier;
  }

  /// قراءة بلا اعتماد (في الأحداث).
  static ShellController read(BuildContext context) {
    final ShellScope? scope = context.getInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope غير موجود في شجرة الواجهة.');
    return scope!.notifier!;
  }
}
