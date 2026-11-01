import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';

/// (P31 — الإضافة الأخيرة) **اختيار الصورة عند التسجيل: يدوي لا عشوائي.**
///
/// **ما يجب أن يثبته هذا الملف:**
/// 1. إنشاء الحساب (طالب أو مدرس) **لا يعيّن** صورة تلقائيًا ولا عشوائيًا.
/// 2. الحساب الجديد بلا اختيار يُوجب شاشة الاختيار الإلزامية.
/// 3. التأكيد يحفظ `avatarPreset` فيبقى الاختيار بعد إعادة التشغيل والدخول.
/// 4. مغادرة التطبيق قبل التأكيد تُبقي الحساب «ناقص الاختيار».
/// 5. الحسابات المكتملة لا تُحجب، وأي حساب بلا صورة يُحجب مهما كان تاريخه.
class _FakeAuthService implements AuthService {
  _FakeAuthService({this.storedPreset, this.createdAt});

  /// ما «تحفظه» قاعدة البيانات للحساب (يحاكي `users/{uid}`).
  int? storedPreset;

  /// تاريخ إنشاء الحساب — معلومة وصفية فقط، **لا تدخل في قرار الحجب**.
  DateTime? createdAt;

  UserRole role = UserRole.student;

  int assignRoleCalls = 0;
  bool signedOut = false;

  AppUser get stored => AppUser(
    id: 'uid-existing',
    displayName: 'مستخدم',
    role: role,
    avatarPreset: storedPreset,
    createdAt: createdAt,
  );

