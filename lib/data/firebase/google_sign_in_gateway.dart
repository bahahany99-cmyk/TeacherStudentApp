import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:teacher_student_app/core/config/firebase_config.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/google_sign_in_error_mapper.dart';

/// عقد الحصول على `idToken` من Google عبر الـSDK الأصلي.
///
/// لماذا واجهة منفصلة عن الحزمة؟
/// - `FirebaseAuthService` يُختبر بلا جهاز ولا خدمة Google: يكفي مزيّف يعيد
///   رمزًا نصيًا.
/// - الحزمة (`google_sign_in`) لا تظهر خارج هذا الملف و`firebase_auth_service`،
///   فيبقى بقية المشروع مستقلًا عنها.
abstract interface class GoogleIdTokenProvider {
  /// يعرض قائمة حسابات Google المدمجة ويعيد `idToken` صالحًا لـFirebase.
  ///
  /// يرمي [AppException] عربية عند الإلغاء أو خطأ الإعداد أو انقطاع الشبكة.
  Future<String> obtainIdToken();

  /// تسجيل الخروج من Google (لا يُفشل عملية الخروج في التطبيق).
  Future<void> signOut();
}

/// التنفيذ الحقيقي فوق حزمة `google_sign_in` (v7 SDK الأصلي).
///
/// الفرق عن المسار القديم (`signInWithProvider`):
/// - القديم: يفتح متصفحًا/صفحة ويب ويعتمد على redirect ⇒ فشل على أندرويد
///   برسالة «لا يوجد اتصال بالإنترنت» رغم وجود شبكة.
/// - الجديد: واجهة Credential Manager الأصلية (نفس قائمة «اختر حسابًا» في
///   النظام) ثم نُمرّر `idToken` إلى Firebase عبر
///   `GoogleAuthProvider.credential`، فلا متصفح ولا redirect.
///
/// متطّلبات الإعداد (راجع docs/FIREBASE_SETUP.md §3.8):
/// 1. تسجيل بصمة SHA-1 لتطبيق أندرويد في مشروع Firebase (اسم الحزمة
///    `com.darsly.app`).
/// 2. تمرير معرّف عميل **الويب** في `--dart-define=FIREBASE_GOOGLE_WEB_CLIENT_ID`
///    لأنه هو جمهور (audience) الـ`idToken` الذي يقبله Firebase.
///
/// لا يحتاج `google-services.json` إطلاقًا، تمامًا كبقية إعداد Firebase هنا.
class GoogleSignInGateway implements GoogleIdTokenProvider {
  GoogleSignInGateway({GoogleSignIn? client}) : _injected = client;

  final GoogleSignIn? _injected;

  /// الحزمة تُحقن في الاختبارات فقط؛ في التشغيل نأخذ المفردة عند أول استخدام
  /// (لا نلمس `GoogleSignIn.instance` في الباني، حتى لا يتأثر أي اختبار واجهة
  /// بلا سكربت منصة).
  GoogleSignIn? _resolved;

  GoogleSignIn get _client => _resolved ??= (_injected ?? GoogleSignIn.instance);

  bool _initialized = false;

  @override
  Future<String> obtainIdToken() async {
    if (!FirebaseConfig.hasGoogleWebClientId) {
      // إعداد ناقص: رسالة صريحة الآن أفضل من فشل غامض داخل السكربت.
      throw const AppException(
        AppErrorKind.unavailable,
        debugMessage: 'FIREBASE_GOOGLE_WEB_CLIENT_ID is empty',
        overrideTitle: 'تسجيل الدخول بـGoogle غير مُهيّأ',
        overrideMessage:
            'معرّف عميل الويب (Web client ID) غير موجود في بناء التطبيق. '
            'أضِفه إلى الأسرار ثم أعد البناء (docs/FIREBASE_SETUP.md §3.8).',
      );
    }

    await _ensureInitialized();

    if (!_client.supportsAuthenticate()) {
      throw const AppException(
        AppErrorKind.unavailable,
        debugMessage: 'platform does not support authenticate()',
        overrideTitle: 'تسجيل الدخول بـGoogle غير مدعوم',
        overrideMessage: 'استخدم الدخول بالبريد الإلكتروني على هذا الجهاز.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await _client.authenticate();
    } on GoogleSignInException catch (error) {
      throw googleSignInCodeToException(
        error.code.name,
        debugMessage: error.description,
      );
    }

    // `idToken` يأتي فارغًا فقط عند نقص `serverClientId` أو إعداد غير مكتمل.
    final String? idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AppException(
        AppErrorKind.unavailable,
        debugMessage: 'google idToken is null/empty',
        overrideTitle: 'تعذّر إكمال الدخول بـGoogle',
        overrideMessage:
            'لم يصل رمز الهوية من Google. تحقّق من إعداد معرّف عميل الويب '
            'وبصمة SHA-1 (docs/FIREBASE_SETUP.md §3.8).',
      );
    }
    return idToken;
  }

  @override
  Future<void> signOut() async {
    // الخروج من التطبيق يجب أن ينجح حتى لو فشل الخروج من Google (مثلًا جهاز
    // بلا خدمات Play)؛ لا نرمي هنا.
    try {
      await _client.signOut();
    } on Object catch (error) {
      // تجاهل متعمد: Firebase هو مصدر الحقيقة للجلسة. نسجّل فقط للتشخيص.
      debugPrint('[GoogleSignInGateway] تعذّر الخروج من Google: $error');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }
    try {
      await _client.initialize(
        serverClientId: FirebaseConfig.googleWebClientId,
      );
      _initialized = true;
    } on GoogleSignInException catch (error) {
      throw googleSignInCodeToException(
        error.code.name,
        debugMessage: error.description,
      );
    }
  }
}
