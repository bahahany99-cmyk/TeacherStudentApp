import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/errors/firebase_error_mapper.dart';
import 'package:teacher_student_app/core/errors/request_timeout.dart';

/// اختبارات الصمود (P16): المهلة، وترجمة الأخطاء، وخلوّ أي رسالة من نص تقني.
bool _hasLatinLetters(String value) => RegExp(r'[A-Za-z]').hasMatch(value);

bool _hasArabicLetters(String value) =>
    RegExp(r'[\u0600-\u06FF]').hasMatch(value);

void main() {
  group('مهلة الطلب (P16)', () {
    test('الطلب السريع يمرّ كما هو', () async {
      final int value = await withRequestTimeout<int>(() async => 7);
      expect(value, 7);
    });

    test('الطلب الذي لا ينتهي يصبح خطأ شبكة عربيًا', () async {
      // مستقبل لا يكتمل أبدًا ولا يحمل مؤقتًا: أقرب شيء لطلب ضاع في الشبكة.
      final Completer<void> never = Completer<void>();
      final Future<void> pending = withRequestTimeout<void>(
        () => never.future,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        pending,
        throwsA(
          isA<AppException>()
              .having(
                (AppException error) => error.kind,
                'kind',
                AppErrorKind.network,
              )
              .having((AppException error) => error.title, 'title', contains('مهلة'))
              .having(
                (AppException error) => error.message,
                'message',
                contains('أعد المحاولة'),
              ),
        ),
      );
    });

    test('لا يعيد تغليف خطأ تطبيقي موجود', () async {
      const AppException original = AppException.permission(
        overrideTitle: 'ممنوع',
      );

      await expectLater(
        withRequestTimeout<void>(() async => throw original),
        throwsA(same(original)),
      );
    });
  });

  group('ترجمة أخطاء Firebase (P16)', () {
    const List<String> codes = <String>[
      'network-request-failed',
      'unavailable',
      'permission-denied',
      'too-many-requests',
      'user-not-found',
      'wrong-password',
      'requires-recent-login',
      'invalid-email',
      'internal',
    ];

    test('كل رمز يصل برسالة عربية بلا حروف لاتينية', () {
      for (final String code in codes) {
        final AppException error = firebaseCodeToException(code);
        expect(
          _hasArabicLetters(error.title),
          isTrue,
          reason: 'العنوان يجب أن يكون عربيًا للرمز $code',
        );
        expect(
          _hasArabicLetters(error.message),
          isTrue,
          reason: 'الشرح يجب أن يكون عربيًا للرمز $code',
        );
        expect(
          _hasLatinLetters(error.title) || _hasLatinLetters(error.message),
          isFalse,
          reason: 'لا نص تقني إنجليزي يصل للمستخدم ($code)',
        );
      }
    });

    test('انقطاع الشبكة يُصنّف شبكيًا والتكرار يُصنّف «غير متاح»', () {
      expect(
        firebaseCodeToException('network-request-failed').kind,
        AppErrorKind.network,
      );
      expect(firebaseCodeToException('unavailable').kind, AppErrorKind.network);
      expect(
        firebaseCodeToException('too-many-requests').kind,
        AppErrorKind.unavailable,
      );
      expect(
        firebaseCodeToException('permission-denied').kind,
        AppErrorKind.permission,
      );
    });

    test('فشل الدخول لا يكشف إن كان البريد مسجّلًا', () {
      final AppException missing = firebaseCodeToException('user-not-found');
      final AppException wrong = firebaseCodeToException('wrong-password');

      expect(missing.title, wrong.title);
      expect(missing.message, wrong.message);
      expect(_hasLatinLetters(missing.message), isFalse);
    });

    test('رمز مجهول لا يُظهر الرمز نفسه للمستخدم', () {
      final AppException error = firebaseCodeToException(
        'some-new-internal-code',
        debugMessage: 'stack trace',
      );

      expect(error.kind, AppErrorKind.unknown);
      expect(error.title.contains('some-new-internal-code'), isFalse);
      expect(error.message.contains('some-new-internal-code'), isFalse);
      // لكنه محفوظ للتشخيص.
      expect(error.debugMessage, contains('some-new-internal-code'));
    });
  });

  group('جودة الرسائل (P16)', () {
    test('كل نوع خطأ له عنوان وشرح عربي غير فارغ', () {
      for (final AppErrorKind kind in AppErrorKind.values) {
        final AppException error = AppException(kind);
        expect(error.title.trim(), isNotEmpty, reason: 'عنوان ${kind.name}');
        expect(error.message.trim(), isNotEmpty, reason: 'شرح ${kind.name}');
        expect(_hasArabicLetters(error.title), isTrue, reason: kind.name);
        expect(_hasArabicLetters(error.message), isTrue, reason: kind.name);
      }
    });

    test('أي استثناء غير معروف يُغلَّف برسالة عربية', () {
      final AppException wrapped = toAppException(
        StateError('database exploded at line 42'),
      );

      expect(wrapped.kind, AppErrorKind.unknown);
      expect(_hasLatinLetters(wrapped.message), isFalse);
      expect(wrapped.message.contains('exploded'), isFalse);
    });

    test('الخطأ التطبيقي يمرّ بلا تغليف', () {
      const AppException original = AppException.notFound(
        overrideMessage: 'الملف غير موجود.',
      );
      expect(toAppException(original), same(original));
    });
  });
}
