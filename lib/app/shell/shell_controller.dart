import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/teacher_search_request.dart';

/// يتحكم في القسم المعروض داخل الهيكل الرئيسي.
///
/// الهدف: تسمح أي شاشة (أو زر في الرئيسية) بطلب الانتقال إلى قسم آخر بالاسم
/// `ShellScope.of(context).goTo(AppTab.groups)` بدل تمرير أرقام أو إعادة
/// إنشاء `Navigator`، ما يمنع تكرار منطق التنقل وتضارب الحالة.
class ShellController extends ChangeNotifier {
  AppTab _current = AppTab.home;

  AppTab get current => _current;

  /// طلب بحث مُعلَّق يُسلَّم إلى قسم المدرسين.
  ///
  /// (P18) الشاشات الأخرى (الرئيسية) تطلب بحثًا بنص حقيقي عبر هذا النوتیفاير،
  /// فيصل النص إلى حقل البحث الموجود فعلًا في شاشة المدرسين بدل حقل معطّل في
  /// الرئيسية. النوع [TeacherSearchRequest] لا `String` لأن الطلب المتكرر بنفس
  /// النص يجب أن يُطلق إشعارًا (انظر توثيق الكائن).
  final ValueNotifier<TeacherSearchRequest?> teacherSearch =
      ValueNotifier<TeacherSearchRequest?>(null);

  int _searchSequence = 0;

  /// ينتقل إلى قسم المدرسين، ويُمرّر نص بحث اختياريًا.
  ///
  /// يعمل في الحالتين: قسم المدرسين مفتوح أصلًا (فقط نُطلق الطلب) أو مغلق
  /// (ننتقل إليه ثم يُطبّق الطلب الجاهز).
  void openTeachers({String query = ''}) {
    teacherSearch.value = TeacherSearchRequest(
      query: query.trim(),
      sequence: ++_searchSequence,
    );
    goTo(AppTab.teachers);
  }

  @override
  void dispose() {
    teacherSearch.dispose();
    super.dispose();
  }

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