  @override
  Future<AuthResult?> restoreSession() async => AuthSignedIn(stored);

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
  }) async => const AuthNeedsRole(uid: 'uid-google', displayName: 'مستخدم');

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
    // عقد الخادم الجديد: **لا كتابة لـ`avatarPreset`** عند اختيار الدور.
    createdAt ??= DateTime.now().toUtc();
    return AppUser(
      id: uid,
      displayName: displayName,
      role: role,
      email: email,
      avatarPreset: storedPreset,
      createdAt: createdAt,
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
  group('(P31) التسجيل لا يعيّن صورة تلقائيًا', () {
    test('الطالب الجديد يصل بلا اختيار وتُطلب منه الشاشة الإلزامية', () async {
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
      expect(user.avatarPreset, isNull, reason: 'لا قرعة ولا تعيين تلقائي');
      expect(auth.storedPreset, isNull, reason: 'لم يُكتب شيء للخادم');
      expect(session.needsAvatarSelection, isTrue);
      // لكن العرض لا يكون فارغًا أبدًا: الاحتياط الحتمي يعمل.
      expect(
        user.resolvedAvatarPreset,
        AvatarPresets.forId(user.id),
        reason: 'الخلفية تُعرض بالاحتياط الحتمي إلى أن يختار',
      );
    });

    test('المدرس الجديد أيضًا بلا تعيين تلقائي', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      await session.registerWithEmail(
        email: 'teacher@example.com',
        password: 'secret123',
        displayName: 'أ. جديد',
      );
      await session.completeRoleSelection(UserRole.teacher);

      expect(session.user!.role, UserRole.teacher);
      expect(session.user!.avatarPreset, isNull);
      expect(session.needsAvatarSelection, isTrue);
    });

    test('التأكيد يحفظ الاختيار ويُغلق الشاشة', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);

      await session.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await session.completeRoleSelection(UserRole.student);
      expect(session.needsAvatarSelection, isTrue);

      await session.completeAvatarSelection(17);

      expect(session.user!.avatarPreset, 17);
      expect(session.needsAvatarSelection, isFalse);
    });

    test('الاختيار يبقى بعد إعادة فتح التطبيق وبعد الخروج والدخول', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController first = SessionController(auth);

      await first.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await first.completeRoleSelection(UserRole.student);
      await first.completeAvatarSelection(9);
      auth.storedPreset = 9; // ما كتبه `setPreset` على الخادم

      final SessionController reopened = SessionController(auth);
      await reopened.restore();
      expect(reopened.user!.avatarPreset, 9);
      expect(reopened.needsAvatarSelection, isFalse);

      await reopened.signOut();
      final SessionController again = SessionController(auth);
      await again.restore();
      expect(again.user!.avatarPreset, 9);
      expect(again.needsAvatarSelection, isFalse);
    });

    test('إغلاق التطبيق قبل التأكيد ⇒ العودة إلى الشاشة عند الدخول', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController first = SessionController(auth);

      await first.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await first.completeRoleSelection(UserRole.student);
      // المستخدم أغلق التطبيق بلا تأكيد: لا شيء كُتب.

      final SessionController reopened = SessionController(auth);
      await reopened.restore();
      expect(reopened.user!.avatarPreset, isNull);
      expect(reopened.needsAvatarSelection, isTrue);
    });

    test('حساب بلا اختيار يُحجب حتى لو كان تاريخ إنشائه قديمًا', () async {
      // أُلغي استثناء «الحساب القديم»: التطبيق تجريبي ولا حسابات قدامى حقيقية،
      // والقاعدة البسيطة هي أن غياب `avatarPreset` = لم يكمل الاختيار.
      final _FakeAuthService auth = _FakeAuthService(
        createdAt: DateTime.utc(2024, 3, 3),
      );
      final SessionController session = SessionController(auth);
      await session.restore();

      final AppUser user = session.user!;
      expect(user.avatarPreset, isNull);
      expect(session.needsAvatarSelection, isTrue);
      // والعرض نفسه لا يكون فارغًا: الاحتياط الحتمي يظهر في ملفه فقط.
      expect(user.resolvedAvatarPreset, AvatarPresets.forId(user.id));
    });

    test('حساب بلا تاريخ إنشاء وبلا اختيار يُحجب أيضًا', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);
      await session.restore();

      expect(session.user!.createdAt, isNull);
      expect(session.user!.avatarPreset, isNull);
      expect(session.needsAvatarSelection, isTrue);
    });

    test('قيمة محفوظة خارج المدى تُعامَل كعدم اختيار وتُحجب', () async {
      final _FakeAuthService auth = _FakeAuthService(storedPreset: 42);
      final SessionController session = SessionController(auth);
      await session.restore();

      expect(session.needsAvatarSelection, isTrue);
    });

    test('حساب أكمل اختياره سابقًا لا يُحجب', () async {
      final _FakeAuthService auth = _FakeAuthService(storedPreset: 22);
      final SessionController session = SessionController(auth);
      await session.restore();

      expect(session.user!.avatarPreset, 22);
      expect(session.needsAvatarSelection, isFalse);
    });

    test('الجلسة التجريبية وجلسة الإدارة لا تُحجبان', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController demo = SessionController(auth)
        ..startDemoSession(UserRole.student);
      expect(demo.needsAvatarSelection, isFalse);

      final _FakeAuthService adminAuth = _FakeAuthService(
        createdAt: DateTime.now().toUtc(),
      )..role = UserRole.admin;
      final SessionController admin = SessionController(adminAuth);
      await admin.restore();
      expect(admin.user!.role, UserRole.admin);
      expect(admin.needsAvatarSelection, isFalse);
    });

    test('تغيير الصورة لاحقًا من البطاقة ما زال يعمل', () async {
      final _FakeAuthService auth = _FakeAuthService();
      final SessionController session = SessionController(auth);
      await session.registerWithEmail(
        email: 'new@example.com',
        password: 'secret123',
        displayName: 'طالب جديد',
      );
      await session.completeRoleSelection(UserRole.student);
      await session.completeAvatarSelection(3);

      await session.updateAvatarPreset(8);
      expect(session.user!.avatarPreset, 8);
    });
  });

  // أدوات السحب العشوائي بقيت في النموذج لأنها تُستخدم في أدوات الترحيل
  // وحسابات العرض، **لكنها لم تعد تُستدعى عند التسجيل إطلاقًا** (الاختيار
  // يدوي). نُثبت هنا أنها ما زالت سليمة ومقيّدة بنطاق الدور، حتى لا تُستعمل
  // مستقبلًا استعمالًا يخالف القاعدة.
  group('(P31) أدوات السحب العشوائي — نطاق الدور', () {
    test('البذرة نفسها ⇒ نفس الصورة (تعيين قابل للتكرار)', () {
      for (int seed = 0; seed < 20; seed++) {
        final int first = AvatarPresets.randomIndexFor('uid-$seed', entropy: seed);
        final int again = AvatarPresets.randomIndexFor('uid-$seed', entropy: seed);
        expect(again, first);
      }
    });

    test('البذور المختلفة توزّع الحسابات الجديدة على صور متعدّدة', () {
      // بلا دور معروف يكون النطاق **محايدًا** (بالغون فقط)، فلا يصحّ انتظار
      // تغطية المعرض كله؛ الصحيح أن يتوزّع الحساب على أكثر من صورة داخل
      // النطاق المسموح، وألّا يخرج عنه أبدًا.
      final List<int> pool = AvatarPresets.assignmentPool(
        AvatarAudience.unspecified,
      );
      final Set<int> seen = <int>{
        for (int i = 0; i < 60; i++)
          AvatarPresets.randomIndexFor('new-user-$i', entropy: i * 7919),
      };
      expect(
        seen.length,
        greaterThanOrEqualTo(3),
        reason: 'التوزيع يجب ألا يحصر الحسابات على صورة واحدة',
      );
      expect(
        seen.every(pool.contains),
        isTrue,
        reason: 'كل اختيار تلقائي يبقى داخل النطاق المحايد',
      );
      expect(
        seen.every((int id) => id >= 0 && id < AvatarPresets.count),
        isTrue,
      );
    });

    test('السحب التلقائي يحترم جمهور الدور ولا يختار فئة غير مناسبة', () {
      // المدرّس: بالغون وكبار سن فقط (لا طفل ولا مراهق).
      final List<int> teacherPool = AvatarPresets.assignmentPool(
        AvatarPresets.audienceForRole(UserRole.teacher),
      );
      expect(teacherPool.length, 12);
      for (int i = 0; i < 80; i++) {
        final int id = AvatarPresets.randomIndexFor('teacher-$i', entropy: i);
        final int picked = AvatarPresets.randomIndexFor(
          'teacher-$i',
          entropy: i,
          audience: AvatarPresets.audienceForRole(UserRole.teacher),
        );
        final AvatarCategory category = AvatarPresets.all[picked].category;
        expect(
          <AvatarCategory>[
            AvatarCategory.adultMan,
            AvatarCategory.adultWoman,
            AvatarCategory.olderMan,
            AvatarCategory.olderWoman,
          ],
          contains(category),
        );
        expect(teacherPool, contains(picked));
        // النطاق الافتراضي المحايد لا يُنتج أطفالًا إطلاقًا.
        expect(
          <AvatarCategory>[
            AvatarCategory.boyChild,
            AvatarCategory.girlChild,
            AvatarCategory.boyTeen,
            AvatarCategory.girlTeen,
          ],
          isNot(contains(AvatarPresets.all[id].category)),
        );
      }

      // الطالب: أطفال/مراهقون/شباب — لا كبار سن ولا بالغون.
      for (int i = 0; i < 80; i++) {
        final int picked = AvatarPresets.randomIndexFor(
          'student-$i',
          entropy: i * 17,
          audience: AvatarPresets.audienceForRole(UserRole.student),
        );
        expect(
          <AvatarCategory>[
            AvatarCategory.boyChild,
            AvatarCategory.girlChild,
            AvatarCategory.boyTeen,
            AvatarCategory.girlTeen,
            AvatarCategory.youngMan,
            AvatarCategory.youngWoman,
          ],
          contains(AvatarPresets.all[picked].category),
        );
      }
    });

    test('الدور المجهول ⇒ نطاق محايد من البالغين', () {
      expect(
        AvatarPresets.audienceForRole(null),
        AvatarAudience.unspecified,
      );
      expect(
        AvatarPresets.audienceForRole(UserRole.admin),
        AvatarAudience.unspecified,
      );
      for (final int id in AvatarPresets.assignmentPool(
        AvatarAudience.unspecified,
      )) {
        expect(
          AvatarPresets.all[id].category,
          anyOf(AvatarCategory.adultMan, AvatarCategory.adultWoman),
        );
      }
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
