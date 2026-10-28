import 'package:teacher_student_app/data/models/content_report.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';

/// عقد «لوحة الإدارة» (P14): طابور التوثيق والمراجعة.
///
/// **حدود صريحة:** هذا العقد **لا يمنح** صلاحية. كل دالة هنا تقابل كتابة في
/// `firestore.rules` مشروطة بـ`request.auth.token.admin == true`؛ فإن استُدعي
/// من حساب عادي رفض الخادم الطلب ورمى المستودع خطأ عربيًا
/// ([AppErrorKind.permission]). الواجهة تُخفي الشاشات، والقواعد تمنع الفعل.
///
/// **القراءة** لا تحتاج البحث في كل المجموعات: الطابور استعلام واحد على
/// `teacherProfiles` بحالة غير نهائية، والمراجعة استعلام على `contentReports`
/// المفتوحة، والقرار كتابة واحدة.
abstract interface class AdminRepository {
  /// ملفات المدرسين التي تنتظر قرارًا (`draft` + `pendingReview`) — الأقدم أولًا.
  ///
  /// الترتيب يجري على العميل لتفادي فهرس مركّب (A-89)، والعدد المتوقع صغير
  /// في هذا الحجم من التطبيق.
  Future<List<TeacherProfile>> listVerificationQueue();

  /// كل ملفات المدرسين (بما فيها الموثّقة والمرفوضة) — نظرة عامة للإدارة.
  Future<List<TeacherProfile>> listAllProfiles();

  /// يعتمد الملف: `pendingReview`/`draft` ← `verified`.
  ///
  /// بعد الاعتماد يصبح الملف مقروءًا للطلاب في البحث (القاعدة تقرأ الحالة
  /// من المستند نفسه لحظة القراءة، فلا حاجة لأي مزامنة).
  Future<void> verifyTeacher(String teacherId);

  /// يرفض الملف بسبب مكتوب: `← rejected` + [reason].
  ///
  /// السبب إلزامي: الرفض بلا تفسير لا يفيد المدرس ولا يُراجع لاحقًا.
  Future<void> rejectTeacher({
    required String teacherId,
    required String reason,
  });

  /// البلاغات المفتوحة — الأحدث أولًا.
  Future<List<ContentReport>> listOpenReports();

  /// أحدث التقييمات (للمراجعة المباشرة قبل ورود بلاغ).
  Future<List<TeacherReview>> listRecentReviews({int limit});

  /// يحسم بلاغًا: [ReportResolution.resolved] أو [ReportResolution.dismissed]
  /// مع ملاحظة اختيارية.
  Future<void> resolveReport({
    required String reportId,
    required ReportResolution resolution,
    String? note,
  });

  /// يحذف تقييمًا مخالفًا (إجراء المراجعة الوحيد على المحتوى في هذه المرحلة).
  ///
  /// الحذف إداري فقط في القواعد، ويُنقص التجميع (المجموع والعدد) في **نفس
  /// الكتابة الذرّية** حتى لا يبقى متوسط يقيس تقييمًا محذوفًا (A-90).
  Future<void> deleteReview(String reviewId);
}
