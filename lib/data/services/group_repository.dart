import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// عقد قراءة وكتابة المجموعات الدراسية.
///
/// الكتابة (P7) محصورة في **المدرس صاحب المجموعة**: الإنشاء والتعديل والإيقاف.
/// منع تجاوز السعة عند قبول طلب انضمام يبقى عملية ذرية على الخادم (P8).
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

  /// إنشاء مجموعة جديدة لصاحبها.
  ///
  /// المنفّذ الحقيقي يكتب `seatsTaken = 0` و`isActive = true`، والقواعد ترفض
  /// أي قيمة أخرى — فلا يستطيع التطبيق تزوير مقاعد مشغولة.
  Future<StudyGroup> createGroup({
    required String teacherId,
    required String teacherName,
    required GroupDraft draft,
  });

  /// تعديل مجموعة قائمة.
  ///
  /// لا يغيّر `seatsTaken` ولا `teacherId`، ويرفض تقليل السعة تحت عدد
  /// المنضمين الحالي ([GroupRules.minAllowedSeats]).
  Future<StudyGroup> updateGroup({
    required String groupId,
    required String teacherId,
    required GroupDraft draft,
    required bool isActive,
  });
}
