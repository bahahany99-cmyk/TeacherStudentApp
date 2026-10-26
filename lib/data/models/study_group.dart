/// طريقة الحضور في المجموعة الدراسية.
enum GroupMeetingMode {
  online,
  home,
  center;

  String get label => switch (this) {
    GroupMeetingMode.online => 'أونلاين',
    GroupMeetingMode.home => 'في المنزل',
    GroupMeetingMode.center => 'سنتر',
  };
}

/// مجموعة دراسية تتبع مدرسًا واحدًا.
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.title,
    required this.subject,
    required this.stage,
    required this.seatsTotal,
    required this.seatsTaken,
    required this.meetingMode,
    this.scheduleNote,
  });

  final String id;
  final String teacherId;
  final String teacherName;
  final String title;
  final String subject;
  final String stage;
  final int seatsTotal;
  final int seatsTaken;
  final GroupMeetingMode meetingMode;

  /// وصف نصي مؤقت للموعد (الجدولة الحقيقية مؤجلة - Q-13).
  final String? scheduleNote;

  /// عدد المقاعد المتاحة (لا يقل عن صفر).
  ///
  /// ⚠️ هذا حساب عرض فقط. منع تجاوز السعة يُفرض على الخادم بعملية ذرية عند
  /// الموافقة على طلب الانضمام (Phase 8)، لا في التطبيق.
  int get seatsAvailable => seatsTotal - seatsTaken > 0 ? seatsTotal - seatsTaken : 0;

  bool get isFull => seatsAvailable == 0;
}
