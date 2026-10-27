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

  /// قراءة بلا اعتماد (في الأحداث).
  static ShellController read(BuildContext context) {
    final ShellScope? scope = context.getInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope غير موجود في شجرة الواجهة.');
    return scope!.notifier!;
  }
}
