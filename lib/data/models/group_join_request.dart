import 'package:teacher_student_app/data/models/study_group.dart';

/// حالة طلب الانضمام إلى مجموعة دراسية.
///
/// القيم النصية (`name`) هي **نفس** القيم المسموح بها في `firestore.rules`؛
/// تغيير أي اسم هنا يوجب تغييره هناك، والاختبارات على المحاكي تكشف التباعد.
enum JoinRequestStatus {
  /// بانتظار قرار المدرس (يشغل «مقعدًا محتملًا» لكنه لا يزيد `seatsTaken`).
  pending('قيد الانتظار'),

  /// قُبل الطلب وزيادة المقعد المشغول تمّت في **نفس** العملية الذرية.
  accepted('مقبول'),

  /// رفضه المدرس.
  rejected('مرفوض'),

  /// ألغاه الطالب قبل القرار.
  cancelled('ملغى');

  const JoinRequestStatus(this.label);

  /// نص العرض العربي.
  final String label;

  bool get isPending => this == JoinRequestStatus.pending;
  bool get isAccepted => this == JoinRequestStatus.accepted;

  /// هل يمكن للطالب إعادة المحاولة؟ (بعد الرفض أو الإلغاء فقط)
  bool get allowsRetry =>
      this == JoinRequestStatus.rejected || this == JoinRequestStatus.cancelled;

  /// تحويل نصي متسامح (أي قيمة غير معروفة = `pending`، الأسلم للعرض).
  static JoinRequestStatus parse(Object? raw) {
    return switch (raw) {
      'accepted' => JoinRequestStatus.accepted,
      'rejected' => JoinRequestStatus.rejected,
      'cancelled' => JoinRequestStatus.cancelled,
      _ => JoinRequestStatus.pending,
    };
  }
}

/// طلب انضمام طالب إلى مجموعة.
///
/// **لماذا معرّف حتمي؟** `groupId_studentId` يعني أن الطالب لا يستطيع إنشاء
/// طلبين متوازيين للمجموعة نفسها (المستند نفسه)، فتصبح «لا طلبين نشطين» قاعدة
/// بنيوية لا حاجة لعدّها. القواعد تتحقق من هذا التركيب عند الإنشاء.
class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.groupId,
    required this.groupTitle,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.requestedAt,
    this.decidedAt,
    this.decidedBy,
    this.cooldownUntil,
  });

  /// المعرّف الحتمي لطلب واحد: مجموعة واحدة + طالب واحد = مستند واحد.
  static String idFor({required String groupId, required String studentId}) =>
      '${groupId}_$studentId';

  final String id;
  final String groupId;
  final String groupTitle;

  /// صاحب المجموعة — **منسوخ في الطلب** بقصد.
  ///
  /// لو قرأنا المالك من مستند المجموعة داخل القواعد لاحتجنا `get()` لكل
  /// مستند في القائمة، وقواعد Firestore تحدّ ذلك بعشرة مستندات لكل استعلام.
  /// النسخ يجعل `read` فحصًا على حقول المستند نفسه، بلا حدود عملية.
  final String teacherId;

  final String studentId;
  final String studentName;
  final JoinRequestStatus status;
  final DateTime requestedAt;
  final DateTime? decidedAt;

  /// `uid` من اتخذ القرار (المدرس عند القبول/الرفض، الطالب عند الإلغاء).
  final String? decidedBy;

  /// (P24) نهاية فترة التهدئة بعد إلغاء الطالب لطلبه.
  ///
  /// **لماذا؟** كانت الحلقة «أرسل ⇒ ألغِ ⇒ أرسل» بلا حد، فيستطيع طالب واحد
  /// إغراق مدرس بعشرات الطلبات في دقيقة. الإلغاء يكتب الآن موعدًا لا يسمح
  /// بإعادة الإرسال قبله، والقواعد تتحقق من القيمة نفسها على الخادم.
  final DateTime? cooldownUntil;

  bool get isPending => status.isPending;

  /// نسخة بعدّلة حالة/قرار — تُستخدم في التنفيذ التجريبي وفي تحديثات المعاملة.
  GroupJoinRequest copyWith({
    JoinRequestStatus? status,
    DateTime? requestedAt,
    DateTime? decidedAt,
    String? decidedBy,
    DateTime? cooldownUntil,
    bool clearCooldown = false,
  }) {
    return GroupJoinRequest(
      id: id,
      groupId: groupId,
      groupTitle: groupTitle,
      teacherId: teacherId,
      studentId: studentId,
      studentName: studentName,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      cooldownUntil: clearCooldown
          ? null
          : (cooldownUntil ?? this.cooldownUntil),
    );
  }

  /// خريطة الإلغاء: الحالة + موعد انتهاء التهدئة (P24).
  ///
  /// القواعد ترفض إلغاءً بلا `cooldownUntil`، وتفرض أن يكون في المستقبل بمدة
  /// لا تقل عن مدة التهدئة، فلا يمكن للعميل تجاوزها بكتابة موعد ماضٍ أو بحذف
  /// الحقل. المدة نفسها في `JoinRules.cancelCooldown`.
  Map<String, Object?> cancelMap({required DateTime cooldownUntil}) {
    return <String, Object?>{
      'status': 'cancelled',
      'cooldownUntil': cooldownUntil,
    };
  }

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  ///
  /// `decidedAt`/`decidedBy` غائبة عمدًا: لا يستطيع الطالب كتابة قرار.
  Map<String, Object?> toCreateMap() {
    return <String, Object?>{
      'groupId': groupId,
      'groupTitle': groupTitle,
      'teacherId': teacherId,
      'studentId': studentId,
      'studentName': studentName,
      'status': 'pending',
      'requestedAt': requestedAt,
    };
  }
}

/// طلب انضمام مبني من بيانات المجموعة والطالب الحالي.
GroupJoinRequest buildJoinRequest({
  required StudyGroup group,
  required String studentId,
  required String studentName,
  DateTime? requestedAt,
}) {
  return GroupJoinRequest(
    id: GroupJoinRequest.idFor(groupId: group.id, studentId: studentId),
    groupId: group.id,
    groupTitle: group.title,
    teacherId: group.teacherId,
    studentId: studentId,
    studentName: studentName,
    status: JoinRequestStatus.pending,
    requestedAt: requestedAt ?? DateTime.now(),
  );
}
