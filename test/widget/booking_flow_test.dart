import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_details_screen.dart';
import 'package:teacher_student_app/features/bookings/presentation/bookings_screen.dart';

import '../helpers/test_app.dart';

const String _teacherId = DemoData.demoTeacherId;
const String _studentId = DemoData.demoStudentId;

/// موعد بعد يومين عند السادسة مساءً — داخل النافذة وخارج مهلة الـ12 ساعة.
DateTime _slot() {
  final DateTime base = DateTime.now().add(const Duration(days: 2));
  return DateTime(base.year, base.month, base.day, 18);
}

BookingRequest _booking({
  required String id,
  required BookingStatus status,
  BookingActor? proposedBy,
  DateTime? proposedAt,
}) {
  final DateTime start = _slot();
  return BookingRequest(
    id: id,
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
    proposedBy: proposedBy,
    proposalDateKey: proposedAt == null
        ? null
        : BookingRulesLite.keyOf(proposedAt),
    proposalStartMinutes: proposedAt == null
        ? null
        : BookingRulesLite.minutesOf(proposedAt),
  );
}

class _Harness {
  _Harness({required List<BookingRequest> bookings})
    : repo = DemoBookingRepository(source: bookings);

  final DemoBookingRepository repo;

  AppServices get services => AppServices(
    admin: DemoAdminRepository(),
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: DemoGroupRepository(),
    bookings: repo,
    chats: DemoDirectChatRepository(),
    notifications: DemoNotificationRepository(),
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: DemoReviewRepository(),
    favorites: DemoFavoriteRepository(),
  );
}

Widget _host({
  required _Harness harness,
  required UserRole role,
  required String bookingId,
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
        child: MaterialApp(
          theme: AppTheme.light,
          home: BookingDetailsScreen(bookingId: bookingId),
        ),
      ),
    ),
  );
}

void main() {
  group('تفاصيل الحجز — إجراءات المدرس (P10)', () {
    testWidgets('قبول طلب معلّق يحوّله إلى مؤكد ويحجز الوقت', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(id: 'b1', status: BookingStatus.pending),
        ],
      );

      await tester.pumpWidget(
        _host(harness: harness, role: UserRole.teacher, bookingId: 'b1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانتظار موافقة المدرس'), findsOneWidget);
      expect(find.text('موعد الحصة'), findsOneWidget);

      await tapVisible(tester, find.text('قبول الطلب'));

      expect(
        (await harness.repo.findById('b1'))!.status,
        BookingStatus.accepted,
      );
      expect(find.text('مؤكد'), findsWidgets);
    });

    testWidgets('رفض الطلب يغلق الحالة بلا إجراءات متبقية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(id: 'b1', status: BookingStatus.pending),
        ],
      );

      await tester.pumpWidget(
        _host(harness: harness, role: UserRole.teacher, bookingId: 'b1'),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('رفض'));

      expect(
        (await harness.repo.findById('b1'))!.status,
        BookingStatus.rejected,
      );
      expect(find.textContaining('لا إجراء متاح'), findsOneWidget);
    });
  });

  group('تفاصيل الحجز — إجراءات الطالب (P10)', () {
    testWidgets('الطالب لا يرى أزرار قرار المدرس', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(id: 'b1', status: BookingStatus.pending),
        ],
      );

      await tester.pumpWidget(
        _host(harness: harness, role: UserRole.student, bookingId: 'b1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('قبول الطلب'), findsNothing);
      expect(find.text('رفض'), findsNothing);
      expect(find.text('إلغاء الموعد'), findsOneWidget);
      expect(find.text('اقتراح وقت بديل'), findsOneWidget);
    });

    testWidgets('الطالب يلغي طلبه فيُغلق', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(id: 'b1', status: BookingStatus.pending),
        ],
      );

      await tester.pumpWidget(
        _host(harness: harness, role: UserRole.student, bookingId: 'b1'),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('إلغاء الموعد'));
      // تأكيد في الحوار.
      await tapVisible(tester, find.widgetWithText(FilledButton, 'إلغاء الموعد'));

      final BookingRequest after = (await harness.repo.findById('b1'))!;
      expect(after.status, BookingStatus.cancelled);
      expect(after.cancelledBy, _studentId);
    });

    testWidgets('اقتراح المدرس: الطالب يرى الوقت البديل ويقبله', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final DateTime proposed = _slot().add(const Duration(hours: 2));
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(
            id: 'b1',
            status: BookingStatus.rescheduleProposed,
            proposedBy: BookingActor.teacher,
            proposedAt: proposed,
          ),
        ],
      );

      await tester.pumpWidget(
        _host(harness: harness, role: UserRole.student, bookingId: 'b1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('الوقت البديل'), findsOneWidget);
      expect(find.textContaining('اقتراح المدرس'), findsOneWidget);

      await tapVisible(tester, find.text('قبول الوقت البديل'));

      final BookingRequest after = (await harness.repo.findById('b1'))!;
      expect(after.status, BookingStatus.accepted);
      expect(after.startMinutes, BookingRulesLite.minutesOf(proposed));
    });

    testWidgets('الطلب المنفّذ بلا إجراءات', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(id: 'b1', status: BookingStatus.completed),
        ],
      );

      await tester.pumpWidget(
        _host(harness: harness, role: UserRole.teacher, bookingId: 'b1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('منفّذ'), findsWidgets);
      expect(find.textContaining('لا إجراء متاح'), findsOneWidget);
    });
  });

  group('قائمة الحجوزات (P10)', () {
    testWidgets('صف الحجز يعرض الموعد ويفتح شاشة التفاصيل', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _Harness harness = _Harness(
        bookings: <BookingRequest>[
          _booking(id: 'b1', status: BookingStatus.pending),
        ],
      );
      final AppServices services = harness.services;
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
                onGenerateRoute: (RouteSettings settings) {
                  if (settings.name == RoutePaths.bookingDetails) {
                    return MaterialPageRoute<void>(
                      builder: (_) => BookingDetailsScreen(
                        bookingId: settings.arguments! as String,
                      ),
                    );
                  }
                  return null;
                },
                home: const BookingsScreen(viewerRole: UserRole.teacher),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانتظار موافقة المدرس'), findsOneWidget);

      await tapVisible(tester, find.text('الرياضيات'));
      // انتقلنا إلى التفاصيل: العنوان وعنوان الموعد ظاهران.
      expect(find.text('تفاصيل الطلب'), findsOneWidget);
      expect(find.text('موعد الحصة'), findsOneWidget);
    });
  });
}
