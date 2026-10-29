import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/app.dart';
import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/demo/demo_repositories.dart';
import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';
import 'package:teacher_student_app/features/account/presentation/account_deletion_dialog.dart';

import '../helpers/test_app.dart';

/// خدمة مصادقة مزيّفة: تُعيد نتيجة محددة، وتسجّل نداءات الحذف/الاستعادة.
class _StubAuthService implements AuthService {
  _StubAuthService({this.restoreResult});

  AuthResult? restoreResult;
  final List<String> calls = <String>[];

  @override
  Future<AuthResult?> restoreSession() async => restoreResult;

  @override
  Future<void> signOut() async => calls.add('signOut');

  @override
  Future<AuthResult> signInWithGoogle() async =>
      const AuthNeedsRole(uid: 'uid-g', displayName: 'مستخدم Google');

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthSignedIn(
    AppUser(id: 'uid-1', displayName: 'سارة', role: UserRole.student),
  );

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => AuthNeedsRole(uid: 'uid-r', displayName: displayName);

  @override
  Future<DateTime> requestAccountDeletion({required String uid}) async {
    calls.add('request:$uid');
    return DateTime.now().add(AccountDeletionRules.gracePeriod);
  }

  @override
  Future<void> restoreAccount({required String uid}) async =>
      calls.add('restore:$uid');

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
  }) async => AppUser(id: uid, displayName: displayName, role: role);
}

