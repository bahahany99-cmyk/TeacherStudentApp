import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/route_paths.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/teacher_review.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/admin/presentation/teacher_verification_screen.dart';
import 'package:teacher_student_app/features/bookings/presentation/booking_details_screen.dart';
import 'package:teacher_student_app/features/chat/presentation/direct_chat_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/my_teacher_profile_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teacher_profile_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';

import '../helpers/test_app.dart';

/// رحلات كاملة (P16) على نفس حزمة الخدمات.
///
/// كل رحلة تُبدّل الدور بإعادة بناء الشجرة على **نفس** `AppServices`: هذا هو
/// الفرق بين اختبار شاشة واختبار رحلة — الحالة التي يكتبها طرف يجب أن يراها
/// الطرف الآخر بلا وسيط.
AppServices _services() {
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
      findBooking: bookings.findById,
      isMember: groups.isMember,
      notifications: notifications,
    ),
    notifications: notifications,
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: DemoReviewRepository(findBooking: bookings.findById),
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
            switch (settings.name) {
              case RoutePaths.teacherProfile:
                return MaterialPageRoute<void>(
                  builder: (_) => TeacherProfileScreen(
                    teacherId: settings.arguments! as String,
                  ),
                );
              case RoutePaths.directChat:
                return MaterialPageRoute<void>(
                  builder: (_) =>
                      DirectChatScreen(chatId: settings.arguments! as String),
                );
              case RoutePaths.bookingDetails:
                return MaterialPageRoute<void>(
                  builder: (_) => BookingDetailsScreen(
                    bookingId: settings.arguments! as String,
                  ),
                );
              default:
                return null;
            }
          },
          home: Scaffold(backgroundColor: Colors.white, body: child),
        ),
      ),
    ),
  );
}

