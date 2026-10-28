import 'package:teacher_student_app/data/models/app_notification.dart';

/// قواعد الإشعارات (P12) — **دوال نقية**.
///
/// الحدود هنا مطابقة لـ`firestore.rules`: العنوان ≤ 120 حرفًا، والنص ≤ 200،
/// واسم المُحدِث ≤ 80. أي تغيير في أحدهما يوجب الآخر (تحرسه اختبارات المحاكي).
abstract final class NotificationRules {
  static const int titleMax = 120;
  static const int bodyMax = 200;
  static const int actorNameMax = 80;

  /// أقصى عدد إشعارات تُقرأ في الشاشة الواحدة.
  static const int maxPerLoad = 50;

  /// عنوان مقترح مبني على النوع واسم الطرف الآخر.
  ///
  /// العنوان نص عرض فقط؛ الحقيقة في `type` و`targetId`، والقواعد لا تعتمد
  /// على النص إطلاقًا.
  static String titleFor({
    required NotificationType type,
    required String actorName,
    String? subject,
    String? slotLabel,
  }) {
    final String actor = actorName.trim();
    return switch (type) {
      NotificationType.bookingRequested =>
        actor.isEmpty ? 'طلب حجز جديد' : 'طلب حجز جديد من $actor',
      NotificationType.bookingAccepted =>
        actor.isEmpty ? 'قُبل طلب الحجز' : 'قبل $actor طلب الحجز',
      NotificationType.bookingRejected =>
        actor.isEmpty ? 'رُفض طلب الحجز' : 'رفض $actor طلب الحجز',
      NotificationType.rescheduleProposed =>
        actor.isEmpty ? 'وقت بديل مقترح' : 'اقترح $actor وقتًا بديلًا',
      NotificationType.directMessage =>
        actor.isEmpty ? 'رسالة جديدة' : 'رسالة من $actor',
      NotificationType.waitlistPromoted => slotLabel == null
          ? 'مقعد متاح لك'
          : 'مقعد متاح لك — $slotLabel',
    };
  }

  /// تنظيف النص: توحيد المسافات وإزالة الحواف.
  static String normalize(String? raw) {
    if (raw == null) {
      return '';
    }
    return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// هل النص المقترح عنوان/جسم صالح؟ (`null` = صالح)
  static String? textProblem({
    required String title,
    String? body,
    required String actorName,
  }) {
    final String cleanTitle = normalize(title);
    if (cleanTitle.isEmpty) {
      return 'عنوان الإشعار مطلوب.';
    }
    if (cleanTitle.length > titleMax) {
      return 'عنوان الإشعار أطول من $titleMax حرفًا.';
    }
    final String cleanBody = normalize(body);
    if (cleanBody.length > bodyMax) {
      return 'نص الإشعار أطول من $bodyMax حرفًا.';
    }
    if (normalize(actorName).length > actorNameMax) {
      return 'اسم المُحدِث أطول من $actorNameMax حرفًا.';
    }
    return null;
  }

  /// الإشعارات الأحدث أولًا (والترتيب ثابت عند تساوي الوقت).
  static List<AppNotification> newestFirst(List<AppNotification> items) {
    final List<AppNotification> sorted = <AppNotification>[...items];
    sorted.sort((AppNotification a, AppNotification b) {
      final int byTime = b.createdAt.compareTo(a.createdAt);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });
    return List<AppNotification>.unmodifiable(sorted);
  }

  /// عدد غير المقروء في قائمة.
  static int unreadCount(Iterable<AppNotification> items) =>
      items.where((AppNotification item) => !item.isRead).length;

  /// هل لهذا الإشعار وجهة يمكن فتحها؟ (الوجهة معروفة دائمًا، لكن السبب قد
  /// يكون محذوفًا — الواجهة تتعامل مع غياب المستند هناك.)
  static bool opensScreen(AppNotification notification) =>
      notification.targetId.trim().isNotEmpty;

  /// وقت نسبي عربي للعرض في القائمة.
  ///
  /// لا نستخدم صيغة «قبل يومين» بل نتوقف عند «أمس» ثم تاريخ صريح، لأن التقريب
  /// بالأيام يضلّل في إشعارات عمرها أسابيع.
  static String relativeTime(DateTime value, {required DateTime now}) {
    final Duration diff = now.difference(value);
    if (diff.inSeconds < 0) {
      // ساعة الجهاز قد تكون متأخرة عن الخادم؛ لا نعرض «قبل -٣ دقائق».
      return 'الآن';
    }
    if (diff.inMinutes < 1) {
      return 'الآن';
    }
    if (diff.inMinutes < 60) {
      return 'قبل ${diff.inMinutes} دقيقة';
    }
    if (diff.inHours < 24) {
      return 'قبل ${diff.inHours} ساعة';
    }

    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime target = DateTime(value.year, value.month, value.day);
    final int days = today.difference(target).inDays;
    if (days == 1) {
      return 'أمس';
    }
    if (days < 7) {
      return 'قبل $days أيام';
    }
    final String month = value.month.toString().padLeft(2, '0');
    return '${value.day}/$month/${value.year}';
  }

  /// شرح مختصر تحت العنوان.
  static String bodyFor({
    required NotificationType type,
    required String actorName,
    String? subject,
    String? slotLabel,
  }) {
    final String actor = actorName.trim().isEmpty ? 'الطرف الآخر' : actorName;
    return switch (type) {
      NotificationType.bookingRequested =>
        subject == null ? 'راجع الطلب واقبله أو اقترح وقتًا بديلًا.' : 'المادة: $subject. راجع الطلب واقبله أو اقترح وقتًا بديلًا.',
      NotificationType.bookingAccepted =>
        slotLabel == null ? 'موعدك أصبح مؤكدًا.' : 'موعدك أصبح مؤكدًا: $slotLabel.',
      NotificationType.bookingRejected =>
        'يمكنك اختيار وقت آخر أو مدرس آخر من القائمة.',
      NotificationType.rescheduleProposed =>
        slotLabel == null ? 'افتح الطلب لمراجعة الوقت المقترح.' : 'الوقت المقترح: $slotLabel.',
      NotificationType.directMessage => 'أرسل لك $actor رسالة جديدة.',
      NotificationType.waitlistPromoted =>
        'أصبح لك مقعد في المجموعة — أكمل الخطوات مع المدرس.',
    };
  }
}
