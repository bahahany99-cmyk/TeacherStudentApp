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

/// يفتح «ملفي التعريفي» ← «تعديل المعلومات» من واجهة المدرس.
Future<void> _openEditForm(WidgetTester tester) async {
  await _enterTeacherShell(tester);
  await _tapNav(tester, 'حسابي');
  await tapVisible(tester, find.widgetWithText(ListTile, 'ملفي التعريفي'));
  await tapVisible(tester, find.text('تعديل المعلومات'));
  _expectTitle('تعديل المعلومات');
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
      expect(find.text('الأعضاء وقائمة الانتظار (9)'), findsOneWidget);
      // المدرس لا يرى زر طلب الانضمام لمجموعته.
      expect(find.text('طلب الانضمام'), findsNothing);
    });

    testWidgets('قائمة الأعضاء تعرض العدد المطابق للمقاعد المشغولة', (
      WidgetTester tester,
    ) async {
      await _enterTeacherShell(tester);
      await _tapNav(tester, 'مجموعاتي');
      await tapVisible(tester, find.text('مجموعة الرياضيات — التفاضل'));
      await tapVisible(tester, find.text('الأعضاء وقائمة الانتظار (9)'));

      _expectTitle('أعضاء المجموعة');
      expect(find.text('9 عضوًا يشغلون مقاعدهم'), findsOneWidget);
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
      expect(find.text('موثّق'), findsOneWidget);
      expect(find.text('المعلومات الظاهرة للطلاب'), findsOneWidget);
      expect(find.text('تعديل المعلومات'), findsOneWidget);
    });

    testWidgets('نموذج التعديل يرفض الاسم الفارغ برسالة عربية', (
      WidgetTester tester,
    ) async {
      await _openEditForm(tester);

      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.pumpAndSettle();

      // (P15) النموذج صار أطول من الشاشة، وزر «حفظ» في أسفله. نضغط معالجه
      // مباشرة بدل الاعتماد على إصابة نقطة يحتاج تمريرها — والضغط الحقيقي
      // على الزر مغطّى في اختبار «النموذج الصالح يحفظ فعلًا ويُغلق».
      final FilledButton save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'حفظ'),
      );
      save.onPressed!();
      await tester.pumpAndSettle();

      // الرسالة العامة دليل على أن التحقق جرى.
      expect(find.text('راجع الحقول المطلوبة قبل الحفظ.'), findsOneWidget);

      // ثم نصعد إلى الحقل الأول لقراءة رسالته الخاصة.
      await tester.dragUntilVisible(
        find.text('الاسم مطلوب'),
        find.byType(ListView).first,
        const Offset(0, 300),
      );
      expect(find.text('الاسم مطلوب'), findsOneWidget);
    });

    testWidgets('النموذج الصالح يحفظ فعلًا ويُغلق (P18)', (
      WidgetTester tester,
    ) async {
      await _openEditForm(tester);

      // (P18) توقّف عصر «عرض فقط»: الحفظ يكتب في المستودع ثم يعود للشاشة
      // السابقة. الحقول مسبقة التعبئة من الملف، فالحفظ يمرّ من التحقق.
      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'أ. سارة الخطيب المحدَّثة',
      );
      await tapVisible(tester, find.widgetWithText(FilledButton, 'حفظ'));

      // عاد إلى «ملفي التعريفي»، ولا نص يدّعي غير ذلك.
      _expectTitle('ملفي التعريفي');
      expect(find.textContaining('لم يُحفظ شيء'), findsNothing);
      // والقيمة الجديدة ظاهرة في الشاشة السابقة (قُرئت من المستودع بعد الحفظ).
      expect(find.text('أ. سارة الخطيب المحدَّثة'), findsWidgets);
    });

    testWidgets('نموذج التعديل يعرض طريقة التقديم وموقع المحاضرة (P15)', (
      WidgetTester tester,
    ) async {
      await _openEditForm(tester);

      // (P15) علم واحد لطريقة التقديم، ثم المحافظة والحي للمحاضرة الحضورية.
      expect(find.widgetWithText(SwitchListTile, 'أدرّس عن بُعد'), findsOneWidget);

      final Finder governorate = find.descendant(
        of: find.byType(TextFormField),
        matching: find.text('المحافظة (اختياري)'),
      );
      expect(governorate, findsOneWidget);
      expect(find.text('الحي / المركز (اختياري)'), findsOneWidget);
    });

    testWidgets('تشغيل «عن بُعد» يخفي حقلي المحافظة والحي (P15)', (
      WidgetTester tester,
    ) async {
      await _openEditForm(tester);

      await tapVisible(tester, find.byType(SwitchListTile));

      expect(find.text('المحافظة (اختياري)'), findsNothing);
      expect(find.text('الحي / المركز (اختياري)'), findsNothing);
      // ولا يُطالب بهما في التعليم عن بُعد.
      expect(
        find.textContaining('ولا يُطلبان في'),
        findsOneWidget,
        reason: 'يجب أن يشرح النموذج أن المحافظة غير مطلوبة عن بُعد',
      );
      expect(tester.takeException(), isNull);
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
