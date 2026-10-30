import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/app_router.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/teacher/presentation/teacher_home_screen.dart';

import '../helpers/test_app.dart';

/// (P28) الرئيسية الجديدة للمدرس: **حالة الملف صفٌّ لا بطاقة، والأرقام حقيقية.**
///
/// القياسات هنا ليست ذوقًا: ارتفاع صف الحالة محدود فيزيائيًا، والبطاقة القديمة
/// كانت تحتلّ قرابة نصف الشاشة على هاتف 360×720. ضبط الحد الأعلى هو الطريقة
/// الوحيدة لمنع الانحدار إلى البطاقة الضخمة مرة أخرى.
const String _teacherId = 'demo-teacher-1';

AppServices _services(TeacherProfile? profile) {
  final AppServices base = AppServices.demo();
  return AppServices(
    auth: base.auth,
    teachers: DemoTeacherRepository(
      source: <TeacherProfile>[if (profile != null) profile],
    ),
    groups: base.groups,
    bookings: base.bookings,
    schedules: base.schedules,
    messages: base.messages,
    chats: base.chats,
    notifications: base.notifications,
    reviews: base.reviews,
    favorites: base.favorites,
    admin: base.admin,
  );
}

TeacherProfile _profile(TeacherProfileStatus status) => TeacherProfile(
  id: _teacherId,
  displayName: 'أ. منى عبد الرحمن',
  subject: 'اللغة العربية',
  stage: 'الثانوية العامة',
  area: 'الغردقة',
  bio: 'شرح النحو بأمثلة من الامتحانات السابقة.',
  status: status,
  governorate: 'البحر الأحمر',
);

Widget _host(AppServices services) {
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.teacher);

  final ShellController shell = ShellController();

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: ShellScope(
        controller: shell,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            theme: AppTheme.light,
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: Scaffold(body: const TeacherHomeScreen()),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('رئيسية المدرس — الهيكل', () {
    testWidgets('صف حالة الملف مضغوط ولا يسيطر على الشاشة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(_profile(TeacherProfileStatus.verified))));
      await tester.pumpAndSettle();

      final Finder statusCard = find.byKey(
        const Key('teacher-status-card-verified'),
      );
      expect(statusCard, findsOneWidget);

      final Size cardSize = tester.getSize(statusCard);
      final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;

      // 120dp سقف: الصف (أيقونة + عنوان + سطر) لا البطاقة القديمة (>220).
      expect(cardSize.height, lessThanOrEqualTo(120));
      expect(
        cardSize.height / screen.height,
        lessThan(0.2),
        reason: 'بطاقة الحالة تحتلّ أكثر من خُمس الشاشة',
      );
      // ولا يظهر زر بعرض الشاشة داخل الصف.
      expect(find.widgetWithText(FilledButton, 'ملفك موثّق ويظهر للطلاب'), findsNothing);
    });

    testWidgets('الصفحة تعرض أرقام اليوم واختصاراتها', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(_profile(TeacherProfileStatus.verified))));
      await tester.pumpAndSettle();

      for (final String key in <String>[
        'teacher-stat-pending',
        'teacher-stat-groups',
        'teacher-stat-seats',
        'teacher-stat-chats',
        'teacher-quick-requests',
        'teacher-quick-groups',
        'teacher-quick-chats',
        'teacher-quick-profile',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget, reason: 'عنصر ناقص: $key');
      }

      // التحية موجودة بالاسم، بلا نص تطويري.
      expect(find.textContaining('أهلًا'), findsOneWidget);
      expect(find.textContaining('حساب تجريبي'), findsNothing);
      expect(find.textContaining('معاينة محلية'), findsNothing);
    });

    testWidgets('الاختصارات تنتقل إلى الأقسام الصحيحة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(_profile(TeacherProfileStatus.verified))));
      await tester.pumpAndSettle();

      // «مجموعاتي» في الاختصارات يطلب قسم المجموعات من الهيكل.
      final ShellController shell = ShellScope.read(
        tester.element(find.byType(TeacherHomeScreen)),
      );
      await tester.tap(find.byKey(const Key('teacher-quick-groups')));
      await tester.pumpAndSettle();
      expect(shell.current.name, 'groups');

      await tester.tap(find.byKey(const Key('teacher-quick-requests')));
      await tester.pumpAndSettle();
      expect(shell.current.name, 'bookings');
    });

    testWidgets('بلا ملف تعريفي: دعوة مضغوطة بزر إنشاء واحد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(null)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('teacher-onboarding-card')), findsOneWidget);
      expect(find.byKey(const Key('teacher-create-profile')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('teacher-onboarding-card'))).height,
          lessThanOrEqualTo(160));
    });

    testWidgets('لا يفيض التخطيط على شاشة ضيقة (320×640)', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(960, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(_services(_profile(TeacherProfileStatus.draft))));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('teacher-stat-seats')), findsOneWidget);
    });

    testWidgets('التباعد المتّسق مطبّق: أزرار 48 وأفاتار مصغّر', (
      WidgetTester tester,
    ) async {
      // رمز واحد للارتفاع في كل التطبيق — لا أرقام مبعثرة في الشاشات.
      expect(AppSpacing.buttonHeight, 48);
      expect(AppSpacing.avatarSm, 40);
      expect(AppSpacing.avatarMd, 56);
    });
  });
}
