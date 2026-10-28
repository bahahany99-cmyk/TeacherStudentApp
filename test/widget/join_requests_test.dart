import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/group_details_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/join_requests_screen.dart';

import '../helpers/test_app.dart';

/// حزمة تجريبية بمستودع مجموعات مشترك (حتى نقرأ أثر القبول في الاختبار).
AppServices _services(DemoGroupRepository groups) {
  return AppServices(
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
  required AppServices services,
  required UserRole role,
  required Widget screen,
}) {
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(role);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: MaterialApp(theme: AppTheme.light, home: screen),
    ),
  );
}

void main() {
  group('طلبات الانضمام (P8)', () {
    testWidgets('المدرس يقبل طلبًا فيُحجز المقعد وتتغير الحالة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById('demo-group-1'))!;
      await groups.requestToJoin(
        group: group,
        studentId: 'demo-student',
        studentName: 'طالب تجريبي',
      );

      await tester.pumpWidget(
        _host(
          services: _services(groups),
          role: UserRole.teacher,
          screen: const JoinRequestsScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانتظار قرارك'), findsOneWidget);
      expect(find.text('طالب تجريبي'), findsOneWidget);
      expect(find.text('قيد الانتظار'), findsWidgets);

      await tapVisible(tester, find.text('قبول'));
      expect(find.text('قبول الطلب؟'), findsOneWidget);

      await tester.tap(find.text('تأكيد القبول'));
      await tester.pumpAndSettle();

      // القرار مرّ عبر المستودع: المقعد زاد مرة واحدة والعضو أُنشئ.
      final StudyGroup updated = (await groups.findById('demo-group-1'))!;
      expect(updated.seatsTaken, group.seatsTaken + 1);
      expect(find.text('مقبول'), findsWidgets);
    });

    testWidgets('تراجع عن القبول لا يغيّر شيئًا', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final DemoGroupRepository groups = DemoGroupRepository();
      final StudyGroup group = (await groups.findById('demo-group-1'))!;
      await groups.requestToJoin(
        group: group,
        studentId: 'demo-student',
        studentName: 'طالب تجريبي',
      );

      await tester.pumpWidget(
        _host(
          services: _services(groups),
          role: UserRole.teacher,
          screen: const JoinRequestsScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('رفض'));
      expect(find.text('رفض الطلب؟'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();

      expect((await groups.findById('demo-group-1'))!.seatsTaken, group.seatsTaken);
      expect(find.text('قيد الانتظار'), findsWidgets);
    });

    testWidgets('الطالب يرسل طلب انضمام من تفاصيل المجموعة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DemoGroupRepository groups = DemoGroupRepository();

      await tester.pumpWidget(
        _host(
          services: _services(groups),
          role: UserRole.student,
          screen: const GroupDetailsScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('طلب الانضمام'), findsOneWidget);

      await tapVisible(tester, find.text('طلب الانضمام'));
      await tester.pumpAndSettle();

      // الحالة تُقرأ من المستودع بعد الإرسال، لا من حالة محلية متفائلة.
      expect(find.text('طلبك قيد مراجعة المدرس.'), findsOneWidget);
      final GroupJoinRequest? request = await groups.findMyRequest(
        groupId: 'demo-group-1',
        studentId: 'demo-student',
      );
      expect(request, isNotNull);
      expect(request!.status, JoinRequestStatus.pending);
    });

    testWidgets('المجموعة المكتملة تعرض قائمة الانتظار بدل زر طلب معطّل', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DemoGroupRepository groups = DemoGroupRepository();

      await tester.pumpWidget(
        _host(
          services: _services(groups),
          role: UserRole.student,
          // demo-group-2 مكتملة (10 من 10).
          screen: const GroupDetailsScreen(groupId: 'demo-group-2'),
        ),
      );
      await tester.pumpAndSettle();

      // P9: مجموعة مكتملة ⇒ باب الانتظار، لا زر معطّل بلا تفسير.
      expect(find.text('انضم لقائمة الانتظار'), findsOneWidget);
      expect(find.text('طلب الانضمام'), findsNothing);
      expect(find.textContaining('المجموعة مكتملة'), findsOneWidget);
    });

    testWidgets('الانضمام لقائمة الانتظار يظهر حالة الانتظار', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DemoGroupRepository groups = DemoGroupRepository();

      await tester.pumpWidget(
        _host(
          services: _services(groups),
          role: UserRole.student,
          screen: const GroupDetailsScreen(groupId: 'demo-group-5'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('انضم لقائمة الانتظار'));

      expect(
        find.textContaining('أنت في قائمة الانتظار'),
        findsOneWidget,
        reason: 'حالة الانتظار تُعرض بعد الانضمام',
      );
      expect(
        await groups.findMyWaitlistEntry(
          groupId: 'demo-group-5',
          studentId: 'demo-student',
        ),
        isNotNull,
      );
      // المقعد لم يُحجز: المنتظر ليس عضوًا.
      expect(
        (await groups.findById('demo-group-5'))!.seatsTaken,
        6,
      );
    });
  });
}
