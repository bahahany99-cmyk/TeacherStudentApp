import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/group_form_screen.dart';

import '../helpers/test_app.dart';

/// يبني شاشة النموذج داخل حزمة خدمات تجريبية وجلسة مدرس.
Widget _host({String? groupId, AppServices? services}) {
  final AppServices resolved = services ?? AppServices.demo();
  final SessionController session = SessionController(resolved.auth)
    ..startDemoSession(UserRole.teacher);

  return AppServicesScope(
    services: resolved,
    child: SessionScope(
      controller: session,
      child: MaterialApp(
        theme: AppTheme.light,
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => GroupFormScreen(
            groupId: groupId ?? settings.arguments as String?,
          ),
        ),
        home: GroupFormScreen(groupId: groupId),
      ),
    ),
  );
}

void main() {
  testWidgets('نموذج الإنشاء يعرض الحقول والسعة الافتراضية', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    expect(find.text('مجموعة جديدة'), findsOneWidget);
    expect(find.text('بيانات المجموعة'), findsOneWidget);
    expect(find.text('السعة'), findsOneWidget);
    expect(find.text('10'), findsOneWidget); // السعة الافتراضية
    expect(find.text('إنشاء المجموعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('الحفظ بلا بيانات يُظهر رسالة تحقق ولا يُنشئ شيئًا', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    final AppServices services = AppServices.demo();
    await tester.pumpWidget(_host(services: services));
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('إنشاء المجموعة'));

    // رسالة الحقل المطلوب تظهر على الحقول الثلاثة.
    expect(find.text('هذا الحقل مطلوب.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('إنشاء مجموعة كاملة ينجح ويُضيفها للمستودع', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    final AppServices services = AppServices.demo();
    await tester.pumpWidget(_host(services: services));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'عنوان المجموعة'),
      'مجموعة الفيزياء',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المادة'),
      'الفيزياء',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'المرحلة الدراسية'),
      'الثانوية العامة',
    );
    await tester.pump();

    await tapVisible(tester, find.text('إنشاء المجموعة'));

    final List<StudyGroup> groups = await services.groups.listDiscoverable();
    expect(
      groups.any((StudyGroup g) => g.title == 'مجموعة الفيزياء'),
      isTrue,
    );
  });

  testWidgets('زر الإنقاص يتوقف عند الحد الأدنى (2)', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();

    // الزر نفسه (لا أداة التلميح) حتى نقرأ onPressed.
    final Finder minus = find.widgetWithIcon(IconButton, Icons.remove);
    for (int i = 0; i < 12; i++) {
      if (tester.widget<IconButton>(minus).onPressed != null) {
        await tester.tap(minus);
        await tester.pump();
      }
    }

    expect(find.text('2'), findsOneWidget);
    expect(tester.widget<IconButton>(minus).onPressed, isNull);
  });

  testWidgets('وضع التعديل يحمّل البيانات ويمنع تقليل السعة تحت المنضمين', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(_host(groupId: 'demo-group-1'));
    await tester.pumpAndSettle();

    // بيانات المجموعة التجريبية محمّلة في الحقول.
    expect(find.text('تعديل المجموعة'), findsOneWidget);
    expect(find.text('حفظ التعديلات'), findsOneWidget);
    expect(find.textContaining('عضوًا منضمًا'), findsOneWidget);

    // السعة الحالية 12 والمشغولة 9 ⇒ الإنقاص يتوقف عند 9.
    final Finder minus = find.widgetWithIcon(IconButton, Icons.remove);
    for (int i = 0; i < 8; i++) {
      if (tester.widget<IconButton>(minus).onPressed != null) {
        await tester.tap(minus);
        await tester.pump();
      }
    }

    expect(find.text('9'), findsOneWidget);
    expect(tester.widget<IconButton>(minus).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('مسار الإنشاء مسجَّل في الراوتر بلا معرّف', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(buildTestApp());
    await tester.pumpAndSettle();

    await tapVisible(tester, find.text('واجهة المدرس'));
    await tapVisible(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('مجموعاتي'),
      ),
    );

    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pushNamed(RoutePaths.groupForm);
    await tester.pumpAndSettle();

    expect(find.text('مجموعة جديدة'), findsOneWidget);
  });
}
