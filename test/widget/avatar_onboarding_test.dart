import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:teacher_student_app/app/session/session_controller.dart';
import 'package:teacher_student_app/app/session/session_scope.dart';
import 'package:teacher_student_app/app/shell/app_shell.dart';
import 'package:teacher_student_app/core/theme/app_theme.dart';
import 'package:teacher_student_app/data/models/app_user.dart';
import 'package:teacher_student_app/data/models/auth_result.dart';
import 'package:teacher_student_app/data/models/user_avatar.dart';
import 'package:teacher_student_app/data/models/user_role.dart';
import 'package:teacher_student_app/data/services/app_services.dart';
import 'package:teacher_student_app/data/services/app_services_scope.dart';
import 'package:teacher_student_app/data/services/auth_service.dart';
import 'package:teacher_student_app/features/profile/domain/avatar_onboarding_policy.dart';
import 'package:teacher_student_app/features/profile/presentation/avatar_onboarding_screen.dart';

import '../helpers/test_app.dart';

/// (P31 — الإضافة الأخيرة) **شاشة اختيار الصورة الإلزامية للحساب الجديد.**
///
/// الحالات الثمانية المطلوبة، كل واحدة اختبار مستقل:
/// 1. فتح الشاشة دون اختيار ⇒ الزر معطّل.
/// 2. الضغط على الزر المعطّل ⇒ لا انتقال ولا حفظ.
/// 3. اختيار صورة من الثلاثين ⇒ تتغيّر المعاينة ويتفعّل الزر.
/// 4. تغيير الاختيار ⇒ تتغيّر المعاينة ومعها علامة التحديد.
/// 5. التأكيد ⇒ يُحفظ `avatarPreset` ويُسمح بالدخول (تختفي الشاشة).
/// 6. إغلاق التطبيق قبل التأكيد ⇒ العودة إلى الشاشة عند الدخول التالي.
/// 7. الصورة المحايدة لا تُحفظ كاختيار.
/// 8. الحسابات القديمة/المكتملة لا تُحجب.
///
/// **لماذا نبني `AppShell` لا الشاشة وحدها في بعض الحالات؟** لأن منع التجاوز
/// ليس في الشاشة، بل في أن الهيكل يعرضها **بدل** محتواه. اختبار الشاشة وحدها
/// لا يُثبت أن المستخدم لا يستطيع الوصول إلى الرئيسية.

/// خدمة مصادقة مزيّفة تمثّل مستندًا واحدًا في `users/{uid}`.
class _FakeAuth implements AuthService {
  _FakeAuth({this.preset, this.createdAt, this.role = UserRole.student});

  int? preset;
  DateTime? createdAt;
  UserRole role;

  AppUser get _user => AppUser(
    id: 'uid-new',
    displayName: 'طالب جديد',
    role: role,
    email: 'new@example.com',
    avatarPreset: preset,
    createdAt: createdAt,
  );

  @override
  Future<AuthResult?> restoreSession() async => AuthSignedIn(_user);

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthResult> signInWithGoogle() async => AuthSignedIn(_user);

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async => AuthSignedIn(_user);

  @override
  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async => AuthSignedIn(_user);

