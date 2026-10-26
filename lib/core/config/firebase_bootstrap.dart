import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'package:teacher_student_app/core/config/app_config.dart';

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

    try {
      // TODO(phase-3): بعد تنفيذ `flutterfire configure` استبدل السطر التالي بـ
      // Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
      // مع استيراد الملف المولَّد (المستثنى من Git).
      await Firebase.initializeApp();
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
