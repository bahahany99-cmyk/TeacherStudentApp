import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/async_view.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/direct_chat.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_details_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teacher_profile_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_carousel.dart';

import '../helpers/faulty_repositories.dart';
import '../helpers/test_app.dart';

const String _teacherId = DemoData.demoTeacherId;
const String _studentId = DemoData.demoStudentId;

final String _chatId = DirectChat.idFor(
  teacherId: _teacherId,
  studentId: _studentId,
);

/// حزمة خدمات كلها سليمة إلا المستودع الذي نحقن فيه العطل.
AppServices _services({
  FaultPlan? teachersFault,
  FaultPlan? bookingsFault,
  FaultPlan? chatsFault,
  FaultPlan? reviewsFault,
  List<BookingRequest>? bookingSource,
}) {
  final DemoNotificationRepository notifications = DemoNotificationRepository();
  final DemoBookingRepository bookings = bookingsFault == null
      ? DemoBookingRepository(
          source: bookingSource,
          notifications: notifications,
        )
      : FaultyBookingRepository(
          plan: bookingsFault,
          source: bookingSource,
          notifications: notifications,
        );
  return AppServices(
    admin: DemoAdminRepository(),
    auth: const DemoAuthService(),
    teachers: teachersFault == null
        ? DemoTeacherRepository()
        : FaultyTeacherRepository(plan: teachersFault),
    groups: DemoGroupRepository(notifications: notifications),
    bookings: bookings,
    chats: chatsFault == null
        ? DemoDirectChatRepository(findBooking: bookings.findById)
        : FaultyDirectChatRepository(
            plan: chatsFault,
            findBooking: bookings.findById,
          ),
    notifications: notifications,
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: reviewsFault == null
        ? DemoReviewRepository(findBooking: bookings.findById)
        : FaultyReviewRepository(
            plan: reviewsFault,
            findBooking: bookings.findById,
          ),
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
          home: Scaffold(backgroundColor: Colors.white, body: child),
        ),
      ),
    ),
  );
}

/// حجز مؤكد لطالب تجريبي — يُستخدم لدفع شاشة التفاصيل.
BookingRequest _booking({required BookingStatus status}) {
  final DateTime start = DateTime.now().add(const Duration(days: 2));
  return BookingRequest(
    id: 'b1',
    teacherId: _teacherId,
    teacherName: 'أ. سارة الخطيب',
    studentId: _studentId,
    studentName: 'طالب تجريبي',
    subject: 'الرياضيات',
    requestedAt: DateTime.now().subtract(const Duration(hours: 3)),
    status: status,
    dateKey: BookingRulesLite.keyOf(start),
    startMinutes: BookingRulesLite.minutesOf(start),
    durationMinutes: 60,
  );
}

void main() {
  group('انقطاع الشبكة (P16)', () {
    testWidgets('الاستكشاف يعرض سببًا عربيًا ثم يعمل بعد «إعادة المحاولة»', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FaultPlan plan = FaultPlan();
      await tester.pumpWidget(_host(_services(teachersFault: plan), const TeachersScreen()));
      await tester.pumpAndSettle();

      // رسالة عربية مفهومة، لا نص استثناء ولا شاشة بيضاء.
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsWidgets);
      expect(find.text('تحقّق من الاتصال ثم أعد المحاولة.'), findsWidgets);
      expect(tester.takeException(), isNull);

      // عودة الشبكة: نفس الشاشة تعيد القراءة بلا إعادة تشغيل التطبيق.
      plan.alwaysFail = false;
      // قسمان فشلا (المميزون والنتائج) ولكل منهما زرّه.
      final int retries = find.text('إعادة المحاولة').evaluate().length;
      for (int i = 0; i < retries; i++) {
        await tapVisible(tester, find.text('إعادة المحاولة').first);
      }

      expect(find.byType(FeaturedTeachersCarousel), findsOneWidget);
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsNothing);
      expect(plan.calls, greaterThan(1), reason: 'إعادة المحاولة تستدعي المستودع من جديد');
    });

    testWidgets('قبول حجز يفشل: رسالة عربية والحالة لا تتغير', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FaultPlan plan = FaultPlan();
      final AppServices services = _services(
        bookingsFault: plan,
        bookingSource: <BookingRequest>[_booking(status: BookingStatus.pending)],
      );

      await tester.pumpWidget(
        _host(
          services,
          const BookingDetailsScreen(bookingId: 'b1'),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('قبول الطلب'));

      expect(find.textContaining('تحقّق من الاتصال'), findsOneWidget);
      // الحالة لم تُحدَّث محليًا كأن القبول نجح.
      expect(find.text('مؤكد'), findsNothing);
      expect(find.text('بانتظار موافقة المدرس'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('إرسال رسالة يفشل: تنبيه عربي ولا رسالة وهمية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      // البثّ سليم والرسائل تُقرأ؛ الفشل في الإرسال وحده (طلب واحد).
      final FaultPlan plan = FaultPlan.once();
      await tester.pumpWidget(
        _host(
          _services(chatsFault: plan),
          DirectChatScreen(chatId: _chatId),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'هل يبدأ الحجز غدًا؟');
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pumpAndSettle();

      expect(find.textContaining('تحقّق من الاتصال'), findsOneWidget);
      // الحقل لم يُفرَّغ: ما لم يُرسل يبقى أمام المستخدم ليعيد المحاولة.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'هل يبدأ الحجز غدًا؟',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('انقطاع بثّ الرسائل: خطأ مفهوم بدل «لا رسائل بعد»', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FaultPlan plan = FaultPlan();
      await tester.pumpWidget(
        _host(_services(chatsFault: plan), DirectChatScreen(chatId: _chatId)),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      expect(find.text('لا رسائل بعد'), findsNothing);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('قسم التقييمات عند انقطاع البثّ: لا يقول «لا توجد تقييمات»', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          _services(reviewsFault: FaultPlan()),
          const TeacherProfileScreen(teacherId: _teacherId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد تقييمات بعد'), findsNothing);
      expect(find.text('تعذّر تحميل التقييم الآن'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('إرسال تقييم يفشل: تنبيه عربي والورقة تبقى مفتوحة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FaultPlan plan = FaultPlan();
      await tester.pumpWidget(
        _host(
          _services(reviewsFault: plan),
          const BookingDetailsScreen(bookingId: 'demo-booking-4'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('قيّم الحصة'));
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('إرسال التقييم'));

      expect(find.textContaining('تحقّق من الاتصال'), findsOneWidget);
      // الورقة تبقى مفتوحة: لا ندّعي أن التقييم كُتب.
      expect(find.text('تقييم الحصة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('التحميل لا يعلق (P16)', () {
    testWidgets('شاشة أثناء التحميل تعرض حالة انتظار صريحة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          _services(),
          AsyncView<int>(
            load: () => Future<int>.delayed(const Duration(seconds: 5), () => 1),
            builder: (BuildContext context, int value) => Text('وصل: $value'),
          ),
        ),
      );
      // إطار واحد فقط: لا ننتظر انتهاء المؤقت.
      await tester.pump();
      expect(find.byType(FutureBuilder<int>), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('وصل: 1'), findsOneWidget);
    });
  });
}
