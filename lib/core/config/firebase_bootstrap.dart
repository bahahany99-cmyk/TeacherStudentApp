import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/core/config/app_config.dart';
import 'package:teacher_student_app/core/config/firebase_config.dart';

/// حالة تهيئة Firebase.
enum FirebaseStatus {
  /// لم تُطلب التهيئة أصلًا (الوضع التجريبي الافتراضي).
  disabled,

  /// التهيئة نجحت.
  ready,

  /// طُلبت التهيئة وفشلت (غالبًا: لا يوجد مشروع Firebase معدّ).
  failed,
}

/// نقطة التهيئة الوحيدة لـ Firebase.
///
/// مبدأ التصميم:
/// - لا تستورد طبقة الواجهات `firebase_core` إطلاقًا؛ فقط هذه النقطة وطبقة
///   الخدمات تعرف عنه شيئًا.
/// - فشل التهيئة **لا يمنع** تشغيل التطبيق؛ يُسجَّل وتُعرض الواجهة التجريبية،
///   لأن التطبيق في هذه المرحلة لا يملك مشروع Firebase بعد.
///
/// ملاحظات أمنية:
/// - لا يوجد أي مفتاح أو سر هنا. الإعدادات الحقيقية تأتي من ملفات المنصة
///   (`google-services.json` / `firebase_options.dart`) وهي **مستثناة من Git**.
/// - لا تُستخدم أي بيانات اعتماد إدارية (service account) داخل تطبيق Android.
abstract final class FirebaseBootstrap {
  static FirebaseStatus _status = FirebaseStatus.disabled;

  static FirebaseStatus get status => _status;

  /// سبب الفشل - لأغراض التشخيص فقط، لا يُعرض للمستخدم النهائي.
  static String? lastError;

  /// تُستدعى مرة واحدة من `bootstrap()` قبل `runApp`.
  static Future<void> initialize() async {
    if (!AppConfig.enableFirebase) {
      _status = FirebaseStatus.disabled;
      return;
    }

    if (!FirebaseConfig.hasOptions) {
      // طُلب التفعيل بلا إعدادات: نفشل بوضوح بدل محاولة صامتة تفشل لاحقًا
      // في شاشة الدخول برسالة غامضة.
      _status = FirebaseStatus.failed;
      lastError =
          'ENABLE_FIREBASE=true لكن إعدادات FirebaseConfig ناقصة. '
          'راجع docs/FIREBASE_SETUP.md ومرّر قيم --dart-define.';
      debugPrint('[FirebaseBootstrap] $lastError');
      return;
    }

    try {
      // النمط المعتمد: خيارات صريحة من `--dart-define`، بلا google-services.json
      // في Git. (FlutterFire CLI يولّد firebase_options.dart بنفس القيم.)
      await Firebase.initializeApp(options: FirebaseConfig.options);
      _status = FirebaseStatus.ready;
      lastError = null;
    } on Object catch (error) {
      // لا نعيد رمي الخطأ: التطبيق يعمل بواجهات تجريبية حتى يُجهَّز المشروع.
      _status = FirebaseStatus.failed;
      lastError = error.toString();
      debugPrint('[FirebaseBootstrap] تهيئة Firebase فشلت: $lastError');
    }
  }
}
