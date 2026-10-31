import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chats_screen.dart';

import '../helpers/test_app.dart';

/// (P28) المحادثات: **تظهر عند الطرفين، وتتحدّث حيًّا، ولا تُرى لغيرهما.**
///
/// ## العطل الذي يحرسه هذا الملف
///
/// كانت قائمة المحادثات تُقرأ مرة واحدة عند البناء. فمحادثة تُنشأ بعد فتح
/// الشاشة (أو رسالة تصل بينما هي مفتوحة) لا تظهر حتى يُغلق المستخدم الصفحة
/// ويعيد فتحها — وهو ما جعل المدرس يقول «المحادثات لا تظهر». الاختبار الأول
/// يُنشئ الخيط **بعد** بناء الشاشة، ويتحقّق أنه يظهر بلا إعادة بناء.
const String _teacherId = DemoData.demoTeacherId;
const String _studentId = DemoData.demoStudentId;
const String _studentName = 'سلمى محمد';
const String _teacherName = 'أ. منى عبد الرحمن';

AppServices _services() {
  final DemoNotificationRepository notifications = DemoNotificationRepository();
  final DemoBookingRepository bookings = DemoBookingRepository(
    notifications: notifications,
    source: const <BookingRequest>[],
  );
  final DemoGroupRepository groups = DemoGroupRepository(
    notifications: notifications,
  );
  return AppServices(
    admin: DemoAdminRepository(),
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: groups,
    bookings: bookings,
    chats: DemoDirectChatRepository(
      // نبدأ بقائمة فارغة: كل خيط في هذه الاختبارات يُنشأ داخل الاختبار نفسه.
      source: const <DirectChat>[],
      messages: const <DirectChatMessage>[],
      // الاستفسار قبل الحجز مسموح فقط حين يفعّله المدرس — نفعّله صراحةً هنا
      // حتى يقيس الاختبار سلوك المحادثة لا سياسة السماح.
      settings: <String, bool>{_teacherId: true, 'demo-teacher-9': true},
      findBooking: bookings.findById,
      isMember: groups.isMember,
      notifications: notifications,
    ),
    notifications: notifications,
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: DemoReviewRepository(),
    favorites: DemoFavoriteRepository(),
  );
}

Widget _host(AppServices services, Widget child, {required UserRole role}) {
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(role);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: ShellScope(
        controller: ShellController(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            theme: AppTheme.light,
            onGenerateRoute: (RouteSettings settings) {
              if (settings.name == RoutePaths.directChat) {
                return MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      DirectChatScreen(chatId: settings.arguments! as String),
                );
              }
              return null;
            },
            home: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ظهور المحادثات', () {
    testWidgets('خيط جديد يُنشأ بعد فتح الشاشة يظهر بلا إعادة فتح', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(services, const DirectChatsScreen(), role: UserRole.teacher),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا محادثات بعد'), findsOneWidget);

      // الطالب يفتح محادثة الآن (بعد بناء شاشة المدرس).
      await services.chats.openChat(
        teacherId: _teacherId,
        teacherName: _teacherName,
        studentId: _studentId,
        studentName: _studentName,
        origin: DirectChatOrigin.inquiry,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_studentName),
        findsOneWidget,
        reason: 'الخيط الجديد لم يظهر بلا إعادة فتح الصفحة',
      );
    });

    testWidgets('رسالة جديدة تظهر في القائمة الحيّة لصاحب المحادثة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      final DirectChat chat = await services.chats.openChat(
        teacherId: _teacherId,
        teacherName: _teacherName,
        studentId: _studentId,
        studentName: _studentName,
        origin: DirectChatOrigin.inquiry,
      );

      await tester.pumpWidget(
        _host(services, const DirectChatsScreen(), role: UserRole.teacher),
      );
      await tester.pumpAndSettle();
      expect(find.text('ابدأ المحادثة'), findsOneWidget);

      await services.chats.sendMessage(
        chatId: chat.id,
        senderId: _studentId,
        senderName: _studentName,
        senderRole: UserRole.student,
        text: 'هل درس الغد في موعده؟',
      );
      await tester.pumpAndSettle();

      expect(
        find.text('هل درس الغد في موعده؟'),
        findsOneWidget,
        reason: 'آخر رسالة لم تظهر في القائمة بلا إعادة فتح',
      );
      // عدّاد «غير مقروء» يظهر لأن المدرس لم يقرأ بعد.
      expect(find.textContaining('لم تُقرأ'), findsOneWidget);
    });

    testWidgets('محادثة لا تخصّ المدرس لا تظهر عنده (عزل)', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await services.chats.openChat(
        teacherId: 'demo-teacher-9',
        teacherName: 'مدرس آخر',
        studentId: 'student-other',
        studentName: 'طالب آخر',
        origin: DirectChatOrigin.inquiry,
      );

      await tester.pumpWidget(
        _host(services, const DirectChatsScreen(), role: UserRole.teacher),
      );
      await tester.pumpAndSettle();

      expect(find.text('طالب آخر'), findsNothing);
      expect(find.text('لا محادثات بعد'), findsOneWidget);
    });
  });

  group('تبادل الرسائل', () {
    test('رسالة الطالب تصل للمدرس ورد المدرس يعود للطالب', () async {
      final AppServices services = _services();

      final DirectChat chat = await services.chats.openChat(
        teacherId: _teacherId,
        teacherName: _teacherName,
        studentId: _studentId,
        studentName: _studentName,
        origin: DirectChatOrigin.inquiry,
      );

      await services.chats.sendMessage(
        chatId: chat.id,
        senderId: _studentId,
        senderName: _studentName,
        senderRole: UserRole.student,
        text: 'سؤال قبل الحجز',
      );
      await services.chats.sendMessage(
        chatId: chat.id,
        senderId: _teacherId,
        senderName: _teacherName,
        senderRole: UserRole.teacher,
        text: 'أهلًا، تفضّل.',
      );

      final List<DirectChatMessage> teacherView = await services.chats
          .watchMessages(chat.id)
          .first;
      expect(teacherView.map((DirectChatMessage m) => m.text), <String>[
        'سؤال قبل الحجز',
        'أهلًا، تفضّل.',
      ]);

      // كل طرف يرى «الطرف الآخر» لا نفسه، ويعرف أن لديه رسالة غير مقروءة.
      final DirectChat latest = (await services.chats.findById(chat.id))!;
      expect(latest.hasUnreadFor(_studentId), isTrue);
      expect(latest.hasUnreadFor(_teacherId), isFalse);
      expect(latest.partnerNameFor(_teacherId), _studentName);
      expect(latest.partnerNameFor(_studentId), _teacherName);
    });

    test('خيط لا يخصّ مستخدمًا ثالثًا لا يظهر في قائمته', () async {
      final AppServices services = _services();

      await services.chats.openChat(
        teacherId: _teacherId,
        teacherName: _teacherName,
        studentId: _studentId,
        studentName: _studentName,
        origin: DirectChatOrigin.inquiry,
      );

      expect(await services.chats.listMine('student-intruder'), isEmpty);
      expect(
        (await services.chats.listMine(_teacherId)).length,
        1,
      );
    });
  });
}
