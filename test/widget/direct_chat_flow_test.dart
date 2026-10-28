import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/validation/direct_chat_rules.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chats_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teacher_profile_screen.dart';

import '../helpers/test_app.dart';

const String _teacherId = 'demo-teacher-1';
const String _studentId = DemoData.demoStudentId;
final String _chatId = DirectChat.idFor(
  teacherId: _teacherId,
  studentId: _studentId,
);

/// بيانات حجز بسيطة حتى يجد المسار «الأصل الموثّق» حين يُطلب.
AppServices _services({
  List<DirectChat>? chats,
  List<DirectChatMessage>? messages,
  Map<String, bool>? settings,
}) {
  final DemoNotificationRepository notifications = DemoNotificationRepository();
  final DemoBookingRepository bookings = DemoBookingRepository(
    notifications: notifications,
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
      source: chats,
      messages: messages,
      settings: settings,
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
            if (settings.name == RoutePaths.directChat) {
              return MaterialPageRoute<void>(
                builder: (_) =>
                    DirectChatScreen(chatId: settings.arguments! as String),
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
  group('شاشة المحادثة المباشرة (P11)', () {
    testWidgets('تعرض الرسائل القائمة باسم الطرف الآخر', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(_services(), DirectChatScreen(chatId: _chatId)),
      );
      await tester.pumpAndSettle();

      // العنوان والمادة من المحادثة التجريبية الأولى.
      expect(find.text('أ. سارة الخطيب'), findsOneWidget);
      expect(find.text('الرياضيات — التفاضل'), findsOneWidget);
      expect(
        find.text(
          'السلام عليكم، أرسلت طلب حجز لمراجعة التفاضل. هل الموعد مناسب؟',
        ),
        findsOneWidget,
      );
      expect(find.text('تمام يا أستاذة، أجهّز أسئلة الوحدة الثانية.'), findsOneWidget);
      // الفاصل الزمني يظهر مع الرسالة.
      expect(find.textContaining('6:40 م'), findsOneWidget);
    });

    testWidgets('إرسال رسالة يضيفها فورًا للمحادثة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      await tester.pumpWidget(
        _host(services, DirectChatScreen(chatId: _chatId)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'سؤال قبل الحصة: هل نبدأ من الوحدة الأولى؟',
      );
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pumpAndSettle();

      expect(
        find.text('سؤال قبل الحصة: هل نبدأ من الوحدة الأولى؟'),
        findsOneWidget,
      );
      // الحقل يُفرّغ بعد الإرسال.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      // ووصلت للطرف الآخر فعلًا (لا عرض وهمي).
      final DirectChat chat = (await services.chats.findById(_chatId))!;
      expect(chat.lastMessageText, 'سؤال قبل الحصة: هل نبدأ من الوحدة الأولى؟');
    });

    testWidgets('رسالة فارغة لا تُرسل', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      await tester.pumpWidget(
        _host(services, DirectChatScreen(chatId: _chatId)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '    ');
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pumpAndSettle();

      expect(find.text('لا يمكن إرسال رسالة فارغة.'), findsOneWidget);
      final DirectChat chat = (await services.chats.findById(_chatId))!;
      expect(chat.lastMessageText, isNot('    '));
    });

    testWidgets('استفسار أُوقف استقباله: سبب المنع بدل صندوق الكتابة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DirectChat inquiry = DirectChat(
        id: DirectChat.idFor(teacherId: 'demo-teacher-2', studentId: _studentId),
        teacherId: 'demo-teacher-2',
        teacherName: 'أ. أحمد الشناوي',
        studentId: _studentId,
        studentName: 'طالب تجريبي',
        origin: DirectChatOrigin.inquiry,
        createdAt: DateTime(2026, 10, 20, 10),
      );
      final AppServices services = _services(
        chats: <DirectChat>[inquiry],
        messages: const <DirectChatMessage>[],
        settings: <String, bool>{'demo-teacher-2': false},
      );

      await tester.pumpWidget(
        _host(services, DirectChatScreen(chatId: inquiry.id)),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('أوقف المدرس استقبال الرسائل قبل الحجز'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('صندوق المحادثات (P11)', () {
    testWidgets('يعرض محادثات الطرف الحالي ويعلّم غير المقروء', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(_services(), const DirectChatsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('أ. سارة الخطيب'), findsOneWidget);
      expect(find.text('أ. منى عبد الرحمن'), findsOneWidget);
      // محادثة «منى» وصلت منها رسالة بعد آخر قراءة ⇒ وسم «جديد».
      expect(find.text('جديد'), findsOneWidget);
      expect(find.text('مرتبطة بحجز'), findsOneWidget);
      expect(find.text('استفسار قبل الحجز'), findsOneWidget);
    });

    testWidgets('الطالب الذي لا محادثات له يرى حالة فراغ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        chats: const <DirectChat>[],
        messages: const <DirectChatMessage>[],
      );
      await tester.pumpWidget(_host(services, const DirectChatsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لا محادثات بعد'), findsOneWidget);
    });
  });

  group('خصوصية المدرس في ملفه العام (P11)', () {
    testWidgets('خيار مغلق: زر المحادثة يشرح السبب ولا يفتح شيئًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      // teacher-2 في البيانات التجريبية لا يستقبل استفسارات.
      final AppServices services = _services(
        chats: const <DirectChat>[],
        messages: const <DirectChatMessage>[],
        settings: <String, bool>{'demo-teacher-2': false},
      );

      await tester.pumpWidget(
        _host(
          services,
          const TeacherProfileScreen(teacherId: 'demo-teacher-2'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('محادثة'));

      expect(find.textContaining('لا يستقبل رسائل قبل الحجز'), findsOneWidget);
      // لم تُنشأ محادثة جديدة.
      final DirectChat? chat = await services.chats.findById(
        DirectChat.idFor(teacherId: 'demo-teacher-2', studentId: _studentId),
      );
      expect(chat, isNull);
    });

    testWidgets('خيار مفتوح: المحادثة تُنشأ كاستفسار', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        chats: const <DirectChat>[],
        messages: const <DirectChatMessage>[],
        settings: <String, bool>{'demo-teacher-2': true},
      );

      await tester.pumpWidget(
        _host(services, const TeacherProfileScreen(teacherId: 'demo-teacher-2')),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('محادثة'));

      final DirectChat? chat = await services.chats.findById(
        DirectChat.idFor(teacherId: 'demo-teacher-2', studentId: _studentId),
      );
      expect(chat, isNotNull);
      expect(chat!.origin, DirectChatOrigin.inquiry);
      expect(
        DirectChatRules.canView(chat: chat, viewerId: _studentId),
        isTrue,
      );
    });
  });
}
