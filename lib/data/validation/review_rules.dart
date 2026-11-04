import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';

/// قواعد التقييم وبوابة الأهلية G7 (P13).
///
/// **لماذا هنا لا في القواعد فقط؟** لأن القواعد تحمي البيانات، وهذه تحمي
/// **التجربة**: تشرح للمستخدم بالعربية لماذا لا يستطيع التقييم الآن، بدل رسالة
/// رفض غامضة من الخادم. والتقييم النهائي يبقى للقواعد، فهي وحدها لا تُخدع.
///
/// **G7:** الأهلية = وجود حجز **منفّذ** (`completed`) بين الطالب والمدرس. لا
/// يكفي حجز مؤكد (لم تُعطَ الحصة بعد)، ولا ملغى، ولا حجز معلّق.
abstract final class ReviewRules {
  static const int minStars = 1;
  static const int maxStars = 5;

  /// حدّ التعليق — مطابق للحدّ في `firestore.rules`.
  static const int maxCommentLength = 400;

  /// حدّ اسم الكاتب — يُنسخ من الحجز، والقواعد تقارنه به.
  static const int maxStudentNameLength = 80;

  /// تنظيف النص: بلا أطراف فارغة، وبلا فراغات مكرّرة (نفس أسلوب بقية النماذج).
  static String normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  /// مشكلة التعليق، أو `null` إن كان صالحًا (التعليق اختياري).
  static String? commentProblem(String? comment) {
    if (comment == null) {
      return null;
    }
    final String clean = normalize(comment);
    if (clean.isEmpty) {
      return null;
    }
    if (clean.length > maxCommentLength) {
      return 'التعليق طويل جدًا؛ الحد الأقصى $maxCommentLength حرفًا.';
    }
    return null;
  }

  /// مشكلة التقييم، أو `null` إن كان صالحًا.
  static String? ratingProblem(int? rating) {
    if (rating == null) {
      return 'اختر عدد النجوم أولًا.';
    }
    if (rating < minStars || rating > maxStars) {
      return 'التقييم من $minStars إلى $maxStars نجوم.';
    }
    return null;
  }

  /// **بوابة G7** — سبب منع تقييم هذا الحجز، أو `null` إن كان مسموحًا.
  ///
  /// [alreadyReviewed] تُقرأ من المستودع (تقييم قائم لهذا الحجز) لأن القواعد
  /// تعالج التكرار بنيويًا، أما الواجهة فتحتاج أن تعرف قبل عرض الزر.
  static String? eligibilityProblem({
    required BookingRequest booking,
    required String studentId,
    required bool alreadyReviewed,
  }) {
    if (studentId.trim().isEmpty) {
      return 'لا يمكن تحديد الطالب الحالي.';
    }
    if (booking.studentId != null && booking.studentId != studentId) {
      return 'هذا الحجز ليس لك؛ لا يمكنك تقييمه.';
    }
    if (booking.status != BookingStatus.completed) {
      return switch (booking.status) {
        BookingStatus.accepted =>
          'لا يمكن التقييم قبل انتهاء الحصة وإعلان تنفيذها.',
        BookingStatus.pending => 'الطلب لم يُقبل بعد؛ لا يوجد ما يُقيَّم.',
        BookingStatus.rescheduleProposed => 'الموعد ما زال قيد التنسيق.',
        BookingStatus.rejected => 'لم تُعقد الحصة، فلا يوجد تقييم.',
        BookingStatus.cancelled || BookingStatus.cancelledLate =>
          'أُلغي الموعد، ولا يُقيَّم ما لم يُنفَّذ.',
        BookingStatus.completed => 'الحصة منفّذة.',
      };
    }
    if (alreadyReviewed) {
      return 'قيّمت هذه الحصة بالفعل؛ التقييم يُكتب مرة واحدة.';
    }
    return null;
  }

  static bool canReview({
    required BookingRequest booking,
    required String studentId,
    required bool alreadyReviewed,
  }) =>
      eligibilityProblem(
        booking: booking,
        studentId: studentId,
        alreadyReviewed: alreadyReviewed,
      ) ==
      null;

  /// أحدث التقييمات أولًا (الترتيب على العميل — نفس سياسة بقية القوائم).
  static List<TeacherReview> newestFirst(List<TeacherReview> reviews) {
    final List<TeacherReview> sorted = <TeacherReview>[...reviews];
    sorted.sort((TeacherReview a, TeacherReview b) {
      final int byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : a.bookingId.compareTo(b.bookingId);
    });
    return List<TeacherReview>.unmodifiable(sorted);
  }
}
