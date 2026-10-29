import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/core/constants/app_strings.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/demo_banner.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/teacher_home_screen.dart';

import '../helpers/session_helpers.dart';
import '../helpers/test_app.dart';

/// (P18) اختبارات انحدار لعطل «وضع الزائر يظهر لحساب حقيقي».
///
/// كان `const DemoBanner()` مكتوبًا بلا شرط في 20 شاشة، فتظهر الشريحة لكل
/// مستخدم حتى المسجّل بـGoogle. الإصلاح: الشريحة تقرأ الجلسة بنفسها عبر
/// `SessionScope.maybeOf` وتختفي كليًا لغير الجلسة التجريبية.
///
/// هذه الاختبارات تثبّت أربعة أشياء:
/// 1. **بلا `SessionScope`** لا انهيار (`maybeOf` لا `of`) وتُخفى الشريحة.
/// 2. الجلسة الحقيقية ⇒ لا شريحة ولا مساحة محجوزة.
/// 3. الجلسة التجريبية ⇒ الشريحة تظهر (لم نكسر المعاينة).
/// 4. النص المخصّص ⇒ يظهر دائمًا (معرض المكونات).
void main() {
  /// شاشة اختبار بعرض هاتف حقيقي.
  Future<void> pumpBanner(
    WidgetTester tester, {
    required Widget banner,
    SessionController? session,
    bool withServices = false,
  }) async {
    usePhoneSurface(tester);

    Widget app = MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: banner),
    );

    // شاشات الرئيسية تقرأ repositories من `AppServicesScope` (قوائم مميزة/
    // حجوزات)، فتحتاج الحزمة التجريبية. الشريحة وحدها لا تحتاجها.
    if (withServices) {
      app = AppServicesScope(services: AppServices.demo(), child: app);
    }
    if (session != null) {
      app = withSession(session, child: app);
    }

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  group('DemoBanner يتحقق من الجلسة ذاتيًا (P18)', () {
    testWidgets('بلا SessionScope: لا انهيار، وتُعاد مساحة صفرية', (
      WidgetTester tester,
    ) async {
      // جوهر الحماية: `SessionScope.of` كان سيُسقط الاختبار بـ`assert`.
      await pumpBanner(tester, banner: const DemoBanner());

      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings.demoBannerShort),
        findsNothing,
        reason: 'غياب النطاق يعني جلسة غير معروفة ⇒ لا شريحة',
      );
      expect(
        find.byType(SizedBox),
        findsWidgets,
        reason: 'البديل هو SizedBox.shrink بلا حجز مساحة',
      );
      expect(tester.getSize(find.byType(DemoBanner)).height, 0);
    });

    testWidgets('جلسة حقيقية: الشريحة تختفي تمامًا', (
      WidgetTester tester,
    ) async {
      final session = await realSession();
      expect(session.isDemoSession, isFalse);

      await pumpBanner(tester, banner: const DemoBanner(), session: session);

      expect(find.text(AppStrings.demoBannerShort), findsNothing);
      expect(tester.getSize(find.byType(DemoBanner)).height, 0);
    });

    testWidgets('جلسة مجهولة (بلا دخول): الشريحة تختفي', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        banner: const DemoBanner(),
        session: signedOutSession(),
      );

      expect(find.text(AppStrings.demoBannerShort), findsNothing);
    });

    testWidgets('جلسة تجريبية: الشريحة تظهر كما كانت', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        banner: const DemoBanner(),
        session: demoSession(),
      );

      expect(find.text(AppStrings.demoBannerShort), findsOneWidget);
      expect(tester.getSize(find.byType(DemoBanner)).height, greaterThan(0));
    });

    testWidgets('نص مخصّص: يظهر حتى بلا جلسة (معرض المكونات)', (
      WidgetTester tester,
    ) async {
      const String custom = 'شاشة تطوير للمراجعة البصرية فقط.';
      await pumpBanner(tester, banner: const DemoBanner(message: custom));

      expect(find.text(custom), findsOneWidget);
    });

    testWidgets('نص مخصّص: يظهر أيضًا مع جلسة حقيقية', (
      WidgetTester tester,
    ) async {
      const String custom = 'تنبيه صريح لا علاقة له بالجلسة.';
      await pumpBanner(
        tester,
        banner: const DemoBanner(message: custom),
        session: await realSession(),
      );

      expect(find.text(custom), findsOneWidget);
    });
  });

  group('الشاشات الرئيسية بعد الإصلاح', () {
    testWidgets('الرئيسية للطالب بحساب حقيقي: لا شريحة زائر', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        banner: const StudentHomeScreen(),
        session: await realSession(),
        withServices: true,
      );

      expect(
        find.text(AppStrings.demoBannerShort),
        findsNothing,
        reason: 'هذا هو العطل الأصلي: كانت الشريحة تظهر لكل حساب',
      );
    });

    testWidgets('الرئيسية للمدرس بحساب حقيقي: لا شريحة زائر', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        banner: const TeacherHomeScreen(),
        session: await realSession(role: UserRole.teacher),
        withServices: true,
      );

      expect(find.text(AppStrings.demoBannerShort), findsNothing);
    });

    testWidgets('الرئيسية للطالب في جلسة تجريبية: الشريحة باقية', (
      WidgetTester tester,
    ) async {
      await pumpBanner(
        tester,
        banner: const StudentHomeScreen(),
        session: demoSession(),
        withServices: true,
      );

      expect(find.text(AppStrings.demoBannerShort), findsOneWidget);
    });
  });
}
