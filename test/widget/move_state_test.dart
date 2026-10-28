import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_join_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/move_rules.dart';
import 'package:teacher_student_app/features/groups/presentation/group_chat_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_details_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_members_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_timetable_screen.dart';

import '../helpers/test_app.dart';

const String _teacherId = DemoData.demoTeacherId;

/// حزمة بمستودع مشترك: النقل يحدث «من جهة المدرس» والشاشة تُفتح «من جهة
/// الطالب»، وهو الوضع الحقيقي الذي نريد التحقق منه.
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
  required Widget screen,
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
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    ),
  );
}

/// يجعل طالب المعاينة عضوًا في `groupId` عبر مسار الانضمام الحقيقي
/// (طلب ← قبول)، فيبقى بعد ذلك سجل طلب «مقبول» كما في الإنتاج.
Future<void> _joinAndAccept(_Harness harness, String groupId) async {
  final StudyGroup group = (await harness.groups.findById(groupId))!;
  final GroupJoinRequest request = await harness.groups.requestToJoin(
    group: group,
    studentId: DemoData.demoStudentId,
    studentName: 'طالب تجريبي',
  );
  await harness.groups.decideJoinRequest(
    request: request,
    teacherId: _teacherId,
    approve: true,
  );
}

/// ينقل طالب المعاينة من `from` إلى `to` بعد التأكد من وجود مقعد في الهدف.
Future<void> _moveTo(_Harness harness, String from, String to) async {
  final StudyGroup target = (await harness.groups.findById(to))!;
  if (target.isFull) {
    await harness.groups.updateGroupCapacity(
      groupId: to,
      teacherId: _teacherId,
      seatsTotal: target.seatsTotal + 1,
    );
  }
  await harness.groups.moveMember(
    memberId: DemoData.demoStudentId,
    fromGroupId: from,
    toGroupId: to,
    teacherId: _teacherId,
  );
}

void main() {
  group('حالة الطالب بعد النقل (A-73)', () {
    testWidgets('العضو يرى «أنت عضو» لا دعوة للانضمام', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _joinAndAccept(harness, 'demo-group-1');

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupDetailsScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنت عضو في هذه المجموعة.'), findsOneWidget);
      expect(find.text('طلب الانضمام'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('بعد النقل: المجموعة القديمة تعرض طلب الانضمام من جديد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _joinAndAccept(harness, 'demo-group-1');
      await _moveTo(harness, 'demo-group-1', 'demo-group-5');

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupDetailsScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      // لا عضوية ولا «أنت عضو» ولا «قُبلت» — الحالة القديمة اختفت مع النقل.
      expect(find.text('أنت عضو في هذه المجموعة.'), findsNothing);
      expect(find.textContaining('طلب الانضمام'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('بعد النقل: المجموعة الجديدة تعرض العضوية مباشرة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _joinAndAccept(harness, 'demo-group-1');
      await _moveTo(harness, 'demo-group-1', 'demo-group-5');

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupDetailsScreen(groupId: 'demo-group-5'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أنت عضو في هذه المجموعة.'), findsOneWidget);
      expect(find.text('طلب الانضمام'), findsNothing);
    });

    testWidgets('شاشة المحادثة القديمة تشرح النقل بدل رسالة مبهمة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _joinAndAccept(harness, 'demo-group-1');
      await _moveTo(harness, 'demo-group-1', 'demo-group-5');

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupChatScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المحادثة لأعضاء المجموعة'), findsOneWidget);
      expect(find.text(MoveRules.notMemberHint), findsOneWidget);
    });

    testWidgets('شاشة الجدول القديمة تشرح النقل أيضًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _joinAndAccept(harness, 'demo-group-1');
      await _moveTo(harness, 'demo-group-1', 'demo-group-5');

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupTimetableScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الجدول لأعضاء المجموعة'), findsOneWidget);
      expect(find.text(MoveRules.notMemberHint), findsOneWidget);
    });

    testWidgets('المدرس يرى أثر النقل على صف العضو (من أين جاء)', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _joinAndAccept(harness, 'demo-group-1');
      await _moveTo(harness, 'demo-group-1', 'demo-group-5');

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          screen: const GroupMembersScreen(groupId: 'demo-group-5'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('نُقل من'), findsOneWidget);
      expect(find.textContaining('مجموعة الرياضيات — التفاضل'), findsWidgets);
    });
  });
}
