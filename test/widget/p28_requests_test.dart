import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/shell_controller.dart';
import 'package:teacher_student_app/app/shell/shell_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_data.dart';
import 'package:teacher_student_app/data/models/booking_request.dart';
import 'package:teacher_student_app/data/models/study_group.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/bookings/presentation/teacher_requests_screen.dart';

import '../helpers/test_app.dart';

/// (P28) **طلب الطالب يصل إلى المدرس الصحيح ويظهر في شاشة الطلبات.**
///
/// هذا اختبار وظيفي لا شكلي: يكتب طلبًا بمعرّفات حقيقية (معرّف المدرس الذي
/// يفتح الشاشة)، ثم يتحقّق أن الاسم يظهر في الشاشة، وأن الطلب **لا** يظهر عند
/// مدرس آخر، وأن قرار القبول/الرفض ينعكس مباشرة.
///
/// **ما لا يُثبته:** كتابة Firestore الفعلية وقواعد الخادم (تُغطّى في
/// `test/firebase` بمحاكي Firestore في CI). هنا يُثبت أن مسار القراءة الذي
/// تعرضه الشاشة يقرأ نفس المعرّفات التي يكتبها مسار الإنشاء.
const String _teacherId = DemoData.demoTeacherId; // demo-teacher-1
const String _otherTeacherId = 'demo-teacher-2';
const String _studentId = 'student-access-test';
const String _studentName = 'طالبة اختبار الوصول';

/// موعد صالح دائمًا: غدًا 17:00 (داخل نافذة 8–22، وبعد المهلة الدنيا).
DateTime _slot() {
  final DateTime now = DateTime.now();
  return DateTime(now.year, now.month, now.day, 17).add(
    const Duration(days: 2),
  );
}

AppServices _services() => AppServices.demo();

Widget _host(AppServices services, Widget child) {
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.teacher);

  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: ShellScope(
        controller: ShellController(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('وصول الطلب إلى المدرس الصحيح', () {
    testWidgets('طلب حجز أرسله طالب يظهر في شاشة طلبات مدرسه', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      // 1) الطالب يرسل الطلب — نفس المستودع الذي تستخدمه شاشة الحجز.
      final BookingRequest created = await services.bookings.createRequest(
        teacherId: _teacherId,
        teacherName: DemoData.teacherName,
        studentId: _studentId,
        studentName: _studentName,
        subject: 'الرياضيات',
        startsAt: _slot(),
        durationMinutes: 60,
        note: 'أحتاج مراجعة الجبر.',
      );
      expect(created.teacherId, _teacherId);

      // 2) المدرس المستهدف يفتح «الطلبات».
      await tester.pumpWidget(
        _host(services, const TeacherRequestsScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_studentName),
        findsOneWidget,
        reason: 'الطلب لم يصل إلى شاشة المدرس المستهدف',
      );
      expect(find.text('حجز حصة'), findsWidgets);
      // الحالة تظهر بالنص العربي لا بالرمز الداخلي.
      expect(find.text(BookingStatus.pending.label), findsWidgets);

      // 3) فلتر «جديد» يحوي الطلب، وفلتر «مرفوض» لا يحويه.
      await tester.tap(find.byKey(const Key('requests-filter-pending')));
      await tester.pumpAndSettle();
      expect(find.text(_studentName), findsOneWidget);

      await tester.tap(find.byKey(const Key('requests-filter-rejected')));
      await tester.pumpAndSettle();
      expect(find.text(_studentName), findsNothing);
    });

    testWidgets('طلب مدرس آخر لا يظهر في طلباتي (عزل)', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      await services.bookings.createRequest(
        teacherId: _otherTeacherId,
        teacherName: 'مدرس آخر',
        studentId: _studentId,
        studentName: 'طالب مدرس آخر',
        subject: 'الفيزياء',
        startsAt: _slot(),
        durationMinutes: 60,
      );

      await tester.pumpWidget(
        _host(services, const TeacherRequestsScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('طالب مدرس آخر'),
        findsNothing,
        reason: 'طلب موجَّه لمدرس آخر ظهر عندي — تسريب بين الحسابات',
      );
    });

    testWidgets('قرار المدرس يحدّث الحالة في القائمة فورًا', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      final BookingRequest created = await services.bookings.createRequest(
        teacherId: _teacherId,
        teacherName: DemoData.teacherName,
        studentId: _studentId,
        studentName: _studentName,
        subject: 'الرياضيات',
        startsAt: _slot(),
        durationMinutes: 60,
      );

      await tester.pumpWidget(
        _host(services, const TeacherRequestsScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text(BookingStatus.pending.label), findsWidgets);

      // القبول يكتب في المستودع نفسه الذي تبثّ منه الشاشة.
      await services.bookings.decideRequest(
        request: created,
        teacherId: _teacherId,
        approve: true,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(BookingStatus.accepted.label),
        findsWidgets,
        reason: 'القبول لم يظهر بلا إعادة فتح الشاشة',
      );
    });

    testWidgets('طلب انضمام لمجموعة يظهر في نفس شاشة الطلبات', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = _services();

      final List<StudyGroup> groups = await services.groups.listForTeacher(
        _teacherId,
      );
      if (groups.isEmpty) {
        // لا مجموعات للمدرس في البيانات التجريبية ⇒ لا يمكن اختبار الانضمام.
        // نُعلن التخطي صراحةً بدل ادّعاء النجاح.
        markTestSkipped('لا توجد مجموعة للمدرس التجريبي لاختبار طلب الانضمام');
        return;
      }
      final StudyGroup group = groups.first;

      await services.groups.requestToJoin(
        group: group,
        studentId: _studentId,
        studentName: _studentName,
      );

      await tester.pumpWidget(
        _host(services, const TeacherRequestsScreen()),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(_studentName),
        findsOneWidget,
        reason: 'طلب الانضمام لم يظهر في شاشة الطلبات',
      );
    });
  });
}
