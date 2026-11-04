import 'package:teacher_student_app/core/config/app_identity.dart';

/// إعدادات التشغيل العامة للتطبيق.
///
/// كل ما هنا يُمرَّر وقت البناء عبر `--dart-define` ولا يحتوي أي سر.
/// مثال:
/// `flutter run --dart-define=ENABLE_FIREBASE=true`
abstract final class AppConfig {
  /// هل نحاول تهيئة Firebase عند الإقلاع؟
  ///
  /// الافتراضي `false` لأن مشروع Firebase لم يُنشأ بعد ولم تُولَّد
  /// `firebase_options.dart`. عند تفعيله ستحتاج الخطوات في
  /// `docs/FIREBASE_SETUP.md` أولًا.
  static const bool enableFirebase = bool.fromEnvironment(
    'ENABLE_FIREBASE',
    defaultValue: false,
  );

  /// تشغيل التطبيق في وضع العرض التجريبي (بيانات محلية وهمية).
  ///
  /// هذا هو الوضع الافتراضي في المرحلة 2: الواجهات تعمل بلا خادم.
  static bool get isDemoMode => !enableFirebase;

  /// اسم التطبيق المستخدم في السجلات والتشخيص (معرّف تقني، لا اسم تجاري).
  static const String appName = AppIdentity.technicalId;
}
