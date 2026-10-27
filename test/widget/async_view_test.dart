import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/errors/app_exception.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';

void main() {
  group('AsyncView — الحالات الأربع', () {
    testWidgets('يعرض حالة التحميل أثناء الانتظار', (WidgetTester tester) async {
      final Future<List<String>> never = Future<List<String>>.delayed(
        const Duration(seconds: 5),
        () => <String>[],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AsyncView<List<String>>(
              future: never,
              builder: (BuildContext context, List<String> data) =>
                  const Text('تم'),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('جارٍ التحميل…'), findsOneWidget);

      // ننهي المستقبل المعلّق حتى لا يبقى مؤقّت مفتوح في الاختبار.
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('يعرض خطأ عربيًا وزر إعادة المحاولة ثم ينجح', (
      WidgetTester tester,
    ) async {
      int attempts = 0;
      Future<List<String>>? pending;

      Future<List<String>> load() {
        attempts++;
        if (attempts == 1) {
          return Future<List<String>>.error(const AppException.network());
        }
        return Future<List<String>>.value(<String>['بيانات']);
      }

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                pending ??= load();
                return AsyncView<List<String>>(
                  future: pending!,
                  onRetry: () => setState(() => pending = load()),
                  builder: (BuildContext context, List<String> data) =>
                      Text(data.first),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.text('تحقّق من الاتصال ثم أعد المحاولة.'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'إعادة المحاولة'));
      await tester.pumpAndSettle();

      expect(attempts, 2);
      expect(find.text('بيانات'), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
    });

    testWidgets('خطأ الصلاحية يعرض رسالة مختلفة', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AsyncView<List<String>>(
              future: Future<List<String>>.error(
                const AppException.permission(),
              ),
              builder: (BuildContext context, List<String> data) =>
                  const Text('لن يظهر'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا تملك صلاحية لهذا المحتوى'), findsOneWidget);
    });

    testWidgets('يعرض الحالة البديلة عند نتيجة فارغة', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: AsyncView<List<String>>(
              future: Future<List<String>>.value(<String>[]),
              isEmpty: (List<String> data) => data.isEmpty,
              emptyBuilder: (BuildContext context) => const EmptyState(
                icon: Icons.groups_outlined,
                title: 'لا توجد مجموعات',
              ),
              builder: (BuildContext context, List<String> data) =>
                  const Text('لن يظهر'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد مجموعات'), findsOneWidget);
      expect(find.text('لن يظهر'), findsNothing);
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
