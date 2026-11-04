import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/notification_page.dart';

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

  /// (P25) **نفس القائمة حيًّا**: كل إشعار جديد يصل يظهر في الشاشة المفتوحة
  /// بلا سحب للتحديث ولا إعادة فتح.
  ///
  /// **لماذا تدفّق لا طلب؟** لأن الإشعار بطبيعته حدث لحظي: طالب يرسل طلب حجز
  /// والمدرس على الشاشة يجب أن يراه الآن. القراءة بالطلب كانت تُظهره فقط بعد
  /// مغادرة الشاشة والعودة إليها — وهو ما بدا للمستخدم كأن الإشعار «لم يُنشأ».
  ///
  /// المنفّذ الحقيقي يستخدم `snapshots()` على استعلام `recipientId == uid`
  /// (شرط واحد + ترتيب في العميل)، والقواعد تمنع أي مستند لغيره.
  Stream<List<AppNotification>> watchMine(String recipientId);

  /// صفحة من الإشعارات **الأقدم** بعد [before] (P32).
  ///
  /// **لماذا صفحة لا قائمة كاملة؟** لأن `listMine` كانت تقرأ حتى 50 إشعارًا
  /// وتتوقف: ما قبلها غير قابل للوصول إطلاقًا. هنا نقرأ صفحة واحدة بحدّ صريح
  /// ونعيد `hasMore`، فتتحمّل الشاشة الأقدم عند طلب المستخدم فقط.
  ///
  /// **المؤشر مركّب:** الترتيب `createdAt` تنازليًا ثم المعرّف تصاعديًا (نفس
  /// ترتيب [NotificationRules.newestFirst])، والمتابعة تبدأ **بعد** الزوج
  /// (`before`, `beforeId`) لا بعد الوقت وحده. هذا يمنع حالتين معًا: تكرار
  /// عنصر بين صفحتين، و**ضياع** إشعارين تشتركا في نفس المللي ثانية (وقع ممكن
  /// حين يُنشئ طرفان إشعارين في اللحظة نفسها).
  ///
  /// **العدّاد مستقل تمامًا:** هذه الدالة لا تُعلّم شيئًا مقروءًا ولا تُغيّر
  /// `readAt`، فقراءة صفحة قديمة لا تصفّر جرس الإشعارات.
  Future<NotificationPage> listPage({
    required String recipientId,
    int limit,
    DateTime? before,
    String? beforeId,
  });

  /// علّم إشعارات **محادثة واحدة** من نوع `directMessage` كمقروءة (P32).
  ///
  /// **المشكلة التي يحلّها:** قراءة الرسائل داخل المحادثة كانت تُحدّث حالة
  /// المحادثة وحدها، فتبقى إشعارات الرسائل غير مقروءة والجرس يعدّها أبدًا.
  ///
  /// **حدوده:** النوع `directMessage` فقط، و`targetId` مساوٍ لمعرّف المحادثة،
  /// والمستلم هو صاحب الشاشة. لا يمسّ إشعارات الحجز أو الانضمام أو المزاد،
  /// ولا يكتب شيئًا إن لم يكن هناك غير مقروء (فلا كتابات لا أثر لها).
  /// يعيد عدد ما عُدِّل فعلًا، ويرمي الأخطاء لتقرّر الشاشة: أفضل جهد.
  Future<int> markChatMessagesRead({
    required String recipientId,
    required String chatId,
  });

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
  /// [dedupeId] (P32): مفتاح حتمي للمستند يجعل الإشعار **قابلًا للتكرار
  /// بأمان**. إعادة تنفيذ العملية نفسها (نقر مزدوج، إعادة محاولة بعد خطأ شبكة،
  /// طلب مكرر) تحاول الكتابة على **نفس المعرّف**، فتُرفض الثانية (لأن القواعد
  /// تمنع على المُحدِث تعديل إشعار مستلمه) ولا يُنشأ إشعار ثانٍ. `null` = معرّف
  /// عشوائي كما كان (كل حدث إشعار مستقل، مثل رسالة جديدة).
  Future<AppNotification> push({
    required NotificationType type,
    required String recipientId,
    required String actorId,
    required String actorName,
    required String targetId,
    String? title,
    String? body,
    String? dedupeId,
  });
}
