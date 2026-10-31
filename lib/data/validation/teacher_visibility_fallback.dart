/// سياسة «الحقل الغائب يعني ظاهرًا» — منطق نقي قابل للاختبار (P29).
///
/// ## المشكلة
///
/// استعلامات الاكتشاف تفلتر بمساواة صريحة:
/// `where('accountHidden', '==', false)`، وفي Firestore **غياب الحقل ≠ false**.
/// فمستند موثّق أُنشئ خارج مسار التطبيق (وحدة تحكّم/استيراد/قبل P17) يُقرأ
/// بالمعرّف (القواعد تستخدم `get('accountHidden', false)`) لكنه **غائب عن كل
/// قائمة**: صفحة المدرسين، والمميزون، وخيارات المحافظات (مصدرها نفس الاستعلام).
///
/// ## السياسة: دمج لا «احتياطي عند الفراغ»
///
/// المحاولة الأولى كانت: «إن كان الاستعلام الصارم فارغًا فجرّب الواسع». وهي
/// **ناقصة**: يكفي أن يوجد ملف واحد بـ`accountHidden: false` ليعود الاستعلام
/// الصارم غير فارغ، فيبقى كل ملف قديم غائبًا — وهذا ما يظهر عمليًا عند البحث
/// عن اسم مثل «Shady»: لا نتيجة، مع أن الملف موجود.
///
/// لذلك نُدمج النتيجتين دائمًا:
///
/// 1. **الصارم**: `status == verified` + `accountHidden == false`.
/// 2. **الواسع**: `status == verified` فقط — يلتقط ما ينقصه الحقل. يُجرَّب
///    دائمًا لأنه الطريق الوحيد لمعرفة وجود تلك المستندات (لا يمكن لفلتر
///    المساواة أن يطابق حقلًا غائبًا).
/// 3. **الدمج**: بالمعرّف، والأولوية للصارم (نتيجته مطابقة بالتعريف)، ثم ما
///    يعود من الواسع **بعد إسقاط** كل مستند `accountHidden: true`.
/// 4. **الواسع أفضل جهد**: إن رفضته القواعد (`permission-denied`) أو فشل
///    لأي سبب، نُكمل بنتيجة الصارم بلا إفشال الشاشة. أما فشل **الصارم** فيُرفع
///    كما هو — لا نُحوّل عطلًا إلى «لا نتائج».
///
/// ## الأمان: لا نثق في تصفية الخادم وحدها
///
/// قراءة الحساب المخفي بالمعرّف مرفوضة بقواعد Firestore، لكن **نتائج
/// الاستعلام** لا تُضمن تصفيتها في كل بيئة: رصدنا على محاكي القواعد في CI أن
/// الاستعلام الواسع يعيد مستندًا موثّقًا مخفيًا مع رفض قراءته المباشرة. لذا
/// تُسقط التصفية هنا (`isExplicitlyHidden`) كل مستند موسوم بالإخفاء **مهما
/// أعاد الخادم**، بلا أي تعديل على `firestore.rules`.
///
/// المنطق هنا لا يعرف Firebase: يأخذ دوالًا ويُختبر بمصادر وهمية حتمية.
library;

abstract final class TeacherVisibilityFallback {
  /// هل المستند **موسوم صراحةً** بالإخفاء؟
  ///
  /// الغياب أو `null` يعني ظاهرًا (توافقًا مع القواعد والمُحوِّل)، ولا يسقط
  /// إلا `true` الصريحة.
  static bool isExplicitlyHidden(Map<String, Object?> data) =>
      data['accountHidden'] == true;

  /// يُدمج نتيجة الاستعلام الصارم مع الواسع (أولوية الصارم، بلا تكرار).
  ///
  /// - [idOf]: مفتاح الدمج (معرّف المستند).
  /// - [isHidden]: هل يجب إسقاط العنصر القادم من الواسع؟
  /// - [broadErrorIsFatal]: `false` (الافتراضي) يجعل أخطاء الواسع تُبتلع، لأن
  ///   الواسع مكسب إضافي لا أساس. اجعلها `true` لو كان الفشل الصامت غير مقبول.
  ///
  /// أخطاء [strict] تُرفع دائمًا.
  static Future<List<T>> resolveMerged<T>({
    required Future<List<T>> Function() strict,
    required Future<List<T>> Function() broad,
    required String Function(T item) idOf,
    required bool Function(T item) isHidden,
    bool broadErrorIsFatal = false,
  }) async {
    final List<T> strictItems = await strict();

    List<T> broadItems;
    try {
      broadItems = await broad();
    } on Object {
      if (broadErrorIsFatal) {
        rethrow;
      }
      broadItems = const <T>[];
    }

    final Set<String> seen = <String>{};
    final List<T> merged = <T>[];
    for (final T item in strictItems) {
      if (seen.add(idOf(item))) {
        merged.add(item);
      }
    }
    for (final T item in broadItems) {
      // الحساب المخفي لا يدخل القائمة حتى لو أعاده الخادم في الاستعلام الواسع.
      if (isHidden(item)) {
        continue;
      }
      if (seen.add(idOf(item))) {
        merged.add(item);
      }
    }
    return merged;
  }
}
