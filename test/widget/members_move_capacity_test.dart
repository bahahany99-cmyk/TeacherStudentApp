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
import 'package:teacher_student_app/data/validation/move_rules.dart';
import 'package:teacher_student_app/features/groups/presentation/group_members_screen.dart';

import '../helpers/test_app.dart';

class _Harness {
  final DemoGroupRepository groups = DemoGroupRepository();

  AppServices get services => AppServices(
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: groups,
    bookings: DemoBookingRepository(),
    chats: DemoDirectChatRepository(),
    notifications: DemoNotificationRepository(),
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
  );
}

Widget _host({required _Harness harness, required String groupId}) {
  final AppServices services = harness.services;
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.teacher);

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
  group('نقل العضو (P9)', () {
    testWidgets('ورقة النقل تعرض مجموعات المدرس الأخرى وسعتها', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(harness: harness, groupId: 'demo-group-1'),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithIcon(IconButton, Icons.swap_horiz).first,
      );

      expect(find.text('نقل العضو'), findsOneWidget);
      // مجموعة ثانية للمدرس نفسه (مكتملة) تظهر مع سبب التعطيل.
      expect(find.text('التفاضل — المستوى الثاني'), findsOneWidget);
      expect(find.text(MoveRules.targetFullMessage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('هدف مكتمل: تنبيه صريح بلا أي تغيير في المقاعد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      final StudyGroup before = (await harness.groups.findById(
        'demo-group-1',
      ))!;

      await tester.pumpWidget(
        _host(harness: harness, groupId: 'demo-group-1'),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithIcon(IconButton, Icons.swap_horiz).first,
      );
      await tester.tap(find.text('التفاضل — المستوى الثاني'));
      await tester.pumpAndSettle();

      expect(find.text(MoveRules.targetFullMessage), findsWidgets);
      final StudyGroup after = (await harness.groups.findById(
        'demo-group-1',
      ))!;
      expect(after.seatsTaken, before.seatsTaken);
      expect(
        (await harness.groups.listMembers('demo-group-1')).length,
        before.seatsTaken,
      );
    });

    testWidgets('هدف به مقعد: العضو ينتقل والمقاعد تتحرك في الاتجاهين', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      final StudyGroup source = (await harness.groups.findById(
        'demo-group-5',
      ))!;
      final StudyGroup target = (await harness.groups.findById(
        'demo-group-1',
      ))!;

      await tester.pumpWidget(
        _host(harness: harness, groupId: 'demo-group-5'),
      );
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithIcon(IconButton, Icons.swap_horiz).first,
      );
      await tester.tap(find.text('مجموعة الرياضيات — التفاضل'));
      await tester.pumpAndSettle();

      final StudyGroup sourceAfter = (await harness.groups.findById(
        'demo-group-5',
      ))!;
      final StudyGroup targetAfter = (await harness.groups.findById(
        'demo-group-1',
      ))!;

      expect(sourceAfter.seatsTaken, source.seatsTaken - 1);
      expect(targetAfter.seatsTaken, target.seatsTaken + 1);
      expect(find.textContaining('نُقل'), findsWidgets);
    });
  });

  group('إعدادات السعة (P9)', () {
    testWidgets('رفع السعة من الشاشة يحدّث المجموعة ولا يمسّ المشغول', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      final StudyGroup before = (await harness.groups.findById(
        'demo-group-1',
      ))!;

      await tester.pumpWidget(
        _host(harness: harness, groupId: 'demo-group-1'),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('تعديل السعة'));
      expect(find.text('سعة المجموعة'), findsOneWidget);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.add_circle_outline));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('حفظ السعة'));

      final StudyGroup after = (await harness.groups.findById(
        'demo-group-1',
      ))!;
      expect(after.seatsTotal, before.seatsTotal + 1);
      expect(after.seatsTaken, before.seatsTaken);
    });

    testWidgets('لا يمكن تقليل السعة تحت عدد المنضمين', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(harness: harness, groupId: 'demo-group-5'),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('تعديل السعة'));

      // المجموعة 6 من 6: زر التقليل معطّل من البداية.
      final IconButton decrease = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
      );
      expect(decrease.onPressed, isNull);
      expect(find.text('حفظ السعة'), findsOneWidget);
    });

    testWidgets('الحد الأقصى 40: زر الزيادة يتوقف عنده', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      // مجموعة بسعة 40 جاهزة.
      final StudyGroup group = StudyGroup(
        id: 'cap-40',
        teacherId: 'demo-teacher-1',
        teacherName: 'أ. سارة الخطيب',
        title: 'مجموعة الحد الأقصى',
        subject: 'الرياضيات',
        stage: 'الثانوية العامة',
        seatsTotal: 40,
        seatsTaken: 5,
        meetingMode: GroupMeetingMode.online,
      );
      final DemoGroupRepository repo = DemoGroupRepository(
        source: <StudyGroup>[group],
      );
      final AppServices services = AppServices(
        auth: const DemoAuthService(),
        teachers: DemoTeacherRepository(),
        groups: repo,
        bookings: DemoBookingRepository(),
        chats: DemoDirectChatRepository(),
        notifications: DemoNotificationRepository(),
        schedules: DemoScheduleRepository(),
        messages: DemoMessageRepository(),
      );
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.teacher);

      await tester.pumpWidget(
        AppServicesScope(
          services: services,
          child: SessionScope(
            controller: session,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: MaterialApp(
                theme: AppTheme.light,
                home: const GroupMembersScreen(groupId: 'cap-40'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('تعديل السعة'));
      final IconButton increase = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.add_circle_outline),
      );
      expect(increase.onPressed, isNull);
      expect((await repo.findById('cap-40'))!.seatsTotal, 40);
    });
  });
}
