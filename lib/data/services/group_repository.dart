import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/study_group.dart';

/// عقد قراءة وكتابة المجموعات الدراسية.
///
/// الكتابة على بيانات المجموعة (P7) محصورة في **المدرس صاحب المجموعة**.
///
/// **الانضمام (P8)** عقد منفصل بنيّة مختلفة: الطالب ينشئ طلبًا، والمدرس يقرر،
/// والقبول يزيد `seatsTaken` بمقدار واحد **داخل المعاملة نفسها** التي تغيّر حالة
/// الطلب وتنشئ مستند العضو. لا توجد لحظة يكون فيها مقعد محسوبًا بلا عضو أو
/// العكس، ولا يمكن لقبولين متزامنين أن يحصلا على المقعد الأخير معًا لأن
/// المعاملة تُعيد قراءة المجموعة قبل الكتابة.
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

  // ── P8: طلبات الانضمام ────────────────────────────────────────────────────

  /// ينشئ الطالب طلب انضمام واحدًا للمجموعة (المعرّف حتمي: مجموعة + طالب).
  ///
  /// يرفض مسبقًا (برسالة عربية) إن كانت المجموعة موقوفة/مكتملة أو كان هناك
  /// طلب معلّق أو عضوية قائمة. المنع النهائي في القواعد والمعاملة.
  Future<GroupJoinRequest> requestToJoin({
    required StudyGroup group,
    required String studentId,
    required String studentName,
  });

  /// طلب الطالب الحالي لهذه المجموعة (بأي حالة)، أو `null`.
  Future<GroupJoinRequest?> findMyRequest({
    required String groupId,
    required String studentId,
  });

  /// كل طلبات مجموعة — للمدرس صاحبها فقط (القواعد تفرض ذلك).
  ///
  /// الترتيب: المعلّقة أولًا، ثم الأحدث قرارًا.
  Future<List<GroupJoinRequest>> listRequestsForGroup(String groupId);

  /// طلبات الطالب الحالي في كل المجموعات.
  Future<List<GroupJoinRequest>> listMyRequests(String studentId);

  /// قرار المدرس: قبول (زيادة مقعد ذرية + إنشاء عضو) أو رفض.
  ///
  /// يقرأ المجموعة والطلب داخل معاملة، فلا يمكن تجاوز السعة حتى لو قُبلت
  /// طلبات أخرى في اللحظة نفسها. يعيد الطلب بعد تحديث حالته.
  Future<GroupJoinRequest> decideJoinRequest({
    required GroupJoinRequest request,
    required String teacherId,
    required bool approve,
  });

  /// إلغاء الطالب لطلبه المعلّق.
  Future<GroupJoinRequest> cancelJoinRequest({
    required GroupJoinRequest request,
    required String studentId,
  });
}
