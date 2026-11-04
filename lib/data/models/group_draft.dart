import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// مسودة إنشاء/تعديل مجموعة دراسية.
///
/// لماذا كائن مستقل بدل تمرير عشرة معاملات؟
/// - نفس الشكل يُستخدم في نموذج الواجهة، والتحقق، وكتابة Firestore، والتنفيذ
///   التجريبي ⇒ لا يختلف تنفيذ عن آخر في حقل منسي.
/// - `toFirestore` هي الخريطة الوحيدة المسموح بها في القواعد؛ أي مفتاح إضافي
///   يجعل الخادم يرفض الكتابة كاملة. هذا مقصود.
class GroupDraft {
  const GroupDraft({
    required this.title,
    required this.subject,
    required this.stage,
    required this.meetingMode,
    required this.seatsTotal,
    this.scheduleNote,
  });

  /// مسودة من مجموعة قائمة (وضع التعديل).
  factory GroupDraft.fromGroup(StudyGroup group) {
    return GroupDraft(
      title: group.title,
      subject: group.subject,
      stage: group.stage,
      meetingMode: group.meetingMode,
      seatsTotal: group.seatsTotal,
      scheduleNote: group.scheduleNote,
    );
  }

  final String title;
  final String subject;
  final String stage;
  final GroupMeetingMode meetingMode;
  final int seatsTotal;

  /// وصف نصي للموعد (الجدولة الحقيقية مؤجلة — Q-13).
  final String? scheduleNote;

  GroupDraft copyWith({
    String? title,
    String? subject,
    String? stage,
    GroupMeetingMode? meetingMode,
    int? seatsTotal,
    String? scheduleNote,
  }) {
    return GroupDraft(
      title: title ?? this.title,
      subject: subject ?? this.subject,
      stage: stage ?? this.stage,
      meetingMode: meetingMode ?? this.meetingMode,
      seatsTotal: seatsTotal ?? this.seatsTotal,
      scheduleNote: scheduleNote ?? this.scheduleNote,
    );
  }

  /// قيم نصية مطبَّعة (بلا مسافات طرفية، والفراغ = `null`).
  String get normalizedTitle => normalizeText(title) ?? '';
  String get normalizedSubject => normalizeText(subject) ?? '';
  String get normalizedStage => normalizeText(stage) ?? '';
  String? get normalizedScheduleNote => normalizeText(scheduleNote);

  /// خريطة الإنشاء — **الحقول المسموح بها في القواعد فقط**.
  ///
  /// `seatsTaken` تبدأ صفرًا دائمًا، و`isActive` صحيحة، والحقول الإدارية
  /// (`rating`… لا تخص المجموعة أصلًا) غير موجودة.
  Map<String, Object?> toCreateMap({
    required String teacherId,
    required String teacherName,
  }) {
    return <String, Object?>{
      'teacherId': teacherId,
      'teacherName': teacherName,
      'title': normalizedTitle,
      'subject': normalizedSubject,
      'stage': normalizedStage,
      'seatsTotal': seatsTotal,
      'seatsTaken': 0,
      'meetingMode': meetingMode.name,
      'isActive': true,
      if (normalizedScheduleNote != null)
        'scheduleNote': normalizedScheduleNote,
    };
  }

  /// خريطة التحديث — بلا `seatsTaken` وبلا `teacherId` (كلاهما غير قابل
  /// للتغيير من التطبيق؛ القواعد ترفض تغييرهما).
  Map<String, Object?> toUpdateMap({required bool isActive}) {
    return <String, Object?>{
      'title': normalizedTitle,
      'subject': normalizedSubject,
      'stage': normalizedStage,
      'seatsTotal': seatsTotal,
      'meetingMode': meetingMode.name,
      'isActive': isActive,
      // نص فارغ بدل null: القواعد تقارن المستند **بعد الدمج**، وnull يجعل
      // الحقل موجودًا بنوع غير نصي فيُرفض التعديل.
      'scheduleNote': normalizedScheduleNote ?? '',
    };
  }
}
