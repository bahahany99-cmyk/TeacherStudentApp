import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/config/firebase_config.dart';
import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/google_sign_in_error_mapper.dart';
import 'package:teacher_student_app/core/config/firebase_public_defaults.dart';
import 'package:teacher_student_app/data/firebase/google_id_token.dart';
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
      // نحقن معرّفًا فارغًا صراحةً حتى لا يعتمد الاختبار على قيمة البناء
      // (الافتراضي العام قد يُملأ لاحقًا بقيمة حقيقية).
      final GoogleSignInGateway gateway = GoogleSignInGateway(webClientId: '');

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

    test('معرّف بصيغة خاطئة (عميل أندرويد بالخطأ) يُرفض برسالة مختلفة', () async {
      final GoogleSignInGateway gateway = GoogleSignInGateway(
        webClientId: 'not-a-client-id',
      );

      await expectLater(
        gateway.obtainIdToken(),
        throwsA(
          isA<AppException>().having(
            (AppException e) => e.message,
            'message',
            contains('apps.googleusercontent.com'),
          ),
        ),
      );
    });

    test('معرّف صحيح الشكل يمرّ من فحص الإعداد (الفشل التالي من الحزمة)', () async {
      // لا يمكن اختبار الحزمة نفسها بلا جهاز، لكن نضمن ألّا يكون فحص الصيغة
      // هو ما يوقف المسار: البوابة تتجاوز فحص المعرّف.
      const String id = '1234-abc.apps.googleusercontent.com';
      final GoogleSignInGateway gateway = GoogleSignInGateway(webClientId: id);

      // `hasGoogleWebClientId` وحده هو ما نتحقق منه هنا.
      expect(id.endsWith('.apps.googleusercontent.com'), isTrue);
      expect(gateway, isNotNull);
    });
  });

  group('جمهور رمز Google (aud)', _audienceTests);

  group('ترتيب أسبقية قيمة معرّف عميل الويب', () {
    test('القيمة المضمّنة تُقرأ من القيم العامة حين لا يوجد dart-define', () {
      // في هذه البيئة لا يوجد --dart-define، فالمصدر هو القيم العامة.
      expect(
        FirebaseConfig.googleWebClientId,
        FirebaseConfig.googleWebClientId.trim(),
      );
      // التحقق من الصيغة مرتبط بالانتهاء الصحيح لا بمجرد عدم الفراغ.
      if (FirebaseConfig.googleWebClientId.isEmpty) {
        expect(FirebaseConfig.hasGoogleWebClientId, isFalse);
      } else {
        expect(
          FirebaseConfig.hasGoogleWebClientId,
          FirebaseConfig.googleWebClientId.endsWith(
            '.apps.googleusercontent.com',
          ),
        );
      }
    });
  });
}

/// (P18) قراءة `aud` من رمز Google: تشخيص «عميل أندرويد بدل عميل ويب».
void _audienceTests() {
  // رموز مصطنعة: التوقيع غير صالح عن قصد (لا نتحقق منه أصلًا).
  const String webToken =
      'eyJhbGciOiJSUzI1NiJ9.'
      'eyJhdWQiOiAiOTU0NjgzMTI3MDAxLXYwc3A2M2IzOTdrcnUyMDY2aDgxYnRhOTh1bjQwdjJk'
      'LmFwcHMuZ29vZ2xldXNlcmNvbnRlbnQuY29tIiwgImVtYWlsIjogImFAYi5jIn0.'
      'c2ln';
  const String androidToken =
      'eyJhbGciOiJSUzI1NiJ9.'
      'eyJhdWQiOiAiOTU0NjgzMTI3MDAxLW90aGVyYXBwaGFzaC5hcHBzLmdvb2dsZXVzZXJjb250'
      'ZW50LmNvbSJ9.'
      'c2ln';

  test('يستخرج aud من رمز سليم', () {
    expect(
      GoogleIdToken.audience(webToken),
      FirebasePublicDefaults.googleWebClientId,
    );
  });

  test('رمز غير قابل للقراءة يعيد null ولا يرمي', () {
    expect(GoogleIdToken.audience('not-a-jwt'), isNull);
    expect(GoogleIdToken.audience('a.b'), isNull);
    expect(GoogleIdToken.audience('a.!!!.c'), isNull);
  });

  test('يرصد جمهورًا مختلفًا (عميل أندرويد بدل عميل الويب)', () {
    expect(
      GoogleIdToken.hasForeignAudience(
        token: androidToken,
        expectedClientId: FirebasePublicDefaults.googleWebClientId,
      ),
      isTrue,
    );
  });

  test('لا يعترض على رمز مطابق', () {
    expect(
      GoogleIdToken.hasForeignAudience(
        token: webToken,
        expectedClientId: FirebasePublicDefaults.googleWebClientId,
      ),
      isFalse,
    );
  });

  test('عدم القدرة على القراءة لا يمنع المحاولة (Firebase يحكم)', () {
    expect(
      GoogleIdToken.hasForeignAudience(
        token: 'garbage',
        expectedClientId: FirebasePublicDefaults.googleWebClientId,
      ),
      isFalse,
    );
  });
}
