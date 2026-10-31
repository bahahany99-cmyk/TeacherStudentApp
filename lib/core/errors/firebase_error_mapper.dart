import 'package:teacher_student_app/core/errors/app_exception.dart';

/// ترجمة رموز Firebase إلى رسائل عربية صالحة للعرض.
///
/// لماذا دالة مستقلة بلا استيراد Firebase؟
/// - قابلة للاختبار بلا مشروع Firebase ولا شبكة.
/// - تمنع تسرّب نصوص Firebase الإنجليزية أو تفاصيل تقنية إلى المستخدم.
///
/// ملاحظة أمنية: لا نكشف أي فرق بين «البريد غير مسجّل» و«كلمة المرور خاطئة»،
/// حتى لا يُستخدم التطبيق لمعرفة البُرد المسجّلة.
AppException firebaseCodeToException(String code, {String? debugMessage}) {
  switch (code) {
    case 'invalid-email':
      return AppException(
        AppErrorKind.invalidInput,
        debugMessage: debugMessage,
        overrideTitle: 'البريد غير صالح',
        overrideMessage: 'اكتب بريدًا إلكترونيًا بصيغة صحيحة.',
      );

    case 'weak-password':
      return AppException(
        AppErrorKind.invalidInput,
        debugMessage: debugMessage,
        overrideTitle: 'كلمة المرور ضعيفة',
        overrideMessage: 'استخدم 6 أحرف على الأقل.',
      );

    case 'missing-password':
      return AppException(
        AppErrorKind.invalidInput,
        debugMessage: debugMessage,
        overrideTitle: 'كلمة المرور مطلوبة',
      );

    case 'email-already-in-use':
      return AppException(
        AppErrorKind.invalidInput,
        debugMessage: debugMessage,
        overrideTitle: 'البريد مسجّل بالفعل',
        overrideMessage: 'هذا البريد له حساب. جرّب تسجيل الدخول بدل إنشاء حساب.',
      );

    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
    case 'invalid-login-credentials':
      return AppException(
        AppErrorKind.invalidInput,
        debugMessage: debugMessage,
        overrideTitle: 'تعذّر تسجيل الدخول',
        overrideMessage: 'تحقّق من البريد الإلكتروني وكلمة المرور.',
      );

    case 'user-disabled':
      return AppException(
        AppErrorKind.permission,
        debugMessage: debugMessage,
        overrideTitle: 'الحساب موقوف',
        overrideMessage: 'تواصل مع الدعم لمعرفة السبب.',
      );

    case 'operation-not-allowed':
      return AppException(
        AppErrorKind.unavailable,
        debugMessage: debugMessage,
        overrideTitle: 'طريقة الدخول غير مُفعّلة',
        overrideMessage:
            'هذه الطريقة غير مُفعّلة في إعدادات المشروع. فعّلها من Firebase '
            'Console (Authentication ← Sign-in method).',
      );

    // (P18) أخطاء خاصة ببيانات اعتماد Google لا بالبريد/كلمة المرور.
    // وجودها هنا يمنع رسالة مضلِّلة مثل «تحقّق من البريد وكلمة المرور» لمن
    // سجّل الدخول بـGoogle أصلًا.
    case 'invalid-idp-response':
    case 'invalid-provider-id':
      return AppException(
        AppErrorKind.unavailable,
        debugMessage: debugMessage,
        overrideTitle: 'تعذّر التحقق من حساب Google',
        overrideMessage:
            'بيانات اعتماد Google لم تُقبل. تحقّق أن معرّف عميل الويب هو '
            '«Web client» من نفس مشروع Firebase، وأن بصمة SHA-1 مسجّلة '
            '(docs/FIREBASE_SETUP.md §3.8).',
      );

    case 'account-exists-with-different-credential':
      return AppException(
        AppErrorKind.invalidInput,
        debugMessage: debugMessage,
        overrideTitle: 'الحساب موجود بطريقة دخول أخرى',
        overrideMessage: 'سجّل الدخول بنفس الطريقة التي استخدمتها سابقًا.',
      );

    case 'requires-recent-login':
      return AppException(
        AppErrorKind.permission,
        debugMessage: debugMessage,
        overrideTitle: 'أعد تسجيل الدخول',
        overrideMessage: 'هذه العملية تحتاج تسجيل دخول حديث.',
      );

    case 'network-request-failed':
    case 'unavailable':
      return AppException(
        AppErrorKind.network,
        debugMessage: debugMessage,
      );

    case 'too-many-requests':
      return AppException(
        AppErrorKind.unavailable,
        debugMessage: debugMessage,
        overrideTitle: 'محاولات كثيرة جدًا',
        overrideMessage: 'انتظر قليلًا ثم أعد المحاولة.',
      );

    case 'permission-denied':
      return AppException(
        AppErrorKind.permission,
        debugMessage: debugMessage,
      );

    default:
      return AppException(
        AppErrorKind.unknown,
        debugMessage: debugMessage == null ? code : '$code: $debugMessage',
      );
  }
}
