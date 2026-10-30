import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/core/widgets/pill_chip.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/groups/presentation/groups_screen.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_card.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_filter_bar.dart';
import 'package:teacher_student_app/features/groups/presentation/widgets/group_filter_sheet.dart';

import '../helpers/test_app.dart';

AppServices _services() {
  return AppServices(
    admin: DemoAdminRepository(),
    auth: const DemoAuthService(),
    teachers: DemoTeacherRepository(),
    groups: DemoGroupRepository(),
    bookings: DemoBookingRepository(),
    chats: DemoDirectChatRepository(),
    notifications: DemoNotificationRepository(),
    schedules: DemoScheduleRepository(),
    messages: DemoMessageRepository(),
    reviews: DemoReviewRepository(),
    favorites: DemoFavoriteRepository(),
  );
}

Widget _host(AppServices services) {
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
            body: const GroupsScreen.discover(),
          ),
        ),
      ),
    ),
  );
}

/// (P24) يفتح ورقة «فلترة متقدمة» ويضغط حبة ثم «عرض النتائج».
///
/// الفلاتر التي ليست مادة انتقلت من الشاشة إلى الورقة، فالاختبار يمرّ بنفس
/// مسار المستخدم بدل أن يفترض مكان الحبة.
Future<void> _pickInAdvancedSheet(
  WidgetTester tester,
  String chipLabel,
) async {
  await tester.tap(find.byKey(GroupFilterBar.filterButtonKey));
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(GroupFilterSheet),
      matching: find.widgetWithText(PillChip, chipLabel),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(GroupFilterSheet.applyKey));
  await tester.pumpAndSettle();
}

void main() {
  group('استكشاف المجموعات (P9)', () {
    testWidgets('كل المجموعات المنشورة تظهر أول الأمر', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(_host(_services()));
      await tester.pumpAndSettle();

      // (P24) عنوان الشاشة من القسم، وشريط الفلاتر صار بحثًا + زر فلترة.
      expect(find.text('مجموعات متاحة'), findsOneWidget);
      expect(find.byKey(GroupFilterBar.filterButtonKey), findsOneWidget);
      expect(find.text('مجموعة الرياضيات — التفاضل'), findsOneWidget);
      expect(find.text('مجموعة الفيزياء — الحديثة'), findsOneWidget);
      // المادة تُعرض كحبة فلتر.
      expect(find.text('الفيزياء'), findsWidgets);
      // (P24) هوية المدرس على البطاقة: اسمه + شارة توثيقه (المدرسون التجريبيون
      // موثّقون)، فالطالب يعرف من يدرّس قبل أن يفتح التفاصيل.
      expect(find.text('أ. سارة الخطيب'), findsWidgets);
      expect(find.byKey(GroupCard.teacherBadgeKey), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('فلتر المادة يستبعد بقية المواد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(_host(_services()));
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('الرياضيات').first);

      expect(find.text('مجموعة الرياضيات — التفاضل'), findsOneWidget);
      expect(find.text('مجموعة الفيزياء — الحديثة'), findsNothing);
    });

    testWidgets('فلتر المكتملة يُظهر المجموعات الممتلئة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(_host(_services()));
      await tester.pumpAndSettle();

      // (P24) فلتر المقاعد انتقل إلى ورقة «فلترة متقدمة».
      await _pickInAdvancedSheet(tester, 'مكتملة');

      expect(find.text('مجموعة الفيزياء — الحديثة'), findsOneWidget);
      expect(find.text('مجموعة الرياضيات — التفاضل'), findsNothing);
      expect(find.textContaining('قائمة انتظار'), findsWidgets);
    });

    testWidgets('البحث النصي بلا نتيجة يعرض «لا نتائج» وزر تفريغ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(_host(_services()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'كيمياء عضوية');
      await tester.pumpAndSettle();

      expect(find.text('لا نتائج'), findsOneWidget);
      // زر التفريغ يظهر في الشريط وفي حالة «لا نتائج» معًا.
      expect(find.textContaining('تفريغ الفلاتر'), findsWidgets);
    });

    testWidgets('تفريغ الفلاتر يعيد كل المجموعات ويخفي الزر', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(_host(_services()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'نحو');
      await tester.pumpAndSettle();
      expect(find.text('تأسيس النحو'), findsOneWidget);
      expect(find.text('مجموعة الرياضيات — التفاضل'), findsNothing);

      await tapVisible(tester, find.text('تفريغ الفلاتر (1)'));

      expect(find.text('مجموعة الرياضيات — التفاضل'), findsOneWidget);
      expect(find.textContaining('تفريغ الفلاتر'), findsNothing);
    });

    testWidgets('الترتيب الأبجدي يغيّر ترتيب البطاقات', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      await tester.pumpWidget(_host(_services()));
      await tester.pumpAndSettle();

      await _pickInAdvancedSheet(tester, 'أبجديًا');

      final double firstY = tester.getTopLeft(find.text('تأسيس النحو')).dy;
      final double otherY = tester
          .getTopLeft(find.text('مجموعة الرياضيات — التفاضل'))
          .dy;
      expect(firstY, lessThan(otherY));
    });
  });
}