  @override
  Future<AppUser> assignRole({
    required String uid,
    required String displayName,
    required UserRole role,
    String? email,
  }) async => _user;

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

/// حزمة اختبار: خدمة مصادقة مزيّفة + خدمات تجريبية (ذاكرة، بلا Firebase).
({AppServices services, SessionController session}) _bundle(
  _FakeAuth auth,
) {
  final AppServices services = AppServices.demo();
  return (
    services: services,
    session: SessionController(auth, avatars: services.avatars),
  );
}

Widget _host(AppServices services, SessionController session) {
  return AppServicesScope(
    services: services,
    child: SessionScope(
      controller: session,
      child: MaterialApp(theme: AppTheme.light, home: const AppShell()),
    ),
  );
}

/// يقرأ أصل الصورة المعروضة في دائرة المعاينة (يفكّ غلاف `ResizeImage`).
String _previewAsset(WidgetTester tester) {
  final Image image = tester.widget<Image>(
    find.byKey(const Key('avatar-onboarding-preview')),
  );
  final ImageProvider<Object> provider = image.image;
  if (provider is ResizeImage) {
    final ImageProvider<Object> inner = provider.imageProvider;
    return inner is AssetImage ? inner.assetName : '';
  }
  return provider is AssetImage ? provider.assetName : '';
}

/// زر التأكيد: `null` = معطّل.
FilledButton _confirmButton(WidgetTester tester) =>
    tester.widget<FilledButton>(
      find.byKey(const Key('avatar-onboarding-confirm')),
    );

void main() {
  group('(P31) شاشة الاختيار الإلزامية — السلوك', () {
    testWidgets('1) بلا اختيار: الزر معطّل والمعاينة محايدة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();

      expect(find.byType(AvatarOnboardingScreen), findsOneWidget);
      expect(
        _previewAsset(tester),
        AvatarPresets.neutralPlaceholderAsset,
        reason: 'الدائرة تعرض صورة محايدة لا فراغًا',
      );
      expect(_confirmButton(tester).onPressed, isNull, reason: 'معطّل');
      expect(tester.takeException(), isNull);
    });

    testWidgets('2) الضغط على الزر المعطّل لا ينقل ولا يحفظ', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('avatar-onboarding-confirm')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      expect(find.byType(AvatarOnboardingScreen), findsOneWidget);
      expect(bundle.session.user!.avatarPreset, isNull);
      expect(bundle.session.needsAvatarSelection, isTrue);
      expect(
        await bundle.services.avatars.getFor('uid-new'),
        isNull,
        reason: 'لم تُكتب أي صورة رمزية',
      );
    });

    testWidgets('3) اختيار صورة: تتغيّر المعاينة ويتفعّل الزر', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();

      const int chosen = 1; // داخل القسم الأول، ظاهر بلا تمرير.
      await tester.tap(find.byKey(const Key('onboarding-avatar-$chosen')));
      await tester.pumpAndSettle();

      expect(_previewAsset(tester), AvatarPresets.all[chosen].asset);
      expect(_confirmButton(tester).onPressed, isNotNull, reason: 'مُفعّل');
    });

