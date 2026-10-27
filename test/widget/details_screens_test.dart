import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';

import '../helpers/test_app.dart';

/// يمر عبر شاشة البداية إلى شاشة الدخول.
Future<void> _openLogin(WidgetTester tester) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(buildTestApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// يدخل الهيكل بدور الطالب.
Future<void> _enterStudentShell(WidgetTester tester) async {
  await _openLogin(tester);
  await tapVisible(
    tester,
    find.widgetWithText(OutlinedButton, 'واجهة الطالب'),
  );
}

/// يبدّل واجهة المعاينة إلى المدرس من تبويب «حسابي».
Future<void> _enterTeacherShell(WidgetTester tester) async {
  await _enterStudentShell(tester);
  await _tapNav(tester, 'حسابي');
  await tapVisible(
    tester,
    find.widgetWithText(OutlinedButton, 'واجهة المدرس'),
  );
}

Future<void> _tapNav(WidgetTester tester, String label) async {
  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    ),
  );
}

/// نص ظاهر فعليًا (يستبعد الشاشات المغطاة في مكدّس التنقل).
Finder _visibleText(String text) => find.text(text).hitTestable();

/// عنوان الشريط العلوي للشاشة الحالية.
void _expectTitle(String title) {
  expect(
    find.descendant(of: find.byType(AppBar), matching: find.text(title)),
    findsOneWidget,
    reason: 'الشريط العلوي لا يعرض "$title"',
  );
}

void main() {
  group('شاشات التفاصيل (P3)', () {
    testWidgets('ملف المدرس يُفتح من قائمة المدرسين ويعرض بياناته', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);
      await _tapNav(tester, 'المدرسون');

      await tapVisible(tester, find.text('أ. سارة الخطيب').hitTestable().first);

      _expectTitle('ملف المدرس');
      expect(find.text('أ. سارة الخطيب'), findsWidgets);
      expect(find.text('الرياضيات • الثانوية العامة'), findsOneWidget);
      // التقييم والسعر ظاهران في بطاقة الرأس.
      expect(find.textContaining('126 تقييم'), findsOneWidget);
      expect(find.textContaining('150 ج.م'), findsOneWidget);
    });

    testWidgets('ملف المدرس يعرض مجموعاته وتُفتح تفاصيلها', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);
      await _tapNav(tester, 'المدرسون');
      await tapVisible(tester, find.text('أ. سارة الخطيب').hitTestable().first);

      await tapVisible(tester, find.text('مجموعة الرياضيات — التفاضل'));

      _expectTitle('تفاصيل المجموعة');
      // نبحث في الشجرة لا في منطقة العرض: التفاصيل قد تكون أسفل الطيّة على
      // هاتف 360dp، والمهم أنها مبنية بلا خطأ.
      expect(find.text('مجموعة الرياضيات — التفاضل'), findsOneWidget);
      expect(find.text('9 / 12'), findsOneWidget);
      expect(find.text('السبت والثلاثاء — 5 مساءً'), findsOneWidget);
      // طالب: زر انضمام ظاهر لكنه غير مفعّل فعليًا.
      expect(find.text('طلب الانضمام'), findsOneWidget);
    });

    testWidgets('تفاصيل طلب الحجز تعرض الحالة والملاحظة', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);
      await _tapNav(tester, 'الحجوزات');

      await tapVisible(tester, find.text('أ. سارة الخطيب').hitTestable().first);

      _expectTitle('تفاصيل الطلب');
      expect(find.text('بانتظار موافقة المدرس'), findsOneWidget);
      expect(find.text('أحتاج حصة لمراجعة الوحدة الثانية.'), findsOneWidget);
      expect(find.text('demo-booking-1'), findsOneWidget);
    });

    testWidgets('تفاصيل المجموعة في واجهة المدرس تعرض مدخل الأعضاء فقط', (
      WidgetTester tester,
    ) async {
      await _enterTeacherShell(tester);
      await _tapNav(tester, 'مجموعاتي');

      await tapVisible(tester, find.text('مجموعة الرياضيات — التفاضل'));

      _expectTitle('تفاصيل المجموعة');
      expect(find.text('أعضاء المجموعة (9)'), findsOneWidget);
      // المدرس لا يرى زر طلب الانضمام لمجموعته.
      expect(find.text('طلب الانضمام'), findsNothing);
    });

    testWidgets('قائمة الأعضاء تعرض العدد المطابق للمقاعد المشغولة', (
      WidgetTester tester,
    ) async {
      await _enterTeacherShell(tester);
      await _tapNav(tester, 'مجموعاتي');
      await tapVisible(tester, find.text('مجموعة الرياضيات — التفاضل'));
      await tapVisible(tester, find.text('أعضاء المجموعة (9)'));

      _expectTitle('أعضاء المجموعة');
      expect(find.text('قائمة الأعضاء'), findsOneWidget);
      expect(find.text('9 عضوًا — تُقرأ من بيانات تجريبية'), findsOneWidget);
      expect(find.text('محمد سامي'), findsOneWidget);
    });

    testWidgets('ملف المدرس الخاص يعرض الحالة الحقيقية من البيانات', (
      WidgetTester tester,
    ) async {
      await _enterTeacherShell(tester);
      await _tapNav(tester, 'حسابي');

      await tapVisible(
        tester,
        find.widgetWithText(ListTile, 'ملفي التعريفي'),
      );

      _expectTitle('ملفي التعريفي');
      expect(find.text('معتمد'), findsOneWidget);
      expect(find.text('المعلومات الظاهرة للطلاب'), findsOneWidget);
      expect(find.text('تعديل المعلومات'), findsOneWidget);
    });

    testWidgets('نموذج التعديل يتحقق من المدخلات ولا يدّعي الحفظ', (
      WidgetTester tester,
    ) async {
      await _enterTeacherShell(tester);
      await _tapNav(tester, 'حسابي');
      await tapVisible(tester, find.widgetWithText(ListTile, 'ملفي التعريفي'));
      await tapVisible(tester, find.text('تعديل المعلومات'));

      _expectTitle('تعديل المعلومات');

      // اسم فارغ → رسالة تحقق عربية.
      await tester.enterText(find.byType(TextFormField).first, '');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(find.text('الاسم مطلوب'), findsOneWidget);

      // اسم صحيح → لا يُدّعى الحفظ، بل تُقال الحقيقة.
      await tester.enterText(
        find.byType(TextFormField).first,
        'أ. سارة الخطيب',
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));
      expect(find.textContaining('لم يُحفظ شيء'), findsOneWidget);
    });

    testWidgets('معرّف غير موجود يعرض حالة واضحة لا شاشة منهارة', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pushNamed(
        RoutePaths.teacherProfile,
        arguments: 'لا-يوجد-مدرس-بهذا-المعرّف',
      );
      await tester.pumpAndSettle();

      _expectTitle('ملف المدرس');
      expect(_visibleText('الملف غير موجود'), findsOneWidget);
    });

    testWidgets('مسار تفاصيل بدون معرّف يعرض شاشة «الصفحة غير موجودة»', (
      WidgetTester tester,
    ) async {
      await _enterStudentShell(tester);

      final NavigatorState navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      navigator.pushNamed(RoutePaths.groupDetails);
      await tester.pumpAndSettle();

      _expectTitle('الصفحة غير موجودة');
    });
  });
}
