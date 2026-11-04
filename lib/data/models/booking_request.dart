/// حالة طلب الحجز (P10).
///
/// القيم النصية (`name`) هي **نفس** القيم المسموح بها في `firestore.rules`؛
/// تغيير أي اسم هنا يوجب تغييره هناك، واختبارات المحاكي تكشف التباعد.
///
/// دورة الحياة (A-75):
/// ```
/// pending ──accept──▶ accepted ──complete──▶ completed
///    │                   │
///    │                   ├─cancel──▶ cancelled / cancelledLate
///    │                   └─rescheduleProposed ──▶ accepted | cancelled
///    ├─reject──▶ rejected
///    ├─cancel──▶ cancelled
///    └─rescheduleProposed ──▶ accepted | cancelled | rejected
/// ```
/// كل حالة نهائية بعد `rejected`/`completed`/`cancelled`/`cancelledLate`؛
/// الانتقالات تُفحص في الطبقة الوسطى **وفي القواعد**.
enum BookingStatus {
  /// بانتظار قرار المدرس. لا يشغل وقتًا في تقويم المدرس.
  pending('بانتظار موافقة المدرس'),

  /// مؤكد ويشغل وقته فعلًا.
  accepted('مؤكد'),

  /// رفضه المدرس.
  rejected('مرفوض'),

  /// ملغى قبل الموعد بمهلة كافية.
  cancelled('ملغى'),

  /// ملغى داخل مهلة الإلغاء (12 ساعة قبل الموعد).
  cancelledLate('ملغى متأخرًا'),

  /// أحد الطرفين اقترح وقتًا بديلًا، والآخر يقرّر.
  rescheduleProposed('وقت بديل مقترح'),

  /// أعلنه المدرس بعد انتهاء الموعد.
  completed('منفّذ');

  const BookingStatus(this.label);

  /// نص العرض العربي.
  final String label;

  bool get isPending => this == BookingStatus.pending;
  bool get isAccepted => this == BookingStatus.accepted;
  bool get isReschedule => this == BookingStatus.rescheduleProposed;

  /// حالة نهائية لا انتقال بعدها.
  bool get isTerminal =>
      this == BookingStatus.rejected ||
      this == BookingStatus.completed ||
      this == BookingStatus.cancelled ||
      this == BookingStatus.cancelledLate;

  /// ملغى بأي صيغة (يُستخدم في العرض والفلترة).
  bool get isCancelled =>
      this == BookingStatus.cancelled || this == BookingStatus.cancelledLate;

  /// يشغل وقتًا في تقويم المدرس.
  bool get holdsSlot => this == BookingStatus.accepted;

  /// يحق للطرفين إلغاؤه الآن.
  bool get canCancel =>
      this == BookingStatus.pending ||
      this == BookingStatus.accepted ||
      this == BookingStatus.rescheduleProposed;

  /// تحويل نصي متسامح. أي قيمة غير معروفة تُقرأ `pending` (الأسلم للعرض: لا
  /// ندّعي تأكيدًا ولا إلغاءً على بيانات لا نفهمها).
  static BookingStatus parse(Object? raw) {
    return switch (raw) {
      'accepted' => BookingStatus.accepted,
      'rejected' => BookingStatus.rejected,
      'cancelled' => BookingStatus.cancelled,
      'cancelledLate' => BookingStatus.cancelledLate,
      'rescheduleProposed' => BookingStatus.rescheduleProposed,
      'completed' => BookingStatus.completed,
      _ => BookingStatus.pending,
    };
  }
}

/// من اقترح الوقت البديل.
enum BookingActor {
  teacher,
  student;

  String get label => switch (this) {
    BookingActor.teacher => 'المدرس',
    BookingActor.student => 'الطالب',
  };

  static BookingActor parse(Object? raw) =>
      raw == 'student' ? BookingActor.student : BookingActor.teacher;
}

