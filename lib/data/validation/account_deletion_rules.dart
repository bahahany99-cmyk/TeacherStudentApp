import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';

/// قواعد حذف الحساب واستعادته (P17) — **دوال نقية** بلا Flutter ولا شبكة.
///
/// المهلة 7 أيام معلنة هنا مرة واحدة: الواجهة والقواعد والخادم (عند إضافة
/// وظيفة الحذف النهائي) يجب أن تقرأ الرقم نفسه، لا أن تنسخه.
abstract final class AccountDeletionRules {
  /// مهلة السماح قبل الحذف النهائي.
  static const Duration gracePeriod = Duration(days: 7);

  /// الموعد الذي يصبح بعده الحساب قابلًا للحذف النهائي.
  static DateTime scheduledAt(DateTime requestedAt) =>
      requestedAt.add(gracePeriod);

  /// هل الطلب ما زال **داخل** المهلة؟ (الموعد لم يمرّ بعد)
  static bool isWithinGrace({required DateTime? scheduledAt, required DateTime now}) {
    if (scheduledAt == null) {
      return false;
    }
    return now.isBefore(scheduledAt);
  }

  /// هل انتهت المهلة دون استعادة؟ (الحساب بانتظار الحذف النهائي)
  static bool isExpired({required DateTime? scheduledAt, required DateTime now}) =>
      scheduledAt != null && !now.isBefore(scheduledAt);

  /// الأيام المتبقية للإبقاء على الحساب (تقريب لأعلى، ولا ينزل تحت صفر).
  ///
  /// التقريب لأعلى مقصود: «يتبقّى يوم» أصدق من «0 يوم» لساعاتٍ قليلة، وإلا
  /// ظنّ المستخدم أن الحساب حُذف بالفعل.
  static int daysLeft({required DateTime scheduledAt, required DateTime now}) {
    final Duration remaining = scheduledAt.difference(now);
    if (remaining.isNegative || remaining == Duration.zero) {
      return 0;
    }
    const Duration day = Duration(days: 1);
    final int days = (remaining.inSeconds / day.inSeconds).ceil();
    return days < 0 ? 0 : days;
  }

  /// صياغة عربية سليمة لعدد الأيام.
  static String daysLabel(int days) {
    if (days <= 0) {
      return 'أقل من يوم';
    }
    if (days == 1) {
      return 'يوم واحد';
    }
    if (days == 2) {
      return 'يومان';
    }
    if (days <= 10) {
      return '$days أيام';
    }
    return '$days يومًا';
  }

  /// تاريخ مقروء `dd/MM/yyyy` بلا حزم إضافية (نفس أسلوب بقية الشاشات).
  static String dateLabel(DateTime value) {
    final String day = value.day.toString().padLeft(2, '0');
    final String month = value.month.toString().padLeft(2, '0');
    return '$day/$month/${value.year}';
  }

  // ── نصوص الواجهة (مكان واحد، فتتطابق الشاشة والحوار) ─────────────────────

  static const String deleteTitle = 'حذف الحساب';
  static const String deleteAction = 'تأكيد الحذف';
  static const String cancelAction = 'إلغاء';
  static const String signOutAction = 'تسجيل الخروج';
  static const String restoreAction = 'استعادة حسابي';

  /// شرح الحوار قبل التأكيد: يقول ما سيحدث، ومتى، وكيف يُتراجع عنه.
  static String deleteWarning(DateTime scheduledAt) =>
      'سيُخفى حسابك وملفاتك من البحث مباشرةً، وسيُسجَّل خروجك من التطبيق.\n\n'
      'تبقى لديك ${daysLabel(gracePeriod.inDays)} لاستعادة الحساب: يكفي أن '
      'تسجّل الدخول مرة أخرى وتختار «$restoreAction».\n\n'
      'بعد ${dateLabel(scheduledAt)} يصبح الحساب جاهزًا للحذف النهائي، '
      'ولا يمكن التراجع.';

  static const String deleteNotice =
      'لا يُحذف أي شيء الآن: الطلب يوقف الظهور ويبدأ المهلة.';

  static String restoreBody({
    required DateTime scheduledAt,
    required DateTime now,
  }) {
    final int days = daysLeft(scheduledAt: scheduledAt, now: now);
    return 'حسابك مجدول للحذف في ${dateLabel(scheduledAt)} '
        '(${daysLabel(days)} متبقية).\n\n'
        'استعادة الحساب تعيده نشطًا وتلغي الموعد فورًا، ويعود ملفك للظهور إن '
        'كان موثّقًا.';
  }

  /// حالة نادرة: الحساب موسوم `pending_deletion` بلا موعد محفوظ (مستند قديم أو
  /// تعديل إداري ناقص). لا نعرض زرًا يفشل على الخادم.
  static const String missingScheduleNotice =
      'الحساب موسوم بانتظار الحذف لكن دون موعد محدد، فلا يمكن حسابه من '
      'التطبيق. تواصل مع الدعم لمراجعة الحساب.';

  static const String expiredNotice =
      'انتهت مهلة الاستعادة، والحساب بانتظار الحذف النهائي. لا يمكن استخدامه '
      'من التطبيق، ولا تُستقبل له طلبات جديدة.';

  /// هل يمكن استعادة هذا الحساب الآن؟
  static bool canRestore({
    required AccountStatus status,
    required DateTime? scheduledAt,
    required DateTime now,
  }) =>
      status == AccountStatus.pendingDeletion &&
      isWithinGrace(scheduledAt: scheduledAt, now: now);

  /// وصف مختصر لحالة الحساب — يُستخدم في الشاشات والتشخيص.
  static String statusSummary(AppUser user, DateTime now) {
    if (!user.isPendingDeletion) {
      return AccountStatus.active.label;
    }
    final DateTime? scheduledAt = user.scheduledDeletionAt;
    if (scheduledAt == null) {
      return AccountStatus.pendingDeletion.label;
    }
    if (isExpired(scheduledAt: scheduledAt, now: now)) {
      return 'بانتظار الحذف النهائي';
    }
    return 'بانتظار الحذف — ${daysLabel(daysLeft(scheduledAt: scheduledAt, now: now))}';
  }
}
