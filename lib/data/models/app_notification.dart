/// نوع الإشعار داخل التطبيق (P12).
///
/// الأنواع محدودة بقائمة مغلقة لأن القواعد على الخادم تتحقق من **علاقة حقيقية**
/// وراء كل إشعار (حجز، محادثة، عضوية مجموعة). نوع غير معروف يُقرأ كأخبار عامة
/// ولا يفتح أي شاشة — الأسلم عند بيانات قديمة أو مكتوبة يدويًا.
enum NotificationType {
  /// الطالب أنشأ طلب حجز ⇒ المدرس.
  bookingRequested('طلب حجز جديد', NotificationTarget.booking),

  /// المدرس قبل الطلب ⇒ الطالب.
  bookingAccepted('قُبل طلب الحجز', NotificationTarget.booking),

  /// المدرس رفض الطلب ⇒ الطالب.
  bookingRejected('رُفض طلب الحجز', NotificationTarget.booking),

  /// اقتراح وقت بديل من أي طرف ⇒ الطرف الآخر.
  rescheduleProposed('وقت بديل مقترح', NotificationTarget.booking),

  /// رسالة مباشرة ⇒ الطرف الآخر.
  directMessage('رسالة جديدة', NotificationTarget.chat),

  /// ترقية من قائمة انتظار مجموعة مكتملة ⇒ الطالب.
  waitlistPromoted('مقعد متاح لك', NotificationTarget.group),

  // ── (P25) طلبات الانضمام: كانت بلا إشعار إطلاقًا ────────────────────────
  // الثغرة: طلب الانضمام يُنشئ مستندًا في `groupJoinRequests` فقط، فالمدرس
  // لا يعلم بالطلب إلا لو فتح الشاشة بنفسه — والقبول/الرفض لا يعلم به الطالب
  // إلا لو أعاد الفتح. الأنواع الثلاثة تغلق الحلقة، و`targetId` هو **معرّف
  // المجموعة** فتفتح الضغطة تفاصيلها حيث تظهر الطلبات.

  /// الطالب أرسل طلب انضمام ⇒ المدرس صاحب المجموعة.
  joinRequested('طلب انضمام جديد', NotificationTarget.group),

  /// المدرس قبل الطلب ⇒ الطالب.
  joinAccepted('قُبل طلب انضمامك', NotificationTarget.group),

  /// المدرس رفض الطلب ⇒ الطالب.
  joinRejected('رُفض طلب انضمامك', NotificationTarget.group),

  // ── (P30) مزاد التمييز: يكتبها **الخادم فقط** ───────────────────────────
  // لماذا لا تُقبل من العميل؟ لأنها تعني «فزت» أو «مقعدك متاح»: لو استطاع
  // أي عميل إنشاءها لاستطاع إيهام مدرّس بفوز لم يحدث. القواعد لا تُدرج هذه
  // الأنواع في قائمة الإنشاء من العميل، و`auctionWon` تُكتب من Cloud Functions
  // بعد حسم فعلي فقط. `targetId` هو **معرّف دورة المزاد** (`2026-W45-online`).

  /// فزت بمقعد ⇒ المدرس، بعد إعلان الخميس 09:00.
  auctionWon('فزت في مزاد التمييز', NotificationTarget.auction),

  /// توفّر لك مقعد في دورة البديل ⇒ المدرس.
  auctionReplacement('مقعد متاح في مزاد التمييز', NotificationTarget.auction),

  /// انتهت مهلة الدفع ولم يُسجَّل ⇒ المدرس.
  auctionPaymentExpired('انتهت مهلة دفع المزاد', NotificationTarget.auction);

  const NotificationType(this.label, this.target);

  /// عنوان مختصر للعرض.
  final String label;

  /// أين يقود الضغط على الإشعار.
  final NotificationTarget target;

