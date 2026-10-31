import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
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


/// يضغط زرًا بمعالجه مباشرة.
///
/// قسم «بانتظار التوثيق» أسفل بطاقات الأرقام في `ListView`، فقد يكون خارج
/// منطقة العرض. `tester.tap` يصيب مركز الودجت حتى لو لم يكن على الشاشة فيضيع
/// بلا فشل صريح (نفس الدرس المتكرر في P19). استدعاء `onPressed` يقيس السلوك.
Future<void> _pressButton(WidgetTester tester, Key key) async {
  final ButtonStyleButton button = tester.widget<ButtonStyleButton>(
    find.byKey(key),
  );
  button.onPressed!();
  await tester.pumpAndSettle();
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

      // بلا سبب: رسالة خطأ ولا إغلاق للنافذة (النص الدقيق لخطأ التحقق، لأن
      // وصف النافذة نفسه يبدأ بالكلمات نفسها).
      await tapVisible(tester, find.text('تأكيد الرفض'));
      expect(
        find.text('اكتب سببًا واضحًا (٥ أحرف على الأقل) قبل حفظ القرار.'),
        findsOneWidget,
      );

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

  // ───────────────────────────────────────────────────────────────────────────
  // (P19) قرار مباشر من اللوحة: المسؤول لا يفتح شاشة ثانية ليوثّق ملفًا.
  // ───────────────────────────────────────────────────────────────────────────
  group('لوحة الإدارة — قرار مباشر على المعلّقين', () {
    Future<AppServices> pumpDashboard(WidgetTester tester) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      await tester.pumpWidget(
        _host(
          const AdminGuard(child: AdminDashboardScreen()),
          role: UserRole.admin,
          services: services,
        ),
      );
      await tester.pumpAndSettle();
      return services;
    }

    testWidgets('تعرض أول المعلّقين مع زرّي التوثيق والرفض', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester);

      expect(find.text('بانتظار التوثيق'), findsOneWidget);
      expect(find.text('أ. خالد إبراهيم'), findsOneWidget);
      expect(find.text('أ. منال عادل'), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard-approve-demo-teacher-6-review')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('dashboard-reject-demo-teacher-6-review')),
        findsOneWidget,
      );
      // ملفان فقط في الطابور، فلا حاجة إلى «عرض كل الطابور».
      expect(find.byKey(const Key('dashboard-open-queue')), findsNothing);
    });

    testWidgets('نقرة توثيق واحدة تكتب الحالة ويختفي الملف من اللوحة', (
      WidgetTester tester,
    ) async {
      final AppServices services = await pumpDashboard(tester);

      await _pressButton(
        tester,
        const Key('dashboard-approve-demo-teacher-6-review'),
      );

      // رسالة نجاح عربية واسم الملف لم يبقَ في قائمة الانتظار.
      expect(find.textContaining('تم توثيق'), findsOneWidget);
      expect(find.text('أ. خالد إبراهيم'), findsNothing);
      // المسودة بقيت: القرار يخص ملفًا واحدًا لا الطابور كله.
      expect(find.text('أ. منال عادل'), findsOneWidget);

      // الحالة تتغيّر في المصدر فعلًا، وهذا ما يجعل الملف يظهر في البحث.
      final List<TeacherProfile> all = await services.admin.listAllProfiles();
      final TeacherProfile approved = all.firstWhere(
        (TeacherProfile profile) => profile.id == 'demo-teacher-6-review',
      );
      expect(approved.status, TeacherProfileStatus.verified);
    });

    testWidgets('الرفض يفتح حوار سبب مكتوب ولا يرفض بلا سبب', (
      WidgetTester tester,
    ) async {
      final AppServices services = await pumpDashboard(tester);

      await _pressButton(
        tester,
        const Key('dashboard-reject-demo-teacher-6-review'),
      );

      expect(
        find.byKey(const Key('verification-reject-reason')),
        findsOneWidget,
      );

      // تأكيد بلا سبب: رسالة تحقق ولا إغلاق.
      await tapVisible(tester, find.text('تأكيد الرفض'));
      expect(
        find.text('اكتب سببًا واضحًا (٥ أحرف على الأقل) قبل حفظ القرار.'),
        findsOneWidget,
      );

      // إلغاء الحوار ليس قرارًا: لا كتابة ولا رسالة.
      await tapVisible(tester, find.text('إلغاء'));
      expect(find.text('أ. خالد إبراهيم'), findsOneWidget);

      final List<TeacherProfile> all = await services.admin.listAllProfiles();
      final TeacherProfile still = all.firstWhere(
        (TeacherProfile profile) => profile.id == 'demo-teacher-6-review',
      );
      expect(still.status, TeacherProfileStatus.pendingReview);
    });

    testWidgets('الرفض بسبب صالح يكتب الحالة والسبب', (
      WidgetTester tester,
    ) async {
      final AppServices services = await pumpDashboard(tester);

      await _pressButton(
        tester,
        const Key('dashboard-reject-demo-teacher-6-review'),
      );
      await tester.enterText(
        find.byKey(const Key('verification-reject-reason')),
        'الملف بلا نبذة كافية عن طريقة التدريس.',
      );
      await tapVisible(tester, find.text('تأكيد الرفض'));

      expect(find.textContaining('تم رفض'), findsOneWidget);
      expect(find.text('أ. خالد إبراهيم'), findsNothing);

      final List<TeacherProfile> all = await services.admin.listAllProfiles();
      final TeacherProfile rejected = all.firstWhere(
        (TeacherProfile profile) => profile.id == 'demo-teacher-6-review',
      );
      expect(rejected.status, TeacherProfileStatus.rejected);
      expect(rejected.reviewNote, contains('بلا نبذة كافية'));
    });

    testWidgets('طابور فارغ ⇒ حالة فراغ مفهومة لا قائمة صامتة', (
      WidgetTester tester,
    ) async {
      await pumpDashboard(tester);

      await _pressButton(
        tester,
        const Key('dashboard-approve-demo-teacher-6-review'),
      );
      await _pressButton(
        tester,
        const Key('dashboard-approve-demo-teacher-7-draft'),
      );

      expect(find.text('لا ملفات بانتظار التوثيق'), findsOneWidget);
      expect(find.text('بانتظار التوثيق'), findsNothing);
    });

    testWidgets('لوحة الطالب لا تعرض القسم أصلًا (الصلاحية على الخادم لا هنا)', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(
        _host(
          const AdminGuard(child: AdminDashboardScreen()),
          role: UserRole.student,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('بانتظار التوثيق'), findsNothing);
      expect(find.byKey(const Key('dashboard-approve-demo-teacher-6-review')),
          findsNothing);
    });
  });
}
