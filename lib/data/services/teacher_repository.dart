import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// عقد قراءة ملفات المدرسين.
///
/// التنفيذ الحقيقي (Phase 5–6) سيستعلم Firestore بشرطين: الملف معتمد،
/// والاستعلام مقسّم إلى صفحات (pagination) مع فهارس مناسبة.
abstract interface class TeacherRepository {
  /// المدرسون المعتمدون فقط.
  Future<List<TeacherProfile>> listApproved();

  /// المدرسون المميزون (قسم مستقل عن نتائج البحث العادي — C-14).
  ///
  /// ⚠️ آلية اختيار المميزين لم تُحسم (Q-01..Q-03)؛ نعرض الحقل فقط.
  Future<List<TeacherProfile>> listFeatured();

  /// ملف مدرس واحد بالمعرّف.
  ///
  /// يعيد `null` إن لم يوجد أو لم يكن معتمدًا؛ لا نكشف وجود ملف قيد المراجعة
  /// للطلاب (C-06). الشاشة تُترجم `null` إلى حالة «الملف غير موجود».
  Future<TeacherProfile?> findById(String id);
}
