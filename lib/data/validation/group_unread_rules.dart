import 'package:teacher_student_app/data/models/group_message.dart';

/// قواعد «غير المقروء» في محادثة المجموعة (P32) — **دوال نقية**.
///
/// **المشكلة:** محادثة المجموعة لا تحمل أي حالة قراءة، فالمستخدم لا يعرف أن في
/// مجموعة لم يفتحها رسائل جديدة، والجرس لا يعدّها (ولا ينبغي أن يعدّها: قائمة
/// الإشعارات لا تُغرق برسالة لكل رسالة مجموعة).
///
/// **الحل:** علامة قراءة **لكل مشارك** (`studyGroups/{id}/reads/{uid}.lastReadAt`)،
/// ويُحسب العدد من الرسائل الأحدث منها. الحساب هنا نقي حتى يُختبر بلا خادم.
///
/// **لماذا لا نقرأ الرسائل ونستبعد رسائل العضو على العميل؟** كان ذلك هو
/// التنفيذ الأول: استعلام بـ`limit(10)` ثم استبعاد رسائل العضو نفسه. وهو
/// **خاطئ**: السقف يُستهلك برسائل العضو (التي لا تُحتسب) قبل أن تصل رسالة
/// عضو آخر، فيُعرض «0» وهناك رسائل غير مقروءة فعلًا. الحساب الآن من **عددين**
/// يحسبهما الخادم (تجميع `count`) — الكل بعد آخر قراءة، ورسائل العضو نفسه بعد
/// آخر قراءة — والفرق بينهما هو غير المقروء: رقم **دقيق** لا يعتمد على سقف.
abstract final class GroupUnreadRules {
  /// أقصى رقم يُعرض صريحًا قبل «9+».
  static const int displayCap = 9;

  /// غير المقروء = (كل الرسائل بعد آخر قراءة) − (رسائلي أنا بعد آخر قراءة).
  ///
  /// الحدّ الأدنى صفر لأن الفرق لا يصح أن يكون سالبًا (لو تغيّرت البيانات بين
  /// الاستعلامين: رسالة جديدة من العضو نفسه بين العدّين).
  static int unreadFromCounts({
    required int totalAfterRead,
    required int ownAfterRead,
  }) {
    final int unread = totalAfterRead - ownAfterRead;
    return unread < 0 ? 0 : unread;
  }

  /// هل هذه الرسالة غير مقروءة لهذا العضو؟
  ///
  /// * رسالة العضو نفسه ليست غير مقروءة — كتبها هو.
  /// * [lastReadAt] غائب ⇒ العضو لم يقرأ شيئًا بعد (عضو قديم أو جديد).
  /// * المقارنة **بصرامة** (`isAfter`): رسالة في نفس لحظة التعليم تُعدّ مقروءة،
  ///   فلا تبقى شارة لا تختفي أبدًا بسبب تساوي الطوابع الزمنية.
  static bool isUnread({
    required GroupMessage message,
    required String memberId,
    required DateTime? lastReadAt,
  }) {
    if (message.senderId == memberId) {
      return false;
    }
    if (lastReadAt == null) {
      return true;
    }
    return message.sentAt.isAfter(lastReadAt);
  }

  /// عدد غير المقروء من قائمة رسائل (الوضع التجريبي والاختبارات).
  static int countUnread({
    required Iterable<GroupMessage> messages,
    required String memberId,
    required DateTime? lastReadAt,
  }) {
    return messages
        .where(
          (GroupMessage message) => isUnread(
            message: message,
            memberId: memberId,
            lastReadAt: lastReadAt,
          ),
        )
        .length;
  }

  /// نص الشارة، أو `null` إن لم يكن هناك ما يُعرض.
  static String? badgeLabel(int count) {
    if (count <= 0) {
      return null;
    }
    if (count > displayCap) {
      return '$displayCap+';
    }
    return '$count';
  }
}
