import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/config/firebase_config.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/google_sign_in_error_mapper.dart';
import 'package:teacher_student_app/data/firebase/google_sign_in_gateway.dart';

/// (P18) اختبارات مسار الدخول الأصلي بـGoogle بلا جهاز ولا خدمة Google.
///
/// ما **يمكن** التحقق منه هنا حقيقةً:
/// - ترجمة رموز الأخطاء (دالة نقية، لا تعتمد على الحزمة).
/// - سلوك البوابة عند غياب معرّف عميل الويب (لا تُلمس الحزمة أصلًا).
///
/// ما **لا يمكن** التحقق منه إلا على جهاز حقيقي: ظهور قائمة الحسابات فعلًا.
void main() {
  group('ترجمة رموز google_sign_in', () {
    test('الإلغاء نوع مستقل وليس خطأً', () {
      final AppException failure = googleSignInCodeToException('canceled');

      expect(failure.kind, AppErrorKind.canceled);
      expect(failure.title, 'أُلغي تسجيل الدخول');
      // الرسالة تذكّر بأن الأعراض نفسها قد تكون خطأ إعداد (توثيق الحزمة).
      expect(failure.message, contains('بصمة التوقيع'));
    });

    test('clientConfigurationError يشرح مشكلة الإعداد لا مشكلة شبكة', () {
      final AppException failure = googleSignInCodeToException(
        'clientConfigurationError',
      );

      expect(failure.kind, AppErrorKind.unavailable);
      expect(failure.title, contains('إعداد Google'));
      expect(failure.message, contains('SHA-1'));
      // لا نكشف نص الخطأ الإنجليزي للمستخدم.
      expect(failure.message, isNot(contains('clientConfigurationError')));
    });

    test('interrupted يُعامل كانقطاع اتصال', () {
      expect(
        googleSignInCodeToException('interrupted').kind,
        AppErrorKind.network,
      );
    });

    test('uiUnavailable و providerConfigurationError غير متاحين', () {
      expect(
        googleSignInCodeToException('uiUnavailable').kind,
        AppErrorKind.unavailable,
      );
      expect(
        googleSignInCodeToException('providerConfigurationError').kind,
        AppErrorKind.unavailable,
      );
    });

    test('userMismatch صلاحية', () {
      expect(
        googleSignInCodeToException('userMismatch').kind,
        AppErrorKind.permission,
      );
    });

    test('رمز غير معروف لا يُسقط التطبيق ويحتفظ بالرمز للتشخيص', () {
      final AppException failure = googleSignInCodeToException(
        'somethingNewFromGoogle',
        debugMessage: 'boom',
      );

      expect(failure.kind, AppErrorKind.unknown);
      expect(failure.debugMessage, contains('somethingNewFromGoogle'));
      expect(failure.debugMessage, contains('boom'));
    });
  });

  group('بوابة Google الأصلية', () {
    test('بلا معرّف عميل ويب: رسالة إعداد واضحة ولا لمس للحزمة', () async {
      // الاختبار يعمل بلا --dart-define، أي أن المعرّف فارغ هنا فعليًا.
      expect(FirebaseConfig.hasGoogleWebClientId, isFalse);

      final GoogleSignInGateway gateway = GoogleSignInGateway();

      await expectLater(
        gateway.obtainIdToken(),
        throwsA(
          isA<AppException>()
              .having((AppException e) => e.kind, 'kind', AppErrorKind.unavailable)
              .having(
                (AppException e) => e.title,
                'title',
                contains('غير مُهيّأ'),
              ),
        ),
      );
    });
  });
}
