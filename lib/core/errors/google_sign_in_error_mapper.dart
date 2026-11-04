import 'package:teacher_student_app/core/errors/app_exception.dart';

/// ترجمة رموز `google_sign_in` (v7) إلى رسائل عربية صالحة للعرض.
///
/// لماذا دالة مستقلة بلا استيراد الحزمة؟
/// - قابلة للاختبار بلا جهاز ولا خدمة Google (الاختبارات لا تلمس سكربت المنصة).
/// - ثابتة أمام تغيّر الحزمة: نستقبل اسم الرمز نصًّا (`error.code.name`) لا
///   نوعه، فلا ينكسر الملف إن أضافت Google رمزًا جديدًا.
///
/// الأعراض الشائعة على أندرويد (من توثيق الحزمة الرسمي):
/// - `clientConfigurationError` ⇒ بصمة SHA-1 غير مسجّلة، أو اسم الحزمة خطأ،
///   أو `serverClientId` ناقص/خاطئ.
/// - `canceled` بعد اختيار الحساب ⇒ كثيرًا ما يكون **خطأ إعداد** لا إلغاء
///   حقيقيًا؛ لأن Credential Manager يبلّغ عن أخطاء الإعداد هكذا. لذلك نُظهر
///   رسالة تُذكّر بالإعداد بدل الاكتفاء بـ«أُلغي».
AppException googleSignInCodeToException(String code, {String? debugMessage}) {
  switch (code) {
    case 'canceled':
      return AppException(
        AppErrorKind.canceled,
        debugMessage: debugMessage,
        overrideMessage:
            'لم يكتمل تسجيل الدخول. إن اخترت حسابك وتوقفت العملية، فتأكد أن '
            'بصمة التوقيع مسجّلة في Firebase ثم أعد المحاولة.',
      );

    case 'clientConfigurationError':
      return AppException(
        AppErrorKind.unavailable,
        debugMessage: debugMessage,
        overrideTitle: 'إعداد Google غير مكتمل',
        overrideMessage:
            'بصمة التطبيق (SHA-1) أو معرّف عميل الويب غير مُسجَّل في Firebase. '
            'راجع docs/FIREBASE_SETUP.md §3.8.',
      );

    case 'providerConfigurationError':
      return AppException(
        AppErrorKind.unavailable,
        debugMessage: debugMessage,
        overrideTitle: 'خدمة Google غير متاحة على هذا الجهاز',
        overrideMessage:
            'حدّث «خدمات Google Play» ثم أعد المحاولة، أو استخدم البريد '
            'الإلكتروني.',
      );

    case 'uiUnavailable':
      return AppException(
        AppErrorKind.unavailable,
        debugMessage: debugMessage,
        overrideTitle: 'تعذّر عرض قائمة الحسابات',
        overrideMessage: 'أعد المحاولة بعد لحظات، أو استخدم البريد الإلكتروني.',
      );

    case 'interrupted':
      return AppException(
        AppErrorKind.network,
        debugMessage: debugMessage,
        overrideTitle: 'انقطعت عملية تسجيل الدخول',
        overrideMessage: 'تحقّق من الاتصال ثم أعد المحاولة.',
      );

    case 'userMismatch':
      return AppException(
        AppErrorKind.permission,
        debugMessage: debugMessage,
        overrideTitle: 'حساب Google مختلف',
        overrideMessage: 'سجّل الخروج من الحساب الحالي أولًا ثم أعد المحاولة.',
      );

    default:
      return AppException(
        AppErrorKind.unknown,
        debugMessage: debugMessage == null ? code : '$code: $debugMessage',
      );
  }
}
