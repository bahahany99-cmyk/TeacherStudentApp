import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// عقد قراءة المجموعات الدراسية.
///
/// التنفيذ الحقيقي (Phase 7): استعلام Firestore مقسّم إلى صفحات، مع منع
/// تجاوز السعة على الخادم عند الموافقة على طلب الانضمام.
abstract interface class GroupRepository {
  /// المجموعات المتاحة للاستكشاف (واجهة الطالب).
  Future<List<StudyGroup>> listDiscoverable();

  /// مجموعات مدرس محدّد (واجهة المدرس).
  Future<List<StudyGroup>> listForTeacher(String teacherId);

  /// مجموعة واحدة بالمعرّف، أو `null` إن لم توجد.
  Future<StudyGroup?> findById(String id);

  /// أعضاء مجموعة (واجهة المدرس فقط في هذه المرحلة).
  ///
  /// قاعدة الوصول الحقيقية (المدرس يرى أعضاء مجموعته فقط، والطالب لا يرى
  /// أسماء بقية الطلاب) تُفرض في Firestore، لا في الواجهة.
  Future<List<GroupMember>> listMembers(String groupId);
}
