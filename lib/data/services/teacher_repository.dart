import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// عقد قراءة ملفات المدرسين.
///
/// التنفيذ الحقيقي (Phase 5–6) سيستعلم Firestore بشرطين: الملف معتمد،
/// والاستعلام مقسّم إلى صفحات (pagination) مع فهارس مناسبة.
abstract interface class TeacherRepository {
  /// المدرسون **الموثّقون** فقط (P14: التوثيق بديل «الاعتماد» القديم).
  Future<List<TeacherProfile>> listVerified();

  /// المدرسون المميزون (قسم مستقل عن نتائج البحث العادي — C-14).
  ///
  /// (P15) الترتيب حتمي: `featuredOrder` ثم التقييم ثم الاسم — انظر
  /// `TeacherDiscoveryRules.featured`. التمييز قرار إداري لا يكتبه المدرس.
  Future<List<TeacherProfile>> listFeatured();

  /// استكشاف المدرسين بفلتر (P15): بحث نصي + مادة/مرحلة + عن بُعد/حضوري
  /// بمحافظة. النتيجة تحمل إجمالي الموثّقين قبل فلاتر العميل.
  Future<TeacherSearchResult> search(TeacherFilter filter);

  /// ملف مدرس واحد بالمعرّف.
  ///
  /// يعيد `null` إن لم يوجد أو لم يكن معتمدًا؛ لا نكشف وجود ملف قيد المراجعة
  /// للطلاب (C-06). الشاشة تُترجم `null` إلى حالة «الملف غير موجود».
  Future<TeacherProfile?> findById(String id);
}
