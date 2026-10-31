/// ترحيل لمرة واحدة: إضافة `accountHidden: false` لملفات المدرسين التي تنقصها.
///
/// ## لماذا هذا الترحيل ضروري؟
///
/// كل استعلامات اكتشاف المدرسين تفلتر بمساواة صريحة:
///
/// ```dart
/// where('status', isEqualTo: 'verified')
///   .where('accountHidden', isEqualTo: false)
/// ```
///
/// وفي Firestore **غياب الحقل ≠ `false`**: مستند بلا `accountHidden` لا يطابق
/// فلتر المساواة، فلا يعود في نتيجة أي استعلام — مع أن قاعدة القراءة تسمح به
/// (`get('accountHidden', false) == false`) والمُحوِّل يعتبره ظاهرًا. النتيجة
/// التي رآها صاحب المشروع: مدرس **موثّق** تظهر مجموعته (استعلام آخر لا يفلتر
/// على هذا الحقل) وشارة توثيقه (قراءة مستند مباشرة)، بينما صفحة المدرسين تعرض
/// «لا نتائج»، وصفّ المحافظات يفرغ لأن مصدره نفس القائمة الفارغة.
///
/// ## قواعد الأمان (مفروضة في هذا الملف وفي السكربت)
///
/// 1. **لا يُلمس مستند يحمل الحقل أصلًا** — بأي قيمة، صحيحة أو خاطئة. الترحيل
///    لا يُصلح قيمًا ولا «يصحّح» قرارات إخفاء، ولا يعيد حسابًا أخفاه المسؤول.
/// 2. **لا حذف ولا تعديل لأي حقل آخر** — عملية الإضافة هي `accountHidden: false`
///    وحدها.
/// 3. **Dry Run هو الوضع الافتراضي** (`dryRun: true`) — يُعيد تقريرًا بعدد
///    المستندات التي **ستتغيّر** وبمعرّفاتها، ولا يكتب شيئًا.
/// 4. **التكرار آمن (idempotent):** تشغيله بعد نجاحه يعيد «0 مستندات» لأن
///    الجميع صار يحمل الحقل.
/// 5. **الفشل الجزئي لا يُسقط العملية:** كل مستند يُعالج وحده، وتُجمع الأخطاء
///    في التقرير ليعيد المستخدم المحاولة على ما تبقّى فقط.
///
/// ## أين يُنفَّذ؟
///
/// - **الإنتاج:** سكربت `tool/migrations/backfill_account_hidden.js` بـ
///   Firebase Admin SDK — يتجاوز قواعد الأمان بحساب خدمة (وهو الطريق الوحيد
///   الذي يعمل على ملفات فيها حقول لا تسمح القواعد بتحديثها كاملة، مثل
///   `isFeatured`). التفاصيل في `docs/P29_MIGRATION.md`.
/// - **الاختبار وما داخل التطبيق:** هذا الملف، عبر واجهة
///   [AccountHiddenBackfillGateway] — مُنفَّذها الحقيقي
///   `FirestoreAccountHiddenBackfill`، ويُختبر بمستودع وهمي حتمي.
library;

/// حالة علم الإخفاء في مستند مدرس واحد كما قرأه الترحيل.
class TeacherProfileFlagRecord {
  const TeacherProfileFlagRecord({
    required this.id,
    required this.hasAccountHiddenFlag,
  });

  /// معرّف المستند (هو `uid` صاحب الملف — القواعد تربط `teacherProfiles/{uid}`).
  final String id;

  /// هل الحقل **موجود** في المستند؟ القيمة نفسها لا تهم: الموجود لا يُلمس.
  final bool hasAccountHiddenFlag;
}

/// فشل تحديث مستند واحد (صلاحيات، شبكة، مستند اختفى…).
class AccountHiddenBackfillFailure {
  const AccountHiddenBackfillFailure({required this.id, required this.message});

  final String id;
  final String message;

  @override
  String toString() => '$id: $message';
}

/// تقرير فحص أو ترحيل — يُعرض للمستخدم كما هو، فلا يحتاج ترجمة لاحقة.
class AccountHiddenBackfillReport {
  const AccountHiddenBackfillReport({
    required this.dryRun,
    required this.scanned,
    required this.missingIds,
    required this.updatedIds,
    required this.failures,
  });

  /// هل كانت هذه معاينة فقط (بلا كتابة)؟
  final bool dryRun;

  /// إجمالي المستندات المقروءة.
  final int scanned;

  /// المستندات التي ينقصها الحقل — هي فقط ما يُحدَّث.
  final List<String> missingIds;

