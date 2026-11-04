import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/validation/message_rules.dart';

/// قواعد المحادثة المباشرة (P11) — **دوال نقية**.
///
/// كل حدّ هنا له نظير في `firestore.rules`؛ والواجهة تعرض نفس السبب الذي يمنع
/// الخادمُ الكتابةَ، فلا يرى المستخدم زرًا يعمل ثم يُرفض عند الإرسال.
abstract final class DirectChatRules {
  /// حدّ طول الرسالة — نفس حدّ محادثة المجموعة (P9)، وقاعدة Firestore.
  static const int maxLength = MessageRules.maxLength;

  /// أقصى عدد رسائل تُقرأ في الجلسة الواحدة.
  static const int maxMessagesPerLoad = MessageRules.maxMessagesPerLoad;

  /// المدرس لا يستقبل استفسارات قبل الحجز ما لم يفعّل الخيار صراحةً (A-78).
  ///
  /// القيمة الافتراضية عند غياب المستند في الخادم: `false` — أي **متشدّدة**.
  static const bool defaultAllowDirectMessages = false;

  /// هل يمكن بدء محادثة **جديدة** مع هذا المدرس؟
  ///
  /// [hasBooking] حجز قائم بين الطرفين، [isGroupMember] عضوية مجموعة عنده.
  static bool canStartChat({
    required String? viewerId,
    required bool hasBooking,
    required bool isGroupMember,
    required bool allowDirectMessages,
  }) {
    if (viewerId == null || viewerId.isEmpty) {
      return false;
    }
    return hasBooking || isGroupMember || allowDirectMessages;
  }

  /// سبب منع بدء محادثة جديدة (أو `null` إن كان مسموحًا).
  static String? startBlockedReason({
    required String? viewerId,
    required bool hasBooking,
    required bool isGroupMember,
    required bool allowDirectMessages,
  }) {
    if (viewerId == null || viewerId.isEmpty) {
      return 'سجّل الدخول لمراسلة المدرس.';
    }
    if (hasBooking || isGroupMember || allowDirectMessages) {
      return null;
    }
    return 'هذا المدرس لا يستقبل رسائل قبل الحجز. أرسل طلب حجز أولًا، أو انضم '
        'إلى إحدى مجموعاته، وستُفتح المحادثة بعد ذلك.';
  }

  /// أصل المحادثة الأنسب عند البدء من سياق معروف.
  static DirectChatOrigin originFor({
    required bool hasBooking,
    required bool isGroupMember,
  }) {
    if (hasBooking) {
      return DirectChatOrigin.booking;
    }
    if (isGroupMember) {
      return DirectChatOrigin.group;
    }
    return DirectChatOrigin.inquiry;
  }

  /// سبب منع **الإرسال** في محادثة قائمة (أو `null`).
  ///
  /// [bookingRejected] صحيح إن كان الحجز المرتبط مرفوضًا — يُغلق الإرسال
  /// (معيار P11: «إيقاف الإرسال عند الرفض»).
  static String? sendBlockedReason({
    required DirectChat chat,
    required String? viewerId,
    required bool allowDirectMessages,
    bool bookingRejected = false,
  }) {
    if (!chat.involves(viewerId)) {
      return 'هذه المحادثة ليست لك.';
    }
    if (bookingRejected) {
      return 'رُفض طلب الحجز المرتبط بهذه المحادثة، فلا يمكن متابعتها.';
    }
    if (chat.origin == DirectChatOrigin.inquiry && !allowDirectMessages) {
      return 'أوقف المدرس استقبال الرسائل قبل الحجز؛ أرسل طلب حجز لمتابعة '
          'المحادثة.';
    }
    return null;
  }

  /// هل يمكن عرض المحادثة لـ[viewerId]؟ (طرفا المحادثة فقط)
  static bool canView({required DirectChat chat, required String? viewerId}) =>
      chat.involves(viewerId);

  /// تنظيف النص — نفس سياسة P9 (رسالة من فراغات ليست رسالة).
  static String normalize(String? raw) => MessageRules.normalize(raw);

  /// ساعة بصيغة عربية مختصرة: «9:05 م».
  static String timeLabel(DateTime value) {
    final int hour12 = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${value.hour >= 12 ? 'م' : 'ص'}';
  }

  /// فاصل اليوم في قائمة الرسائل: «اليوم» / «أمس» / «12/10/2026».
  static String dayLabel(DateTime day, {required DateTime now}) {
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(day.year, day.month, day.day);
    final int diff = today.difference(target).inDays;
    if (diff == 0) {
      return 'اليوم';
    }
    if (diff == 1) {
      return 'أمس';
    }
    final String month = day.month.toString().padLeft(2, '0');
    return '${day.day}/$month/${day.year}';
  }

  /// هل الرسالة [index] في القائمة تفتح يومًا جديدًا؟ (لبناء الفواصل)
  static bool startsNewDay(List<DirectChatMessage> messages, int index) {
    if (index <= 0) {
      return true;
    }
    final DateTime previous = messages[index - 1].sentAt;
    final DateTime current = messages[index].sentAt;
    return previous.year != current.year ||
        previous.month != current.month ||
        previous.day != current.day;
  }
}
