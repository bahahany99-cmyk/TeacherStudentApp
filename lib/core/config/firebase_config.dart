import 'package:firebase_core/firebase_core.dart';

/// إعدادات مشروع Firebase، تأتي **وقت البناء** عبر `--dart-define`.
///
/// لماذا لا نقرأ `google-services.json`؟
/// - ملف المنصة يُطبَّع في Gradle، ويجعل بناء APK يفشل إن لم يوجد الملف.
/// - تمرير الخيارات هنا يبقي المستودع قابلًا للبناء والاختبار بلا أي ملف
///   أسرار، ويسمح بتشغيل النسخة التجريبية.
///
/// ⚠️ تنبيه أمني مقصود: هذه القيم **معرّفات عميل** وليست أسرارًا (تظهر داخل
/// أي تطبيق Firebase)، لكنها ما زالت غير مرفوعة في Git حتى لا يرتبط المستودع
/// بمشروع بعينه. لا تضع هنا أي مفتاح خدمة (service account) إطلاقًا.
///
/// مثال تشغيل:
/// ```
/// flutter run \
///   --dart-define=ENABLE_FIREBASE=true \
///   --dart-define=FIREBASE_PROJECT_ID=... \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_STORAGE_BUCKET=...
/// ```
abstract final class FirebaseConfig {
  static const String projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const String apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const String storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  /// الحد الأدنى الذي يسمح بتهيئة Firebase: معرّف المشروع ومفتاح الـAPI
  /// ومعرّف التطبيق والمرسل.
  static bool get hasOptions =>
      projectId.isNotEmpty &&
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );

  /// منطقة المكوّنات المختارة (قرار صاحب المشروع 2026-10-27).
  ///
  /// للتوثيق فقط: تُضبط في Firebase Console ولا يقرأها التطبيق.
  static const String firestoreRegion = 'me-central1';
}
