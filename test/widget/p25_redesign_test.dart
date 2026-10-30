import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_notification.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/group_draft.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/bookings_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/join_requests_screen.dart';
import 'package:teacher_student_app/features/notifications/presentation/notifications_screen.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/student/presentation/widgets/global_search_panel.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_strip.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_showcase_card.dart';

import '../helpers/test_app.dart';

/// حزمة خدمات تجريبية بمرسِل إشعارات مشترك (كما تُركَّب في التطبيق).
AppServices _services({List<AppNotification>? notifications}) {
  final DemoNotificationRepository repo = DemoNotificationRepository(
    source: notifications,
  );
  return AppServices(
    admin: DemoAdminRepository(),
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

/// يستضيف شاشة بجلسة تجريبية (طالب/مدرس) ومزوّد خدمات يملكه الاختبار.
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
            if (settings.name == RoutePaths.teacherProfile ||
                settings.name == RoutePaths.groupDetails ||
                settings.name == RoutePaths.bookingDetails ||
                settings.name == RoutePaths.featuredTeachers) {
              return MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Text('وجهة ${settings.arguments ?? ''}'),
                ),
              );
            }
            return null;
          },
          home: Scaffold(backgroundColor: Colors.white, body: child),
        ),
      ),
    ),
  );
}

void main() {
  group('P25 — الرئيسية', () {
    testWidgets('رأس ذكي + جرس إشعارات + حبوب تنقّل + شريط مميزين', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(), const StudentHomeScreen()));
      await tester.pumpAndSettle();

      // الجرس حاضر في الرأس.
      expect(find.byType(NotificationBell), findsOneWidget);
      // حبوب التنقّل الثلاثة المطلوبة.
      expect(find.byKey(const Key('home-quick-groups')), findsOneWidget);
      expect(find.byKey(const Key('home-quick-teachers')), findsOneWidget);
      expect(find.byKey(const Key('home-quick-featured')), findsOneWidget);
      // المميزون بمبدّل [أونلاين]/[أوفلاين].
      expect(find.byType(FeaturedTeachersStrip), findsOneWidget);
      expect(find.byKey(featuredSegmentOnlineKey), findsOneWidget);
      expect(find.byKey(featuredSegmentOfflineKey), findsOneWidget);
      // البطاقات تعرض المدرسين بسعرهم وتوثيقهم.
      expect(find.byType(TeacherShowcaseCard), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('المبدّل ينتقل إلى مدرسي الأوفلاين', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(), const StudentHomeScreen()));
      await tester.pumpAndSettle();

      // في البيانات التجريبية الأونلاين: منى + هدى فقط.
      expect(find.text('أ. منى عبد الرحمن'), findsOneWidget);

      await tester.tap(find.byKey(featuredSegmentOfflineKey));
      await tester.pumpAndSettle();

      // الأوفلاين شريحة أخرى: منى (أونلاين) تختفي، وتبقى بطاقات حضورية.
      expect(find.text('أ. منى عبد الرحمن'), findsNothing);
      expect(find.byType(TeacherShowcaseCard), findsWidgets);
    });

    testWidgets('البحث الشامل يعيد مدرسين ومجموعات معًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(), const StudentHomeScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(homeSearchFieldKey), 'الرياضيات');
      // مهلة الكتابة (350ms) ثم استعلام المستودعين.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.byType(GlobalSearchPanel), findsOneWidget);
      // مدرس من النتائج + مجموعة من النتائج، في الشاشة نفسها.
      expect(find.text('أ. سارة الخطيب'), findsWidgets);
      expect(find.text('مجموعة الرياضيات — التفاضل'), findsOneWidget);
      // أثناء البحث تُخفى الأقسام حتى لا يُقرأ قسمان معًا.
      expect(find.byType(FeaturedTeachersStrip), findsNothing);
    });

    testWidgets('لا نتائج: رسالة عربية واضحة بلا استثناء', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(), const StudentHomeScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(homeSearchFieldKey), 'زززززز');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.textContaining('لا نتائج'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('P25 — الإشعارات حيّة', () {
    testWidgets('إشعار جديد يظهر دون إعادة فتح الشاشة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(notifications: <AppNotification>[]);
      await tester.pumpWidget(_host(services, const NotificationsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('لا إشعارات'), findsOneWidget);

      // رسالة من المدرس إلى الطالب عبر المسار الحقيقي ⇒ إشعار حيّ.
      await services.chats.sendMessage(
        chatId: 'demo-teacher-1_demo-student',
        senderId: DemoData.demoTeacherId,
        senderName: 'أ. سارة الخطيب',
        senderRole: UserRole.teacher,
        text: 'تذكير بحصة الغد',
      );
      await tester.pumpAndSettle();

      expect(find.text('لا إشعارات'), findsNothing);
      expect(find.textContaining('أ. سارة الخطيب'), findsWidgets);
    });
  });

  group('P25 — لوحة طلبات المدرس العامة', () {
    testWidgets('طلبات الانضمام وطلبات الحجز تظهر معًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      final StudyGroup group = DemoData.groups.first;

      await services.groups.requestToJoin(
        group: group,
        studentId: 'student-live',
        studentName: 'سلمى محمود',
      );

      await tester.pumpWidget(
        _host(
          services,
          const JoinRequestsScreen(groupId: 'demo-group-1'),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      // قسمان مستقلان: الانضمام والحجز.
      expect(find.text('طلبات الانضمام'), findsOneWidget);
      expect(find.text('طلبات الحجز'), findsOneWidget);
      // اسم الطالب مقدّم الطلب، واسم الطالب صاحب الحجز المعلّق.
      expect(find.text('سلمى محمود'), findsOneWidget);
      expect(find.text('طالب تجريبي'), findsWidgets);
    });

    testWidgets('طلب انضمام لمجموعة أخرى يصل حيًّا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const JoinRequestsScreen(groupId: 'demo-group-1'),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ليلى فؤاد'), findsNothing);

      // مجموعة ثانية **للمدرس نفسه** (مفتوحة بمقاعد): الشاشة كانت مقيّدة
      // بمجموعة واحدة فتُخفي طلبات البقية.
      final StudyGroup second = await services.groups.createGroup(
        teacherId: DemoData.demoTeacherId,
        teacherName: DemoData.teacherName,
        draft: const GroupDraft(
          title: 'مجموعة الجبر — الثالث',
          subject: 'الرياضيات',
          stage: 'الثانوية العامة',
          meetingMode: GroupMeetingMode.center,
          seatsTotal: 10,
          scheduleNote: 'السبت 6 مساءً',
        ),
      );
      await services.groups.requestToJoin(
        group: second,
        studentId: 'student-other',
        studentName: 'ليلى فؤاد',
      );
      await tester.pumpAndSettle();

      expect(find.text('ليلى فؤاد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('P25 — الحجوزات تتزامن مع قرار المدرس', () {
    testWidgets('قبول المدرس يظهر فورًا في شاشة الطالب', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      // طلب حجز جديد بموعد مستقبلي (لا يعتمد على تواريخ البيانات التجريبية).
      final BookingRequest created = await services.bookings.createRequest(
        teacherId: DemoData.demoTeacherId,
        teacherName: DemoData.teacherName,
        studentId: DemoData.demoStudentId,
        studentName: DemoData.studentName,
        subject: 'الرياضيات — التفاضل',
        startsAt: DateTime.now().add(const Duration(days: 3, hours: 2)),
        durationMinutes: 60,
      );

      await tester.pumpWidget(
        _host(services, const BookingsScreen(viewerRole: UserRole.student)),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانتظار موافقة المدرس'), findsWidgets);
      expect(find.text('مؤكد'), findsOneWidget);

      // قرار المدرس من خارج الشاشة (كما يفعله في جهازه).
      await services.bookings.decideRequest(
        request: created,
        teacherId: DemoData.demoTeacherId,
        approve: true,
      );
      await tester.pumpAndSettle();

      // الطلب صار «مؤكد» في شاشة الطالب بلا إعادة فتح.
      expect(find.text('مؤكد'), findsNWidgets(2));
    });
  });
}