  /// نص المتجر (اسم الملف في القواعد) — تغييره يوجب تغييره في `firestore.rules`.
  String get wireName => switch (this) {
    NotificationType.bookingRequested => 'bookingRequested',
    NotificationType.bookingAccepted => 'bookingAccepted',
    NotificationType.bookingRejected => 'bookingRejected',
    NotificationType.rescheduleProposed => 'rescheduleProposed',
    NotificationType.directMessage => 'directMessage',
    NotificationType.waitlistPromoted => 'waitlistPromoted',
    NotificationType.joinRequested => 'joinRequested',
    NotificationType.joinAccepted => 'joinAccepted',
    NotificationType.joinRejected => 'joinRejected',
    NotificationType.auctionWon => 'auctionWon',
    NotificationType.auctionReplacement => 'auctionReplacement',
    NotificationType.auctionPaymentExpired => 'auctionPaymentExpired',
  };

  static NotificationType parse(Object? raw) {
    return switch (raw) {
      'bookingRequested' => NotificationType.bookingRequested,
      'bookingAccepted' => NotificationType.bookingAccepted,
      'bookingRejected' => NotificationType.bookingRejected,
      'rescheduleProposed' => NotificationType.rescheduleProposed,
      'directMessage' => NotificationType.directMessage,
      'waitlistPromoted' => NotificationType.waitlistPromoted,
      'joinRequested' => NotificationType.joinRequested,
      'joinAccepted' => NotificationType.joinAccepted,
      'joinRejected' => NotificationType.joinRejected,
      'auctionWon' => NotificationType.auctionWon,
      'auctionReplacement' => NotificationType.auctionReplacement,
      'auctionPaymentExpired' => NotificationType.auctionPaymentExpired,
      // نوع غير معروف: نعرضه كإشعار بلا وجهة بدل إسقاطه بصمت.
      _ => NotificationType.bookingRequested,
    };
  }
}

/// وجهة الإشعار.
enum NotificationTarget {
  booking,
  chat,
  group,

  /// (P30) شاشة مزاد التمييز — مقعد الفائز ومهلته.
  auction;

  static NotificationTarget parse(Object? raw) => switch (raw) {
    'chat' => NotificationTarget.chat,
    'group' => NotificationTarget.group,
    'auction' => NotificationTarget.auction,
    _ => NotificationTarget.booking,
  };
}

/// إشعار داخل التطبيق (P12).
///
/// **لماذا `AppNotification` لا `Notification`؟** لأن `Notification` اسم صنف
/// موجود في Flutter نفسه (`flutter/widgets`)، واستخدامه هنا يجعل كل ملف يستورد
/// نموذجنا يعيش في التباس دائم مع صنف الإطار. الاسم هنا صريح: إشعار التطبيق.
///
/// **المرسل ليس حرًا:** [actorId] هو من قام بالفعل، و[recipientId] من سيقرأ،
/// والقواعد تتحقق من وجود علاقة حقيقية بينهما (حجز/محادثة/عضوية) قبل قبول
/// الإنشاء. النص ([title]/[body]) يكتبه العميل، وحدوده مفروضة في القواعد.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.actorId,
    required this.actorName,
    required this.targetId,
    required this.title,
    required this.createdAt,
    this.body,
    this.readAt,
  });

  final String id;
  final String recipientId;
  final NotificationType type;

  /// من تسبّب في الإشعار (طالب أو مدرس).
  final String actorId;
  final String actorName;

  /// معرّف الكيان المقصود: حجز، أو محادثة، أو مجموعة — حسب [type].
  final String targetId;

  final String title;
  final String? body;
  final DateTime createdAt;

  /// `null` = غير مقروء. يُملأ مرة واحدة عند أول قراءة.
  final DateTime? readAt;

  bool get isRead => readAt != null;

  NotificationTarget get target => type.target;

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    recipientId: recipientId,
    type: type,
    actorId: actorId,
    actorName: actorName,
    targetId: targetId,
    title: title,
    body: body,
    createdAt: createdAt,
    readAt: readAt ?? this.readAt,
  );

  /// خريطة الإنشاء — الحقول المسموح بها في القواعد فقط.
  Map<String, Object?> toCreateMap() {
    return <String, Object?>{
      'recipientId': recipientId,
      'type': type.wireName,
      'actorId': actorId,
      'actorName': actorName,
      'targetId': targetId,
      'title': title,
      if (body != null) 'body': body,
      'createdAt': createdAt,
    };
  }
}
