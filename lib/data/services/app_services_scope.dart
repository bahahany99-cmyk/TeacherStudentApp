import 'package:flutter/widgets.dart';

import 'package:teacher_student_app/data/services/app_services.dart';

/// إتاحة [AppServices] لكل شجرة الواجهة.
///
/// نستخدم `InheritedWidget` بدلًا من حزمة إدارة حالة في هذه المرحلة:
/// أبسط، بلا اعتماديات إضافية، وقابل للاستبدال لاحقًا (انظر T-04 في
/// `docs/ARCHITECTURE_DECISIONS.md`).
class AppServicesScope extends InheritedWidget {
  const AppServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppServicesScope? scope = context
        .dependOnInheritedWidgetOfExactType<AppServicesScope>();
    assert(scope != null, 'AppServicesScope غير موجود في شجرة الواجهة.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppServicesScope oldWidget) =>
      oldWidget.services != services;
}
