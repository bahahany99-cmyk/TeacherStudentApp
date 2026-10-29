import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_carousel.dart';

import '../helpers/test_app.dart';

/// يستضيف الرئيسية بجلسة طالب تجريبية وبحزمة خدمات يملكها الاختبار
/// (حتى يستطيع تهيئة «مجموعاتي» عبر نفس الـ API الذي تستخدمه الشاشة).
Widget _host(AppServices services, Widget child) {
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

/// يجعل الطالب التجريبي عضوًا فعليًا في أول مجموعة: طلب، ثم قبول المدرس —
/// نفس المسار الحقيقي (القبول ينشئ العضوية)، فلا بيانات مزيّفة في الاختبار.
Future<StudyGroup> _joinFirstGroup(AppServices services) async {
  final StudyGroup group = DemoData.groups.first;
  final GroupJoinRequest request = await services.groups.requestToJoin(
    group: group,
    studentId: DemoData.demoStudentId,
    studentName: DemoData.studentName,
  );
  await services.groups.decideJoinRequest(
    request: request,
    teacherId: group.teacherId,
    approve: true,
  );
  return group;
}

void main() {
  group('الرئيسية (P18) — بحث حقيقي وتخطيط مدمج', () {
    testWidgets('لا يوجد حقل بحث معطّل بعد الآن', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(AppServices.demo(), const StudentHomeScreen()),
      );
      await tester.pumpAndSettle();

      // العطل الأصلي: TextField(enabled: false) يستهلك مساحة بلا وظيفة.
      final Finder disabledFields = find.byWidgetPredicate(
        (Widget widget) => widget is TextField && !widget.enabled,
        description: 'حقل إدخال معطّل',
      );
      expect(disabledFields, findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('البحث ينقل إلى قسم المدرسين ويُطبّق النص هناك', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'واجهة الطالب'),
      );

      // الرئيسية: حقل بحث واحد فعّال. (نحدّد الشاشة لأن `IndexedStack` تبني
      // كل الأقسام، فحقل المدرسين موجود في الشجرة أيضًا.)
      final Finder homeField = find.descendant(
        of: find.byType(StudentHomeScreen),
        matching: find.byType(TextField),
      );
      expect(homeField, findsOneWidget);
      await tester.enterText(homeField, 'رياضيات');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // انتقلنا فعلًا إلى قسم المدرسين.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('المدرسون'),
        ),
        findsOneWidget,
      );

      // والنص وصل إلى حقل البحث الحقيقي في شاشة المدرسين (لا نسخة مكرّرة).
      final TextField field = tester.widget<TextField>(
        find.descendant(
          of: find.byType(TeachersScreen),
          matching: find.byType(TextField),
        ),
      );
      expect(field.controller?.text, 'رياضيات');

      // وحقل الرئيسية أُفرغ، فالعودة إليه لا تُظهر بحثًا قديمًا كأنه محفوظ.
      final TextField home = tester.widget<TextField>(homeField);
      expect(home.controller?.text, isEmpty);
    });

    testWidgets('الأقسام المطلوب إبرازها ظاهرة وبالترتيب', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(AppServices.demo(), const StudentHomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FeaturedTeachersCarousel), findsOneWidget);
      expect(find.text('مدرسون مميزون'), findsOneWidget);
      expect(find.text('مجموعاتي'), findsOneWidget);

      // المميزون قبل مجموعاتي (ترتيب الإبراز المعتمد).
      final double featured = tester.getTopLeft(find.text('مدرسون مميزون')).dy;
      final double groups = tester.getTopLeft(find.text('مجموعاتي')).dy;
      expect(featured, lessThan(groups));

      // قسم الحجوزات ما زال موجودًا أسفل الصفحة (يُبنى عند التمرير إليه).
      await tester.scrollUntilVisible(
        find.text('حجوزاتي القادمة'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('حجوزاتي القادمة'), findsOneWidget);
    });
  });

  group('الرئيسية (P18) — مجموعاتي من بيانات حقيقية', () {
    testWidgets('بلا عضويات: حالة فراغ تشرح الخطوة التالية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(AppServices.demo(), const StudentHomeScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا مجموعات بعد'), findsOneWidget);
      // القسم يعرض دعوة للتصفّح بدل صمت.
      expect(
        find.widgetWithText(TextButton, 'تصفّح المجموعات'),
        findsOneWidget,
      );
    });

    testWidgets('بعضوية مقبولة: اسم المجموعة يظهر في الرئيسية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final StudyGroup group = await _joinFirstGroup(services);

      await tester.pumpWidget(_host(services, const StudentHomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لا مجموعات بعد'), findsNothing);
      expect(find.text(group.title), findsOneWidget);
    });
  });
}
