/// استخراج ملفات المدرسين انطلاقًا من المجموعات الظاهرة — منطق نقي (P29).
///
/// ## لماذا؟
///
/// صفحة المدرسين فارغة عمليًا لأن كل الاستعلامات تفلتر
/// `where('accountHidden', '==', false)` و**غياب الحقل ≠ false** في Firestore،
/// بينما الاستعلام «الواسع» بلا شرط الحقل ترفضه القواعد كاملًا في الإنتاج
/// («القواعد ليست فلترًا»). فلم يبقَ من طريق يقرأه الطالب إلا ما يعرفه:
///
/// - `studyGroups` مقروءة له (شرط `isActive == true`) — وهي تُعرض في تبويب
///   المجموعات بأسماء المدرسين وشارة توثيقهم، أي أن **القراءة المباشرة** لملف
///   المدرّس تعمل.
/// - فنجمع `teacherId` من تلك المجموعات، ونقرأ كل ملف بالمعرّف، ثم ندمجه في
///   قائمة المدرسين.
///
/// هذا الملف يحتوي الجزء القابل للاختبار بلا Firebase: جمع المعرّفات (بلا تكرار،
/// وبسقف)، وحلّها مع تجاهل الفشل الفردي. الربط بـFirestore في
/// `FirestoreTeacherRepository._teachersFromVisibleGroups`.
///
/// **حدّ معروف:** مدرّس موثّق بلا مجموعة ظاهرة لا يمكن الوصول إليه من العميل
/// قبل ترحيل البيانات (`docs/P29_MIGRATION.md`).
library;

abstract final class GroupTeacherDiscovery {
  /// سقف عدد الملفات المقروءة في التحديث الواحد.
  ///
  /// غرضه منع تكلفة غير متوقعة لو كبر عدد المجموعات؛ والمجموعات الظاهرة في هذا
  /// التطبيق أعدادها صغيرة.
  static const int defaultMax = 80;

  /// معرّفات المدرسين في مستندات المجموعات، بترتيب الظهور وبلا تكرار.
  static List<String> teacherIds(
    Iterable<Map<String, Object?>> groups, {
    int max = defaultMax,
  }) {
    final List<String> ids = <String>[];
    final Set<String> seen = <String>{};
    for (final Map<String, Object?> group in groups) {
      final Object? raw = group['teacherId'];
      final String id = raw is String ? raw.trim() : '';
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      ids.add(id);
      if (ids.length >= max) {
        break;
      }
    }
    return ids;
  }

  /// يحلّ كل معرّف إلى ملفه عبر [load]، ويتجاهل ما فشل أو لم يُقبل.
  ///
  /// - [load] قراءة مباشرة للملف؛ تُرفع استثناءاتها لكل معرّف على حدة فيُتجاهل
  ///   هو وحده (حساب مخفي/محذوف/غير موثّق) ولا تسقط القائمة كلها.
  /// - [isAcceptable] مرشّح نهائي (مثل: الحالة `verified` والفلتر المحلي).
  static Future<List<T>> resolve<T>(
    List<String> ids, {
    required Future<T?> Function(String id) load,
    bool Function(T value)? isAcceptable,
  }) async {
    final List<T> resolved = <T>[];
    for (final String id in ids) {
      try {
        final T? value = await load(id);
        if (value == null) {
          continue;
        }
        if (isAcceptable != null && !isAcceptable(value)) {
          continue;
        }
        resolved.add(value);
      } on Object {
        // ملف واحد غير مقروء لا يُفشل الصفحة.
        continue;
      }
    }
    return resolved;
  }
}
