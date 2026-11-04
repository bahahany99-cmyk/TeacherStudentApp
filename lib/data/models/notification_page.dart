import 'package:teacher_student_app/data/models/app_notification.dart';

/// صفحة واحدة من إشعارات المستلم (P32).
///
/// **لماذا كائن مستقل؟** لأن الشاشة تحتاج جوابين معًا: العناصر، وهل بقي أكثر
/// منها. إرجاع `List` وحدها كان سيجعل «لا توجد صفحة تالية» و«الصفحة الأخيرة
/// ممتلئة تمامًا» حالتين لا يُفرَّق بينهما، فتظهر «تحميل المزيد» بلا مزيد.
class NotificationPage {
  const NotificationPage({required this.items, required this.hasMore});

  /// عناصر الصفحة، الأحدث أولًا، وبلا تكرار.
  final List<AppNotification> items;

  /// هل يوجد على الأغلب إشعار أقدم لم يُقرأ بعد؟
  final bool hasMore;

  static const NotificationPage empty = NotificationPage(
    items: <AppNotification>[],
    hasMore: false,
  );
}