AppServices _demoServices(AuthService auth) => AppServices(
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

/// يشغّل التطبيق من شاشة البداية بجلسة مستعادة من [auth].
Future<SessionController> _pumpApp(
  WidgetTester tester,
  AuthService auth,
) async {
  usePhoneSurface(tester);
  final SessionController session = SessionController(auth);
  await session.restore();

  await tester.pumpWidget(
    TeacherStudentApp(services: _demoServices(auth), session: session),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
  return session;
}

/// يفتح التطبيق كطالب تجريبي ويذهب إلى تبويب «حسابي».
Future<void> _openStudentProfile(WidgetTester tester) async {
  usePhoneSurface(tester);
  await tester.pumpWidget(buildTestApp());
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();

  await tapVisible(
    tester,
    find.widgetWithText(OutlinedButton, 'واجهة الطالب'),
  );
  await tapVisible(
    tester,
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('حسابي'),
    ),
  );
}

void main() {
  group('تسجيل الخروج من «حسابي» (P17)', () {
    testWidgets('زر «تسجيل الخروج» ظاهر داخل إعدادات الحساب', (
      WidgetTester tester,
    ) async {
      await _openStudentProfile(tester);

      expect(find.byKey(const Key('profile-sign-out')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('profile-sign-out')),
          matching: find.text(AccountDeletionRules.signOutAction),
        ),
        findsOneWidget,
      );
      // وزر الحذف منفصل في «منطقة الخطر».
      expect(find.byKey(const Key('profile-delete-account')), findsOneWidget);
    });

    testWidgets('يطلب تأكيدًا، ثم يخرج إلى شاشة الدخول', (
      WidgetTester tester,
    ) async {
      await _openStudentProfile(tester);

      await tapVisible(tester, find.byKey(const Key('profile-sign-out')));

      // الحوار معروض، ولم يحدث خروج بعد.
      expect(find.byKey(AccountDeletionKeys.signOutDialog), findsOneWidget);
      expect(find.text('المتابعة باستخدام Google'), findsNothing);

      await tapVisible(tester, find.byKey(AccountDeletionKeys.signOutConfirm));

      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('الإلغاء يُبقي المستخدم داخل التطبيق', (
      WidgetTester tester,
    ) async {
      await _openStudentProfile(tester);

      await tapVisible(tester, find.byKey(const Key('profile-sign-out')));
      await tapVisible(tester, find.byKey(AccountDeletionKeys.signOutCancel));

      expect(find.byKey(AccountDeletionKeys.signOutDialog), findsNothing);
      expect(find.byKey(const Key('profile-sign-out')), findsOneWidget);
    });
  });

  group('طلب حذف الحساب بمهلة 7 أيام (P17)', () {
    testWidgets('الحوار يشرح المهلة قبل أي كتابة', (
      WidgetTester tester,
    ) async {
      await _openStudentProfile(tester);

      await tapVisible(tester, find.byKey(const Key('profile-delete-account')));

      expect(find.byKey(AccountDeletionKeys.dialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(AccountDeletionKeys.dialog),
          matching: find.textContaining('7 أيام'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('لا يُحذف أي شيء الآن'), findsOneWidget);

      // الإلغاء لا يُخرج ولا يحذف.
      await tapVisible(tester, find.byKey(AccountDeletionKeys.cancel));
      expect(find.byKey(AccountDeletionKeys.dialog), findsNothing);
      expect(find.byKey(const Key('profile-delete-account')), findsOneWidget);
    });

    testWidgets('التأكيد يسجّل الطلب ويخرج إلى شاشة الدخول', (
      WidgetTester tester,
    ) async {
      await _openStudentProfile(tester);

      await tapVisible(tester, find.byKey(const Key('profile-delete-account')));
      await tapVisible(tester, find.byKey(AccountDeletionKeys.confirm));

      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
      // رسالة صادقة بأن الطلب مسجّل وأن هناك مهلة استعادة.
      expect(find.textContaining('طلبك مسجّل'), findsOneWidget);
    });

    testWidgets('الحساب الحقيقي: النداء يذهب للخدمة مرة واحدة', (
      WidgetTester tester,
    ) async {
      final _StubAuthService auth = _StubAuthService(
        restoreResult: AuthSignedIn(
          AppUser(id: 'uid-1', displayName: 'سارة', role: UserRole.student),
        ),
      );
      await _pumpApp(tester, auth);

      // الدخول مباشرة إلى الهيكل (الحساب نشط).
      await tapVisible(
        tester,
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('حسابي'),
        ),
      );
      await tapVisible(tester, find.byKey(const Key('profile-delete-account')));
      await tapVisible(tester, find.byKey(AccountDeletionKeys.confirm));

      expect(auth.calls, <String>['request:uid-1', 'signOut']);
      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
    });
  });

  group('شاشة الاستعادة (P17)', () {
    testWidgets('حساب معلّق داخل المهلة: زر الاستعادة يعمل ويُدخل التطبيق', (
      WidgetTester tester,
    ) async {
      final _StubAuthService auth = _StubAuthService(
        restoreResult: AuthPendingDeletion(
          AppUser(
            id: 'uid-1',
            displayName: 'سارة',
            role: UserRole.student,
            status: AccountStatus.pendingDeletion,
            scheduledDeletionAt: DateTime.now().add(const Duration(days: 3)),
          ),
        ),
      );
      final SessionController session = await _pumpApp(tester, auth);

      // التوجيه من شاشة البداية إلى الاستعادة، لا إلى الهيكل.
      expect(session.isPendingDeletion, isTrue);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('حسابك مجدول للحذف'), findsOneWidget);
      expect(find.textContaining('3 أيام'), findsOneWidget);

      // `FilledButton.icon` ينشئ نوعًا فرعيًا، لذا نضغط النص لا النوع.
      await tapVisible(
        tester,
        find.text(AccountDeletionRules.restoreAction),
      );

      expect(auth.calls, <String>['restore:uid-1']);
      expect(session.status, SessionStatus.signedIn);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('حساب انتهت مهلته: لا زر استعادة، وتوضيح المسار', (
      WidgetTester tester,
    ) async {
      final _StubAuthService auth = _StubAuthService(
        restoreResult: AuthPendingDeletion(
          AppUser(
            id: 'uid-1',
            displayName: 'سارة',
            role: UserRole.student,
            status: AccountStatus.pendingDeletion,
            scheduledDeletionAt: DateTime.now().subtract(
              const Duration(days: 1),
            ),
          ),
        ),
      );
      await _pumpApp(tester, auth);

      expect(find.text(AccountDeletionRules.expiredNotice), findsOneWidget);
      expect(find.text(AccountDeletionRules.restoreAction), findsNothing);
      expect(auth.calls, isEmpty);
      // يبقى قادرًا على الخروج فقط.
      expect(find.text(AccountDeletionRules.signOutAction), findsOneWidget);
    });

    testWidgets('الخروج من شاشة الاستعادة يعود بشاشة الدخول', (
      WidgetTester tester,
    ) async {
      final _StubAuthService auth = _StubAuthService(
        restoreResult: AuthPendingDeletion(
          AppUser(
            id: 'uid-1',
            displayName: 'سارة',
            role: UserRole.student,
            status: AccountStatus.pendingDeletion,
            scheduledDeletionAt: DateTime.now().add(const Duration(days: 2)),
          ),
        ),
      );
      await _pumpApp(tester, auth);

      await tapVisible(
        tester,
        find.text(AccountDeletionRules.signOutAction),
      );

      expect(auth.calls, <String>['signOut']);
      expect(find.text('المتابعة باستخدام Google'), findsOneWidget);
    });
  });
}
