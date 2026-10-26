import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

/// يمر عبر شاشة البداية إلى شاشة الدخول.
Future<void> _openLogin(WidgetTester tester) async {
  await tester.pumpWidget(buildTestApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(milliseconds: 600));
}

/// يبدأ جلسة معاينة بدور الطالب عبر زر شاشة الدخول.
Future<void> _enterStudentShell(WidgetTester tester) async {
  await _openLogin(tester);
  await tester.tap(find.widgetWithText(OutlinedButton, 'واجهة الطالب'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// يضغط عنصر تنقّل محدّد داخل شريط التنقّل السفلي.
Future<void> _tapNav(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('الدخول لواجهة الطالب يفتح الهيكل بشريط تنقّل', (
    WidgetTester tester,
  ) async {
    await _enterStudentShell(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('المدرسون'), findsWidgets);
    expect(find.text('المجموعات'), findsWidgets);
    expect(find.text('الحجوزات'), findsWidgets);
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

    await tester.tap(find.widgetWithText(OutlinedButton, 'واجهة المدرس'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('الطلبات'), findsWidgets);
    expect(find.text('مجموعاتي'), findsWidgets);
  });
}
