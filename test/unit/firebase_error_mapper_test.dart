import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';

void main() {
  group('ترجمة أخطاء Firebase', () {
    test('البريد غير الصالح وكلمة المرور الضعيفة ← مدخلات غير صالحة', () {
      final AppException badEmail = firebaseCodeToException('invalid-email');
      final AppException weak = firebaseCodeToException('weak-password');

      expect(badEmail.kind, AppErrorKind.invalidInput);
      expect(badEmail.title, 'البريد غير صالح');
      expect(weak.kind, AppErrorKind.invalidInput);
      expect(weak.message.contains('6'), isTrue);
    });

    test('لا نفرّق بين بريد غير مسجّل وكلمة مرور خاطئة', () {
      final AppException missing = firebaseCodeToException('user-not-found');
      final AppException wrong = firebaseCodeToException('wrong-password');
      final AppException invalid = firebaseCodeToException('invalid-credential');

      // نفس العنوان ونفس الشرح: حتى لا يُستخدم التطبيق لمعرفة البُرد المسجّلة.
      expect(missing.title, wrong.title);
      expect(missing.message, wrong.message);
      expect(invalid.title, wrong.title);
      expect(missing.title, 'تعذّر تسجيل الدخول');
    });

    test('البريد المسجّل مسبقًا له رسالة مختلفة', () {
      final AppException exists = firebaseCodeToException(
        'email-already-in-use',
      );

      expect(exists.kind, AppErrorKind.invalidInput);
      expect(exists.title, 'البريد مسجّل بالفعل');
    });

    test('مشاكل الشبكة تُصنَّف شبكة', () {
      expect(
        firebaseCodeToException('network-request-failed').kind,
        AppErrorKind.network,
      );
      expect(
        firebaseCodeToException('unavailable').kind,
        AppErrorKind.network,
      );
    });

    test('المزود غير المفعّل والحساب الموقوف لهما رسالتان واضحتان', () {
      final AppException notEnabled = firebaseCodeToException(
        'operation-not-allowed',
      );
      final AppException disabled = firebaseCodeToException('user-disabled');

      expect(notEnabled.kind, AppErrorKind.unavailable);
      expect(notEnabled.message.contains('Firebase Console'), isTrue);
      expect(disabled.kind, AppErrorKind.permission);
    });

    test('رفض الصلاحية يُصنَّف صلاحية', () {
      expect(
        firebaseCodeToException('permission-denied').kind,
        AppErrorKind.permission,
      );
    });

    test('الرمز المجهول لا يكشف تفاصيل إنجليزية للمستخدم', () {
      final AppException unknown = firebaseCodeToException(
        'some-new-code',
        debugMessage: 'internal detail',
      );

      expect(unknown.kind, AppErrorKind.unknown);
      expect(unknown.title, 'حدث خطأ غير متوقع');
      // التفاصيل تبقى للتشخيص فقط، وليست في نص العرض.
      expect(unknown.message.contains('some-new-code'), isFalse);
      expect(unknown.debugMessage, contains('some-new-code'));
    });
  });
}
