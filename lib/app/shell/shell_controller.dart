import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/app/shell/app_tab.dart';

/// يتحكم في القسم المعروض داخل الهيكل الرئيسي.
///
/// الهدف: تسمح أي شاشة (أو زر في الرئيسية) بطلب الانتقال إلى قسم آخر بالاسم
/// `ShellScope.of(context).goTo(AppTab.groups)` بدل تمرير أرقام أو إعادة
/// إنشاء `Navigator`، ما يمنع تكرار منطق التنقل وتضارب الحالة.
class ShellController extends ChangeNotifier {
  AppTab _current = AppTab.home;

  AppTab get current => _current;

  /// ينتقل إلى قسم. إذا كان القسم هو الحالي، لا شيء يحدث.
  void goTo(AppTab tab) {
    if (_current == tab) {
      return;
    }
    _current = tab;
    notifyListeners();
  }

  /// يعيد التحديد إلى الرئيسية (يُستخدم عند تغيّر الدور أو تسجيل الخروج).
  void reset() {
    if (_current == AppTab.home) {
      return;
    }
    _current = AppTab.home;
    notifyListeners();
  }

  /// يضمن أن القسم الحالي متاح في قائمة الدور، وإلا يعود للرئيسية.
  void ensureAllowed(List<AppTabSpec> specs) {
    final bool allowed = specs.any((AppTabSpec spec) => spec.tab == _current);
    if (!allowed) {
      reset();
    }
  }
}
