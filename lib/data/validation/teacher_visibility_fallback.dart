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
/// ## السياسة
///
/// 1. **الاستعلام الصارم أولًا** (بشرط `accountHidden == false`): إن أعاد
///    نتيجة، انتهى الأمر — لا استعلام إضافي، ولا تكلفة قراءة إضافية.
/// 2. **فارغ ⇒ استعلام واسع** بلا شرط `accountHidden`، فيلتقط المستندات التي
///    تنقصها القيمة. لا يُعرض منه إلا ما تسمح به القواعد، تمامًا كأي قراءة.
/// 3. **الاستعلام الواسع مرفوض (`permission-denied`)** ⇒ قد يعيد مستندًا لا
///    تسمح به القواعد، فترفضه القواعد كاملًا. نُعيد نتيجة الاستعلام الصارم بدل
///    إفشال الشاشة: المستخدم يرى ما يُسمح به، لا خطأ تقنيًا بسبب حالة بيانات
///    قديمة. (بعض النُّسخ تُصفّي المستندات غير المسموحة وتُنجح الاستعلام؛
///    الحالتان مقبولتان لأن الحساب المخفي لا يصل إلى الواجهة في أي منهما —
///    مُثبت في `tool/rules_tests`.)
/// 4. أي خطأ آخر (شبكة، مهلة) **يُعاد رفعه** — لا نُحوّل عطلًا إلى «لا نتائج».
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

  /// يُسقط ما وسمه صاحبه/المسؤول بالإخفاء من نتيجة استعلام.
  ///
  /// **لماذا نُصفّي في العميل بعد الاستعلام؟** لأن أمان الاكتشاف لا يجوز أن
  /// يعتمد على تصفية الخادم وحدها: الواجهة البرمجية لـFirestore قد تُرفض
  /// الاستعلام كاملًا عند وجود مستند غير مسموح (السلوك الموثّق في الإنتاج)،
  /// وقد تُعيده في بيئات أخرى — وقد رصدنا ذلك فعليًا على محاكي القواعد في CI
  /// (اختبار `(P29) الحساب المخفي` في `tool/rules_tests`). التصفية هنا تجعل
  /// «الحساب المخفي لا يظهر» صحيحًا في كل الحالات، بلا تعديل قواعد.
  static List<T> filterVisible<T>(
    Iterable<T> items,
    Map<String, Object?> Function(T item) dataOf,
  ) {
    return <T>[
      for (final T item in items)
        if (!isExplicitlyHidden(dataOf(item))) item,
    ];
  }

  /// يُنفّذ [strict]، ولا ينتقل إلى [broad] إلا إذا كان [strict] فارغًا.
  ///
  /// [isEmpty] ما الذي يعتبر «لا نتيجة» (في Firestore: `docs.isEmpty`).
  /// [isPermissionDenied] هل هذا الخطأ رفضٌ من القواعد؟
  static Future<T> resolve<T>({
    required Future<T> Function() strict,
    required Future<T> Function() broad,
    required bool Function(T value) isEmpty,
    required bool Function(Object error) isPermissionDenied,
  }) async {
    final T strictResult = await strict();
    if (!isEmpty(strictResult)) {
      return strictResult;
    }
    try {
      return await broad();
    } on Object catch (error) {
      if (isPermissionDenied(error)) {
        return strictResult;
      }
      rethrow;
    }
  }
}
