import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_spacing.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/app_card.dart';
import 'package:teacher_student_app/core/widgets/user_avatar_view.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/group_details_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/profile_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teacher_profile_screen.dart';

import '../helpers/test_app.dart';

/// مدرّس موثّق في البيانات التجريبية (أونلاين).
const String _teacherId = 'demo-teacher-3';

Widget _host(Widget child, AppServices services, SessionController session) {
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
      ),
    ),
  );
}

SessionController _studentSession(AppServices services) =>
    SessionController(services.auth, avatars: services.avatars)
      ..startDemoSession(UserRole.student);

void main() {
  group('P27 — ملف المدرس: شريط إجراءات ثابت', () {
    testWidgets('الإجراءان الأساسيان ظاهران معًا بلا تمرير', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = _studentSession(services);

      await tester.pumpWidget(
        _host(
          const TeacherProfileScreen(teacherId: _teacherId),
          services,
          session,
        ),
      );
      await tester.pumpAndSettle();

      final Finder book = find.text('طلب حجز');
      final Finder chat = find.text('محادثة');

      expect(book, findsOneWidget);
      expect(chat, findsOneWidget);

      // الشريط ثابت أسفل الشاشة: الإجراءان قابلان للضغط فورًا دون تمرير.
      expect(book.hitTestable(), findsOneWidget);
      expect(chat.hitTestable(), findsOneWidget);

      // في صف واحد: نفس الإحداثي الرأسي.
      expect(
        tester.getCenter(book).dy,
        closeTo(tester.getCenter(chat).dy, 1),
      );
    });

    testWidgets('الرأس يعرض صورة الملف الحقيقية لا دائرة أحرف', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = _studentSession(services);

      await tester.pumpWidget(
        _host(
          const TeacherProfileScreen(teacherId: _teacherId),
          services,
          session,
        ),
      );
      await tester.pumpAndSettle();

      // الاسم نفسه يظهر في بطاقات مجموعاته أسفل الصفحة (بحجم 40)، فنُميّز
      // صورة الرأس بحجمها: 64 = avatarMd + 8.
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is UserAvatarLoader &&
              widget.semanticLabel == 'صورة أ. منى عبد الرحمن' &&
              widget.size == AppSpacing.avatarMd + 8,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('P27 — تفاصيل المجموعة: أسطح أقل', () {
    testWidgets('روابط الإدارة في بطاقة واحدة، والمقاعد في بطاقة الرأس', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = _studentSession(services);

      await tester.pumpWidget(
        _host(
          const GroupDetailsScreen(groupId: 'demo-group-1'),
          services,
          session,
        ),
      );
      await tester.pumpAndSettle();

      // شريط التقدّم واحد فقط ⇒ بطاقة «المقاعد» المستقلة اندمجت في الرأس.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // «جدول الحصص» و«محادثة المجموعة» في نفس البطاقة (صفّان بفاصل واحد).
      final Finder schedule = find.ancestor(
        of: find.text('جدول الحصص'),
        matching: find.byType(AppCard),
      );
      final Finder chat = find.ancestor(
        of: find.text('محادثة المجموعة'),
        matching: find.byType(AppCard),
      );
      expect(schedule, findsOneWidget);
      expect(chat, findsOneWidget);
      expect(
        tester.element(schedule),
        tester.element(chat),
        reason: 'كلا الرابطين يجب أن يكونا في بطاقة واحدة',
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('P27 — محرّر الصورة مضغوط', () {
    testWidgets('أزرار الصورة بارتفاع صغير لا تشبه شرائح ضخمة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = _studentSession(services);

      await tester.pumpWidget(
        _host(const ProfileScreen(), services, session),
      );
      await tester.pumpAndSettle();

      final Finder pick = find.byKey(const Key('avatar-pick'));
      expect(pick, findsOneWidget);
      expect(
        tester.getSize(pick).height,
        lessThanOrEqualTo(44),
        reason: 'الزر يجب أن يبقى صغيرًا داخل بطاقة الصورة',
      );

      // المعاينة نفسها 72 لا 88.
      expect(tester.getSize(find.byKey(const Key('avatar-preview'))).width, 72);
      expect(tester.takeException(), isNull);
    });
  });
}
