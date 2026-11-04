import 'package:teacher_student_app/data/models/weekly_auction.dart';

/// قواعد **الواجهة** للمزايدة (P30) — للطمأنة والتوجيه فقط.
///
/// ⚠️ هذه ليست حارسًا أمنيًا: كل رقم هنا يُعيد الخادم التحقق منه داخل معاملة
/// (`functions/lib/auction_core.js`). فائدتها أن المدرس يعرف قبل الضغط لماذا
/// سيرفض الخادم طلبه، فلا يرى أخطاء متكررة بلا سبب مفهوم.
///
/// **لماذا دالة نقية؟** لأن الشاشة تحتاج عرض «أقل مزايدة تالية» وتلميحًا فوريًا
/// أثناء الكتابة، والاختبار يحتاج الحكم نفسه بلا واجهة.
abstract final class AuctionRules {
  /// أقل مبلغ مقبول للمزايدة التالية.
  ///
  /// - بلا مزايدة سابقة: أقل مزايدة إعلانية.
  /// - بعدها: المبلغ الحالي + خطوة الزيادة.
  static int nextMinimum({
    required int minBid,
    required int bidStep,
    int? currentAmount,
  }) {
    if (currentAmount == null) return minBid;
    return currentAmount + bidStep;
  }

  /// حدّ المبلغ الأعلى في مربع الإدخال ([maxBid] من الخادم).
  ///
  /// لا نسمح بكتابة مبلغ أكبر من سقف الخادم حتى لا يُرسل طلبًا مرفوضًا.
  static int clampAmount({required int amount, required int maxBid}) {
    if (amount < 0) return 0;
    if (amount > maxBid) return maxBid;
    return amount;
  }

  /// رسالة خطأ عربية إن كان المبلغ غير مقبول، أو `null` إن بدا صالحًا.
  ///
  /// [isFirst] يحدّد إن كان هذا أول مزايدة (الحد الأدنى `minBid`) أم زيادة
  /// (المبلغ الحالي + `bidStep`).
  static String? validateAmount({
    required int amount,
    required int minBid,
    required int bidStep,
    required int maxBid,
    required bool isFirst,
    int? currentAmount,
  }) {
    if (amount <= 0) return 'أدخل مبلغًا صحيحًا بالجنيه.';
    if (amount > maxBid) return 'الحد الأقصى للمزايدة $maxBid جنيهًا.';
    if (isFirst) {
      if (amount < minBid) return 'أقل مزايدة مقبولة $minBid جنيهًا.';
      return null;
    }
    final int needed = nextMinimum(
      minBid: minBid,
      bidStep: bidStep,
      currentAmount: currentAmount,
    );
    if (amount < needed) {
      return 'أقل زيادة مقبولة $needed جنيهًا (خطوة الزيادة $bidStep).';
    }
    return null;
  }

  /// هل يستطيع المدرّس إرسال مزايدة الآن؟ (عرض فقط — الحكم للخادم)
  static bool canSubmit({
    required AuctionState state,
    required int amount,
    required bool submitting,
  }) {
    if (submitting || !state.eligible) return false;
    if (!state.phase.canBid) return false;
    // الفئة تأتي من الخادم (من ملف المدرّس)، ونتحقق من وجودها قبل القراءة.
    if (state.category == null) return false;
    if (state.myBid != null && state.increasesRemaining <= 0) return false;
    return validateAmount(
          amount: amount,
          minBid: state.minBid,
          bidStep: state.bidStep,
          maxBid: state.maxBid,
          isFirst: state.myBid == null,
          currentAmount: state.myBid?.amount,
        ) ==
        null;
  }
}
