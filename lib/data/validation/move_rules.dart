import 'package:teacher_student_app/data/models/study_group.dart';

/// قواعد **نقل عضو** بين مجموعتين — دوال نقية بلا Flutter ولا شبكة.
///
/// النموذج الصارم (A-71):
/// - النقل مسموح **فقط** إذا كان في المجموعة الهدف مقعد حر
///   (`seatsTaken < seatsTotal`). لا توسيع للسعة أثناء النقل، ولا انتظار في
///   قائمة، ولا قبول مؤقت: إما مقعد حر الآن، أو رفض صريح.
/// - المجموعتان لصاحب واحد. نقل عضو إلى مجموعة مدرس آخر يخرجه من إشراف من
///   قرر النقل — لا نسمح به.
/// - الهدف يجب أن يكون منشورًا (المجموعة الموقوفة لا تستقبل أحدًا)، والمصدر
///   يكفي أن يكون ملك المدرس (الإيقاف لا يمنع إخراج عضو).
/// - العضو يجب أن يكون في المصدر فعلًا، وألا يكون في الهدف أصلًا.
///
/// الرسائل هنا هي نفسها التي تُعرض في الواجهة، ونفسها التي ترفعها المستودعات؛
/// والقواعد هي الحارس الأخير (لا تُصاغ هذه الشروط كلها في `firestore.rules`،
/// لكن حدود السعة كلها مفروضة هناك).
abstract final class MoveRules {
  /// نص الرفض المطلوب عند امتلاء الهدف — **حرفيًا** كما في تجربة الاستخدام.
  static const String targetFullMessage = 'المجموعة المراد النقل إليها مكتملة السعة.';

  /// تلميح لطالب كان يفتح محادثة/جدول مجموعة **لم يعد عضوًا فيها**.
  ///
  /// هذه هي الحالة الباقية بعد النقل: الشاشة المفتوحة في المجموعة القديمة لا
  /// تصبح صالحة لمجرد النقل، فتقول له الشاشة صراحةً أين يبحث عن مجموعته
  /// الجديدة بدل رسالة «الجدول لأعضاء المجموعة» التي تُوحي بأنه لم ينضم قط.
  static const String notMemberHint =
      'إذا كان المدرس قد نقلك إلى مجموعة أخرى، افتح المجموعة الجديدة من '
      '«المجموعات» لعرض جدولها ومحادثتها.';

  /// سبب منع النقل — أو `null` إن كان مسموحًا.
  ///
  /// [sameOwner] تُحسب في المستودع من المجموعتين المقروءتين داخل المعاملة
  /// (لا من واجهة المستخدم).
  static String? blockReason({
    required StudyGroup from,
    required StudyGroup to,
    required bool sameOwner,
    required bool isMember,
    required bool targetAlreadyHasMember,
  }) {
    if (from.id == to.id) {
      return 'العضو في هذه المجموعة بالفعل.';
    }
    if (!sameOwner) {
      return 'لا يمكنك نقل عضو إلى مجموعة لا تملكها.';
    }
    if (!isMember) {
      return 'هذا العضو ليس في المجموعة المصدر.';
    }
    if (targetAlreadyHasMember) {
      return 'العضو موجود في المجموعة الهدف بالفعل.';
    }
    if (!to.isActive) {
      return 'المجموعة الهدف موقوفة؛ لا تستقبل أعضاء حاليًا.';
    }
    // الفحص الحاسم — قبل أي كتابة.
    if (to.seatsAvailable <= 0) {
      return targetFullMessage;
    }
    return null;
  }

  static bool canMove({
    required StudyGroup from,
    required StudyGroup to,
    required bool sameOwner,
    required bool isMember,
    required bool targetAlreadyHasMember,
  }) =>
      blockReason(
        from: from,
        to: to,
        sameOwner: sameOwner,
        isMember: isMember,
        targetAlreadyHasMember: targetAlreadyHasMember,
      ) ==
      null;

  /// المجموعات التي يمكن النقل إليها (للعرض في الشاشة).
  ///
  /// نُبقي المكتملة في القائمة مع سبب الرفض بدل إخفائها: المدرس يجب أن يعرف
  /// **لماذا** لا يستطيع النقل، لا أن يرى قائمة أقصر بلا تفسير.
  static List<StudyGroup> targets({
    required StudyGroup from,
    required List<StudyGroup> ownedGroups,
  }) {
    final List<StudyGroup> others = ownedGroups
        .where((StudyGroup g) => g.id != from.id)
        .toList(growable: false);
    return List<StudyGroup>.unmodifiable(others);
  }

  /// سبب تعطيل صف هدف معيّن (أو `null` إن كان متاحًا).
  static String? targetBlockReason(StudyGroup target) {
    if (!target.isActive) {
      return 'المجموعة موقوفة.';
    }
    if (target.seatsAvailable <= 0) {
      return targetFullMessage;
    }
    return null;
  }
}
