/// حالة طلب الحجز.
///
/// الانتقالات المسموحة تُفرض على الخادم؛ هذه القائمة للعرض فقط.
enum BookingStatus {
  pending,
  accepted,
  rejected,
  cancelled,
  completed;

  String get label => switch (this) {
    BookingStatus.pending => 'بانتظار موافقة المدرس',
    BookingStatus.accepted => 'مقبول',
    BookingStatus.rejected => 'مرفوض',
    BookingStatus.cancelled => 'ملغى',
    BookingStatus.completed => 'منفّذ',
  };
}

/// طلب حجز درس بين طالب ومدرس.
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
  });

  final String id;
  final String teacherName;
  final String studentName;

  /// معرّفات الأطراف — لازمة لاستعلام «طلباتي» ولقواعد الأمان.
  ///
  /// اختيارية لأن البيانات التجريبية بُنيت قبل وجود المصادقة؛ أي طلب قادم من
  /// Firestore يحملها دائمًا.
  final String? teacherId;
  final String? studentId;
  final String subject;
  final DateTime requestedAt;
  final BookingStatus status;
  final String? note;

  bool get waitingForTeacher => status == BookingStatus.pending;
}
