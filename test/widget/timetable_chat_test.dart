import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/group_session.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/group_chat_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/group_timetable_screen.dart';

import '../helpers/test_app.dart';

/// الحزمة التجريبية مع مستودعات P9 مشتركة حتى نتحقق من أثر الكتابة.
class _Harness {
  _Harness()
    : groups = DemoGroupRepository(),
      schedules = DemoScheduleRepository(),
      messages = DemoMessageRepository();

  final DemoGroupRepository groups;
  final DemoScheduleRepository schedules;
  final DemoMessageRepository messages;

  AppServices get services => AppServices(
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: groups,
    bookings: DemoBookingRepository(),
    chats: DemoDirectChatRepository(),
    schedules: schedules,
    messages: messages,
  );
}

Widget _host({
  required _Harness harness,
  required UserRole role,
  required Widget screen,
}) {
  final SessionController session = SessionController(harness.services.auth)
    ..startDemoSession(role);

  return AppServicesScope(
    services: harness.services,
    child: SessionScope(
      controller: session,
      // التطبيق الحقيقي يفرض RTL في `MaterialApp.builder`؛ الاختبار يفعله
      // هنا كي تكون قياسات التخطيط واقعية.
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: screen),
      ),
    ),
  );
}

/// يسجّل الطالب في المجموعة الأولى ويقبل طلبه (ليصبح عضوًا).
Future<void> _makeMember(_Harness harness) async {
  final StudyGroup group = (await harness.groups.findById('demo-group-1'))!;
  final request = await harness.groups.requestToJoin(
    group: group,
    studentId: 'demo-student',
    studentName: 'طالب تجريبي',
  );
  await harness.groups.decideJoinRequest(
    request: request,
    teacherId: group.teacherId,
    approve: true,
  );
}

void main() {
  group('جدول المجموعة (P9)', () {
    testWidgets('المدرس يرى الجدول وزر الإضافة وأزرار الإدارة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          screen: const GroupTimetableScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('السبت'), findsOneWidget);
      expect(find.text('التفاضل — مراجعة الوحدة الثانية'), findsOneWidget);
      expect(find.text('إضافة'), findsOneWidget);
      expect(find.text('تعديل'), findsWidgets);
      expect(find.text('إلغاء الموعد'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('المدرس يضيف موعدًا فيظهر في الجدول', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          screen: const GroupTimetableScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('إضافة'));
      expect(find.text('موعد جديد'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الحصة'),
        'مراجعة نهائية',
      );
      await tapVisible(tester, find.text('الاثنين'));
      await tapVisible(tester, find.text('إضافة الموعد'));
      await tester.pumpAndSettle();

      expect(find.text('مراجعة نهائية'), findsOneWidget);
      final List<GroupSession> sessions = await harness.schedules.listForGroup(
        'demo-group-1',
      );
      expect(
        sessions.any((GroupSession s) => s.title == 'مراجعة نهائية'),
        isTrue,
      );
    });

    testWidgets('عنوان قصير يمنع الحفظ برسالة عربية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          screen: const GroupTimetableScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('إضافة'));
      await tester.enterText(
        find.widgetWithText(TextField, 'عنوان الحصة'),
        'أب',
      );
      await tapVisible(tester, find.text('إضافة الموعد'));
      await tester.pumpAndSettle();

      expect(find.text('عنوان الحصة من 3 إلى 60 حرفًا.'), findsOneWidget);
      expect(
        (await harness.schedules.listForGroup('demo-group-1')).length,
        2,
        reason: 'لم يُضف شيء',
      );
    });

    testWidgets('الطالب العضو يرى الجدول بلا أزرار إدارة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _makeMember(harness);

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupTimetableScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('التفاضل — مراجعة الوحدة الثانية'), findsOneWidget);
      expect(find.text('إضافة'), findsNothing);
      expect(find.text('إلغاء الموعد'), findsNothing);
    });

    testWidgets('غير العضو يرى دعوة للانضمام لا جدولًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupTimetableScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الجدول لأعضاء المجموعة'), findsOneWidget);
      expect(find.text('التفاضل — مراجعة الوحدة الثانية'), findsNothing);
    });
  });

  group('محادثة المجموعة (P9)', () {
    testWidgets('العضو يقرأ الرسائل ويرسل رسالة تظهر في القائمة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _makeMember(harness);

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupChatScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('هنبدأ الوحدة الثانية'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'جاهز يا أستاذ');
      await tapVisible(
        tester,
        find.widgetWithIcon(IconButton, Icons.send),
      );
      await tester.pumpAndSettle();

      expect(find.text('جاهز يا أستاذ'), findsOneWidget);
      expect(
        (await harness.messages.listForGroup('demo-group-1')).last.text,
        'جاهز يا أستاذ',
      );
    });

    testWidgets('رسالة فارغة لا تُرسل', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();
      await _makeMember(harness);

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupChatScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tapVisible(
        tester,
        find.widgetWithIcon(IconButton, Icons.send),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يمكن إرسال رسالة فارغة.'), findsOneWidget);
      expect(
        (await harness.messages.listForGroup('demo-group-1')).length,
        1,
      );
    });

    testWidgets('غير العضو يُمنع من المحادثة برسالة واضحة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.student,
          screen: const GroupChatScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المحادثة لأعضاء المجموعة'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('المدرس صاحب المجموعة يشارك في المحادثة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness();

      await tester.pumpWidget(
        _host(
          harness: harness,
          role: UserRole.teacher,
          screen: const GroupChatScreen(groupId: 'demo-group-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('مدرس'), findsWidgets);
    });
  });
}
