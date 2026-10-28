import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/admin_guard.dart';
import 'package:teacher_student_app/features/admin/presentation/moderation_screen.dart';
import 'package:teacher_student_app/features/admin/presentation/teacher_verification_screen.dart';
import 'package:teacher_student_app/features/profile/presentation/profile_screen.dart';

import '../helpers/test_app.dart';

/// يبني شاشة إدارية داخل جلسة بدور محدد (تجريبي).
Widget _host(Widget child, {required UserRole role, AppServices? services}) {
  final AppServices resolved = services ?? AppServices.demo();
  final SessionController session = SessionController(resolved.auth)
    ..startDemoSession(role);

  return AppServicesScope(
    services: resolved,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(theme: AppTheme.light, home: child),
      ),
    ),
  );
}

void main() {
  group('حارس المسارات الإدارية (P14)', () {
    testWidgets('الطالب يُمنع من لوحة الإدارة', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(child: AdminDashboardScreen()),
          role: UserRole.student,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا تملك صلاحية'), findsOneWidget);
      expect(find.text('طابور التوثيق'), findsNothing);
    });

    testWidgets('المدرس يُمنع من لوحة الإدارة', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(
            title: 'المراجعة والبلاغات',
            child: ModerationScreen(),
          ),
          role: UserRole.teacher,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا تملك صلاحية'), findsOneWidget);
      expect(find.text('البلاغات المفتوحة'), findsNothing);
    });

    testWidgets('جلسة الإدارة تمرّ من الحارس وتُظهر اللوحة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(child: AdminDashboardScreen()),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا تملك صلاحية'), findsNothing);
      expect(find.text('طابور التوثيق'), findsOneWidget);
      expect(find.text('البلاغات المفتوحة'), findsOneWidget);
      expect(find.text('المدرسون الموثّقون'), findsOneWidget);
    });
  });

  group('طابور التوثيق', () {
    testWidgets('التوثيق يوافق على الملف ويُزيله من الطابور', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(
            title: 'طابور التوثيق',
            child: TeacherVerificationScreen(),
          ),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أ. خالد إبراهيم'), findsOneWidget);
      expect(find.text('قيد المراجعة'), findsOneWidget);

      await tapVisible(tester, find.text('توثيق').first);

      expect(find.textContaining('تم توثيق'), findsOneWidget);
      expect(find.text('أ. خالد إبراهيم'), findsNothing);
      // المسودة بقيت في الطابور.
      expect(find.text('أ. منال عادل'), findsOneWidget);
    });

    testWidgets('الرفض لا يكتمل بلا سبب واضح', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(
            title: 'طابور التوثيق',
            child: TeacherVerificationScreen(),
          ),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('رفض').first);
      expect(find.text('سبب الرفض'), findsOneWidget);

      // بلا سبب: رسالة خطأ ولا إغلاق للنافذة.
      await tapVisible(tester, find.text('تأكيد الرفض'));
      expect(find.textContaining('اكتب سببًا واضحًا'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'النبذة تحتوي بيانات تواصل خارج التطبيق.',
      );
      await tapVisible(tester, find.text('تأكيد الرفض'));

      expect(find.textContaining('تم رفض'), findsOneWidget);
      expect(find.text('أ. خالد إبراهيم'), findsNothing);
    });
  });

  group('شاشة المراجعة', () {
    testWidgets('البلاغات المفتوحة تظهر ويُستبعد أحدها', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(
            title: 'المراجعة والبلاغات',
            child: ModerationScreen(),
          ),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('السبب: ألفاظ غير لائقة'), findsOneWidget);
      expect(find.text('السبب: بيانات تواصل خارج التطبيق'), findsOneWidget);

      await tapVisible(tester, find.text('استبعاد البلاغ').first);

      expect(find.textContaining('استُبعد البلاغ'), findsOneWidget);
      // الأحدث أولًا: استُبعد بلاغ «بيانات التواصل» وبقي بلاغ «الألفاظ».
      expect(find.text('السبب: بيانات تواصل خارج التطبيق'), findsNothing);
      expect(find.text('السبب: ألفاظ غير لائقة'), findsOneWidget);
    });

    testWidgets('حذف التقييم المخالف يُغلق البلاغ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(
            title: 'المراجعة والبلاغات',
            child: ModerationScreen(),
          ),
          role: UserRole.admin,
        ),
      );
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('حذف المحتوى').first);

      expect(find.textContaining('حُذف التقييم وأُغلق البلاغ'), findsOneWidget);
    });
  });

  group('مدخل اللوحة في «حسابي»', () {
    testWidgets('المسؤول يرى المدخل', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(const ProfileScreen(), role: UserRole.admin),
      );
      await tester.pumpAndSettle();

      expect(find.text('لوحة الإدارة'), findsOneWidget);
      expect(find.text('مسؤول تجريبي'), findsOneWidget);
    });

    testWidgets('الطالب لا يرى المدخل', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(const ProfileScreen(), role: UserRole.student),
      );
      await tester.pumpAndSettle();

      expect(find.text('لوحة الإدارة'), findsNothing);
    });
  });
}
