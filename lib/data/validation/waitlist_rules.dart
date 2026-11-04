import 'package:teacher_student_app/data/models/group_waitlist_entry.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/validation/model_validators.dart';

/// قواعد قائمة الانتظار — **دوال نقية** تُستخدم في الواجهة والمستودع والقواعد.
///
/// الفلسفة نفسها (A-55): الرسالة العربية هنا، والمنع النهائي في
/// `firestore.rules`، واختبارات المحاكي تثبت التطابق.
///
/// **المبدأ:** المقعد لا يُحجز في الطابور. المنتظر لا يشغل مقعدًا، ولا يرى
/// الجدول ولا المحادثة (لأنه ليس عضوًا)، ولا يُقبل إلا عندما يوجد مقعد فعلي.
abstract final class WaitlistRules {
  /// سبب منع الانضمام إلى قائمة الانتظار — أو `null` إن كان مسموحًا.
  ///
  /// القيد الحاسم: **القائمة للمجموعات المكتملة فقط**. مجموعة بها مقعد لا
  /// تحتاج طابورًا؛ وضعها هناك يعني تأخير الطالب بلا سبب.
  static String? joinBlockReason({
    required StudyGroup group,
    required String? viewerId,
    WaitlistStatus? existingStatus,
  }) {
    if (viewerId != null && viewerId == group.teacherId) {
      return 'أنت صاحب المجموعة؛ لا يمكنك الانضمام إلى قائمتها.';
    }
    if (!group.isActive) {
      return 'المجموعة موقوفة؛ لا تقبل طلبات انتظار.';
    }
    if (group.seatsAvailable > 0) {
      return 'المجموعة بها مقعد متاح الآن؛ أرسل طلب انضمام بدل الانتظار.';
    }
    if (existingStatus == WaitlistStatus.waiting) {
      return 'أنت في قائمة الانتظار بالفعل.';
    }
    if (existingStatus == WaitlistStatus.promoted) {
      return 'تم قبولك في هذه المجموعة بالفعل.';
    }
    return null;
  }

  static bool canJoin({
    required StudyGroup group,
    required String? viewerId,
    WaitlistStatus? existingStatus,
  }) =>
      joinBlockReason(
        group: group,
        viewerId: viewerId,
        existingStatus: existingStatus,
      ) ==
      null;

  /// سبب منع قبول المنتظر — أو `null`.
  ///
  /// تُستدعى داخل معاملة بقراءة طازجة للمجموعة والصف، فيبقى القرار صحيحًا حتى
  /// لو تغيّرت السعة بعد عرض الشاشة.
  static String? promoteBlockReason({
    required StudyGroup group,
    required GroupWaitlistEntry entry,
  }) {
    if (!entry.isWaiting) {
      return 'هذا الصف لم يعد في قائمة الانتظار.';
    }
    if (!group.isActive) {
      return 'المجموعة موقوفة؛ لا يمكن قبول منتظرين.';
    }
    if (group.seatsAvailable <= 0) {
      return 'لا مقعد متاح؛ حرّر مقعدًا أو ارفع السعة أولًا.';
    }
    return null;
  }

  static bool canPromote({
    required StudyGroup group,
    required GroupWaitlistEntry entry,
  }) =>
      promoteBlockReason(group: group, entry: entry) == null;

  /// ترتيب الطابور: المنتظرون أولًا (الأقدم أولًا)، ثم المنتهون (الأحدث أولًا).
  static List<GroupWaitlistEntry> ordered(List<GroupWaitlistEntry> entries) {
    final List<GroupWaitlistEntry> sorted = <GroupWaitlistEntry>[...entries];
    sorted.sort((GroupWaitlistEntry a, GroupWaitlistEntry b) {
      if (a.isWaiting != b.isWaiting) {
        return a.isWaiting ? -1 : 1;
      }
      if (a.isWaiting) {
        return a.addedAt.compareTo(b.addedAt);
      }
      final DateTime aTime = a.decidedAt ?? a.addedAt;
      final DateTime bTime = b.decidedAt ?? b.addedAt;
      return bTime.compareTo(aTime);
    });
    return List<GroupWaitlistEntry>.unmodifiable(sorted);
  }

  /// موضع الطالب داخل الطابور (يبدأ من 1) — `null` إن لم يكن منتظرًا.
  ///
  /// الترتيب مأخوذ من [ordered] لا من واجهة الشاشة، فلا يختلف الموضع بين
  /// طالب والمدرس.
  static int? positionOf(
    List<GroupWaitlistEntry> entries,
    String entryId,
  ) {
    int position = 0;
    for (final GroupWaitlistEntry entry in ordered(entries)) {
      if (!entry.isWaiting) {
        continue;
      }
      position++;
      if (entry.id == entryId) {
        return position;
      }
    }
    return null;
  }

  /// منتظرون فقط.
  static List<GroupWaitlistEntry> waitingOnly(List<GroupWaitlistEntry> entries) =>
      List<GroupWaitlistEntry>.unmodifiable(
        ordered(entries).where((GroupWaitlistEntry e) => e.isWaiting),
      );

  /// ملخص عربي لحالة الطابور أسفل بطاقة السعة.
  static String summaryLine({
    required int waiting,
    required int seatsAvailable,
  }) {
    if (waiting == 0) {
      return seatsAvailable > 0
          ? 'لا أحد في قائمة الانتظار.'
          : 'القائمة فارغة؛ من يطلب الانضمام بعد الامتلاء يدخلها.';
    }
    final String queue = waiting == 1
        ? 'طالب واحد في قائمة الانتظار'
        : '$waiting طلاب في قائمة الانتظار';
    return seatsAvailable > 0 ? '$queue — مقعد متاح الآن.' : queue;
  }

  /// هل يمكن إرسال إشعار يدوي؟ (لا إشعارات تلقائية بلا دوال خادم — A-67)
  static const bool hasAutomaticPromotion = false;

  /// تحقق من حقول الصف قبل الكتابة (حدود مطابقة للقواعد).
  static ValidationResult validateEntry({
    String? groupId,
    String? groupTitle,
    String? studentId,
    String? studentName,
    bool hasAddedAt = true,
  }) {
    final List<ValidationProblem> problems = <ValidationProblem>[];

    void check(
      String field,
      String? value, {
      required int minLength,
      required int maxLength,
    }) {
      final String? text = normalizeText(value);
      if (text == null) {
        problems.add(ValidationProblem(field, FieldIssue.missing));
      } else if (text.length < minLength) {
        problems.add(ValidationProblem(field, FieldIssue.tooShort));
      } else if (text.length > maxLength) {
        problems.add(ValidationProblem(field, FieldIssue.tooLong));
      }
    }

    check('groupId', groupId, minLength: 1, maxLength: 200);
    check(
      'groupTitle',
      groupTitle,
      minLength: 3,
      maxLength: ModelLimits.groupTitle,
    );
    check('studentId', studentId, minLength: 1, maxLength: 200);
    check(
      'studentName',
      studentName,
      minLength: 1,
      maxLength: ModelLimits.displayName,
    );
    if (!hasAddedAt) {
      problems.add(const ValidationProblem('addedAt', FieldIssue.missing));
    }

    return ValidationResult(List<ValidationProblem>.unmodifiable(problems));
  }
}
