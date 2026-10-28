import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';

/// عقد تقييمات المدرسين (P13).
///
/// **الكتابة مرة واحدة:** لا يوجد في هذا العقد `update` ولا `delete`. التقييم
/// يُكتب بعد حصة منفّذة ويبقى؛ تعديله أو حذفه من التطبيق غير متاح (القواعد
/// ترفضهما أيضًا). سبب ذلك أن التقييم دليل على حصة عُقدت، لا رأيًا قابلًا
/// للمحو كلما تغيّر المزاج.
///
/// **المتوسط ليس رقمًا يكتبه العميل:** [submit] يكتب التقييم وتراكم المتوسط في
/// **كتابة ذرّية واحدة**، و`firestore.rules` تقارن الزيادة بتقييم التقييم نفسه،
/// فلا يمكن نفخ المتوسط بلا تقييم حقيقي (A-85).
abstract interface class ReviewRepository {
  /// تقييمات مدرس واحد — الأحدث أولًا.
  Future<List<TeacherReview>> listForTeacher(String teacherId);

  /// نفس القائمة كتدفّق (تحديث شاشة الملف عند وصول تقييم جديد).
  Stream<List<TeacherReview>> watchForTeacher(String teacherId);

  /// المتوسط التراكمي كما يحسبه الخادم (مجموع + عدد).
  Future<TeacherRating> ratingFor(String teacherId);

  /// المتوسط كتدفّق — لعرضه حيًا في ملف المدرس.
  Stream<TeacherRating> watchRating(String teacherId);

  /// تقييم الحجز إن وُجد.
  ///
  /// يُستخدم في الواجهة لمعرفة أن الحصة قُيِّمت (فتظهر «تقييمك» بدل زر
  /// التقييم)، ولأن معرّف التقييم = معرّف الحجز فلا حاجة إلى استعلام.
  Future<TeacherReview?> findForBooking(String bookingId);

  /// ينشئ تقييمًا بعد حصة منفّذة، ويحدّث المتوسط معه.
  ///
  /// يرفض مبكرًا (برسالة عربية) إن لم تنطبق G7 أو كان التقييم مكرّرًا؛
  /// والرفض النهائي يبقى للقواعد.
  ///
  /// [studentName] يُنسخ من الحجز عند الكتابة لتطابقه القواعد.
  Future<TeacherReview> submit({
    required BookingRequest booking,
    required String studentId,
    required String studentName,
    required int rating,
    String? comment,
  });
}
