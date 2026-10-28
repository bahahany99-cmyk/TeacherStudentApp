import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

/// خدمة مصادقة مزيّفة: تسمح باختبار منطق الجلسة بلا Firebase ولا شبكة.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.restoreResult});

  AuthResult? restoreResult;

  int assignRoleCalls = 0;
  UserRole? assignedRole;
  bool signedOut = false;

  @override
  Future<AuthResult?> restoreSession() async => restoreResult;

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<AuthResult> signInWithGoogle() async => AuthNeedsRole(
    uid: 'uid-google',
    displayName: 'مستخدم Google',
    email: 'user@example.com',
  );

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthSignedIn(
    AppUser(id: 'uid-email', displayName: 'طالب', role: UserRole.student),
  );

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => AuthNeedsRole(uid: 'uid-new', displayName: displayName);

  @override
  Future<DateTime> requestAccountDeletion({required String uid}) async =>
      DateTime(2026, 11, 4);

  @override
  Future<void> restoreAccount({required String uid}) async {}

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async {
    assignRoleCalls++;
    assignedRole = role;
    return AppUser(
      id: uid,
      displayName: displayName,
      role: role,
      email: email,
    );
  }
}

void main() {
  group('دورة اختيار الدور (P4)', () {
    test('حساب بلا دور ← needsRole لا signedIn', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: const AuthNeedsRole(
          uid: 'uid-1',
          displayName: 'مستخدم جديد',
          email: 'new@example.com',
        ),
      );
      final SessionController session = SessionController(auth);

      await session.restore();

      expect(session.status, SessionStatus.needsRole);
      expect(session.needsRoleSelection, isTrue);
      expect(session.isSignedIn, isFalse);
      expect(session.role, isNull);
      expect(session.pendingDisplayName, 'مستخدم جديد');
      expect(session.pendingEmail, 'new@example.com');
    });

    test('اختيار الدور يُحفظ مرة واحدة ويحوّل الحالة إلى signedIn', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: const AuthNeedsRole(uid: 'uid-1', displayName: 'سارة'),
      );
      final SessionController session = SessionController(auth);
      await session.restore();

      await session.completeRoleSelection(UserRole.teacher);

      expect(auth.assignRoleCalls, 1);
      expect(auth.assignedRole, UserRole.teacher);
      expect(session.status, SessionStatus.signedIn);
      expect(session.isSignedIn, isTrue);
      expect(session.role, UserRole.teacher);
      expect(session.isDemoSession, isFalse);
    });

    test('الدخول التالي يقرأ الدور من الخادم بلا شاشة اختيار', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: const AuthSignedIn(
          AppUser(id: 'uid-2', displayName: 'أحمد', role: UserRole.student),
        ),
      );
      final SessionController session = SessionController(auth);

      await session.restore();

      expect(session.needsRoleSelection, isFalse);
      expect(session.isSignedIn, isTrue);
      expect(session.role, UserRole.student);
    });

    test('اختيار الدور بلا حساب ينتظر مرفوض', () async {
      final SessionController session = SessionController(
        _FakeAuthService(restoreResult: null),
      );
      await session.restore();

      expect(
        () => session.completeRoleSelection(UserRole.student),
        throwsA(isA<StateError>()),
      );
    });

    test('الدخول بالبريد يعطي مستخدمًا بدور من الخادم', () async {
      final SessionController session = SessionController(_FakeAuthService());

      await session.signInWithEmail(
        email: 'student@example.com',
        password: 'secret123',
      );

      expect(session.isSignedIn, isTrue);
      expect(session.role, UserRole.student);
    });

    test('التسجيل الجديد يحتاج اختيار الدور', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      await session.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'مريم',
      );

      expect(session.needsRoleSelection, isTrue);
      expect(session.pendingDisplayName, 'مريم');
    });

    test('تسجيل الخروج يمرّ إلى الخدمة ويصفّر الحالة', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: const AuthSignedIn(
          AppUser(id: 'uid-3', displayName: 'سارة', role: UserRole.teacher),
        ),
      );
      final SessionController session = SessionController(auth);
      await session.restore();

      await session.signOut();

      expect(auth.signedOut, isTrue);
      expect(session.status, SessionStatus.signedOut);
      expect(session.user, isNull);
      expect(session.isSignedIn, isFalse);
    });

    test('الجلسة التجريبية معلَّمة ولا تُخلط بالمصادقة الحقيقية', () {
      final SessionController session = SessionController(_FakeAuthService());

      session.startDemoSession(UserRole.student);

      expect(session.isDemoSession, isTrue);
      expect(session.role, UserRole.student);
      expect(session.status, SessionStatus.signedIn);
    });
  });
}
