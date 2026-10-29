import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/app.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

import '../helpers/test_app.dart';

/// خدمة مصادقة مزيّفة بلا Firebase: تعيد نتيجة محددة سلفًا.
class _StubAuthService implements AuthService {
  _StubAuthService({this.restoreResult});

  final AuthResult? restoreResult;
  UserRole? assignedRole;

  @override
  Future<AuthResult?> restoreSession() async => restoreResult;

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> signInWithGoogle() async =>
      const AuthNeedsRole(uid: 'uid-g', displayName: 'مستخدم Google');

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      throw const _FakeFailure();

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => AuthNeedsRole(uid: 'uid-r', displayName: displayName);

  @override
  Future<DateTime> requestAccountDeletion({required String uid}) async =>
      DateTime(2026, 11, 4);

  @override
  Future<void> restoreAccount({required String uid}) async {}

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? phone,
    String? stage,
  }) async {}

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async {
    assignedRole = role;
    return AppUser(id: uid, displayName: displayName, role: role);
  }
}

/// خطأ تجريبي بصيغة التطبيق.
class _FakeFailure implements Exception {
  const _FakeFailure();
}

/// يشغّل التطبيق بشاشة البداية وجلسة محددة مسبقًا.
Future<SessionController> _pumpApp(
  WidgetTester tester,
  AuthService auth,
) async {
  usePhoneSurface(tester);
  final AppServices services = AppServices(
    admin: DemoAdminRepository(),
    auth: auth,
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
  final SessionController session = SessionController(auth);
  await session.restore();

  await tester.pumpWidget(
    TeacherStudentApp(services: services, session: session),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return session;
}

void main() {
  group('شاشة الدخول (P4)', () {
    testWidgets('تعرض الدخول بـGoogle والبريد، وتوضّح أن الخادم غير مُهيَّأ', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const DemoAuthService());

      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
      expect(find.text('الدخول بالبريد الإلكتروني'), findsOneWidget);
      expect(
        find.textContaining('المصادقة الحقيقية غير مُهيَّأة'),
        findsOneWidget,
      );
    });

    testWidgets('زر البريد يفتح شاشة الدخول بالبريد', (
      WidgetTester tester,
    ) async {
      await _pumpApp(tester, const DemoAuthService());

      await tapVisible(tester, find.text('الدخول بالبريد الإلكتروني'));

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('تسجيل الدخول'),
        ),
        findsOneWidget,
      );
      expect(find.text('لدي حساب'), findsOneWidget);
      expect(find.text('حساب جديد'), findsOneWidget);
    });
  });

  group('نموذج البريد الإلكتروني', () {
    Future<void> openForm(
      WidgetTester tester, {
      AuthService auth = const DemoAuthService(),
    }) async {
      await _pumpApp(tester, auth);
      await tapVisible(tester, find.text('الدخول بالبريد الإلكتروني'));
    }

    testWidgets('يرفض البريد الفارغ وكلمة المرور القصيرة', (
      WidgetTester tester,
    ) async {
      await openForm(tester);

      await tapVisible(tester, find.widgetWithText(FilledButton, 'دخول'));

      expect(find.text('البريد الإلكتروني مطلوب'), findsOneWidget);
      expect(find.text('كلمة المرور مطلوبة'), findsOneWidget);
    });

    testWidgets('يرفض صيغة بريد غير صحيحة', (WidgetTester tester) async {
      await openForm(tester);

      await tester.enterText(find.byType(TextFormField).first, 'بريد-خاطئ');
      await tester.enterText(find.byType(TextFormField).last, 'secret123');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'دخول'));

      expect(find.text('صيغة البريد غير صحيحة'), findsOneWidget);
    });

    testWidgets('الوضع «حساب جديد» يضيف الاسم وتأكيد كلمة المرور', (
      WidgetTester tester,
    ) async {
      await openForm(tester);

      await tapVisible(tester, find.text('حساب جديد'));

      expect(find.text('الاسم الكامل'), findsOneWidget);
      expect(find.text('تأكيد كلمة المرور'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'إنشاء الحساب'), findsOneWidget);
    });

    testWidgets('خطأ غير معروف يُعرض عربيًا داخل النموذج', (
      WidgetTester tester,
    ) async {
      // خدمة ترمي خطأ غير مصنّف: الواجهة يجب أن تعرض رسالة عربية عامة.
      await openForm(tester, auth: _StubAuthService());

      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret123');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'دخول'));

      // الخدمة ترمي خطأ غير معروف ← رسالة عربية عامة تبقى ظاهرة في الصفحة.
      expect(find.textContaining('حدث خطأ غير متوقع'), findsOneWidget);
      // ولم نغادر النموذج (لم يُفتح الهيكل).
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.widgetWithText(FilledButton, 'دخول'), findsOneWidget);
    });

    testWidgets('الخدمة غير المُهيَّأة تُعرض برسالتها الصريحة', (
      WidgetTester tester,
    ) async {
      // الخدمة التجريبية ترمي AppException.unavailable.
      await openForm(tester);

      await tester.enterText(
        find.byType(TextFormField).first,
        'student@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret123');
      await tapVisible(tester, find.widgetWithText(FilledButton, 'دخول'));

      expect(find.text('الخدمة غير متاحة الآن'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });

  group('اختيار الدور عند أول دخول', () {
    testWidgets('الحساب بلا دور يُوجَّه لاختيار الدور لا للهيكل', (
      WidgetTester tester,
    ) async {
      await _pumpApp(
        tester,
        _StubAuthService(
          restoreResult: const AuthNeedsRole(
            uid: 'uid-1',
            displayName: 'مريم',
            email: 'maryam@example.com',
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('اختيار نوع الحساب'),
        ),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('أهلًا مريم'), findsOneWidget);
      expect(find.text('maryam@example.com'), findsOneWidget);
    });

    testWidgets('اختيار «طالب» يفتح الهيكل بواجهة الطالب', (
      WidgetTester tester,
    ) async {
      final _StubAuthService auth = _StubAuthService(
        restoreResult: const AuthNeedsRole(uid: 'uid-1', displayName: 'مريم'),
      );
      await _pumpApp(tester, auth);

      await tapVisible(tester, find.text('طالب'));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'متابعة'));

      expect(auth.assignedRole, UserRole.student);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('المدرسون'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('زر «متابعة» معطّل قبل الاختيار', (WidgetTester tester) async {
      await _pumpApp(
        tester,
        _StubAuthService(
          restoreResult: const AuthNeedsRole(uid: 'uid-1', displayName: 'مريم'),
        ),
      );

      final FilledButton button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'متابعة'),
      );
      expect(button.onPressed, isNull);
    });
  });
}