  /// المستندات التي كُتب عليها `accountHidden: false` فعلًا (فارغة في المعاينة).
  final List<String> updatedIds;

  final List<AccountHiddenBackfillFailure> failures;

  /// عدد المستندات التي **ستتغيّر** (في المعاينة) أو تغيّرت (في التنفيذ).
  int get needsMigration => missingIds.length;

  /// هل البيانات نظيفة أصلًا؟ (لا شيء يحتاج ترحيلًا)
  bool get isClean => missingIds.isEmpty;

  /// هل انتهى الترحيل بلا فشل؟ المعاينة تعتبر «مكتملة» إن لم يكن هناك ما يمنع.
  bool get isComplete => failures.isEmpty;

  /// ملخص عربي في سطر — لا أرقام غامضة ولا كلمات تقنية.
  String get summary {
    final String scope = dryRun ? 'معاينة (لم يُكتب شيء)' : 'تنفيذ';
    if (scanned == 0) {
      return '$scope: لا توجد ملفات مدرسين للفحص.';
    }
    if (missingIds.isEmpty) {
      return '$scope: كل الملفات ($scanned) تحمل حقل الظهور — لا حاجة لترحيل.';
    }
    if (dryRun) {
      return '$scope: $needsMigration من $scanned ملفًا ينقصها حقل الظهور '
          'وستُضاف لها `accountHidden: false`.';
    }
    final int failed = failures.length;
    return failed == 0
        ? '$scope: حُدِّث $needsMigration من $scanned ملفًا بنجاح.'
        : '$scope: حُدِّث ${updatedIds.length} من $scanned، وفشل $failed.';
  }
}

/// المصدر الذي يقرأه الترحيل ويكتب فيه.
///
/// الفصل مقصود: المنطق (ما يُحدَّث وما لا يُلمس) يُختبر بمستودع وهمي حتمي بلا
/// Firebase، والتنفيذ الحقيقي في طبقة البيانات.
abstract interface class AccountHiddenBackfillGateway {
  /// كل ملفات المدرسين (بأي حالة) مع بيان وجود الحقل.
  Future<List<TeacherProfileFlagRecord>> listTeacherProfiles();

  /// يضيف `accountHidden: false` **فقط**. لا يمسّ أي حقل آخر.
  Future<void> setAccountHiddenFalse(String teacherId);
}

/// منفّذ الترحيل: فحص ومعاينة وكتابة.
abstract final class AccountHiddenBackfill {
  /// يفحص كل الملفات، ويُحدّث الناقص **إن كان [dryRun] خطأ**.
  ///
  /// - `dryRun: true` (الافتراضي): يقرأ ويحسب فقط.
  /// - `dryRun: false`: يكتب على المستندات التي ينقصها الحقل حصرًا.
  ///
  /// [onProgress] اختياري لتقارير التقدّم في الأداة، ولا يؤثر في النتيجة.
  static Future<AccountHiddenBackfillReport> run({
    required AccountHiddenBackfillGateway gateway,
    bool dryRun = true,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<TeacherProfileFlagRecord> profiles = await gateway
        .listTeacherProfiles();

    final List<String> missing = <String>[
      for (final TeacherProfileFlagRecord record in profiles)
        if (!record.hasAccountHiddenFlag) record.id,
    ]..sort();

    if (dryRun || missing.isEmpty) {
      onProgress?.call(missing.length, missing.length);
      return AccountHiddenBackfillReport(
        dryRun: dryRun,
        scanned: profiles.length,
        missingIds: List<String>.unmodifiable(missing),
        updatedIds: const <String>[],
        failures: const <AccountHiddenBackfillFailure>[],
      );
    }

    final List<String> updated = <String>[];
    final List<AccountHiddenBackfillFailure> failures =
        <AccountHiddenBackfillFailure>[];

    for (int index = 0; index < missing.length; index++) {
      final String id = missing[index];
      try {
        await gateway.setAccountHiddenFalse(id);
        updated.add(id);
      } on Object catch (error) {
        // فشل مستند واحد لا يُسقط البقية: يُسجَّل ويُكمَل، فيستطيع المستخدم
        // إعادة التشغيل على ما تبقّى وحده (التشغيل آمن ومتكرّر).
        failures.add(
          AccountHiddenBackfillFailure(id: id, message: '$error'),
        );
      }
      onProgress?.call(index + 1, missing.length);
    }

    return AccountHiddenBackfillReport(
      dryRun: false,
      scanned: profiles.length,
      missingIds: List<String>.unmodifiable(missing),
      updatedIds: List<String>.unmodifiable(updated),
      failures: List<AccountHiddenBackfillFailure>.unmodifiable(failures),
    );
  }
}
