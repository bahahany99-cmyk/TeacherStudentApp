import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_tab.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/empty_state.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/bookings_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/profile_screen.dart';

import '../helpers/test_app.dart';

/// حزمة الخدمات التجريبية لكن بقائمة حجوزات فارغة — لاختبار حالة الفراغ
/// الحقيقية (البيانات التجريبية فيها حجوزات دائمًا).
AppServices _emptyBookings() {
  final AppServices base = AppServices.demo();
  return AppServices(
    auth: base.auth,
    teachers: base.teachers,
    groups: base.groups,
    bookings: DemoBookingRepository(source: const <BookingRequest>[]),
    schedules: base.schedules,
    messages: base.messages,
    chats: base.chats,
    notifications: base.notifications,
    reviews: base.reviews,
    favorites: base.favorites,
    admin: base.admin,
  );
}

Widget _host(
  Widget child, {
  required AppServices services,
  required SessionController session,
  ShellController? shell,
}) {
  Widget tree = AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
      ),
    ),
  );
  if (shell != null) {
    tree = ShellScope(controller: shell, child: tree);
  }
  return tree;
}

SessionController _studentSession(AppServices services) =>
    SessionController(services.auth, avatars: services.avatars)
      ..startDemoSession(UserRole.student);

void main() {
  group('P26 — مقاييس التصميم', () {
    test('الحشوات والحواف موحّدة ومضغوطة', () {
      // حشوة البطاقة 16 في كل الاتجاهات (كانت 20).
      expect(AppSpacing.cardPadding.horizontal / 2, AppSpacing.md);
      expect(AppSpacing.cardPadding.vertical / 2, AppSpacing.md);
      // المسافة بين الأقسام أقصر من السابق (28) وبلا تفاوت.
      expect(AppSpacing.sectionGap, 24);
      // الحواف مرتّبة: حقل < بطاقة < شريط.
      expect(AppSpacing.radiusCard, greaterThan(AppSpacing.radiusLg));
      expect(AppSpacing.radiusCard, lessThan(AppSpacing.radiusXl));
    });

    testWidgets('البطاقة تستخدم نصف قطر البطاقة لا نصف قطر أكبر', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: AppCard(child: Text('محتوى')),
            ),
          ),
        ),
      );

      final Container container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AppSpacing.radiusCard),
      );
    });
  });

  group('P26 — الحالات الفارغة', () {
    testWidgets('الفراغ يعرض إجراءً أساسيًا حقيقيًا لا نصًّا فقط', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: EmptyState(
                icon: Icons.person_search_outlined,
                title: 'لا نتائج',
                message: 'جرّب كلمة أخرى.',
                primaryActionLabel: 'استكشف المدرسين الآن',
                onPrimaryAction: () => taps++,
              ),
            ),
          ),
        ),
      );

      // زر ممتلئ، لا `TextButton` عائم.
      expect(
        find.widgetWithText(FilledButton, 'استكشف المدرسين الآن'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(EmptyState.primaryActionKey));
      expect(taps, 1);
    });

    testWidgets('بلا إجراء: لا زر أصلًا (لا زر ميّت)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: EmptyState(
                icon: Icons.inbox_outlined,
                title: 'لا توجد طلبات جديدة',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('حجوزات فارغة: زر ينقل فعليًا إلى تبويب المدرسين', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _emptyBookings();
      final SessionController session = _studentSession(services);
      final ShellController shell = ShellController();
      addTearDown(shell.dispose);

      await tester.pumpWidget(
        _host(
          const BookingsScreen(viewerRole: UserRole.student),
          services: services,
          session: session,
          shell: shell,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
      final Finder cta = find.widgetWithText(
        FilledButton,
        'استكشف المدرسين الآن',
      );
      expect(cta, findsOneWidget);

      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(shell.current, AppTab.teachers);
    });
  });

  group('P26 — حسابي', () {
    testWidgets('كل وجهة تظهر مرة واحدة، والمجموعات معنونة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = _studentSession(services);

      await tester.pumpWidget(
        _host(const ProfileScreen(), services: services, session: session),
      );
      await tester.pumpAndSettle();

      // لا تكرار: كان من السهل أن ينشأ صفّان لنفس الوجهة عند إعادة الترتيب.
      for (final String label in <String>[
        'بياناتي',
        'المفضلة',
        'المحادثات',
        'الإشعارات',
        'المساعدة والدعم',
        'الشروط وسياسة الخصوصية',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'الوجهة «$label» يجب أن تظهر مرة واحدة بالضبط',
        );
      }

      // مجموعات معنونة بدل قائمة مسطّحة.
      for (final String group in <String>[
        'الحساب',
        'التواصل',
        'الدعم والمعلومات',
        'الجلسة',
        'منطقة الخطر',
      ]) {
        expect(find.text(group), findsOneWidget, reason: 'مجموعة $group');
      }

      // المفاتيح التي تعتمدها اختبارات أخرى تبقى في مكانها.
      expect(find.byKey(const Key('profile-avatar-image')), findsOneWidget);
      expect(find.byKey(const Key('profile-avatar-editor')), findsOneWidget);
      expect(find.byKey(const Key('profile-my-data')), findsOneWidget);
      expect(find.byKey(const Key('profile-sign-out')), findsOneWidget);
      expect(find.byKey(const Key('profile-delete-account')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

  });

  group('P26 — جرس واحد لكل شاشة', () {
    testWidgets('رئيسية الطالب: جرس الرأس وحده، لا جرس في الشريط', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithText(OutlinedButton, 'واجهة الطالب'),
      );

      // داخل الرئيسية: جرس واحد ظاهر (جرس الرأس) — لا اثنان.
      expect(
        find.byType(NotificationBell).hitTestable(),
        findsOneWidget,
        reason: 'جرسان على الشاشة نفسها خطأ واجهة',
      );

      // في بقية الأقسام يبقى جرس الشريط ظاهرًا مرة واحدة.
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('الحجوزات'),
        ),
      );
      expect(find.byType(NotificationBell).hitTestable(), findsOneWidget);
    });
  });
}
