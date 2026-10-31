/// هوية البناء المعروضة في التطبيق (P29).
///
/// **لماذا يحتاج التطبيق أن يعرف رقم بنائه؟** لأن صاحب المشروع ثبّت نسخة قديمة
/// مرات متعددة وهو يظنها الجديدة (الاسم نفسه `app-arm64-v8a-release.apk` في كل
/// بناء). سطر إصدار واحد في «حسابي» يقطع الشك: إن لم يظهر الرقم المتوقع فالتطبيق
/// على الجهاز ليس البناء الأخير.
///
/// القيمة تُمرَّر وقت البناء عبر `--dart-define=APP_VERSION=<version>` من CI
/// (مأخوذة من `pubspec.yaml`)، فلا تنحرف عن الحقيقة أبدًا. وفي تشغيل محلي بلا
/// التعريف تبقى فارغة فيُخفى السطر (لا نعرض رقمًا مخترعًا).
library;

abstract final class AppBuildInfo {
  static const String version = String.fromEnvironment('APP_VERSION');

  /// نص السطر المعروض، أو سلسلة فارغة إن لم تُمرَّر قيمة (بناء محلي).
  static String get label =>
      version.isEmpty ? '' : 'الإصدار $version';

  static bool get isVisible => label.isNotEmpty;
}
