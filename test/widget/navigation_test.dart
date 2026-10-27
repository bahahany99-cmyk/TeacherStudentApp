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

void main() {
  testWidgets('الدخول لواجهة الطالب يفتح الهيكل بشريط تنقّل', (
    WidgetTester tester,
  ) async {
    await _enterStudentShell(tester);

    expect(find.byType(NavigationBar), findsOneWidget);

    // كل عناصر تنقّل الطالب موجودة داخل شريط التنقّل.
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

    expect(find.text('مجموعات متاحة'), findsOneWidget);
  });

  testWidgets('تبديل واجهة المعاينة إلى المدرس يغيّر عناصر التنقل', (
    WidgetTester tester,
  ) async {
    await _enterStudentShell(tester);

    // الذهاب إلى "حسابي" ثم تبديل الدور.
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
}
