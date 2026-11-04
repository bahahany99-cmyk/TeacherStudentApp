import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/group_message.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/notification_rules.dart';
import 'package:teacher_student_app/features/groups/presentation/group_chat_screen.dart';
import 'package:teacher_student_app/features/notifications/presentation/notifications_screen.dart';

import '../helpers/test_app.dart';

const String _studentId = 'demo-student';

AppNotification _item(int index) {
  return AppNotification(
    id: 'n${index.toString().padLeft(2, '0')}',
    recipientId: _studentId,
    type: NotificationType.bookingAccepted,
    actorId: 'demo-teacher-1',
    actorName: 'أ. سارة الخطيب',
    targetId: 'demo-booking-2',
    title: 'إشعار رقم $index',
    createdAt: DateTime(2026, 10, 27, 12).subtract(Duration(minutes: index)),
  );
}

AppServices _services(
  List<AppNotification> source, {
  DemoMessageRepository? messages,
}) {
  final DemoNotificationRepository repo = DemoNotificationRepository(
    source: source,
  );
  return AppServices(
    admin: DemoAdminRepository(notifications: repo),
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: DemoGroupRepository(notifications: repo),
    bookings: DemoBookingRepository(notifications: repo),
    chats: DemoDirectChatRepository(notifications: repo),
    notifications: repo,
    schedules: DemoScheduleRepository(),
    messages: messages ?? DemoMessageRepository(),
    reviews: DemoReviewRepository(),
    favorites: DemoFavoriteRepository(),
  );
}

Widget _host(
  AppServices services,
  Widget child, {
  UserRole role = UserRole.student,
}) {
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(role);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    ),
  );
}

void main() {
  group('P32 — تصفّح الإشعارات', () {
    testWidgets('الحمولة الأولى صفحة واحدة، والأقدم يُحمَّل عند النزول', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final List<AppNotification> source = <AppNotification>[
        for (int i = 0; i < 25; i++) _item(i),
      ];
      final AppServices services = _services(source);

      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      // الأحدث معروض، والأقدم مما بعد الصفحة الأولى غير محمّل بعد.
      expect(find.text('إشعار رقم 0'), findsOneWidget);
      expect(find.text('إشعار رقم 24'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('إشعار رقم 24'),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pumpAndSettle();

      expect(find.text('إشعار رقم 24'), findsOneWidget);
      // نهاية القائمة معلنة بعد استنفاد الصفحات.
      await tester.scrollUntilVisible(
        find.text('وصلت إلى نهاية الإشعارات.'),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 50,
      );
      expect(find.text('وصلت إلى نهاية الإشعارات.'), findsOneWidget);
    });

    testWidgets('العدّاد لا يتأثر بتصفّح الأقدم', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final List<AppNotification> source = <AppNotification>[
        for (int i = 0; i < 25; i++) _item(i),
      ];
      final AppServices services = _services(source);

      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      // 25 غير مقروء قبل التصفّح.
      expect(
        await services.notifications.watchUnreadCount(_studentId).first,
        25,
      );

      await tester.scrollUntilVisible(
        find.text('إشعار رقم 24'),
        400,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 200,
      );
      await tester.pumpAndSettle();

      // التمرير لا يعلّم شيئًا مقروءًا: العدّاد كما هو.
      expect(
        await services.notifications.watchUnreadCount(_studentId).first,
        25,
      );
      expect(NotificationRules.maxPerLoad, greaterThan(0));
    });

    testWidgets('زر «تعليم الكل» يصفّر شارة الجرس', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final List<AppNotification> source = <AppNotification>[
        for (int i = 0; i < 3; i++) _item(i),
      ];
      final AppServices services = _services(source);

      await tester.pumpWidget(
        _host(
          services,
          Scaffold(
            appBar: AppBar(
              actions: const <Widget>[NotificationBell(viewerId: _studentId)],
            ),
            body: const NotificationsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byTooltip('تعليم الكل مقروءًا'));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsNothing);
      expect(
        await services.notifications.watchUnreadCount(_studentId).first,
        0,
      );
    });
  });

  // ── (P32) قراءة محادثة المجموعة ───────────────────────────────────────────
  group('P32 — قراءة محادثة المجموعة', () {
    testWidgets('فتح محادثة المجموعة يحدّث علامة القراءة لهذا العضو وحده', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DateTime sentAt = DateTime(2026, 10, 27, 12);
      final DemoMessageRepository messages = DemoMessageRepository(
        source: <GroupMessage>[
          GroupMessage(
            id: 'm1',
            groupId: 'demo-group-1',
            senderId: 'student-x',
            senderName: 'طالب',
            senderRole: UserRole.student,
            text: 'سؤال عن الواجب',
            sentAt: sentAt,
          ),
        ],
      );
      final AppServices services = _services(
        <AppNotification>[],
        messages: messages,
      );

      // قبل الفتح: رسالة واحدة غير مقروءة للمدرس، وكذلك لزميل آخر.
      expect(
        await messages.unreadCount(
          groupId: 'demo-group-1',
          memberId: 'demo-teacher-1',
        ),
        1,
      );
      expect(
        await messages.unreadCount(
          groupId: 'demo-group-1',
          memberId: 'student-2',
        ),
        1,
      );

      await tester.pumpWidget(
        _host(
          services,
          const GroupChatScreen(groupId: 'demo-group-1'),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      // بعد الفتح والقراءة: عدّاد هذا العضو صفر، وعدّاد الزميل كما هو.
      expect(
        await messages.unreadCount(
          groupId: 'demo-group-1',
          memberId: 'demo-teacher-1',
        ),
        0,
      );
      expect(
        await messages.unreadCount(
          groupId: 'demo-group-1',
          memberId: 'student-2',
        ),
        1,
      );
      expect(find.text('محادثة المجموعة'), findsOneWidget);
    });
  });
}
