import 'package:firebase_core/firebase_core.dart';

import 'package:teacher_student_app/core/config/firebase_public_defaults.dart';

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

  /// معرّف عميل **الويب** في مشروع Firebase (P18).
  ///
  /// لماذا نحتاجه؟ `google_sign_in` على أندرويد لا يقرأ `google-services.json`
  /// عندنا (نمرّر إعدادات Firebase عبر `--dart-define` فقط)، فالسكربت الأصلي
  /// يحتاج `serverClientId` صريحًا ليُصدر `idToken` بجمهور (audience) صحيح
  /// يقبله Firebase. القيمة هي «Web client (auto created by Google Service)»
  /// من Google Cloud Console — راجع docs/FIREBASE_SETUP.md §3.8.
  ///
  /// ⚠️ ليست سرًا (تظهر في أي عميل ويب ومرفقة بكل APK).
  static const String _googleWebClientIdDefine = String.fromEnvironment(
    'FIREBASE_GOOGLE_WEB_CLIENT_ID',
  );

  /// معرّف عميل الويب الفعّال.
  ///
  /// الأفضلية: قيمة البناء (`--dart-define`) ثم الافتراضي العام في
  /// `FirebasePublicDefaults` (P18). وجود الافتراضي يجعل الدخول يعمل في أي
  /// بناء بلا أي إعداد من GitHub، والقيمة نُقطِّع المسافات احتياطًا عند اللصق.
  static String get googleWebClientId {
    final String defined = _googleWebClientIdDefine.trim();
    return defined.isNotEmpty
        ? defined
        : FirebasePublicDefaults.googleWebClientId.trim();
  }

  /// هل معرّف عميل الويب متاح **وبصيغة صحيحة**؟ بدونه لا يعمل الدخول الأصلي
  /// بـGoogle، فنُظهر رسالة إعداد واضحة بدل فشل غامض.
  static bool get hasGoogleWebClientId =>
      googleWebClientId.isNotEmpty &&
      googleWebClientId.endsWith(
        FirebasePublicDefaults.googleClientIdSuffix,
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
