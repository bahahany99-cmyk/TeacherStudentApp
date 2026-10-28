import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/models/account_status.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/data/validation/account_deletion_rules.dart';

/// خدمة مصادقة مزيّفة تسجّل كل نداء، حتى نتحقق من **الترتيب** لا النتيجة فقط.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.restoreResult});

  AuthResult? restoreResult;

  final List<String> calls = <String>[];
  bool signedOut = false;

  /// موعد يُعاد من الطلب (يثبت أن الواجهة تعرض ما حُفظ لا ما حسبته).
  DateTime nextScheduledAt = DateTime.utc(2026, 11, 4, 12);

  @override
  Future<AuthResult?> restoreSession() async => restoreResult;

  @override
  Future<void> signOut() async {
    signedOut = true;
    calls.add('signOut');
  }

  @override
  Future<AuthResult> signInWithGoogle() async =>
      const AuthNeedsRole(uid: 'uid-g', displayName: 'مستخدم Google');

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
  Future<DateTime> requestAccountDeletion({required String uid}) async {
    calls.add('request:$uid');
    return nextScheduledAt;
  }

  @override
  Future<void> restoreAccount({required String uid}) async {
    calls.add('restore:$uid');
  }

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async => AppUser(id: uid, displayName: displayName, role: role);
}

AppUser _pendingUser({DateTime? scheduledAt}) => AppUser(
  id: 'uid-1',
  displayName: 'سارة',
  role: UserRole.teacher,
  email: 'sara@example.com',
  status: AccountStatus.pendingDeletion,
  scheduledDeletionAt: scheduledAt ?? DateTime.utc(2026, 11, 4, 12),
);

void main() {
  group('حالة الحساب في الجلسة (P17)', () {
    test('حساب مجدول للحذف لا يُعدّ مسجلًا للدخول', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: AuthPendingDeletion(_pendingUser()),
      );
      final SessionController session = SessionController(auth);

      await session.restore();

      expect(session.status, SessionStatus.pendingDeletion);
      expect(session.isSignedIn, isFalse);
      expect(session.isPendingDeletion, isTrue);
      // نحتفظ بالمستخدم لأن شاشة الاستعادة تحتاجه (الاسم/الموعد).
      expect(session.user, isNotNull);
      expect(session.user?.isPendingDeletion, isTrue);
      expect(session.scheduledDeletionAt, DateTime.utc(2026, 11, 4, 12));
      // ولا يدخل مسار اختيار الدور.
      expect(session.needsRoleSelection, isFalse);
    });

    test('حساب نشط: لا شيء يتغيّر عن السلوك السابق', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: AuthSignedIn(
          AppUser(id: 'uid-1', displayName: 'سارة', role: UserRole.student),
        ),
      );
      final SessionController session = SessionController(auth);

      await session.restore();

      expect(session.status, SessionStatus.signedIn);
      expect(session.isPendingDeletion, isFalse);
      expect(session.scheduledDeletionAt, isNull);
    });
  });

  group('طلب الحذف', () {
    test('يكتب في الخدمة أولًا ثم يسجّل الخروج ويعيد الموعد', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: AuthSignedIn(
          AppUser(id: 'uid-1', displayName: 'سارة', role: UserRole.teacher),
        ),
      );
      final SessionController session = SessionController(auth);
      await session.restore();

      final DateTime? scheduledAt = await session.requestAccountDeletion();

      expect(scheduledAt, DateTime.utc(2026, 11, 4, 12));
      // الترتيب: طلب الحذف قبل الخروج، وإلا خرج المستخدم بلا طلب مسجّل.
      expect(auth.calls, <String>['request:uid-1', 'signOut']);
      expect(auth.signedOut, isTrue);
      expect(session.status, SessionStatus.signedOut);
      expect(session.user, isNull);
      expect(session.isSignedIn, isFalse);
    });

    test('بلا جلسة: لا نداء ولا استثناء', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      final DateTime? scheduledAt = await session.requestAccountDeletion();

      expect(scheduledAt, isNull);
      expect(auth.calls, isEmpty);
    });

    test('الجلسة التجريبية: لا تلمس الخدمة وتُنهي الجلسة محليًا', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth)
        ..startDemoSession(UserRole.student);

      final DateTime before = DateTime.now();
      final DateTime? scheduledAt = await session.requestAccountDeletion();
      final DateTime after = DateTime.now();

      expect(auth.calls, <String>['signOut']);
      expect(session.status, SessionStatus.signedOut);
      expect(scheduledAt, isNotNull);
      // الموعد = الآن + مهلة السماح (بهامش تنفيذ الاختبار).
      final DateTime expectedMin = AccountDeletionRules.scheduledAt(before);
      final DateTime expectedMax = AccountDeletionRules.scheduledAt(after);
      expect(scheduledAt!.isBefore(expectedMin), isFalse);
      expect(scheduledAt.isAfter(expectedMax), isFalse);
    });
  });

  group('الاستعادة', () {
    test('تعيد الحالة نشطة وتُدخل الجلسة للتطبيق', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: AuthPendingDeletion(_pendingUser()),
      );
      final SessionController session = SessionController(auth);
      await session.restore();

      await session.restoreAccount();

      expect(auth.calls, <String>['restore:uid-1']);
      expect(session.status, SessionStatus.signedIn);
      expect(session.isSignedIn, isTrue);
      expect(session.isPendingDeletion, isFalse);
      expect(session.user?.status, AccountStatus.active);
      expect(session.user?.scheduledDeletionAt, isNull);
      // لا تحديث إضافي للشاشات عبر الخدمة.
      expect(auth.signedOut, isFalse);
    });

    test('حساب نشط: استعادة غير منطقية تُرفض بلا نداء', () async {
      final _FakeAuthService auth = _FakeAuthService(
        restoreResult: AuthSignedIn(
          AppUser(id: 'uid-1', displayName: 'سارة', role: UserRole.student),
        ),
      );
      final SessionController session = SessionController(auth);
      await session.restore();

      await expectLater(session.restoreAccount(), throwsStateError);
      expect(auth.calls, isEmpty);
      expect(session.status, SessionStatus.signedIn);
    });

    test('الجلسة التجريبية المعلّقة تُستعاد محليًا بلا خدمة', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth)
        ..startDemoSession(UserRole.teacher);

      // نحاكي المعلّق محليًا كما تفعل شاشة الاستعادة في المعاينة.
      final AppUser demoUser = session.user!.withAccountStatus(
        AccountStatus.pendingDeletion,
        scheduledDeletionAt: DateTime.utc(2026, 11, 4, 12),
      );
      final SessionController pendingSession = SessionController(auth);
      // مزيّف يعيد حالة «معلّق» تجريبية.
      auth.restoreResult = AuthPendingDeletion(demoUser);
      await pendingSession.restore();
      expect(pendingSession.isPendingDeletion, isTrue);

      await pendingSession.restoreAccount();

      expect(pendingSession.status, SessionStatus.signedIn);
      expect(pendingSession.user?.status, AccountStatus.active);
      // الجلسة التجريبية لا تُنشئ مستندًا: لا نداء استعادة.
      expect(auth.calls, isEmpty);
    });
  });
}
