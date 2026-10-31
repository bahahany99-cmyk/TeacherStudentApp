import 'package:teacher_student_app/data/models/study_group.dart';

/// حالة طلب الانتظار في مجموعة مكتملة.
///
/// القيم النصية مطابقة حرفيًا لما في `firestore.rules` — أي تغيير هنا يوجب
/// تغييره هناك، واختبارات المحاكي تكشف التباعد.
enum WaitlistStatus {
  /// في الطابور، لا يشغل مقعدًا.
  waiting('في قائمة الانتظار'),

  /// حصل على مقعد بعد قبول المدرس (أصبح عضوًا).
  promoted('تم قبوله'),

  /// غادر الطابور بنفسه.
  left('غادر القائمة');

  const WaitlistStatus(this.label);

  final String label;

  bool get isWaiting => this == WaitlistStatus.waiting;

  /// تحويل متسامح: أي قيمة غير معروفة تُعامل كـ«منتظر» (الأسلم للعرض).
  static WaitlistStatus parse(Object? raw) {
    return switch (raw) {
      'promoted' => WaitlistStatus.promoted,
      'left' => WaitlistStatus.left,
      _ => WaitlistStatus.waiting,
    };
  }
}

/// قائمة انتظار مجموعة مكتملة.
///
/// **لماذا مستند مستقل وليس عضوًا بحالة `waitlist`؟**
/// لأن العضو يُقرأ في القواعد عبر `exists()` لفتح الجدول والمحادثة؛ لو كان
/// المنتظر «عضوًا» لدخل الجدول والمحادثة بلا مقعد. الفصل يجعل العضوية تعني
/// المقعد حرفيًا.
///
/// **لماذا لا يوجد حقل `position`؟** لأن الترتيب مشتق من `addedAt`؛ تخزين رقم
/// موضع يعني تحديث كل الصفوف عند أي انسحاب، وهو عمل بلا فائدة وقابل للتناقض.
class GroupWaitlistEntry {
  const GroupWaitlistEntry({
    required this.id,
    required this.groupId,
    required this.groupTitle,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.status,
    required this.addedAt,
    this.decidedAt,
    this.decidedBy,
  });

  /// المعرّف الحتمي: مجموعة واحدة + طالب واحد = مستند واحد.
  static String idFor({required String groupId, required String studentId}) =>
      '${groupId}_$studentId';

  final String id;
  final String groupId;
  final String groupTitle;

  /// صاحب المجموعة — منسوخ في المستند بنفس سبب الطلب (A-59): القواعد تقرأ
  /// حقول المستند نفسه، فلا تحتاج `get()` لكل سطر في قائمة الانتظار.
  final String teacherId;

  final String studentId;
  final String studentName;
  final WaitlistStatus status;
  final DateTime addedAt;
  final DateTime? decidedAt;

  /// `uid` من غيّر الحالة (المدرس عند القبول، الطالب عند المغادرة).
  final String? decidedBy;

  bool get isWaiting => status.isWaiting;

  GroupWaitlistEntry copyWith({
    WaitlistStatus? status,
    DateTime? addedAt,
    DateTime? decidedAt,
    String? decidedBy,
  }) {
    return GroupWaitlistEntry(
      id: id,
      groupId: groupId,
      groupTitle: groupTitle,
      teacherId: teacherId,
      studentId: studentId,
      studentName: studentName,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
    );
  }

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  ///
  /// `decidedAt`/`decidedBy` غائبة عمدًا: الطالب لا يكتب قرارًا.
  Map<String, Object?> toCreateMap() {
    return <String, Object?>{
      'groupId': groupId,
      'groupTitle': groupTitle,
      'teacherId': teacherId,
      'studentId': studentId,
      'studentName': studentName,
      'status': WaitlistStatus.waiting.name,
      'addedAt': addedAt,
    };
  }
}

/// بناء طلب انتظار من بيانات المجموعة والطالب الحالي.
GroupWaitlistEntry buildWaitlistEntry({
  required StudyGroup group,
  required String studentId,
  required String studentName,
  DateTime? addedAt,
}) {
  return GroupWaitlistEntry(
    id: GroupWaitlistEntry.idFor(groupId: group.id, studentId: studentId),
    groupId: group.id,
    groupTitle: group.title,
    teacherId: group.teacherId,
    studentId: studentId,
    studentName: studentName,
    status: WaitlistStatus.waiting,
    addedAt: addedAt ?? DateTime.now(),
  );
}
