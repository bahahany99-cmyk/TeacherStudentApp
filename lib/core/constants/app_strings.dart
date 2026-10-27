import 'package:teacher_student_app/core/config/app_identity.dart';

/// نصوص عامة مشتركة بين الشاشات.
///
/// النصوص الخاصة بكل شاشة تبقى داخل ملف الشاشة (لأنها قصيرة ومحلية)، أما
/// النصوص المتكرّرة أو التي ستُترجم مستقبلًا فتُجمع هنا.
abstract final class AppStrings {
  /// الاسم الظاهر — مؤقت، ويأتي من [AppIdentity] وليس من هنا.
  static const String appName = AppIdentity.displayName;
  static const String appTagline = AppIdentity.tagline;

  /// نص «وضع الزائر»: يوضّح أن التطبيق يعمل ببيانات محلية بلا حساب ولا خادم.
  static const String demoBanner =
      'وضع الزائر: بيانات تجريبية محلية بلا حساب ولا اتصال بخادم.';

  /// النسخة القصيرة التي تظهر في الشريحة الدقيقة أعلى الصفحة.
  /// النص الكامل أعلاه يبقى لقارئ الشاشة (صدق المعلومة بلا إزعاج بصري).
  static const String demoBannerShort = 'وضع الزائر · بيانات تجريبية';

  static const String comingSoon = 'غير مفعّل في هذه المرحلة';
  static const String retry = 'إعادة المحاولة';
  static const String loading = 'جارٍ التحميل…';
  static const String unknownRoute = 'الصفحة غير موجودة';
  static const String backToHome = 'العودة للرئيسية';
}
