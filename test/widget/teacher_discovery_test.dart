import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/teachers_screen.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_carousel.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/featured_teachers_strip.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:teacher_student_app/features/teachers/presentation/widgets/teacher_showcase_card.dart';

import '../helpers/test_app.dart';

/// يبني الشاشة داخل جلسة طالب ببيانات تجريبية (لا Firebase).
Widget _host(Widget child) {
  final AppServices services = AppServices.demo();
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.student);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            backgroundColor: Colors.white,
            body: child,
          ),
        ),
      ),
    ),
  );
}

/// اسم داخل بطاقة نتيجة (لا داخل شريط المميزين، فالأسماء تتكرر فيه).
Finder _resultName(String name) => find.widgetWithText(TeacherCard, name);

/// حبة فلتر بعنوان محدد — لا نستخدم `find.text` وحده لأن الوسم نفسه يظهر
/// داخل بطاقات المدرسين أيضًا.
Finder _chip(String label) => find.widgetWithText(PillChip, label);

void main() {
  group('استكشاف المدرسين (P15)', () {
    testWidgets('شريط المميزين وقائمة الموثّقين يظهران', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(FeaturedTeachersCarousel), findsOneWidget);
      expect(find.text('مدرسون مميزون'), findsOneWidget);
      // 5 ملفات موثّقة في البيانات التجريبية.
      expect(find.text('5 مدرسًا'), findsOneWidget);
      expect(find.byType(TeacherCard), findsNWidgets(5));
    });

    testWidgets('«عن بُعد» يعرض المتاحين عن بُعد فقط', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, _chip('عن بُعد'));

      expect(_resultName('أ. منى عبد الرحمن'), findsOneWidget);
      expect(_resultName('أ. هدى مصطفى'), findsOneWidget);
      expect(_resultName('أ. سارة الخطيب'), findsNothing);
      // الإجمالي بعد شروط الخادم (طريقة التقديم) لا بعد فلاتر العميل.
      expect(find.text('2 مدرسًا'), findsOneWidget);
      // شريط المميزين لا يتأثر بالفلتر (قسم مستقل).
      expect(find.byType(FeaturedTeachersCarousel), findsOneWidget);
    });

    testWidgets('«حضوري فقط» يعرض المحافظات ويفلتر بها', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, _chip('حضوري فقط'));

      // خيارات المحافظات تظهر عند اختيار الحضور.
      expect(_chip('القاهرة'), findsOneWidget);
      expect(_chip('أسيوط'), findsOneWidget);
      expect(_resultName('أ. يوسف كامل'), findsOneWidget); // الدقهلية
      expect(_resultName('أ. منى عبد الرحمن'), findsNothing); // عن بُعد

      await tapVisible(tester, _chip('القاهرة'));

      expect(_resultName('أ. سارة الخطيب'), findsOneWidget);
      expect(_resultName('أ. يوسف كامل'), findsNothing);
      expect(find.text('1 مدرسًا'), findsOneWidget);
    });

    testWidgets('البحث النصي يتجاوز الهمزة ويُظهر النتائج بعد مهلة الكتابة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'احمد');
      // القراءة تؤجَّل 250 مللي ثانية بعد آخر حرف.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(_resultName('أ. أحمد الشناوي'), findsOneWidget);
      expect(_resultName('أ. سارة الخطيب'), findsNothing);
    });

    testWidgets('«تفريغ الفلاتر» يعيد كل النتائج', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tapVisible(tester, _chip('عن بُعد'));
      expect(find.byType(TeacherCard), findsNWidgets(2));

      await tapVisible(tester, _chip('تفريغ الفلاتر'));

      expect(find.byType(TeacherCard), findsNWidgets(5));
      expect(find.text('5 مدرسًا'), findsOneWidget);
    });

    testWidgets('لا نتائج: رسالة تشرح السبب بدل صمت', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const TeachersScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'لا يوجد مدرس بهذا الاسم');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('لا نتائج'), findsOneWidget);
      expect(find.byType(TeacherCard), findsNothing);
    });
  });

  group('الرئيسية (P15/P25)', () {
    testWidgets('قسم المميزين يعرض مدرسين بمبدّل أونلاين/أوفلاين', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await tester.pumpWidget(_host(const StudentHomeScreen()));
      await tester.pumpAndSettle();

      // (P25) الشريط القديم (تمرير أفقي لكل المميزين) صار قسّمًا بمبدّل
      // شرائح: خمسة أونلاين وخمسة أوفلاين أسبوعيًا.
      expect(find.byType(FeaturedTeachersStrip), findsOneWidget);
      expect(find.text('مدرسون مميزون'), findsOneWidget);
      expect(find.byKey(featuredSegmentOnlineKey), findsOneWidget);

      // البطاقة الأولى (أونلاين): الاسم، والمكان يُعرض للمدرسين الحضوريين
      // فقط — لذلك نتحقق من الاسم داخل الشريط لا من نص «حضوري فقط» القديم.
      final Finder strip = find.byType(FeaturedTeachersStrip);
      expect(
        find.descendant(of: strip, matching: find.byType(TeacherShowcaseCard)),
        findsWidgets,
      );
      expect(
        find.descendant(of: strip, matching: find.text('أ. منى عبد الرحمن')),
        findsOneWidget,
      );
    });
  });
}
