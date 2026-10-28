import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/group_members_screen.dart';

import '../helpers/test_app.dart';

/// حزمة بمستودع مجموعات مشترك حتى نتحقق من أثر الإزالة/القبول.
class _Harness {
  final DemoGroupRepository groups = DemoGroupRepository();

  AppServices get services => AppServices(
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: groups,
    bookings: DemoBookingRepository(),
    chats: DemoDirectChatRepository(),
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
  );
}

Widget _host({
  required _Harness harness,
  required UserRole role,
  required String groupId,
}) {
  final AppServices services = harness.services;
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(role);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          home: GroupMembersScreen(groupId: groupId),
        ),
      ),
    ),
  );
}

void main() {
  group('أعضاء المجموعة (P9)', () {
    testWidgets('المدرس يرى الأعضاء وقائمة الانتظار', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          groupId: 'demo-group-5',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأعضاء'), findsOneWidget);
      expect(find.text('قائمة الانتظار'), findsOneWidget);
      // الاسم يظهر في الأعضاء (من مولّد الأسماء) وفي قائمة الانتظار معًا.
      expect(find.text('سلمى مجدي'), findsWidgets);
      expect(find.text('كريم طارق'), findsOneWidget);
      expect(find.text('6 / 6 مقعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('بلا مقعد زر القبول معطّل', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          groupId: 'demo-group-5',
        ),
      );
      await tester.pumpAndSettle();

      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'لا مقعد متاح').first,
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('إزالة عضو تحرّر مقعدًا ثم يُقبل أول المنتظرين', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          groupId: 'demo-group-5',
        ),
      );
      await tester.pumpAndSettle();

      // إزالة أول عضو: تأكيد في نافذة حوار.
      await tapVisible(tester, find.widgetWithIcon(IconButton, Icons.person_remove_outlined).first);
      expect(find.text('إزالة عضو'), findsWidgets);
      await tester.tap(find.widgetWithText(FilledButton, 'إزالة'));
      await tester.pumpAndSettle();

      final StudyGroup afterRemoval = (await harness.groups.findById(
        'demo-group-5',
      ))!;
      expect(afterRemoval.seatsTaken, 5);
      expect(afterRemoval.seatsAvailable, 1);

      // الزر صار مفعّلًا بعد تحرر المقعد.
      expect(find.text('قبول ومنح مقعد'), findsWidgets);
      await tapVisible(tester, find.text('قبول ومنح مقعد').first);

      final StudyGroup afterPromotion = (await harness.groups.findById(
        'demo-group-5',
      ))!;
      expect(afterPromotion.seatsTaken, 6, reason: 'مقعد واحد للمنتظر');
      expect(
        await harness.groups.isMember(
          groupId: 'demo-group-5',
          userId: 'demo-waitlist-1',
        ),
        isTrue,
      );
      expect(find.text('تم قبوله'), findsWidgets);
    });

    testWidgets('البحث بالاسم يرشّح الأعضاء', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          groupId: 'demo-group-1',
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'محمد');
      await tester.pumpAndSettle();

      expect(find.text('محمد سامي'), findsOneWidget);
      expect(find.text('مريم أشرف'), findsNothing);
    });

    testWidgets('الطالب لا يرى قائمة الأعضاء (خصوصية)', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          groupId: 'demo-group-1',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأعضاء لصاحب المجموعة'), findsOneWidget);
      expect(find.text('محمد سامي'), findsNothing);
      expect(find.text('قائمة الانتظار'), findsNothing);
    });
  });
}
