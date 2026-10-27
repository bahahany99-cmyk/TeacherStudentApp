import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/group_filter.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/group_member.dart';
import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
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

  /// استكشاف مفلتر (P9).
  ///
  /// المنفّذ يدفع إلى الخادم ما يمكن دفعه (النشر + مساواة المادة/المرحلة/
  /// طريقة الحضور)، ويطبّق الباقي عبر `DiscoveryRules` (A-66). يعيد النتيجة مع
  /// إجمالي ما ورد من الخادم قبل فلاتر العميل، حتى تقول الشاشة «3 من 12».
  Future<GroupSearchResult> searchDiscoverable(GroupFilter filter);

  /// إزالة عضو من المجموعة — **لصاحب المجموعة فقط**.
  ///
  /// عملية ذرّية: تُحذف العضوية وتنقص المقاعد المشغولة بمقدار واحد في المعاملة
  /// نفسها، فلا يبقى مقعد محسوبًا لعضو محذوف ولا العكس. المقعد المحرَّر هو ما
  /// يسمح بقبول أول المنتظرين ([promoteFromWaitlist]).
  Future<StudyGroup> removeMember({
    required String groupId,
    required String memberId,
    required String teacherId,
  });

  // ── P9: قائمة الانتظار (المجموعة المكتملة) ──────────────────────────────

  /// ينضم الطالب إلى قائمة انتظار مجموعة **مكتملة**.
  ///
  /// يرفض مبكرًا إن كان بها مقعد، أو كانت موقوفة، أو كان الطالب في القائمة/
  /// عضوًا. القواعد تفرض الشرط نفسه (`seatsTaken >= seatsTotal`).
  Future<GroupWaitlistEntry> joinWaitlist({
    required StudyGroup group,
    required String studentId,
    required String studentName,
  });

  /// صف الطالب الحالي في قائمة انتظار مجموعة (بأي حالة)، أو `null`.
  Future<GroupWaitlistEntry?> findMyWaitlistEntry({
    required String groupId,
    required String studentId,
  });

  /// كل صفوف قائمة الانتظار لمجموعة — لصاحبها فقط.
  ///
  /// [teacherId] إلزامي عمليًا: القواعد تقرأ `resource.data.teacherId`،
  /// والاستعلام الذي لا يقيّده يُرفض كاملًا (نفس سبب `listRequestsForGroup`).
  Future<List<GroupWaitlistEntry>> listWaitlist(
    String groupId, {
    String? teacherId,
  });

  /// يقبل المدرس أول المنتظرين: مقعد واحد + عضوية جديدة + حالة الصف، في معاملة.
  ///
  /// يرفض إن لم يبقَ مقعد أو لم يكن الصف منتظرًا — والفحص على قراءة طازجة.
  Future<GroupWaitlistEntry> promoteFromWaitlist({
    required GroupWaitlistEntry entry,
    required String teacherId,
  });

  /// يغادر الطالب القائمة. الحالة تصبح `left` ولا يُحذف الصف (سجل تاريخي).
  Future<GroupWaitlistEntry> leaveWaitlist({
    required GroupWaitlistEntry entry,
    required String studentId,
  });

  /// مجموعات مدرس محدّد (واجهة المدرس).
  Future<List<StudyGroup>> listForTeacher(String teacherId);

  /// مجموعة واحدة بالمعرّف، أو `null` إن لم توجد.
  Future<StudyGroup?> findById(String id);

  /// أعضاء مجموعة (واجهة المدرس فقط في هذه المرحلة).
  ///
  /// قاعدة الوصول الحقيقية (المدرس يرى أعضاء مجموعته فقط، والطالب لا يرى
  /// أسماء بقية الطلاب) تُفرض في Firestore، لا في الواجهة.
  Future<List<GroupMember>> listMembers(String groupId);

  /// هل هذا المستخدم عضو مقبول في المجموعة؟
  ///
  /// تُستخدم لإتاحة الجدول والمحادثة (P9) في الواجهة. **ليست فحصًا أمنيًا**:
  /// القواعد تفحص العضوية بنفسها عند كل قراءة/كتابة.
  Future<bool> isMember({required String groupId, required String userId});

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
  /// [teacherId] ليس ترشيحًا في الواجهة: قواعد Firestore تقرأ
  /// `resource.data.teacherId`، وأي استعلام (list) لا يقيّد هذا الحقل **يُرفض
  /// كاملًا** لا يُرشَّح فقط. لذلك تمرير معرّف المالك ضروري ليصبح الاستعلام
  /// قابلًا للتحقق على الخادم.
  ///
  /// الترتيب: المعلّقة أولًا، ثم الأحدث قرارًا.
  Future<List<GroupJoinRequest>> listRequestsForGroup(
    String groupId, {
    String? teacherId,
  });

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
