/// قيم **عامة غير سرية** من مشروع Firebase، مضمّنة في الكود عن قصد.
///
/// لماذا يُلصق معرّف عميل الويب هنا بدل الاكتفاء بـ`--dart-define`؟
/// - هو **ليس سرًا**: يظهر لأي شخص داخل أي APK أو صفحة ويب تُهيَّأ
///   Firebase — نفس مرتبة `FIREBASE_API_KEY` التي تمرّ في كل نسخة.
/// - كان المصدر الوحيد له هو سر GitHub، وفشل بناءان متتاليان في رؤيته
///   (الاسم/التبويب)، وتوقف تسجيل الدخول بـGoogle على هذا الشرط وحده.
/// - وجوده هنا يجعل الزر يعمل في **أي** بناء: CI، أو `flutter run` محلي، أو
///   نسخة يعطيها صاحب المشروع لشخص آخر.
///
/// ترتيب الأفضلية في `FirebaseConfig`:
///   1) `--dart-define=FIREBASE_GOOGLE_WEB_CLIENT_ID=…` (يتقدّم دائمًا، لمشروع
///      Firebase آخر أو اختبار).
///   2) القيمة أدناه (الافتراضي للتشغيل العادي).
///
/// ⚠️ ما **لا** يجوز وضعه في هذا الملف إطلاقًا: مفتاح خدمة
/// (service account)، كلمة مرور، أو أي سرّ حقيقي.
abstract final class FirebasePublicDefaults {
  /// معرّف عميل **الويب** (Web client ID) — جمهور الـ`idToken` الذي يقبله
  /// Firebase. الشكل: `<number>-<hash>.apps.googleusercontent.com`
  ///
  /// فارغ يعني: لم يُلصق بعد ⇒ `hasGoogleWebClientId == false` ويظهر للمستخدم
  /// تنبيه إعداد واضح بدل فشل غامض.
  /// المصدر: `google-services.json` → عنصر `oauth_client` ذو
  /// `"client_type": 3` (عميل الويب)، لصقه صاحب المشروع 2026-10-29.
  // سطر واحد عن قصد (والسطر طويل): خطوة CI تستخرج القيمة من هذا الملف
  // بتعبير نمطي. أي تقسيم على سطرين يجعل الاستخراج يفشل.
  static const String googleWebClientId = '954683127001-v0sp63b397kru2066h81bta98un40v2d.apps.googleusercontent.com';

  /// لاحقة معرّفات عميل Google الصحيحة — تُستخدم للتحقق من أن القيمة الملصوقة
  /// ليست معرّف تطبيق أندرويد (الذي ينتهي بـ`.apps.googleusercontent.com` أيضًا
  /// لكنه ليس هو المطلوب) ولا قيمة مقطوعة.
  static const String googleClientIdSuffix = '.apps.googleusercontent.com';
}
