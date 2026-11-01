import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

/// (P31) الصورة الرمزية عند إنشاء الحساب: عشوائية، محفوظة، وثابتة.
///
/// **ما يجب أن يثبته هذا الملف:**
/// 1. الحساب الجديد (طالب أو مدرس) يحصل على صورة رمزية داخل 0..23.
/// 2. الاختيار يُحفظ في بيانات المستخدم ويُعاد كما هو عند الدخول التالي.
/// 3. لا يُعاد الاختيار عند فتح التطبيق أو تسجيل الخروج والدخول.
/// 4. التوزيع يغطّي المعرض كله ولا ينحاز لصورة واحدة.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.storedPreset, this.role = UserRole.student});

  /// ما «تحفظه» قاعدة البيانات للحساب (يحاكي `users/{uid}`).
  int? storedPreset;
  UserRole role;

  int assignRoleCalls = 0;
  bool signedOut = false;

  @override
  Future<AuthResult?> restoreSession() async => AuthSignedIn(
    AppUser(
      id: 'uid-existing',
      displayName: 'طالب قديم',
      role: role,
      avatarPreset: storedPreset,
    ),
  );

  @override
  Future<void> signOut() async {
    signedOut = true;
  }

  @override
  Future<AuthResult> signInWithGoogle() async => const AuthNeedsRole(
    uid: 'uid-google',
    displayName: 'مستخدم Google',
    email: 'user@example.com',
  );

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthNeedsRole(uid: 'uid-google', displayName: 'مستخدم');

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => AuthNeedsRole(uid: 'uid-new', displayName: displayName);

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async {
    assignRoleCalls++;
    this.role = role;
    // نفس عقد الخادم: يُكتب الاختيار مرة واحدة فقط، ولا يُعاد تعيينه.
    storedPreset ??= AvatarPresets.randomIndexFor(uid);
    return AppUser(
      id: uid,
      displayName: displayName,
      role: role,
      email: email,
      avatarPreset: storedPreset,
    );
  }

  @override
  Future<DateTime> requestAccountDeletion({required String uid}) async =>
      DateTime(2030);

  @override
  Future<void> restoreAccount({required String uid}) async {}

  @override
  Future<void> updateProfile({
    required String uid,
    required String displayName,
    String? phone,
    String? stage,
  }) async {}
}

void main() {
  group('(P31) تعيين صورة رمزية للحساب الجديد', () {
    test('الطالب الجديد يحصل على صورة رمزية داخل المعرض', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      await session.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await session.completeRoleSelection(UserRole.student);

      final AppUser user = session.user!;
      expect(user.role, UserRole.student);
      expect(user.avatarPreset, isNotNull);
      expect(user.avatarPreset, inInclusiveRange(0, AvatarPresets.count - 1));
      expect(auth.storedPreset, user.avatarPreset, reason: 'حُفظت في البيانات');
    });

    test('المدرس الجديد أيضًا يحصل على صورة رمزية', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      await session.registerWithEmail(
        email: 'teacher@example.com',
        password: 'secret123',
        displayName: 'أ. جديد',
      );
      await session.completeRoleSelection(UserRole.teacher);

      expect(session.user!.role, UserRole.teacher);
      expect(
        session.user!.avatarPreset,
        inInclusiveRange(0, AvatarPresets.count - 1),
      );
    });

    test('تسجيل الدخول مرة أخرى لا يعيد الاختيار', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController first = SessionController(auth);

      await first.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await first.completeRoleSelection(UserRole.student);
      final int assigned = first.user!.avatarPreset!;

      // «إعادة فتح التطبيق»: جلسة جديدة تقرأ نفس المستند.
      final SessionController second = SessionController(auth);
      await second.restore();

      expect(second.user!.avatarPreset, assigned);
      expect(second.user!.resolvedAvatarPreset, assigned);
    });

    test('تسجيل الخروج ثم الدخول لا يغيّر الصورة', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      await session.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await session.completeRoleSelection(UserRole.student);
      final int assigned = session.user!.avatarPreset!;

      await session.signOut();
      expect(auth.signedOut, isTrue);
      expect(session.user, isNull);

      final SessionController again = SessionController(auth);
      await again.restore();
      expect(again.user!.avatarPreset, assigned);
    });

    test('حساب قديم بلا اختيار يظهر بصورة رمزية حتمية (لا فراغ)', () async {
      final _FakeAuthService auth = _FakeAuthService(storedPreset: null);
      final SessionController session = SessionController(auth);
      await session.restore();

      final AppUser user = session.user!;
      expect(user.avatarPreset, isNull);
      expect(user.resolvedAvatarPreset, AvatarPresets.forId(user.id));
      expect(
        AvatarPresets.all[user.resolvedAvatarPreset].asset,
        startsWith('assets/avatars/'),
      );
    });

    test('تغيير الصورة لاحقًا يظهر في الجلسة', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);
      await session.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await session.completeRoleSelection(UserRole.student);
      final int assigned = session.user!.avatarPreset!;
      final int target = assigned == 5 ? 6 : 5;

      await session.updateAvatarPreset(target);
      expect(session.user!.avatarPreset, target);
    });
  });

  group('(P31) عشوائية التعيين وتوزيعه', () {
    test('البذرة نفسها ⇒ نفس الصورة (تعيين قابل للتكرار)', () {
      for (int seed = 0; seed < 20; seed++) {
        final int first = AvatarPresets.randomIndexFor('uid-$seed', entropy: seed);
        final int again = AvatarPresets.randomIndexFor('uid-$seed', entropy: seed);
        expect(again, first);
      }
    });

    test('البذور المختلفة تعطي أكثر من صورة على الحسابات الجديدة', () {
      final Set<int> seen = <int>{
        for (int i = 0; i < 60; i++)
          AvatarPresets.randomIndexFor('new-user-$i', entropy: i * 7919),
      };
      // 60 حسابًا على 24 صورة: التوقّع يغطي معظم المعرض. الحدّ هنا متحفظ حتى
      // لا يكون الاختبار هشًّا أمام تغيير طفيف في الخلط.
      expect(seen.length, greaterThanOrEqualTo(12));
      expect(seen.every((int id) => id >= 0 && id < AvatarPresets.count), isTrue);
    });

    test('بلا بذرة: النتيجة دائمًا صالحة (عشوائية آمنة)', () {
      for (int i = 0; i < 50; i++) {
        final int index = AvatarPresets.randomIndexFor('uid-$i');
        expect(index, inInclusiveRange(0, AvatarPresets.count - 1));
      }
    });

    test('المعرّف الفارغ لا ينكسر', () {
      expect(
        AvatarPresets.randomIndexFor('', entropy: 1),
        inInclusiveRange(0, AvatarPresets.count - 1),
      );
    });
  });
}
