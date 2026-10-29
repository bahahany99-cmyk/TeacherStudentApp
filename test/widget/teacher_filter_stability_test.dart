import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_filter_bar.dart';

import '../helpers/test_app.dart';

/// يستضيف شاشة المدرسين بجلسة طالب تجريبية (بلا هيكل تنقّل — كما في بقية
/// اختبارات الاستكشاف).
Widget _host(Widget child) {
  final AppServices services = AppServices.demo();
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.student);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(backgroundColor: Colors.white, body: child),
        ),
      ),
    ),
  );
}

/// حبة فلتر بعنوان محدّد (الوسم نفسه يظهر في بطاقات المدرسين أيضًا).
Finder _chip(String label) => find.widgetWithText(PillChip, label);

void main() {
  group('ثبات شريط الفلاتر (P18)', () {
    testWidgets('«عن بُعد» لا يُخفي صف المحافظات', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      // قبل: الصف ظاهر.
      expect(_chip('كل المحافظات'), findsOneWidget);
      expect(_chip('القاهرة'), findsOneWidget);

      await tapVisible(tester, _chip('عن بُعد'));

      // بعد: الصف **باقٍ** — الخيارات لا تختفي (هذا هو العطل الأصلي).
      expect(_chip('كل المحافظات'), findsOneWidget);
      expect(_chip('القاهرة'), findsOneWidget);
      expect(_chip('أسيوط'), findsOneWidget);
    });

    testWidgets('ارتفاع شريط الفلاتر ثابت قبل/بعد تغيير طريقة التقديم', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      final Size before = tester.getSize(find.byType(TeacherFilterBar));

      await tapVisible(tester, _chip('عن بُعد'));
      final Size online = tester.getSize(find.byType(TeacherFilterBar));
      expect(online, before, reason: 'تغيّر الارتفاع = قفزة بصرية');

      await tapVisible(tester, _chip('حضوري فقط'));
      final Size inPerson = tester.getSize(find.byType(TeacherFilterBar));
      expect(inPerson, before);

      await tapVisible(tester, _chip('الكل'));
      expect(tester.getSize(find.byType(TeacherFilterBar)), before);
    });

    testWidgets('«عن بُعد» يعطّل المحافظات بدل حذفها', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, _chip('عن بُعد'));
      expect(find.byType(TeacherCard), findsNWidgets(2));

      // الضغط على محافظة مع «عن بُعد» لا يفعل شيئًا: الحبة معطّلة.
      await tester.ensureVisible(_chip('أسيوط'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('أسيوط'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byType(TeacherCard), findsNWidgets(2));
      expect(find.text('2 مدرسًا'), findsOneWidget);
    });

    testWidgets('العودة إلى «حضوري فقط» تُعيد المحافظات مفعّلة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, _chip('عن بُعد'));
      await tapVisible(tester, _chip('حضوري فقط'));
      await tapVisible(tester, _chip('القاهرة'));

      expect(tester.widget<PillChip>(_chip('القاهرة')).selected, isTrue);
    });

    testWidgets('«تفريغ الفلاتر» داخل الشريط ويُعيد كل النتائج', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      // لا يظهر قبل تفعيل فلتر.
      expect(_chip('تفريغ الفلاتر'), findsNothing);

      await tapVisible(tester, _chip('عن بُعد'));
      expect(_chip('تفريغ الفلاتر'), findsOneWidget);

      await tapVisible(tester, _chip('تفريغ الفلاتر'));

      expect(_chip('تفريغ الفلاتر'), findsNothing);
      expect(find.byType(TeacherCard), findsNWidgets(5));
      expect(find.text('5 مدرسًا'), findsOneWidget);
      // الشريط لم يتغيّر ارتفاعه حتى عند التفريغ.
      expect(find.byType(TeacherFilterBar), findsOneWidget);
    });
  });

  group('AsyncView — إعادة الجلب بلا وميض (P18)', () {
    testWidgets('keepPreviousData يُبقي النتائج القديمة حتى تصل الجديدة', (
      WidgetTester tester,
    ) async {
      final List<Completer<String>> gates = <Completer<String>>[
        Completer<String>(),
        Completer<String>(),
      ];
      int calls = 0;

      Widget host(int reloadKey) {
        return MaterialApp(
          home: Scaffold(
            body: AsyncView<String>(
              reloadKey: reloadKey,
              keepPreviousData: true,
              load: () => gates[calls++].future,
              builder: (BuildContext context, String data) =>
                  Text('بيانات:$data'),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(0));
      gates[0].complete('أ');
      await tester.pumpAndSettle();
      expect(find.text('بيانات:أ'), findsOneWidget);

      // تغيير المعامل: إعادة جلب جارية — القديم يبقى معروضًا.
      await tester.pumpWidget(host(1));
      await tester.pump();
      expect(find.text('بيانات:أ'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      gates[1].complete('ب');
      await tester.pumpAndSettle();
      expect(find.text('بيانات:ب'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('بلا keepPreviousData: تظهر حالة التحميل كما كانت', (
      WidgetTester tester,
    ) async {
      final List<Completer<String>> gates = <Completer<String>>[
        Completer<String>(),
        Completer<String>(),
      ];
      int calls = 0;

      Widget host(int reloadKey) {
        return MaterialApp(
          home: Scaffold(
            body: AsyncView<String>(
              reloadKey: reloadKey,
              load: () => gates[calls++].future,
              builder: (BuildContext context, String data) =>
                  Text('بيانات:$data'),
            ),
          ),
        );
      }

      await tester.pumpWidget(host(0));
      gates[0].complete('أ');
      await tester.pumpAndSettle();

      await tester.pumpWidget(host(1));
      await tester.pump();
      expect(find.text('بيانات:أ'), findsNothing);

      gates[1].complete('ب');
      await tester.pumpAndSettle();
      expect(find.text('بيانات:ب'), findsOneWidget);
    });
  });
}
