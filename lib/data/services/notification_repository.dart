import 'package:teacher_student_app/data/models/app_notification.dart';

/// عقد الإشعارات داخل التطبيق (P12).
///
/// **القراءة والكتابة مقيّدتان بالمستلم:** القواعد على الخادم تسمح للمستخدم
/// بقراءة إشعاراته وتعليمها مقروءة وحذفها فقط. أما **الإنشاء** فيقوم به الطرف
/// الذي نفّذ الفعل (`actorId == request.auth.uid`)، والقواعد تتحقق من وجود
/// علاقة حقيقية بينه وبين المستلم (حجز/محادثة/عضوية مجموعة) قبل قبول الكتابة —
/// فلا يمكن إرسال إشعار لشخص لا توجد بينك وبينه علاقة.
///
/// لا دالة عامة «أنشئ إشعارًا لأي أحد»: [push] هو الباب الوحيد، وحدوده مفروضة
/// في القواعد لا في الواجهة.
abstract interface class NotificationRepository {
  /// إشعارات [recipientId] — الأحدث أولًا.
  Future<List<AppNotification>> listMine(String recipientId);

  /// عدّاد غير المقروء حيًّا (لجرس شريط التطبيق).
  ///
  /// تدفّق صغير: استعلام واحد على `recipientId` + `readAt == null`، والقيمة
  /// عدد لا قائمة.
  Stream<int> watchUnreadCount(String recipientId);

  Future<void> markRead({
    required String notificationId,
    required String recipientId,
  });

  Future<void> markAllRead(String recipientId);

  /// حذف إشعار للمستلم نفسه فقط (القواعد تمنع حذف إشعار غيرك).
  Future<void> deleteNotification({
    required String notificationId,
    required String recipientId,
  });

  /// ينشئ إشعارًا للمستلم [recipientId] بفعل [actorId] على الكيان [targetId].
  ///
  /// يُستدعى من المستودعات بعد نجاح الفعل الأصلي، وبأسلوب «أفضل جهد»: فشل
  /// الإشعار لا يُفشل العملية التي أنشأته.
  Future<AppNotification> push({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
    String? title,
    String? body,
  });
}
