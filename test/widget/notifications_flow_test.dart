import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/notifications/presentation/notifications_screen.dart';

import '../helpers/test_app.dart';

const String _studentId = 'demo-student';
const String _teacherId = 'demo-teacher-1';

AppServices _services({List<AppNotification>? notifications}) {
  final DemoNotificationRepository repo = DemoNotificationRepository(
    source: notifications,
  );
  return AppServices(
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: DemoGroupRepository(notifications: repo),
    bookings: DemoBookingRepository(notifications: repo),
    chats: DemoDirectChatRepository(notifications: repo),
    notifications: repo,
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
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
        child: MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: (RouteSettings settings) {
            // وجهات العمق: شاشات بديلة تعرض معرّف الوجهة.
            if (settings.name == RoutePaths.bookingDetails) {
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Text('حجز ${settings.arguments}'),
                ),
              );
            }
            if (settings.name == RoutePaths.directChat) {
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Text('محادثة ${settings.arguments}'),
                ),
              );
            }
            if (settings.name == RoutePaths.groupDetails) {
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Text('مجموعة ${settings.arguments}'),
                ),
              );
            }
            return null;
          },
          home: child,
        ),
      ),
    ),
  );
}

void main() {
  group('شاشة الإشعارات (P12)', () {
    testWidgets('تعرض إشعارات المستلم فقط مع الوقت النسبي', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        notifications: <AppNotification>[
          AppNotification(
            id: 'n1',
            recipientId: _studentId,
            type: NotificationType.bookingAccepted,
            actorId: _teacherId,
            actorName: 'أ. سارة الخطيب',
            targetId: 'demo-booking-2',
            title: 'قبلت أ. سارة الخطيب طلب الحجز',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
          ),
          AppNotification(
            id: 'n2',
            recipientId: _teacherId,
            type: NotificationType.bookingRequested,
            actorId: _studentId,
            actorName: 'طالب تجريبي',
            targetId: 'demo-booking-1',
            title: 'طلب حجز جديد من طالب تجريبي',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('قبلت أ. سارة الخطيب طلب الحجز'), findsOneWidget);
      // إشعار المدرس لا يظهر للطالب على هذه الشاشة.
      expect(find.text('طلب حجز جديد من طالب تجريبي'), findsNothing);
      expect(find.text('قبل 5 دقيقة'), findsOneWidget);
    });

    testWidgets('الضغط يعلّم مقروءًا ويفتح وجهة الحجز', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        notifications: <AppNotification>[
          AppNotification(
            id: 'n1',
            recipientId: _studentId,
            type: NotificationType.bookingAccepted,
            actorId: _teacherId,
            actorName: 'أ. سارة الخطيب',
            targetId: 'demo-booking-2',
            title: 'قبلت أ. سارة الخطيب طلب الحجز',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('قبلت أ. سارة الخطيب طلب الحجز'));

      expect(find.text('حجز demo-booking-2'), findsOneWidget);
      final List<AppNotification> mine = await services.notifications.listMine(
        _studentId,
      );
      expect(mine.single.isRead, isTrue);
    });

    testWidgets('إشعار رسالة يفتح المحادثة', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        notifications: <AppNotification>[
          AppNotification(
            id: 'n1',
            recipientId: _studentId,
            type: NotificationType.directMessage,
            actorId: _teacherId,
            actorName: 'أ. سارة الخطيب',
            targetId: 'demo-teacher-1_demo-student',
            title: 'رسالة من أ. سارة الخطيب',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('رسالة من أ. سارة الخطيب'));
      expect(find.text('محادثة demo-teacher-1_demo-student'), findsOneWidget);
    });

    testWidgets('«تعليم الكل مقروءًا» يصفّر غير المقروء', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(
        (await services.notifications.listMine(_studentId))
            .where((AppNotification n) => !n.isRead)
            .length,
        1,
      );

      await tester.tap(find.byTooltip('تعليم الكل مقروءًا'));
      await tester.pumpAndSettle();

      expect(
        (await services.notifications.listMine(_studentId))
            .where((AppNotification n) => !n.isRead)
            .length,
        0,
      );
    });

    testWidgets('حالة الفراغ تظهر حين لا إشعارات', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        notifications: <AppNotification>[],
      );
      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لا إشعارات'), findsOneWidget);
    });
  });

  group('جرس الإشعارات (P12)', () {
    testWidgets('يعرض عدّاد غير المقروء ويختفي بعد القراءة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      await tester.pumpWidget(
        _host(services, Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell(viewerId: _studentId)]))),
      );
      await tester.pumpAndSettle();

      // في البيانات التجريبية إشعار واحد غير مقروء للطالب.
      expect(find.text('1'), findsOneWidget);

      await services.notifications.markAllRead(_studentId);
      await tester.pumpAndSettle();

      expect(find.text('1'), findsNothing);
      expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    });

    testWidgets('إشعار جديد من فعل حقيقي يرفع العدّاد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        notifications: <AppNotification>[],
      );
      await tester.pumpWidget(
        _host(services, Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell(viewerId: _studentId)]))),
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsNothing);

      // رسالة من المدرس للطالب عبر المسار الحقيقي (P11) ⇒ إشعار للطالب.
      await services.chats.sendMessage(
        chatId: 'demo-teacher-1_demo-student',
        senderId: _teacherId,
        senderName: 'أ. سارة الخطيب',
        senderRole: UserRole.teacher,
        text: 'وصلت أسئلتك، سأرد الليلة.',
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(
        (await services.notifications.listMine(_studentId)).single.type,
        NotificationType.directMessage,
      );
    });

    testWidgets('جرس المدرس يعرض إشعاره هو لا إشعار الطالب', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      await tester.pumpWidget(
        _host(
          services,
          Scaffold(appBar: AppBar(actions: const <Widget>[NotificationBell(viewerId: _teacherId)])),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(
        (await services.notifications.listMine(_teacherId)).single.type,
        NotificationType.bookingRequested,
      );
    });
  });

  group('الربط مع تدفق الحجز (P12)', () {
    test('قبول طلب معلّق يُنشئ إشعارًا للطالب', () async {
      final AppServices services = _services(
        notifications: <AppNotification>[],
      );

      final List<BookingRequest> bookings = await services.bookings.listMine();
      final BookingRequest pending = bookings.firstWhere(
        (BookingRequest b) => b.status == BookingStatus.pending,
      );
      await services.bookings.decideRequest(
        request: pending,
        teacherId: _teacherId,
        approve: true,
      );

      final List<AppNotification> studentInbox = await services.notifications
          .listMine(pending.studentId!);
      expect(studentInbox.length, 1);
      expect(studentInbox.single.type, NotificationType.bookingAccepted);
      expect(studentInbox.single.targetId, pending.id);
    });
  });
}
