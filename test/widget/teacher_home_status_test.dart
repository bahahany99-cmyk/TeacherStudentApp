import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/router/app_router.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/teacher_profile.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/features/student/presentation/student_home_screen.dart';
import 'package:teacher_student_app/features/teacher/presentation/teacher_home_screen.dart';

import '../helpers/test_app.dart';

/// (P21) الرئيسية للمدرس: **حالة حقيقية** لا شريط تطوير.
///
/// كان أعلى الصفحة نصًا ثابتًا لصاحبه لا علاقة له بحسابه:
/// «هذه معاينة محلية بلا Firebase… (C-06)» مع وسم «حساب تجريبي». هنا نُثبت أن
/// البطاقة تُبنى من `teacherProfiles/{uid}` فعليًا، وأن كل حالة تُقال بلغة
/// بشرية، وأن لا نص تطويري يظهر في أي منها.
/// مضيف بمسار حقيقي: أزرار البطاقة تنتقل بمسارات التطبيق
/// (`/me/teacher-profile/edit`)، و`MaterialApp(home:)` بلا `onGenerateRoute`
/// يرمي «Could not find a generator for route» عند أول ضغطة (خطأ مقيس في CI).
Widget _host(Widget child, AppServices services, SessionController session) {
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(
          theme: AppTheme.light,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: Scaffold(body: child),
        ),
      ),
    ),
  );
}

/// حزمة تجريبية بمستودع مدرسين لا يحوي إلا [profile] (أو لا يحوي شيئًا).
AppServices _servicesWith(TeacherProfile? profile) {
  final AppServices base = AppServices.demo();
  return AppServices(
    auth: base.auth,
    teachers: DemoTeacherRepository(
      source: <TeacherProfile>[if (profile != null) profile],
    ),
    groups: base.groups,
    bookings: base.bookings,
    schedules: base.schedules,
    messages: base.messages,
    chats: base.chats,
    notifications: base.notifications,
    reviews: base.reviews,
    favorites: base.favorites,
    admin: base.admin,
  );
}

TeacherProfile _profile(TeacherProfileStatus status, {String? note}) {
  return TeacherProfile(
    id: 'demo-teacher-1',
    displayName: 'أ. سارة الخطيب',
    subject: 'الرياضيات',
    stage: 'الثانوية العامة',
    area: 'المعادي',
    bio: 'شرح مبسّط للجبر مع تدريبات محلولة بعد كل حصة.',
    status: status,
    governorate: 'القاهرة',
    reviewNote: note,
  );
}

Future<SessionController> _pumpTeacherHome(
  WidgetTester tester,
  TeacherProfile? profile,
) async {
  usePhoneSurface(tester);
  final AppServices services = _servicesWith(profile);
  final SessionController session = SessionController(services.auth)
    ..startDemoSession(UserRole.teacher);

  await tester.pumpWidget(
    _host(const TeacherHomeScreen(), services, session),
  );
  await tester.pumpAndSettle();
  return session;
}

/// نصوص التطوير التي يجب ألا تظهر لأي مستخدم في أي حالة.
const List<String> _developerTexts = <String>[
  'حساب تجريبي',
  'معاينة محلية',
  'وضع الزائر',
  'بيانات تجريبية',
  '(C-06)',
  '(C-15)',
  'Firebase',
  'Firestore',
  'معاينة',
];

void _expectNoDeveloperText() {
  for (final String text in _developerTexts) {
    expect(
      find.textContaining(text),
      findsNothing,
      reason: 'نص تطوير مرئي للمستخدم: «$text»',
    );
  }
}

void main() {
  group('بطاقة حالة الملف على الرئيسية', () {
    testWidgets('لا ملف ⇒ دعوة إنشاء واضحة وزر إجراء', (
      WidgetTester tester,
    ) async {
      await _pumpTeacherHome(tester, null);

      expect(find.byKey(const Key('teacher-onboarding-card')), findsOneWidget);
      expect(find.text('ملفك التعريفي بانتظارك'), findsOneWidget);
      expect(find.text('إنشاء ملف تعريفي'), findsOneWidget);
      expect(find.byKey(const Key('teacher-create-profile')), findsOneWidget);
      _expectNoDeveloperText();
    });

    testWidgets('زر الإنشاء يفتح نموذج الملف', (WidgetTester tester) async {
      await _pumpTeacherHome(tester, null);

      await tester.tap(find.byKey(const Key('teacher-create-profile')));
      await tester.pumpAndSettle();

      // انتقلنا إلى نموذج التعديل/الإنشاء (شريط عنوانه معروف).
      expect(find.text('تعديل المعلومات'), findsOneWidget);
    });

    testWidgets('مسودة ⇒ «أكمل ملفك»', (WidgetTester tester) async {
      await _pumpTeacherHome(tester, _profile(TeacherProfileStatus.draft));

      expect(
        find.byKey(const Key('teacher-status-card-draft')),
        findsOneWidget,
      );
      expect(find.text('أكمل ملفك وأرسله للمراجعة'), findsOneWidget);
      _expectNoDeveloperText();
    });

    testWidgets('قيد المراجعة ⇒ طمأنة بلا مطالب', (
      WidgetTester tester,
    ) async {
      await _pumpTeacherHome(
        tester,
        _profile(TeacherProfileStatus.pendingReview),
      );

      expect(
        find.byKey(const Key('teacher-status-card-pendingReview')),
        findsOneWidget,
      );
      expect(find.text('ملفك قيد المراجعة'), findsOneWidget);
      expect(find.textContaining('لا تحتاج إلى أي خطوة الآن'), findsOneWidget);
      _expectNoDeveloperText();
    });

    testWidgets('موثّق ⇒ «يظهر للطلاب»', (WidgetTester tester) async {
      await _pumpTeacherHome(tester, _profile(TeacherProfileStatus.verified));

      expect(
        find.byKey(const Key('teacher-status-card-verified')),
        findsOneWidget,
      );
      expect(find.text('ملفك موثّق ويظهر للطلاب'), findsOneWidget);
      _expectNoDeveloperText();
    });

    testWidgets('مرفوض ⇒ يعرض سبب الإدارة كما كتبه المراجع', (
      WidgetTester tester,
    ) async {
      await _pumpTeacherHome(
        tester,
        _profile(
          TeacherProfileStatus.rejected,
          note: 'النبذة تحتوي بيانات تواصل خارج التطبيق.',
        ),
      );

      expect(
        find.byKey(const Key('teacher-status-card-rejected')),
        findsOneWidget,
      );
      expect(find.text('ملفك يحتاج تعديلًا'), findsOneWidget);
      expect(
        find.textContaining('النبذة تحتوي بيانات تواصل خارج التطبيق.'),
        findsOneWidget,
        reason: 'سبب الرفض معلومة يملكها المدرس، لا رمز داخلي',
      );
      _expectNoDeveloperText();
    });

    testWidgets('حالات الملف الأربع لا تعرض أي نص تطوير', (
      WidgetTester tester,
    ) async {
      for (final TeacherProfileStatus status in TeacherProfileStatus.values) {
        await _pumpTeacherHome(tester, _profile(status));
        _expectNoDeveloperText();
      }
    });
  });

  group('رئيسية الطالب: لا شريط تطوير', () {
    testWidgets('رئيسية الطالب نظيفة من نصوص التطوير', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final AppServices services = AppServices.demo();
      final SessionController session = SessionController(services.auth)
        ..startDemoSession(UserRole.student);

      await tester.pumpWidget(
        _host(const StudentHomeScreen(), services, session),
      );
      await tester.pumpAndSettle();

      _expectNoDeveloperText();
    });
  });
}
