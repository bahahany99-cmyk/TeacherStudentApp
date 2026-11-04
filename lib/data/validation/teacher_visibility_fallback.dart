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
/// 5. **الطبقة الثالثة (المصدر العملي):** في الإنتاج ترفض القواعد الاستعلام
///    الواسع كاملًا لأنه قد يعيد مستندًا غير مسموح، فيبقى الفراغ. لذلك يجمع
///    `FirestoreTeacherRepository` معرّفات المدرسين من المجموعات الظاهرة
///    (`studyGroups` مقروءة للطلاب) ويقرأ كل ملف **بالمعرّف** — وهو المسار
///    الذي يعمل أصلًا (شارة التوثيق في بطاقة المجموعة) — ثم يدمجه هنا.
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

  /// هل يطابق الملف الخام شرط «الطريقة» الذي يفرضه استعلام Firestore؟
  ///
  /// [wantOnline] `null` تعني «بلا فلتر»، و`true`/`false` تعني مساواة صريحة على
  /// `isOnline` — والقيمة الغائبة لا تطابق (نفس سلوك فلتر المساواة في الخادم).
  ///
  /// تُستخدم للملفات المقروءة **بالمعرّف** (المشتقة من المجموعات) لأنها لم تمرّ
  /// بفلتر الخادم؛ بلا هذه المطابقة قد يعيد «حضوري فقط» مدرّسًا عن بُعد.
  static bool matchesOnlineFlag(Map<String, Object?> data, bool? wantOnline) {
    if (wantOnline == null) {
      return true;
    }
    return data['isOnline'] == wantOnline;
  }

  /// مطابقة المحافظة كما يفعل `where('governorate', '==', value)`.
  static bool matchesGovernorate(Map<String, Object?> data, String? want) =>
      want == null || data['governorate'] == want;

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
      broadItems = <T>[];
    }

    return mergeVisible<T>(
      primary: strictItems,
      extra: broadItems,
      idOf: idOf,
      isHidden: isHidden,
    );
  }

  /// الاستعلام المبسّط أولًا، ثم الصارم عند رفض القواعد (P29).
  ///
  /// **لماذا المبسّط أولًا؟** لأن أي شرط على `accountHidden` يستبعد الملفات التي
  /// تنقصها القيمة (غياب الحقل لا يطابق مساواة)، وهو أصل اختفاء المدرسين
  /// الموثّقين. الاستعلام المبسّط `status == verified` وحده يجلبها **إن سمحت
  /// القواعد** — والقواعد تسمح ما دام لا يوجد مستند مخفي في النتائج.
  ///
  /// فإذا رفضت القواعد الاستعلام المبسّط (`permission-denied`، أي أن بين
  /// الملفات ما هو مخفي)، نرجع إلى الاستعلام الصارم الذي يطابق الظاهر فقط.
  /// أي خطأ آخر يُرفع كما هو: الفشل لا يصبح «لا نتائج».
  static Future<List<T>> resolveSimplified<T>({
    required Future<List<T>> Function() simplified,
    required Future<List<T>> Function() strictFallback,
    required bool Function(Object error) isPermissionDenied,
  }) async {
    try {
      return await simplified();
    } on Object catch (error) {
      if (!isPermissionDenied(error)) {
        rethrow;
      }
      return strictFallback();
    }
  }

  /// دمج قائمتين بالمعرّف: [primary] أولًا (أولويتها في الترتيب)، ثم ما هو جديد
  /// في [extra]. أي عنصر [isHidden] يُسقط من [extra] ولا يدخل الناتج أبدًا.
  ///
  /// يُستخدم للمصادر الثلاثة: الصارم، ثم الواسع، ثم الملفات المقروءة بالمعرّف
  /// انطلاقًا من المجموعات الظاهرة (انظر `FirestoreTeacherRepository._visible`).
  static List<T> mergeVisible<T>({
    required List<T> primary,
    required List<T> extra,
    required String Function(T item) idOf,
    required bool Function(T item) isHidden,
  }) {
    final Set<String> seen = <String>{};
    final List<T> merged = <T>[];
    for (final T item in primary) {
      // حتى المصدر الأساسي يُصفّى: الاستعلام المبسّط بلا شرط الحقل يعيد
      // المستندات المخفية أيضًا، وهي يجب ألا تظهر مهما كان مصدرها.
      if (isHidden(item)) {
        continue;
      }
      if (seen.add(idOf(item))) {
        merged.add(item);
      }
    }
    for (final T item in extra) {
      // الحساب المخفي لا يدخل القائمة حتى لو أعاده الخادم.
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
