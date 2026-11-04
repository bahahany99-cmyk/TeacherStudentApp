import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';

/// هوية المدرس الحالي كما تراها الواجهة.
///
/// المشكلة التي يحلّها: في **وضع الزائر** لا يوجد `uid` حقيقي، لكن مجموعات
/// المدرس التجريبي مخزّنة تحت [DemoData.demoTeacherId]. بدون هذا التجميع
/// ستظهر قائمة فارغة للمدرس في وضع المعاينة، أو ستُكتب المجموعات الجديدة تحت
/// معرّف وهمي لا يعود له شيء.
///
/// في الحساب الحقيقي تُعيد `uid` الفعلي — وهو **نفس** القيمة التي تفرضها قواعد
/// Firestore على `teacherId` عند الإنشاء، فلا يمكن كتابة مجموعة باسم غيرك.
abstract final class CurrentTeacher {
  /// معرّف المدرس صاحب الجلسة الحالية.
  static String idOf(SessionController session) {
    final String? uid = session.user?.id;
    if (session.isDemoSession || uid == null || uid.isEmpty) {
      return DemoData.demoTeacherId;
    }
    return uid;
  }

  /// الاسم المعروض (يُحفظ في المجموعة كـ`teacherName` للعرض فقط).
  static String nameOf(SessionController session) {
    final String? name = session.user?.displayName;
    if (name == null || name.trim().isEmpty) {
      return DemoData.teacherName;
    }
    return name.trim();
  }
}