/// طلب حجز درس بين طالب ومدرس (P10).
///
/// **الموعد جزء من الطلب نفسه** (A-74): `dateKey` + `startMinutes` +
/// `durationMinutes`، ويُشتق منهما `startsAt`/`endsAt`. لا يوجد محرّك توفّر في
/// هذه المرحلة: الطالب يقترح وقتًا والمدرس يقبل أو يرفض أو يقترح بديلًا.
///
/// **لماذا `dateKey` نصي؟** لأن «اليوم» عند المدرس مفهوم تقويمي محلي لا لحظة
/// زمنية؛ تخزينه كـ`yyyy-MM-dd` يجعل التجميع اليومي للتقويم مباشرًا، ويجنّب
/// أخطاء المناطق الزمنية عند حساب الليل والنهار.
class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.teacherName,
    required this.studentName,
    this.teacherId,
    this.studentId,
    required this.subject,
    required this.requestedAt,
    required this.status,
    this.note,
    this.dateKey,
    this.startMinutes,
    this.durationMinutes,
    this.decidedAt,
    this.decidedBy,
    this.cancelledAt,
    this.cancelledBy,
    this.proposalDateKey,
    this.proposalStartMinutes,
    this.proposedBy,
    this.proposedAt,
  });

  final String id;
  final String teacherName;
  final String studentName;

  /// معرّفات الأطراف — لازمة للاستعلامات وللقواعد.
  ///
  /// اختيارية لأن البيانات التجريبية بُنيت قبل المصادقة؛ أي طلب من Firestore
  /// يحملها دائمًا.
  final String? teacherId;
  final String? studentId;
  final String subject;

  /// لحظة إنشاء الطلب.
  final DateTime requestedAt;

  final BookingStatus status;
  final String? note;

  /// اليوم المتفق عليه/المقترح بصيغة `yyyy-MM-dd`.
  final String? dateKey;

  /// بداية الحصة بالدقائق من منتصف الليل.
  final int? startMinutes;

  /// مدة الحصة بالدقائق.
  final int? durationMinutes;

  final DateTime? decidedAt;
  final String? decidedBy;
  final DateTime? cancelledAt;
  final String? cancelledBy;

  /// وقت بديل مقترح (يُملأ فقط في حالة [BookingStatus.rescheduleProposed]).
  final String? proposalDateKey;
  final int? proposalStartMinutes;
  final BookingActor? proposedBy;
  final DateTime? proposedAt;

  /// هل الطلب يحمل موعدًا صالحًا للعرض؟
  bool get hasSchedule => dateKey != null && startMinutes != null;

  /// بداية الحصة كلحظة زمنية (أو `null` إن لم يُحدَّد موعد).
  DateTime? get startsAt => BookingRulesLite.startOf(dateKey, startMinutes);

  /// نهاية الحصة.
  DateTime? get endsAt {
    final DateTime? start = startsAt;
    final int? duration = durationMinutes;
    if (start == null || duration == null) {
      return null;
    }
    return start.add(Duration(minutes: duration));
  }

  /// بداية الوقت البديل المقترح.
  DateTime? get proposedStartsAt =>
      BookingRulesLite.startOf(proposalDateKey, proposalStartMinutes);

  bool get waitingForTeacher => status.isPending;

  /// نسخة معدّلة — تُستخدم في المستودع التجريبي وفي تحديثات المعاملة.
  BookingRequest copyWith({
    BookingStatus? status,
    String? dateKey,
    int? startMinutes,
    int? durationMinutes,
    DateTime? decidedAt,
    String? decidedBy,
    DateTime? cancelledAt,
    String? cancelledBy,
    String? proposalDateKey,
    int? proposalStartMinutes,
    BookingActor? proposedBy,
    DateTime? proposedAt,
    String? note,
  }) {
    return BookingRequest(
      id: id,
      teacherName: teacherName,
      studentName: studentName,
      teacherId: teacherId,
      studentId: studentId,
      subject: subject,
      requestedAt: requestedAt,
      status: status ?? this.status,
      note: note ?? this.note,
      dateKey: dateKey ?? this.dateKey,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      decidedAt: decidedAt ?? this.decidedAt,
      decidedBy: decidedBy ?? this.decidedBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      proposalDateKey: proposalDateKey ?? this.proposalDateKey,
      proposalStartMinutes: proposalStartMinutes ?? this.proposalStartMinutes,
      proposedBy: proposedBy ?? this.proposedBy,
      proposedAt: proposedAt ?? this.proposedAt,
    );
  }

  /// نسخة بعد **قبول اقتراح إعادة الجدولة**: الوقت المقترح يصبح هو الموعد،
  /// ويُمسح الاقتراح. كتابتها هنا تمنع تكرار المنطق في المستودعين.
  BookingRequest applyingProposal(DateTime decidedAt, String decidedBy) {
    return BookingRequest(
      id: id,
      teacherName: teacherName,
      studentName: studentName,
      teacherId: teacherId,
      studentId: studentId,
      subject: subject,
      requestedAt: requestedAt,
      status: BookingStatus.accepted,
      note: note,
      dateKey: proposalDateKey ?? dateKey,
      startMinutes: proposalStartMinutes ?? startMinutes,
      durationMinutes: durationMinutes,
      decidedAt: decidedAt,
      decidedBy: decidedBy,
      cancelledAt: cancelledAt,
      cancelledBy: cancelledBy,
    );
  }

  /// هل يتقاطع هذا الطلب مع فترة أخرى؟ (يتجاهل الملغى والمرفوض.)
  bool overlapsWith(DateTime start, DateTime end) {
    final DateTime? myStart = startsAt;
    final DateTime? myEnd = endsAt;
    if (myStart == null || myEnd == null) {
      return false;
    }
    return myStart.isBefore(end) && start.isBefore(myEnd);
  }
}

/// أدوات وقت صغيرة خاصة بنموذج الحجز (بلا اعتماد على طبقة التحقق).
///
/// موجودة هنا لتفادي استيراد دائري: النموذج يحتاج تحويل
/// `dateKey + startMinutes` إلى لحظة، و`BookingRules` تحتاج النموذج نفسه.
abstract final class BookingRulesLite {
  /// `yyyy-MM-dd` + دقائق ⇒ لحظة محلية.
  static DateTime? startOf(String? dateKey, int? startMinutes) {
    if (dateKey == null || startMinutes == null) {
      return null;
    }
    final List<String> parts = dateKey.split('-');
    if (parts.length != 3) {
      return null;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day).add(Duration(minutes: startMinutes));
  }

  /// لحظة ⇒ `yyyy-MM-dd`.
  static String keyOf(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// دقائق من منتصف الليل لهذه اللحظة.
  static int minutesOf(DateTime value) => value.hour * 60 + value.minute;
}
