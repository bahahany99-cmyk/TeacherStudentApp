import 'package:teacher_student_app/data/models/booking_request.dart';

/// عقد قراءة طلبات الحجز.
///
/// التنفيذ الحقيقي (Phase 8): قواعد Firestore تمنع قراءة طلبات الآخرين،
/// وتغيير الحالة يحدث عبر Cloud Function متحقق منها.
abstract interface class BookingRepository {
  /// طلبات المستخدم الحالي (طالبًا كان أو مدرسًا).
  Future<List<BookingRequest>> listMine();
}
