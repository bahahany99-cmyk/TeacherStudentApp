import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/core/constants/app_strings.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('شاشة البداية تعرض الهوية العربية ثم تنتقل لتسجيل الدخول', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp());

    // أول إطار: شاشة البداية.
    await tester.pump();
    expect(find.text(AppStrings.appName), findsWidgets);

    // انتهاء مهلة شاشة البداية (900ms) ثم انتقال التنقل.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsWidgets);
    expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
  });

  testWidgets('اتجاه الواجهة RTL واللغة عربية', (WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(Scaffold).first);

    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context).languageCode, 'ar');
  });
}