    testWidgets('4) تغيير الاختيار يغيّر المعاينة وعلامة التحديد', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('onboarding-avatar-0')));
      await tester.pumpAndSettle();
      expect(_previewAsset(tester), AvatarPresets.all[0].asset);

      await tester.tap(find.byKey(const Key('onboarding-avatar-2')));
      await tester.pumpAndSettle();

      expect(_previewAsset(tester), AvatarPresets.all[2].asset);
      // علامة الصح واحدة فقط، وتتبع الاختيار الأخير.
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-avatar-2')),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('onboarding-avatar-0')),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
    });

    testWidgets('5) التأكيد يحفظ الاختيار ويسمح بالدخول', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();

      const int chosen = 2;
      await tester.tap(find.byKey(const Key('onboarding-avatar-$chosen')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar-onboarding-confirm')));
      await tester.pumpAndSettle();

      expect(bundle.session.user!.avatarPreset, chosen);
      expect(bundle.session.needsAvatarSelection, isFalse);
      // الشاشة اختفت وحلّ الهيكل مكانها (الرئيسية متاحة الآن).
      expect(find.byType(AvatarOnboardingScreen), findsNothing);
      // والحفظ وصل لمستودع الصور (ما يراه الآخرون في `avatars/{uid}`).
      expect(
        (await bundle.services.avatars.getFor('uid-new'))?.presetId,
        chosen,
      );
    });

    testWidgets('6) إغلاق التطبيق قبل التأكيد يعيد الشاشة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();
      // اختار ثم أغلق التطبيق قبل الضغط على «تأكيد».
      await tester.tap(find.byKey(const Key('onboarding-avatar-1')));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      // «فتح التطبيق من جديد»: جلسة جديدة تقرأ نفس المستند (بلا اختيار).
      final ({AppServices services, SessionController session}) reopened =
          _bundle(auth);
      await reopened.session.restore();
      await tester.pumpWidget(
        _host(reopened.services, reopened.session),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AvatarOnboardingScreen), findsOneWidget);
      expect(reopened.session.user!.avatarPreset, isNull);
      expect(
        _previewAsset(tester),
        AvatarPresets.neutralPlaceholderAsset,
        reason: 'لا يُستأنف اختيار غير مؤكَّد',
      );
    });

    testWidgets('7) الصورة المحايدة لا تُحفظ كاختيار', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final _FakeAuth auth = _FakeAuth(createdAt: DateTime.now().toUtc());
      final ({AppServices services, SessionController session}) bundle =
          _bundle(auth);
      await bundle.session.restore();

      await tester.pumpWidget(_host(bundle.services, bundle.session));
      await tester.pumpAndSettle();

      // ليست ضمن الثلاثين أصلًا، ولا تُنتج `avatarPreset`.
      expect(
        AvatarPresets.all.any(
          (AvatarArtwork artwork) =>
              artwork.asset == AvatarPresets.neutralPlaceholderAsset,
        ),
        isFalse,
      );
      expect(bundle.session.user!.avatarPreset, isNull);
      expect(await bundle.services.avatars.getFor('uid-new'), isNull);
      expect(_confirmButton(tester).onPressed, isNull);
    });

    testWidgets('8) الحسابات القديمة والمكتملة تدخل مباشرة بلا شاشة', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);

      // (أ) حساب قديم قبل تاريخ العمل بالشاشة وبلا اختيار محفوظ.
      final _FakeAuth legacy = _FakeAuth(
        createdAt: AvatarOnboardingPolicy.cutover.subtract(
          const Duration(days: 200),
        ),
      );
      final ({AppServices services, SessionController session}) oldBundle =
          _bundle(legacy);
      await oldBundle.session.restore();
      await tester.pumpWidget(_host(oldBundle.services, oldBundle.session));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarOnboardingScreen), findsNothing);

      // (ب) حساب أكمل اختياره.
      final _FakeAuth completed = _FakeAuth(
        preset: 12,
        createdAt: DateTime.now().toUtc(),
      );
      final ({AppServices services, SessionController session}) doneBundle =
          _bundle(completed);
      await doneBundle.session.restore();
      await tester.pumpWidget(
        _host(doneBundle.services, doneBundle.session),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AvatarOnboardingScreen), findsNothing);
      expect(doneBundle.session.user!.avatarPreset, 12);
    });
  });

  group('(P31) سياسة الحجب', () {
    test('الحساب بلا تاريخ إنشاء لا يُحجب أبدًا', () {
      expect(
        AvatarOnboardingPolicy.isRequired(
          const AppUser(
            id: 'uid-legacy',
            displayName: 'قديم',
            role: UserRole.student,
          ),
        ),
        isFalse,
      );
    });

    test('الجلسة التجريبية لا تُحجب', () {
      expect(
        AvatarOnboardingPolicy.isRequired(
          AppUser(
            id: 'demo-student',
            displayName: 'زائر',
            role: UserRole.student,
            isDemoAccount: true,
            createdAt: DateTime.now().toUtc(),
          ),
        ),
        isFalse,
      );
    });

    test('الحساب الجديد بلا اختيار يُحجب', () {
      expect(
        AvatarOnboardingPolicy.isRequired(
          AppUser(
            id: 'uid-new',
            displayName: 'جديد',
            role: UserRole.teacher,
            createdAt: DateTime.now().toUtc(),
          ),
        ),
        isTrue,
      );
    });

    test('الحساب المكتمل لا يُحجب', () {
      expect(
        AvatarOnboardingPolicy.isRequired(
          AppUser(
            id: 'uid-new',
            displayName: 'جديد',
            role: UserRole.student,
            avatarPreset: 4,
            createdAt: DateTime.now().toUtc(),
          ),
        ),
        isFalse,
      );
    });
  });
}
