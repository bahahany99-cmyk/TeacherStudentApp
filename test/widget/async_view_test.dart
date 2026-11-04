import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/core/widgets/error_state.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AsyncView — الحالات الأربع', () {
    testWidgets('يعرض حالة التحميل أثناء الانتظار', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          AsyncView<List<String>>(
            load: () => Future<List<String>>.delayed(
              const Duration(seconds: 5),
              () => <String>[],
            ),
            builder: (BuildContext context, List<String> data) =>
                const Text('بيانات'),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جارٍ التحميل…'), findsOneWidget);

      // نُنهي المؤقّت حتى لا يبقى معلّقًا بعد الاختبار.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('يعرض البيانات بعد نجاح الطلب', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          AsyncView<List<String>>(
            load: () => Future<List<String>>.value(<String>['بيانات']),
            builder: (BuildContext context, List<String> data) =>
                Text(data.first),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بيانات'), findsOneWidget);
    });

    testWidgets('يعرض الحالة البديلة عند نتيجة فارغة', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AsyncView<List<String>>(
            load: () => Future<List<String>>.value(<String>[]),
            isEmpty: (List<String> data) => data.isEmpty,
            emptyBuilder: (BuildContext context) => const EmptyState(
              icon: Icons.groups_outlined,
              title: 'لا توجد مجموعات',
            ),
            builder: (BuildContext context, List<String> data) =>
                const Text('لن يظهر'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مجموعات'), findsOneWidget);
      expect(find.text('لن يظهر'), findsNothing);
    });

    testWidgets('خطأ الشبكة يظهر عربيًا ثم ينجح بعد إعادة المحاولة', (
      WidgetTester tester,
    ) async {
      int attempts = 0;

      Future<List<String>> load() {
        attempts++;
        if (attempts == 1) {
          return Future<List<String>>.error(const AppException.network());
        }
        return Future<List<String>>.value(<String>['بيانات']);
      }

      await tester.pumpWidget(
        _wrap(
          AsyncView<List<String>>(
            load: load,
            builder: (BuildContext context, List<String> data) =>
                Text(data.first),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.text('تحقّق من الاتصال ثم أعد المحاولة.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'إعادة المحاولة'));
      await tester.pumpAndSettle();

      // الزر يعيد الجلب من المصدر فعلًا.
      expect(attempts, 2);
      expect(find.text('بيانات'), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    });

    testWidgets('خطأ غير متوقّع لا يكشف تفاصيل تقنية', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AsyncView<List<String>>(
            load: () =>
                Future<List<String>>.error(StateError('SQLITE_IO_ERROR')),
            builder: (BuildContext context, List<String> data) =>
                const Text('لن يظهر'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('حدث خطأ غير متوقع'), findsOneWidget);
      expect(find.textContaining('SQLITE_IO_ERROR'), findsNothing);
      expect(find.text('لن يظهر'), findsNothing);
    });
  });

  group('ErrorState — نوع الخطأ يحدّد الرسالة', () {
    Future<void> pumpError(WidgetTester tester, Object error) async {
      await tester.pumpWidget(
        _wrap(ErrorState(error: error, onRetry: () {})),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('خطأ الصلاحية له عنوان وشرح مختلفان', (
      WidgetTester tester,
    ) async {
      await pumpError(tester, const AppException.permission());

      expect(find.text('لا تملك صلاحية لهذا المحتوى'), findsOneWidget);
      expect(find.text('إذا كنت تعتقد أن هذا خطأ، تواصل مع الدعم.'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('العنصر المفقود له رسالة مختلفة', (WidgetTester tester) async {
      await pumpError(tester, const AppException.notFound());

      expect(find.text('العنصر غير موجود'), findsOneWidget);
      expect(find.text('ربما تم حذفه أو تغيّر الرابط.'), findsOneWidget);
    });

    testWidgets('زر إعادة المحاولة يُستدعى فعلًا', (WidgetTester tester) async {
      int retries = 0;
      await tester.pumpWidget(
        _wrap(
          ErrorState(
            error: const AppException.network(),
            onRetry: () => retries++,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextButton, 'إعادة المحاولة'));
      expect(retries, 1);
    });

    testWidgets('بدون onRetry لا يظهر زر', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const ErrorState(error: AppException.notFound())),
      );

      expect(find.widgetWithText(TextButton, 'إعادة المحاولة'), findsNothing);
    });
  });

  group('AppException', () {
    test('يحوّل أي خطأ غير معروف إلى رسالة عامة', () {
      final AppException failure = toAppException(StateError('تفاصيل داخلية'));

      expect(failure.kind, AppErrorKind.unknown);
      expect(failure.title, 'حدث خطأ غير متوقع');
      // التفاصيل التقنية لا تظهر في الرسائل المعروضة.
      expect(failure.message.contains('تفاصيل داخلية'), isFalse);
    });

    test('يمرّر AppException كما هو', () {
      const AppException original = AppException.notFound();
      expect(toAppException(original), same(original));
    });
  });
}
