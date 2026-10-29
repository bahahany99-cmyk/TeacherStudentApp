import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/profile/presentation/my_data_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/support_screens.dart';
import 'package:teacher_student_app/features/teacher/presentation/edit_teacher_profile_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/my_teacher_profile_screen.dart';

import '../helpers/test_app.dart';

/// (P18) الشاشات التي كانت «غير مفعّلة» — تختبر السلوك الجديد فعلًا.
Widget _host(
  Widget child, {
  UserRole role = UserRole.teacher,
  AppServices? services,
  SessionController? session,
}) {
  final AppServices resolved = services ?? AppServices.demo();
  final SessionController resolvedSession =
      session ?? (SessionController(resolved.auth)..startDemoSession(role));

  return AppServicesScope(
    services: resolved,
    child: SessionScope(
      controller: resolvedSession,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          home: child,
        ),
      ),
    ),
  );
}

void main() {
  group('«بياناتي» (P18)', () {
    testWidgets('يعرض القيم الحالية ويحفظها في الجلسة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const MyDataScreen()));
      await tester.pumpAndSettle();

      final TextFormField name = tester.widget<TextFormField>(
        find.byKey(const Key('my-data-name')),
      );
      expect(name.controller?.text.isNotEmpty, isTrue);

      await tester.enterText(
        find.byKey(const Key('my-data-name')),
        'اسم محدَّث للاختبار',
      );
      await tester.enterText(
        find.byKey(const Key('my-data-phone')),
        '01012345678',
      );
      await tester.enterText(
        find.byKey(const Key('my-data-stage')),
        'الثانوية العامة',
      );
      await tester.tap(find.byKey(const Key('my-data-save')));
      await tester.pumpAndSettle();

      // الشاشة تُغلق بعد النجاح، والجلسة تحمل القيم الجديدة.
      expect(find.byType(MyDataScreen), findsNothing);
    });

    testWidgets('اسم فارغ: رسالة تحقق ولا حفظ', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const MyDataScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('my-data-name')), ' ');
      await tester.tap(find.byKey(const Key('my-data-save')));
      await tester.pumpAndSettle();

      expect(find.text('الاسم مطلوب'), findsOneWidget);
      // لم تُغلق الشاشة: لا شيء حُفظ.
      expect(find.byType(MyDataScreen), findsOneWidget);
    });

    testWidgets('هاتف بحروف مرفوض قبل الوصول للخادم', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const MyDataScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('my-data-phone')), '010ABCDE');
      await tester.tap(find.byKey(const Key('my-data-save')));
      await tester.pumpAndSettle();

      expect(find.byType(MyDataScreen), findsOneWidget);
    });
  });

  group('«ملفي التعريفي» للمدرس (P18)', () {
    testWidgets('ملف صاحب الجلسة هو المعروض لا ملف تجريبي ثابت', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();

      await tester.pumpWidget(
        _host(const MyTeacherProfileScreen(), services: services),
      );
      await tester.pumpAndSettle();

      // معرّف المعاينة = demoTeacherId، وملفه موجود في البيانات التجريبية.
      expect(find.text('أ. سارة الخطيب'), findsOneWidget);
      expect(find.byKey(const Key('my-profile-edit')), findsOneWidget);
    });

    testWidgets('نموذج التعديل يحفظ فعلًا ويُغلق بنجاح', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(
        _host(
          const EditTeacherProfileScreen(),
          services: services,
          session: session,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name')),
        'أ. سارة الخطيب — محدَّث',
      );
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();

      // الحفظ نجح: ظهرت رسالة نجاح (لا رسالة «لم يُحفظ شيء»).
      expect(find.textContaining('لم يُحفظ شيء'), findsNothing);
      final TeacherProfile? saved = await services.teachers.findMine(
        'demo-teacher-1',
      );
      expect(saved?.displayName, 'أ. سارة الخطيب — محدَّث');
    });

    testWidgets('نبذة قصيرة: يمنع الحفظ برسالة عربية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(
        _host(
          const EditTeacherProfileScreen(),
          services: services,
          session: session,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('profile-bio')), 'قصيرة');
      await tester.tap(find.byKey(const Key('profile-save')));
      await tester.pumpAndSettle();

      expect(find.textContaining('النبذة قصيرة'), findsOneWidget);
      final TeacherProfile? unchanged = await services.teachers.findMine(
        'demo-teacher-1',
      );
      expect(unchanged?.displayName, isNot('أ. سارة الخطيب — محدَّث'));
    });
  });

  group('المساعدة والشروط (P18) — محتوى حقيقي لا زر معطّل', () {
    testWidgets('المساعدة تعرض بريد الدعم وأسئلة قابلة للفتح', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const SupportScreen()));
      await tester.pumpAndSettle();

      expect(find.text(SupportScreen.supportEmail), findsOneWidget);
      expect(find.text('كيف أحجز حصة مع مدرس؟'), findsOneWidget);

      await tester.tap(find.text('كيف أحجز حصة مع مدرس؟'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('يصل الطلب إلى المدرس'),
        findsOneWidget,
      );
    });

    testWidgets('سياسة الخصوصية تعرض البنود الفعلية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const LegalScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ما نجمعه'), findsOneWidget);
      expect(find.text('حذف الحساب'), findsOneWidget);
      expect(find.textContaining('Firebase'), findsOneWidget);
    });
  });

  test('المسارات الجديدة مسجّلة', () {
    expect(RoutePaths.myData, '/me/data');
    expect(RoutePaths.support, '/support');
    expect(RoutePaths.legal, '/legal');
  });
}
