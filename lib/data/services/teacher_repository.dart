import 'package:teacher_student_app/data/models/teacher_filter.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/teacher_profile_draft.dart';

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

  /// **ملفي أنا** (P18): ملف المدرس الخاص بصاحب الجلسة، بأي حالة.
  ///
  /// يختلف عن [findById] جوهريًا: `findById` يُخفي غير الموثّق عن الطلاب، أما
  /// هنا فالقارئ هو صاحب الملف، وقواعد Firestore تسمح له بقراءته دائمًا
  /// (`isSelf(uid)`). لذلك يعيد المسودة والمرفوض أيضًا — وإلا لكان المدرس لا
  /// يستطيع رؤية ملفه بعد الرفض ليعرف السبب ويصحّحه.
  ///
  /// `null` تعني «لا ملف بعد» ⇒ الشاشة تعرض نموذج **الإنشاء**.
  Future<TeacherProfile?> findMine(String uid);

  /// إنشاء ملف المدرس أو تحديث حقوله الوصفية (P18).
  ///
  /// - **الإنشاء** (لا مستند): `status = pendingReview` و`ownerId = uid`
  ///   بانياً على `createdAt`، كما تفرض القاعدة `allow create`.
  /// - **التحديث**: الحقول الوصفية فقط، والحالة والمالك والحقول الإدارية تبقى
  ///   كما هي (**merge** لا استبدال كامل) — وهذا ما تقارنه القاعدة عبر
  ///   `unchangedAdminFields`.
  ///
  /// يعيد الملف بعد الكتابة، فتعرضه الشاشة من نفس المصدر بلا قراءة إضافية.
  Future<TeacherProfile> saveMyProfile({
    required String uid,
    required TeacherProfileDraft draft,
  });

  /// ملف مدرس واحد بالمعرّف.
  ///
  /// يعيد `null` إن لم يوجد أو لم يكن معتمدًا؛ لا نكشف وجود ملف قيد المراجعة
  /// للطلاب (C-06). الشاشة تُترجم `null` إلى حالة «الملف غير موجود».
  Future<TeacherProfile?> findById(String id);
}
