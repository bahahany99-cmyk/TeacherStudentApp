import 'package:teacher_student_app/data/models/teacher_profile.dart';

/// نتيجة اختيار «المدرسون المميزون» الأسبوعي (P25).
///
/// **لماذا كائن لا قائمتان متوازيتان؟** لأن الشاشة تحتاج عدّ كل شريحة
/// («5 من 8») وقائمة الموثّقين الكاملة لصفحة «عرض الكل». الكائن يجمع ذلك في
/// قيمة واحدة قابلة للاختبار بلا واجهة.
class FeaturedSelection {
  const FeaturedSelection({
    required this.online,
    required this.offline,
    required this.allOnline,
    required this.allOffline,
    required this.weekIndex,
  });

  const FeaturedSelection.empty()
    : online = const <TeacherProfile>[],
      offline = const <TeacherProfile>[],
      allOnline = const <TeacherProfile>[],
      allOffline = const <TeacherProfile>[],
      weekIndex = 0;

  /// حتى [FeaturedRules.slotsPerSegment] مدرسًا للعرض في الرئيسية.
  final List<TeacherProfile> online;
  final List<TeacherProfile> offline;

  /// كل المرشّحين لكل شريحة (بلا قص) — تستخدمهم صفحة «عرض الكل».
  final List<TeacherProfile> allOnline;
  final List<TeacherProfile> allOffline;

  /// رقم الأسبوع الذي بُني عليه الاختيار (يظهر للاختبار وللتشخيص).
  final int weekIndex;

  int get visibleCount => online.length + offline.length;

  bool get isEmpty => visibleCount == 0;
}

/// قواعد «المدرسون المميزون» (P25) — **دوال نقية** بلا Flutter ولا شبكة.
///
/// ## القاعدة المطلوبة
/// عشر بطاقات في الرئيسية: **5 أونلاين + 5 أوفلاين**، وتتبدّل **أسبوعيًا**.
///
/// ## لماذا تبديل أسبوعي أصلًا؟
/// لأن «المميز» محدود بعدد لا نهائي من المدرسين: لو ظهر العشرة الأوائل دائمًا
/// لصارت بقية الملفات غير قابلة للاكتشاف مهما كانت جودتها. الاختيار هنا
/// **حتمي لأسبوع كامل** (لا يتغيّر بين إعادة بناء وأخرى، ولا بين جهازين):
/// الترتيب مشتق من بصمة (رقم الأسبوع + معرّف المدرس)، فكل من يفتح التطبيق في
/// الأسبوع نفسه يرى العشرة نفسها، والأسبوع التالي يرى غيرها.
///
/// ## الأولوية
/// الملفات التي ميّزتها الإدارة (`isFeatured`) تتقدّم دائمًا، ثم يكمل العدد من
/// بقية **الموثّقين** حتى لا تظهر خمس شرائح فارغة في أسبوع ضعيف التمييز.
abstract final class FeaturedRules {
  /// عدد البطاقات لكل شريحة (أونلاين/أوفلاين) — المطلوب خمس.
  static const int slotsPerSegment = 5;

  /// المجموع المطلوب (5 + 5).
  static const int totalSlots = slotsPerSegment * 2;

  /// رقم الأسبوع منذ الحقبة (ISO أسبوعيًا: ٧ أيام بالضبط).
  ///
  /// يعتمد UTC ليكون ثابتًا مهما كان توقيت الجهاز — وإلا رأى مستخدمان في مصر
  /// والأردن مجموعتين مختلفتين في الأسبوع نفسه.
  static int weekIndexOf(DateTime now) =>
      (now.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay) ~/ 7;

  /// الترتيب اليومي الحتمي لقائمة مرشّحين في أسبوع معيّن.
  ///
  /// **بلا `Random`:** بذرة عشوائية بلا تثبيت تُنتج ترتيبًا مختلفًا عند كل
  /// إعادة بناء — أي عشر بطاقات تقفز في كل مرة. البصمة هنا دالّة على
  /// (المعرّف، الأسبوع) فقط: ثابتة داخل الأسبوع، ومختلفة بين أسبوعين.
  static List<TeacherProfile> rotated(
    List<TeacherProfile> candidates, {
    required DateTime now,
  }) {
    final int week = weekIndexOf(now);
    final List<TeacherProfile> sorted = <TeacherProfile>[...candidates];
    sorted.sort((TeacherProfile a, TeacherProfile b) {
      // المميّز إداريًا أولًا.
      if (a.isFeatured != b.isFeatured) {
        return a.isFeatured ? -1 : 1;
      }
      final int bySeed = _seedOf(a.id, week).compareTo(_seedOf(b.id, week));
      return bySeed != 0 ? bySeed : a.id.compareTo(b.id);
    });
    return List<TeacherProfile>.unmodifiable(sorted);
  }

  /// يختار 5 أونلاين + 5 أوفلاين لهذا الأسبوع من [pool].
  ///
  /// [pool] هي الملفات المرشّحة (المميزون + الموثّقون). التصنيف على
  /// `isOnline` وحده — وهو العلم نفسه الذي يستخدمه فلتر الاستكشاف (A-93)، فلا
  /// يوجد تعريف ثانٍ لـ«أونلاين» في التطبيق.
  static FeaturedSelection selectWeekly(
    List<TeacherProfile> pool, {
    required DateTime now,
    int perSegment = slotsPerSegment,
  }) {
    final List<TeacherProfile> visible = pool
        .where((TeacherProfile teacher) => teacher.isVisibleToStudents)
        .toList(growable: false);

    final List<TeacherProfile> allOnline = rotated(
      visible.where((TeacherProfile t) => t.isOnline).toList(growable: false),
      now: now,
    );
    final List<TeacherProfile> allOffline = rotated(
      visible.where((TeacherProfile t) => !t.isOnline).toList(growable: false),
      now: now,
    );

    return FeaturedSelection(
      online: List<TeacherProfile>.unmodifiable(allOnline.take(perSegment)),
      offline: List<TeacherProfile>.unmodifiable(allOffline.take(perSegment)),
      allOnline: allOnline,
      allOffline: allOffline,
      weekIndex: weekIndexOf(now),
    );
  }

  /// بصمة 32-بت (FNV-1a) لسلسلة — كافية لترتيب مستقر، ولا تحتاج حزمة.
  static int _seedOf(String id, int week) {
    // لاحقة الأسبوع جزء من النص المُبصَّم، فتتغيّر البصمة أسبوعيًا.
    final String source = '$week|$id';
    int hash = 0x811C9DC5;
    for (int i = 0; i < source.length; i++) {
      hash ^= source.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