void main() {
  group('رحلة A — طالب يكتشف مدرسًا ويحجز ثم يقيّم (G7)', () {
    testWidgets('اكتشاف ← طلب حجز ← قبول ← محادثة ← حصة منفّذة ← تقييم', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      // (١) الطالب يكتشف مدرس «عن بُعد»: الفلتر يفصل الفئتين فعلًا.
      await tester.pumpWidget(_host(services, const TeachersScreen()));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.widgetWithText(PillChip, 'عن بُعد'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TeacherCard, 'أ. منى عبد الرحمن'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TeacherCard, 'أ. سارة الخطيب'), findsNothing);

      // (٢) نعود إلى القائمة بلا فلتر ونفتح ملف مدرس حضوري، لأن جلسة الزائر
      //     لها مدرس واحد ثابت (`demo-teacher-1`) لا يمكن أن يقبل حجزًا
      //     موجّهًا إلى غيره — والقبول نفسه هو ما نختبره في الخطوة التالية.
      await tester.pumpWidget(_host(services, const TeachersScreen()));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.widgetWithText(TeacherCard, 'أ. سارة الخطيب'),
      );
      expect(find.text('طلب حجز'), findsOneWidget);
      await tapVisible(tester, find.text('طلب حجز'));
      // ورقة الطلب: نختار موعدًا (الافتراضي صالح) ثم نؤكده ثم نُرسل.
      await tapVisible(tester, find.text('اختر اليوم والساعة'));
      await tapVisible(tester, find.text('تأكيد الموعد'));
      await tapVisible(tester, find.text('إرسال الطلب'));
      expect(find.textContaining('أُرسل طلبك'), findsOneWidget);

      final BookingRequest created = (await services.bookings.listMine()).first;
      expect(created.status, BookingStatus.pending);

      // (٣) المدرس يقبل الطلب من شاشة التفاصيل.
      await tester.pumpWidget(
        _host(
          services,
          BookingDetailsScreen(bookingId: created.id),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('قبول الطلب'));
      expect(
        (await services.bookings.findById(created.id))!.status,
        BookingStatus.accepted,
      );

      // (٤) المحادثة تُفتح من أصل موثّق (الحجز المقبول) ويُرسل الطالب رسالة.
      await tester.pumpWidget(
        _host(services, BookingDetailsScreen(bookingId: created.id)),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('محادثة بخصوص الطلب'));
      expect(find.text('محادثة مباشرة'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'إلى اللقاء في الموعد.');
      await tester.tap(find.byTooltip('إرسال'));
      await tester.pumpAndSettle();
      expect(find.text('إلى اللقاء في الموعد.'), findsOneWidget);

      // (٥) إعلان التنفيذ قبل انتهاء الموعد مرفوض برسالة عربية صريحة —
      // هذا هو السلوك الصحيح، لا نُعلن تنفيذ حصة لم تبدأ.
      await tester.pumpWidget(
        _host(
          services,
          BookingDetailsScreen(bookingId: created.id),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('إعلان التنفيذ'));
      expect(find.textContaining('قبل انتهاء موعد الحصة'), findsOneWidget);

      // (٦) بدل انتظار الوقت، نستخدم حجزًا منفّذًا في البيانات التجريبية
      // لتكملة الرحلة إلى التقييم (G7): لا تقييم بلا حصة منفّذة.
      await tester.pumpWidget(
        _host(services, const BookingDetailsScreen(bookingId: 'demo-booking-4')),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('قيّم الحصة'));
      await tester.tap(find.byIcon(Icons.star_outline_rounded).at(4));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('إرسال التقييم'));

      final List<TeacherReview> reviews = await services.reviews.listForTeacher(
        'demo-teacher-1',
      );
      expect(
        reviews.any((TeacherReview r) => r.bookingId == 'demo-booking-4'),
        isTrue,
        reason: 'التقييم يُكتب فعلًا بعد الحصة المنفّذة',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('رحلة B — خصوصية المدرس تُحترم في الاتجاهين', () {
    testWidgets('إغلاق «استقبال رسائل قبل الحجز» يمنع الطالب بسببه', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      // المدرس يغلق الاستقبال من ملفه.
      await tester.pumpWidget(
        _host(
          services,
          const MyTeacherProfileScreen(),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();
      final Finder toggle = find.widgetWithText(
        SwitchListTile,
        'استقبال رسائل قبل الحجز',
      );
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      expect(
        await services.chats.allowDirectMessages('demo-teacher-1'),
        isFalse,
      );

      // الطالب يحاول المراسلة: لا خطأ خادم، بل سبب مفهوم.
      await tester.pumpWidget(
        _host(services, const TeacherProfileScreen(teacherId: 'demo-teacher-1')),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('محادثة'));
      expect(
        find.textContaining('لا يستقبل رسائل قبل الحجز'),
        findsOneWidget,
        reason: 'المنع يشرح السبب ويقترح البديل، لا خطأ صلاحيات خام',
      );

      // المدرس يعيد تشغيلها، فتنجح المحادثة بلا تغيير في الكود.
      await tester.pumpWidget(
        _host(
          services,
          const MyTeacherProfileScreen(),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(toggle);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        _host(services, const TeacherProfileScreen(teacherId: 'demo-teacher-1')),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('محادثة'));
      expect(find.text('محادثة مباشرة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('تقييم حجز غير منفّذ ممنوع (G7) برسالة عربية', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      // حجز مؤكد لم ينتهِ بعد: زر التقييم لا يظهر أصلًا.
      await tester.pumpWidget(
        _host(services, const BookingDetailsScreen(bookingId: 'demo-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('قيّم الحصة'), findsNothing);

      // والمستودع نفسه يرفض الكتابة لو حاول أحد تجاوز الواجهة.
      final BookingRequest booking = (await services.bookings.findById(
        'demo-booking-1',
      ))!;
      await expectLater(
        services.reviews.submit(
          booking: booking,
          studentId: 'demo-student',
          rating: 5,
        ),
        throwsA(isA<Exception>()),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('رحلة C — الإدارة توثّق فيظهر الملف للطلاب', () {
    testWidgets('قبل التوثيق مخفي، وبعده يظهر في الاستكشاف فورًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      const String name = 'أ. خالد إبراهيم';

      // (١) قبل: لا يظهر للطالب.
      await tester.pumpWidget(_host(services, const TeachersScreen()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TeacherCard, name), findsNothing);

      // (٢) المسؤول يوثّق الملف من طابور التوثيق.
      await tester.pumpWidget(
        _host(
          services,
          const TeacherVerificationScreen(),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      final Finder queueCard = find.ancestor(
        of: find.text(name),
        matching: find.byType(AppCard),
      );
      expect(queueCard, findsOneWidget);
      await tapVisible(
        tester,
        find.descendant(of: queueCard, matching: find.text('توثيق')),
      );
      expect(find.textContaining('تم توثيق'), findsOneWidget);

      // (٣) بعد: يظهر في بحث الطلاب بلا إعادة تشغيل.
      await tester.pumpWidget(_host(services, const TeachersScreen()));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TeacherCard, name), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('الرفض يحتاج سببًا مكتوبًا ولا يُوثّق الملف', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();
      const String name = 'أ. خالد إبراهيم';

      await tester.pumpWidget(
        _host(
          services,
          const TeacherVerificationScreen(),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      final Finder queueCard = find.ancestor(
        of: find.text(name),
        matching: find.byType(AppCard),
      );
      await tapVisible(
        tester,
        find.descendant(of: queueCard, matching: find.text('رفض')),
      );

      // الحوار يشرح أن الرفض بلا سبب لا يُرسل، وزر التأكيد لا يمرّ بلا نص.
      expect(find.textContaining('الرفض بدون سبب'), findsOneWidget);
      await tapVisible(tester, find.text('تأكيد الرفض'));
      expect(find.textContaining('اكتب سببًا'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
