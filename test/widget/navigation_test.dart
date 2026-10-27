import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// يمر عبر شاشة البداية إلى شاشة الدخول.
Future<void> _openLogin(WidgetTester tester) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(buildTestApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// يبدأ جلسة معاينة بدور الطالب عبر زر شاشة الدخول.
Future<void> _enterStudentShell(WidgetTester tester) async {
  await _openLogin(tester);
  await tapVisible(
    tester,
    find.widgetWithText(OutlinedButton, 'واجهة الطالب'),
  );
}

/// يضغط عنصر تنقّل محدّد داخل شريط التنقّل السفلي.
Future<void> _tapNav(WidgetTester tester, String label) async {
  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
}

/// نص ظاهر فعليًا (يستبعد الأقسام غير المعروضة داخل IndexedStack).
Finder _visibleText(String text) => find.text(text).hitTestable();

void main() {
  group('الهيكل والتنقل', () {
    testWidgets('الدخول لواجهة الطالب يفتح الهيكل بشريط تنقّل', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      expect(find.byType(NavigationBar), findsOneWidget);

      for (final String label in <String>[
        'الرئيسية',
        'المدرسون',
        'المجموعات',
        'الحجوزات',
        'حسابي',
      ]) {
        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
          findsOneWidget,
          reason: 'عنصر التنقّل "$label" مفقود',
        );
      }
    });

    testWidgets('صفحة المجموعات مستقلة وتُفتح من التنقل', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      await _tapNav(tester, 'المجموعات');

      expect(_visibleText('مجموعات متاحة'), findsOneWidget);
    });

    testWidgets('اختصارات الرئيسية تنقل إلى الأقسام الصحيحة', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      // من الرئيسية: اختصار «المجموعات الدراسية».
      await tapVisible(tester, find.widgetWithText(ActionChip, 'المجموعات الدراسية'));
      expect(_visibleText('مجموعات متاحة'), findsOneWidget);

      // العودة للرئيسية ثم اختصار «ابحث عن مدرس».
      await _tapNav(tester, 'الرئيسية');
      await tapVisible(tester, find.widgetWithText(ActionChip, 'ابحث عن مدرس'));
      expect(_visibleText('كل المدرسين'), findsOneWidget);
    });

    testWidgets('زر «عرض الكل» في قسم المميزين ينقل إلى المدرسين', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      await tapVisible(tester, find.widgetWithText(TextButton, 'عرض الكل'));

      expect(_visibleText('كل المدرسين'), findsOneWidget);
    });

    testWidgets('الرجوع من قسم غير الرئيسية يعيدك للرئيسية', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      await _tapNav(tester, 'الحجوزات');
      expect(_visibleText('طلباتي'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // الرئيسية ظاهرة مرة أخرى، والتطبيق لم يُغلق.
      expect(_visibleText('أهلًا طالب تجريبي'), findsWidgets);
    });

    testWidgets('الرجوع من الرئيسية لا يغلق التطبيق فورًا', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('اضغط رجوع مرة أخرى للخروج من التطبيق'), findsOneWidget);
    });

    testWidgets('تبديل واجهة المعاينة إلى المدرس يغيّر عناصر التنقل', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      await _tapNav(tester, 'حسابي');
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'واجهة المدرس'),
      );

      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('مجموعاتي'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('الطلبات'),
        ),
        findsOneWidget,
      );
      // عنصر خاص بالطالب يجب أن يختفي.
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('المدرسون'),
        ),
        findsNothing,
      );
    });

    testWidgets('تبديل الدور من قسم غير متاح للمدرس يعيدك للرئيسية', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      // ننتقل إلى قسم «المدرسون» (غير موجود في واجهة المدرس).
      await _tapNav(tester, 'المدرسون');
      await _tapNav(tester, 'حسابي');
      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'واجهة المدرس'),
      );

      // بعد التبديل يجب ألا يبقى قسم غير متاح، والشريط يعمل.
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('المدرسون'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
