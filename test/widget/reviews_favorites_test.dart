import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/favorite.dart';
import 'package:teacher_student_app/data/models/teacher_rating.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_details_screen.dart';
import 'package:teacher_student_app/features/favorites/presentation/favorites_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/groups_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';
import 'package:teacher_student_app/features/teachers/presentation/teacher_profile_screen.dart';

import '../helpers/test_app.dart';

const String _studentId = DemoData.demoStudentId;
const String _teacherId = DemoData.demoTeacherId;

AppServices _services({
  List<Favorite>? favorites,
  DemoReviewRepository? reviews,
}) {
  final DemoBookingRepository bookings = DemoBookingRepository();
  return AppServices(
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: DemoGroupRepository(),
    bookings: bookings,
    chats: DemoDirectChatRepository(findBooking: bookings.findById),
    notifications: DemoNotificationRepository(),
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: reviews ?? DemoReviewRepository(findBooking: bookings.findById),
    favorites: DemoFavoriteRepository(source: favorites),
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
            if (settings.name == RoutePaths.teacherProfile) {
              return MaterialPageRoute<void>(
                builder: (_) =>
                    Scaffold(body: Text('ملف ${settings.arguments}')),
              );
            }
            if (settings.name == RoutePaths.groupDetails) {
              return MaterialPageRoute<void>(
                builder: (_) =>
                    Scaffold(body: Text('مجموعة ${settings.arguments}')),
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
  group('عرض التقييمات في ملف المدرس (P13)', () {
    testWidgets('المتوسط الحقيقي وقائمة التقييمات من البيانات', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const TeacherProfileScreen(teacherId: 'demo-teacher-2'),
        ),
      );
      await tester.pumpAndSettle();

      // متوسط تقييمَي البيانات التجريبية (5 + 4) من 2.
      expect(find.textContaining('4.5 من 5'), findsWidgets);
      expect(find.text('محمود سيد'), findsOneWidget);
      expect(
        find.textContaining('شرح الفيزياء بطريقة بسيطة'),
        findsOneWidget,
      );
    });

    testWidgets('مدرس بلا تقييمات يعرض حالة فراغ لا متوسطًا كاذبًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const TeacherProfileScreen(teacherId: _teacherId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد تقييمات بعد'), findsOneWidget);
      // الأرقام القديمة في الملف تبقى معروضة حين لا يوجد تقييم داخل التطبيق.
      expect(find.textContaining('126 تقييم'), findsOneWidget);
    });

    testWidgets('نجمة المفضلة تحفظ المدرس وتتحول إلى ممتلئة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const TeacherProfileScreen(teacherId: _teacherId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      await tapVisible(tester, find.byIcon(Icons.favorite_border));

      final List<Favorite> mine = await services.favorites.listForStudent(
        _studentId,
      );
      expect(mine, hasLength(1));
      expect(mine.single.kind, FavoriteKind.teacher);
      expect(mine.single.targetId, _teacherId);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });

    testWidgets('النجمة لا تظهر لواجهة المدرس', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const TeacherProfileScreen(teacherId: _teacherId),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite_border), findsNothing);
    });
  });

  group('كتابة التقييم من حجز منفّذ (P13)', () {
    testWidgets('الحجز المنفّذ يفتح ورقة التقييم ويكتبها', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const BookingDetailsScreen(bookingId: 'demo-booking-4'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('قيّم الحصة'));

      // الورقة: اختيار 4 نجوم ثم تعليق ثم إرسال.
      expect(find.text('تقييم الحصة'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(3));
      await tester.pumpAndSettle();
      expect(find.text('4 من 5'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'شرح ممتاز');
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('إرسال التقييم'));

      // الورقة أُغلقت، والحالة صارت «تقييمك».
      expect(find.text('تقييم الحصة'), findsNothing);
      expect(find.text('تقييمك: 4 من 5'), findsOneWidget);

      final TeacherRating rating = await services.reviews.ratingFor(
        _teacherId,
      );
      expect(rating.totalReviews, 1);
      expect(rating.ratingSum, 4);
    });

    testWidgets('لا إرسال بلا اختيار نجوم: الزر معطّل', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const BookingDetailsScreen(bookingId: 'demo-booking-4'),
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('قيّم الحصة'));

      final FilledButton send = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'إرسال التقييم'),
      );
      expect(send.onPressed, isNull);

      // ومع ذلك: لا تقييم كُتب، والمتوسط ما زال فارغًا.
      expect((await services.reviews.ratingFor(_teacherId)).isEmpty, isTrue);
    });

    testWidgets('الحجز المعلّق لا يعرض زر التقييم', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(
        _host(
          services,
          const BookingDetailsScreen(bookingId: 'demo-booking-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قيّم الحصة'), findsNothing);
    });
  });

  group('المفضلة (P13)', () {
    testWidgets('شاشة المفضلة تعرض المدرسين المحفوظين فقط', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services(
        favorites: <Favorite>[
          Favorite(
            studentId: _studentId,
            kind: FavoriteKind.teacher,
            targetId: _teacherId,
            createdAt: DateTime(2026, 10, 20),
          ),
        ],
      );

      await tester.pumpWidget(_host(services, const FavoritesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('المدرسون'), findsOneWidget);
      expect(find.text('المجموعات'), findsOneWidget);
      expect(find.text('أ. سارة الخطيب'), findsOneWidget);

      // تبويب المجموعات فارغ لأن المحفوظ مدرس فقط.
      await tester.tap(find.text('المجموعات'));
      await tester.pumpAndSettle();
      expect(find.text('لا مجموعات في المفضلة'), findsOneWidget);
    });

    testWidgets('المفضلة الفارغة تعرض حالة فراغ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(_host(services, const FavoritesScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لا مدرسين في المفضلة'), findsOneWidget);
    });

    testWidgets('نجمة بطاقة المجموعة تحفظ المجموعة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await tester.pumpWidget(_host(services, const GroupsScreen.discover()));
      await tester.pumpAndSettle();

      final Finder star = find.descendant(
        of: find.byType(GroupCard).first,
        matching: find.byIcon(Icons.favorite_border),
      );
      expect(star, findsOneWidget);

      await tapVisible(tester, star);

      final List<Favorite> mine = await services.favorites.listForStudent(
        _studentId,
      );
      expect(mine, hasLength(1));
      expect(mine.single.kind, FavoriteKind.group);
    });
  });
}
