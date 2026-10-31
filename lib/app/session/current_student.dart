import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';

/// هوية الطالب الحالي كما تراها الواجهة.
///
/// نفس فكرة `CurrentTeacher` (A-56) لجهة الطالب: في وضع الزائر يكون معرّف
/// الجلسة `demo-student`، وهو معرّف لا يطابق شيئًا في Firestore، لكنه **هو**
/// المعرّف الذي تُكتب به طلبات الانضمام المحلية، فتبقى القوائم متّسقة.
///
/// في الحساب الحقيقي تُعيد `uid` الفعلي، وهو نفسه الذي تفرضه القواعد على
/// `studentId` عند إنشاء الطلب.
abstract final class CurrentStudent {
  static String idOf(SessionController session) {
    final String? uid = session.user?.id;
    if (session.isDemoSession || uid == null || uid.isEmpty) {
      return DemoData.demoStudentId;
    }
    return uid;
  }

  /// الاسم المحفوظ مع الطلب (`studentName`) — للعرض عند المدرس فقط.
  static String nameOf(SessionController session) {
    final String? name = session.user?.displayName;
    if (name == null || name.trim().isEmpty) {
      return DemoData.studentName;
    }
    return name.trim();
  }
}
